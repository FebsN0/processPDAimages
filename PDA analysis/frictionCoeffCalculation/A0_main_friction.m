function varargout=A0_main_friction(varargin)
    clc, close all
    filePath=[]; filesDirs=[];
    for i=1:length(varargin)
        if i==1
            filePath=varargin{1};
        elseif i==2
            filesDirs=varargin{2};
        end
    end
    clear varargin

    % example of input
    %{
        filePath='E:\1_mixingPCinTRCDA\AFM data\september 2024 small samples 40x40 few correct\1_1_1 TRCDA 10mM 10uL 12_9_2024\friction';
        filesDirs={'E:\1_mixingPCinTRCDA\AFM data\september 2024 small samples 40x40 few correct\1_1_1 TRCDA 10mM 10uL 12_9_2024\friction\1_HVoff'
            'E:\1_mixingPCinTRCDA\AFM data\september 2024 small samples 40x40 few correct\1_1_1 TRCDA 10mM 10uL 12_9_2024\friction\3_HVoff'          
            'E:\1_mixingPCinTRCDA\AFM data\september 2024 small samples 40x40 few correct\1_1_1 TRCDA 10mM 10uL 12_9_2024\friction\4_HVoff'          
            'E:\1_mixingPCinTRCDA\AFM data\september 2024 small samples 40x40 few correct\1_1_1 TRCDA 10mM 10uL 12_9_2024\friction\6 air background'};
            'E:\1_mixingPCinTRCDA\AFM data\october-november-december 2024 sample 80x80 random align\1_3_1 TRCDA\friction\5_bkonly'   
            'E:\1_mixingPCinTRCDA\AFM data\october-november-december 2024 sample 80x80 random align\1_3_1 TRCDA\friction\6_bkonly'   };
    %}
    secondMonitorMain=objInSecondMonitor;    
    % to extract the friction coefficient, choose which method use.
    question=sprintf('Which method perform to extract the background friction coefficient? (NOTE: AFM data with Hover Mode OFF)');
    options={ ...
        sprintf('1) Average entire fast scan lines.\n(NOTE: use the .jpk image containing ONLY background!)'), ...
        sprintf('2) Average entire fast scan lines + Masking PDA.\n(Recommended for .jpk image containing both PDA and background)'), ... 
        sprintf('3) Average entire fast scan lines + Masking PDA + Edges and Outliers Removal.\n(Recommended for .jpk image containing both PDA and background)')};
    method = getValidAnswer(question, '', options);   
    clear question options
    
    switch method
        % method 1 : get the friction from ONLY BACKGROUND .jpk file experiments.
        case 1
            nameOperation = "backgroundOnly";
        % method 2 or 3 : get the friction from BACKGROUND+PDA .jpk file experiments.
        case 2
            nameOperation = "backgroundCrystal_maskOnly";
        case 3
            nameOperation = "backgroundCrystal_maskAndOutlierRemoval";
            [pixData,fOutlierRemoval,fOutlierRemoval_text]=prepareSettingsPixel;
    end
    
    [AFM_onlyBK,metadata_onlyBK,AFM_heightIO_onlyBK,filePath,nameScan,idxRemovedPortion_onlyBK]=prepareData(nameOperation,secondMonitorMain,filePath,filesDirs);        
    clear i filesDirs
    if method == 3
        fileResultPath=prepareDirResults(filePath,method,fOutlierRemoval,fOutlierRemoval_text);
        [resFit_friction,definitiveFrictionCoeff]=A1_frictionCalc_method_1_2_3(AFM_onlyBK,metadata_onlyBK,AFM_heightIO_onlyBK,secondMonitorMain,fileResultPath,method,nameScan,idxRemovedPortion_onlyBK,pixData,fOutlierRemoval,fOutlierRemoval_text);
        fOutlierRemovalXfile=sprintf('_%d',fOutlierRemoval);
    else    
        fileResultPath=prepareDirResults(filePath,method);
        resFit_friction=A1_frictionCalc_method_1_2_3(AFM_onlyBK,metadata_onlyBK,AFM_heightIO_onlyBK,secondMonitorMain,fileResultPath,method,nameScan,idxRemovedPortion_onlyBK);
        fOutlierRemovalXfile='';
    end
    close all    
    varargout{1}=resFit_friction;
    if exist("definitiveFrictionCoeff","var")
        varargout{2}=definitiveFrictionCoeff;
    end
    nameFiledata=fullfile(fileResultPath,sprintf('dataResults_method%d%s',method,fOutlierRemovalXfile));
    save(nameFiledata,"resFit_friction",'-v7.3')
    clear AFM_onlyBK metadata_onlyBK AFM_heightIO_onlyBK nameScan secondMonitorMain fileResultPath method fOutlierRemoval* pixData idxRemovedPortion_onlyBK filePath nameOperation nameFiledata filesDirs
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTIONS %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%------- CLEARING THE DATA BY REMOVING SPECIFIC REGION OR ENTIRE FAST SCAN LINE REGION -------%%%%%%%%
function [AFM_data_cleared,AFM_heightIO_cleared,idxRemovedPortion]=removePortions(AFM_data,AFM_heightIO,secondMonitorMain,filepath)
% before start pre-process the lateral data, it may be necessary to manually remove portions which contains 
% outliers by substuting the values with the minimum. For better details, see the documentation of the function
    [AFM_data_cleared,AFM_heightIO_cleared,idxRemovedPortion]=A3_featureRemovePortion(AFM_data,AFM_heightIO,secondMonitorMain);
    % show the results  
    AFM_height_cleared=AFM_data_cleared(1).AFM_image;
    textTitle='Height (measured) channel - Masked, Fitted, Optimized, portions removed';
    idImg=4;
    textColorLabel='Height (nm)'; 
    textNameFile=sprintf('%s/resultA4_4_OptFittedHeightChannel_PortionRemoved.tif',filepath);
    showData(secondMonitorMain,false,idImg,AFM_height_cleared,true,textTitle,textColorLabel,textNameFile)
    % fig is invisible
    close gcf

    textTitle='Baseline and foreground processed - portions removed';
    idImg=5;
    textNameFile=sprintf('%s/resultA4_5_BaselineForeground_PortionRemoved.tif',filepath);
    showData(secondMonitorMain,false,idImg,AFM_heightIO_cleared,false,textTitle,'',textNameFile,true)
    % fig is invisible
    close gcf
end

%%%%%%%%%%%------- PREPARE THE AFM DATA -------%%%%%%%%%%%
function varargout=prepareData(nameOperation,secondMonitorMain,filePath,foldersScans)
    % prepare the data to calculate the friction, regardless the method.
    % AWARE: if using first method, select the proper data (background only).
    % Here there is no check about the type of scan.
    % Method 1 is recommended only for BK ONLY data
    % Method 2 and 3 are ok for every type (BK only and BK+PDA data)

    % select the main folder
    if isempty(filePath)
        filePath=uigetdir(pwd,sprintf('Locate the main directory where there are all the %s scan files',nameOperation));
    end
    if ~ischar(filePath)
        error("Main folder not selected")
    end
    if isempty(foldersScans)
        titleText='Select one or more only-BK scan experiment folders which each contains the sections saved in the directory "HoverMode_OFF"';
        % custom function to select multiple directories
        foldersScans=uigetdirMultiSelect(filePath,titleText);
    end
    if ~iscell(foldersScans)
        error("Data Folders not selected")
    end
    numDirs=length(foldersScans);
    % init the var where store the data
    AFM_onlyBK=cell(1,numDirs); 
    metadata_onlyBK=cell(1,numDirs);
    AFM_heightIO_onlyBK=cell(1,numDirs); 
    nameScans=cell(1,numDirs);
    idxRemovedPortion_onlyBK=cell(1,numDirs);    
    takeAll_auto=[];
    for i=1:numDirs
        clear answer
        pathSingleScan=foldersScans{i};
        [~,nameScan,~]=fileparts(pathSingleScan);
        flag_exeA1=true;
        % check if the pre-processing of AFM data (sections assembly and height optimization) are already done
        if exist(fullfile(pathSingleScan,"resultsOnlyBK.mat"),"file")
            pathResultsData=fullfile(pathSingleScan,"resultsOnlyBK.mat");
            question1=sprintf('Results of %s already exists. Take it? If not, remove the previous one.',nameScan);
            question2='Choose ''A'' to take the results in every selected directories if it already exists.';
            if isempty(takeAll_auto)
                question=sprintf('%s\n%s',question1,question2); options={'Yes','No','A'}; defV=3;
                % ask only once
                takeAll_auto=false;
            else
                question=question1; options={'y','n'};        defV=1;
            end
            if ~takeAll_auto
                answer=getValidAnswer(question,'',options,defV);
                if answer==3, takeAll_auto=true; end
            end
            if takeAll_auto || answer == 1
                load(pathResultsData,"metaData","AFM_data","AFM_heightIO","idxRemovedPortion")
                flag_exeA1=false;               
            else
                delete(sprintf("%s/resultsOnlyBK.mat",pathSingleScan))
            end
        end
        % if never processed, then pre process the AFM data and save the results
        if flag_exeA1
            [AFM_data,AFM_heightIO,metaData,filepathResults,setpointN]=A1_openANDassembly_JPK(secondMonitorMain,'backgroundOnly','Yes','filePath',pathSingleScan);
            % remove manually regions
            [AFM_data,AFM_heightIO,idxRemovedPortion]=removePortions(AFM_data,AFM_heightIO,secondMonitorMain,filepathResults);
            save(fullfile(pathSingleScan,"resultsOnlyBK"),"metaData","AFM_data","AFM_heightIO","setpointN","idxRemovedPortion")
        end                        
        AFM_onlyBK{i}=AFM_data;
        metadata_onlyBK{i}=metaData;
        AFM_heightIO_onlyBK{i}=AFM_heightIO;
        idxRemovedPortion_onlyBK{i}=idxRemovedPortion;
        nameScans{i}=nameScan;
        clear metaData AFM_data AFM_heightIO
    end
    varargout{1}=AFM_onlyBK;
    varargout{2}=metadata_onlyBK;
    varargout{3}=AFM_heightIO_onlyBK;
    varargout{4}=filePath;
    varargout{5}=nameScans;
    varargout{6}=idxRemovedPortion_onlyBK;
end

%%%%%%%%%%%------- SETTING PARAMETERS FOR THE EDGE REMOVAL -------%%%%%%%%%%%
function newFolder=prepareDirResults(filePath,method,fOutlierRemoval,fOutlierRemoval_text)
    % create a new directory where store the BK results of every processes scan
    if method == 3
        details=sprintf(' - option %d - %s',fOutlierRemoval,fOutlierRemoval_text);
    else
        details='';
    end
    nameNewDir=sprintf('Results of All background scans - method %d%s',method,details);
    newFolder=fullfile(filePath,nameNewDir);
    if exist(newFolder, 'dir')
        question= sprintf('Directory already exists and it may already contain previous results.\nDo you want to overwrite it or create new directory?');
        options= {'Keep the dir','Overwrite the existing dir','Create a new dir','Select another existing dir'};
        answer=getValidAnswer(question,'',options);
        if answer == 2
            rmdir(newFolder, 's');
            mkdir(newFolder);
        elseif answer==3
            % create new directory with different name
            nameFolder = inputdlg('Enter the name new folder','',[1 80]);
            newFolder = fullfile(filePath,nameFolder{1});
            mkdir(newFolder);
            clear nameFolder
        elseif answer==4
            newFolder=uigetdir(filePath,'Select the dir where store the results');
        end
    else
        mkdir(newFolder);
    end
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