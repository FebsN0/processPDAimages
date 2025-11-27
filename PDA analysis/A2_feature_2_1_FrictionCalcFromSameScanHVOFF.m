function [avg_fc,FitOrderHVOFF_Height,offsetHVonWithHVoff] = A2_feature_2_1_FrictionCalcFromSameScanHVOFF(idxMon,mainPath,flagSingleSectionProcess,varargin)
    p=inputParser();
    argName = 'FitOrderHVOFF_Height';       defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'idxSectionHVon';             defaultVal = [];     addOptional(p,argName,defaultVal, @(x) (isnumeric(x) || isempty(x)));
    parse(p,varargin{:});
    FitOrderHVOFF_Height=p.Results.FitOrderHVOFF_Height;    
    idxSectionHVon=p.Results.idxSectionHVon;
    clear p varargin argName defaultVal
    flagStartHeightProcess=true;
    % check if data HoverModeOFF post Height fitting has already been made
    if exist(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat'),"file")
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat')); %#ok<LOAD>     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHECK LATER        
        flagStartHeightProcess=false;
    elseif exist(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat'),"file")
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat'),"allData");
    % prepare the data , or if already extracted, upload. Even if this
    % function is called under specific section in HoverModeON, extract the
    % data from any section of HoverModeOFF    
    else
        HVoffPath=fullfile(mainPath,'HoverMode_OFF');
        allData=A1_openANDprepareAFMdata('filePath',HVoffPath,'frictionData',"Yes");
        save(fullfile(HVoffPath,'resultsData_1_extractAFMdata'),"allData");
    end    
    % in case the user chose to process single sections, create the dedicated dir
    if flagSingleSectionProcess
        SaveFigSingleSectionsFolder=fullfile(mainPath,'HoverMode_OFF',"Results singleSectionProcessing");     
        % final path of the subfolder where to store figures for each section
        SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",idxSectionHVon));
        if ~exist(SaveFigIthSectionFolder,"dir")        
            % create nested folder with subfolders
            mkdir(SaveFigIthSectionFolder)                       
        end        
        filePathResultsFriction=SaveFigIthSectionFolder;
        imageType='SingleSection';
        clear SaveFigIthSectionFolder SaveFigSingleSectionsFolder pathDataSingleSectionsHV_OFF
    else
        if ~exist(fullfile(HVoffPath,"Results Processing AFM for friction coefficient"),"dir")
            % create dir where store the friction results for the assembled (no single processed sections) to avoid to save them into the
            % same crowded directory of HVon results.
            filePathResultsFriction=fullfile(HVoffPath,"Results Processing AFM for friction coefficient");
            mkdir(filePathResultsFriction)
            imageType='Assembled';
        end
    end           
    clear HVoffPath
    % if this function is called under the specific section of HoverMode ON (therefore, processing single section before assembling), the concept
    % of estimate friction will be different from an assembled AFM image. If the postHeight channel has been already processed, it is stored
    % in HoverMode_OFF\resultsData_2_postHeight.mat    
    if flagSingleSectionProcess
        % check if results of post height channel step of the specific section were already made.
        [~,nameSection,~]=fileparts(allData(idxSectionHVon).filenameSection);
        fileName=fullfile(filePathResultsFriction,sprintf("%s_heightChannelProcessed.mat",nameSection));                
        if exist(fileName,"file")
            question=sprintf("PostHeightChannelProcess file .mat (HoverModeOFF-FrictionPart) for the section %d already exists. Take it?",idxSectionHVon);
            if getValidAnswer(question,"",{'y','n'})
                load(fileName,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata")
                flagStartHeightProcess=false;
            end
            clear fileName question
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% HEIGHT PROCESSING %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % in case never processed, start the height channel process. However, since the Height Channel of HoverMode ON has been
    % already processed and in principle it should be same. Check if it is still take it to save time
    if flagStartHeightProcess     
        if flagSingleSectionProcess
            dataPreProcess=allData(idxSectionHVon).AFMImage_Raw;
            metadata=allData(idxSectionHVon).metadata;
            % path + filename = save the results for the specific section, to avoid to perform manual binarization everytime
            nameFileResultPostHeightProcess=fullfile(filePathResultsFriction,sprintf("%s_heightChannelProcessed.mat",nameSection));
        else
            % assembly part before process height
            %dataPreProcess
            %metadata
            nameFileResultPostHeightProcess=fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat');
        end
        [AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,FitOrderHVOFF_Height]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,filePathResultsFriction, ...
            'metadata',metadata,...
            'fitOrder',FitOrderHVOFF_Height, ...
            'imageType',imageType, ...
            'SeeMe',false, ...
            'HoverModeImage','HoverModeOFF');        
        save(nameFileResultPostHeightProcess,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata","filePathResultsFriction")            
    end
    clear nameFileResultPostHeightProcess flagStartHeightProcess allData   
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% FRICTION CALCULATION %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
    %[AFM_data,AFM_heightIO,maskRemoval] = featureRemovePortions(AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,idxMon);
    avg_fc=A2_feature_2_2_FrictionCalc_method_1_2(AFM_images_postHeightFit_HVOFF,metadata,AFM_height_IO_HV_OFF,idxMon,filePathResultsFriction,method,pixData,fOutlierRemoval,fOutlierRemoval_text);    
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


