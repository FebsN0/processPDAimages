function avg_fc = A2_feature_2_1_FrictionCalcFromSameScanHVOFF(idxMon,mainPath,flagSingleSectionProcess,idxSectionHVon)
    % to extract the friction coefficient, choose which method use.
    question=sprintf('Which method perform to extract the background friction coefficient? (NOTE: AFM data with Hover Mode OFF)');
    options={ ...
        sprintf('1) Average entire fast scan lines + Masking PDA.'), ... 
        sprintf('2) Average entire fast scan lines + Masking PDA + Edges and Outliers Removal.')};
    method = getValidAnswer(question, '', options);   
    clear question options
    switch method
        case 1
             pixData=[]; fOutlierRemoval=[]; fOutlierRemoval_text=[];
        case 2
            [pixData,fOutlierRemoval,fOutlierRemoval_text]=prepareSettingsPixel;
    end

    % check if data HoverModeOFF post Height fitting has already been made
    if exist(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat'),"file")
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat')); %#ok<LOAD>     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHECK LATER
    
    % prepare the data , or if already extracted, upload. Even if this
    % function is called under specific section in HoverModeON, extract the
    % data from any section of HoverModeOFF    
    elseif ~exist(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat'),"file")
        HVoffPath=fullfile(mainPath,'HoverMode_OFF');
        [allData,~,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',HVoffPath,'frictionData',"Yes");
        save(fullfile(HVoffPath,'resultsData_1_extractAFMdata'));
        if flagSingleSectionProcess && ~exist(fullfile(HVoffPath,"dataSingleSections"),"dir")
            mkdir(fullfile(HVoffPath,"dataSingleSections"))
            mkdir(fullfile(HVoffPath,"dataSingleSections","Results singleSectionsProcessing"))
        end
    else
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat')); %#ok<LOAD>
    end

    % if this function is called under the specific section of HoverMode ON
    % (therefore, processing single section before assembling), the concept
    % of estimate friction will be different from an assembled AFM image.
    if flagSingleSectionProcess
        pathDataSingleSectionsHV_OFF=fullfile(mainPath,'HoverMode_OFF',"dataSingleSections");     
        SaveFigSingleSectionsFolder=fullfile(pathDataSingleSectionsHV_OFF,"Results singleSectionsProcessing");
        % check if results were already made.
        [~,nameSection,~]=fileparts(allData(idxSectionHVon).filenameSection);
        % path of the subfolder where to store figures for each section
        SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",idxSectionHVon));
        fileName=fullfile(pathDataSingleSectionsHV_OFF,sprintf("%s_heightChannelProcessed.mat",nameSection));
        
        flagStartHeightProcess=true;
        if exist(fileName,"file")
            question=sprintf("PostHeightChannel file .mat (HoverModeOFF-FrictionPart) for the section %d already exists. Take it?",idxSection);
            if getValidAnswer(question,"",{'y','n'})
                load(fileName,"AFM_HeightFittedMasked","AFM_height_IO")
                flagStartHeightProcess=false;
            end
        end
        % in case never processed, start the height channel processing.
        % However, since the Height Channel of HoverMode ON has been
        % already processed and in principle it should be same. Check if it
        % is still take it to save time
        if flagStartHeightProcess
            % find the saved figures of HV_ON for the specific section: open its figure and extract the data from it
            pathDirectoryFigSingleSectionsHV_ON=fullfile(mainPath,'HoverMode_ON',"dataSingleSections","Results singleSectionsProcessing",sprintf("section_%d",idxSectionHVon),"figImages");
            files_figHV_ON_mask=dir(fullfile(pathDirectoryFigSingleSectionsHV_ON, 'resultA3_4_BaselineForeground_iteration*'));
            % usually only one file (iteration 1), but just in case take the last iteration if any (which is already 1 in case of only one iteration)
            file_figHV_ON_mask_lastIteration=fullfile(files_figHV_ON_mask(end).folder, files_figHV_ON_mask(end).name);
            hFig = openfig(file_figHV_ON_mask_lastIteration, 'visible'); title(sprintf("Mask of the %d-th section - HOVER MODE ON (normal scan)",idxSectionHVon),"FontSize",16)
            ax = findobj(hFig, 'Type', 'axes');      % get axes handle(s)
            img = findobj(ax, 'Type', 'image');      % get image object(s)
            mask_sectionHV_ON = get(img, 'CData');   % extract matrix data
            clear pathDirectoryFigSingleSectionsHV_ON files_figHV_ON_mask file_figHV_ON_mask_lastIteration
           
            dataPreProcess=allData(idxSectionHVon).AFMImage_Raw;
            [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_processHeightChannel(dataPreProcess,SaveFigIthSectionFolder,idxMon,"Low",'imageType','SingleSection');                
            % save the results for the specific section, to avoid to perform manual binarization
            save(fullfile(pathDataSingleSectionsHV_OFF,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO") 
        end
        
        metadata=allData(idxSectionHVon).metadata;
        filePathResults=pathDataSingleSectionsHV_OFF;
    else
        filePathResults=SaveFigFolder;
    end
    
    [AFM_data,AFM_heightIO,maskRemoval] = featureRemovePortions(AFM_HeightFittedMasked,AFM_height_IO,idxMon);
    avg_fc=A5_featureFrictionCalc_method_1_2(AFM_data,metadata,AFM_heightIO,idxMon,filePathResults,method,maskRemoval,pixData,fOutlierRemoval,fOutlierRemoval_text);    
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTIONS %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
    
%%%%%%%%%%%------- SETTING PARAMETERS FOR THE EDGE REMOVAL -------%%%%%%%%%%%
function [pixData,fOutlierRemoval,fOutlierRemoval_text]=prepareSettingsPixel   
    % the user has to choose:
    % 1) the number of points to remove in from a single edge BK-crystal, which contains the spike values
    % 2) the step size (i.e. in each iteration, the size pixel increases until the desired number of point    
    question= 'Choose the modality of removal outliers';
    options={ ...
    sprintf('1) Apply outlier removal to each segment after pixel reduction.'), ...
    sprintf('2) Apply outlier removal to one large connected segment after pixel reduction.'),...
    sprintf('3) Apply outlier removal to entire same-setpoint section.')};                
    fOutlierRemoval = getValidAnswer(question, '', options);
    if fOutlierRemoval==1
        fOutlierRemoval_text='SingleSegmentsProcess';
    elseif fOutlierRemoval==2
        fOutlierRemoval_text='ConnectedSegmentProcess';                                   
    else
        fOutlierRemoval_text='EntireSectionProcess';
    end
    % define the size of the pixel
    pixData=zeros(3,1);
    question ={'Maximum pixels to remove from both edges of a segment:' ...
        'Enter the step size of pixel loop:'...
        'Minimum number of elements in a section required for the fitting:'};
    defValues={'50' '2' '20'};
    while true
        pixData = str2double(inputdlg(question,'SETTING PARAMETERS FOR THE EDGE REMOVAL',[1 90],defValues));
        if any(isnan(pixData)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
        else, break
        end
    end
end



