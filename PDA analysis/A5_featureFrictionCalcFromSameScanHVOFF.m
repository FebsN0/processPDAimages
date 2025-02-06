function avg_fc = A5_featureFrictionCalcFromSameScanHVOFF(secondMonitorMain,mainPath)
    % to extract the friction coefficient, choose which method use.
    question=sprintf('Which method perform to extract the background friction coefficient? (NOTE: AFM data with Hover Mode OFF)');
    options={ ...
        sprintf('1) Average entire fast scan lines + Masking PDA.'), ... 
        sprintf('2) Average entire fast scan lines + Masking PDA + Edges and Outliers Removal.')};
    method = getValidAnswer(question, '', options);   
    clear question options
    switch method
        case 1
            fOutlierRemoval=''; fOutlierRemoval_text='';
        case 2
            [pixData,fOutlierRemoval,fOutlierRemoval_text]=prepareSettingsPixel;
    end
%    folderResultsImg=prepareDirResults(mainPath,method,fOutlierRemoval,fOutlierRemoval_text)
    [AFM,metadata,AFM_heightIO,maskRemoval,filePathResults]=prepareData(secondMonitorMain,fullfile(mainPath,'HoverMode_OFF'));        
    if method == 2
        avg_fc=A5_featureFrictionCalc_method_1_2(AFM,metadata,AFM_heightIO,secondMonitorMain,filePathResults,method,maskRemoval,pixData,fOutlierRemoval,fOutlierRemoval_text);
    else    
        avg_fc=A5_featureFrictionCalc_method_1_2(AFM,metadata,AFM_heightIO,secondMonitorMain,filePathResults,method,maskRemoval);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTIONS %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
    


%%%%%%%%%%%------- PREPARE THE AFM DATA HOVER MODE OFF -------%%%%%%%%%%%
function varargout=prepareData(secondMonitorMain,pathSingleScan)
    % prepare the data to calculate the friction, regardless the method.        
    flag_exeA1=true;
    pathResultsData=fullfile(pathSingleScan,"resultsData_1_postProcessA4_HVoff.mat");
    % check if the pre-processing of AFM data (sections assembly and height optimization) are already done
    if exist(pathResultsData,"file")
        tmp=strsplit(pathSingleScan,'\');
        nameScan=tmp{end-1}; clear tmp        
        question=sprintf('Results of the scan %s HoverModeOFF already exists. Take it? If not, remove the previous one.',nameScan);
        if getValidAnswer(question,'',{'Yes','No'})
            load(pathResultsData,"metaData","AFM_data","AFM_heightIO","maskRemoval","filepathResults")
            flag_exeA1=false;               
        else
            delete(pathResultsData)
        end
    end
        % if never processed, then pre process the AFM data and save the results
    if flag_exeA1
        [AFM_data,AFM_heightIO,metaData,filepathResults,setpointN]=A1_openANDassembly_JPK(secondMonitorMain,'backgroundOnly','Yes','filePath',pathSingleScan);
        % remove manually regions
        [AFM_data,AFM_heightIO,maskRemoval] = featureRemovePortions(AFM_data,AFM_heightIO,secondMonitorMain);
        % in case of removal, save the final images
        if ~isempty(maskRemoval)
            % show the results  
            titleData='Yellow = Removed Portions';
            nameFig=fullfile(filepathResults,"resultA4_5_RemovedPortions.tif");
            showData(secondMonitorMain,false,4,maskRemoval,false,titleData,'',nameFig,'Binarized','Yes')
            AFM_height_cleared=AFM_data(1).AFM_image;
            titleData='Height (measured) channel - Masked, Fitted, Optimized, portions removed';
            nameFig=fullfile(filepathResults,"resultA4_6_OptFittedHeightChannel_PortionRemoved.tif");
            textColorLabel='Height (nm)'; 
            showData(secondMonitorMain,false,5,AFM_height_cleared,true,titleData,textColorLabel,nameFig)
            titleData='Baseline and foreground processed - portions removed';
            nameFig=fullfile(filepathResults,"resultA4_7_BaselineForeground_PortionRemoved.tif");
            showData(secondMonitorMain,false,6,AFM_heightIO,false,titleData,'',nameFig,'Binarized','Yes')
        end
        save(fullfile(pathSingleScan,"resultsData_1_postProcessA4_HVoff"),"metaData","AFM_data","AFM_heightIO","setpointN","maskRemoval","filepathResults")
    end                        
    varargout{1}=AFM_data;
    varargout{2}=metaData;
    varargout{3}=AFM_heightIO;
    varargout{4}=maskRemoval;
    varargout{5}=filepathResults;
end

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



