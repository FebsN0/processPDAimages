clc, clear, close all
filePath='E:\1_mixingPCinTRCDA\AFM data\october-november-december 2024 sample 80x80 random align\1_3_1 TRCDA\friction';
secondMonitorMain=objInSecondMonitor;

% to extract the friction coefficient, choose which method use.
question=sprintf('Which method perform to extract the background friction coefficient?');
options={ ...
    sprintf('1) Average fast scan lines containing only background.\nUse the .jpk image containing only background'), ...
    sprintf('2) Masking PDA feature. Use the .jpk image containing both PDA and background\n(ReTrace Data required - Hover Mode OFF)'), ... 
    sprintf('3) Masking PDA + outlier removal features. Use the .jpk image containing both PDA and background\n(ReTrace Data required - Hover Mode OFF)')};
choice = getValidAnswer(question, '', options);   

% methods 2 and 3 require the .jpk file with HOVER MODE OFF but in the same condition (same scanned PDA area
% of when HOVER MODE is ON)
switch choice
    % method 1 : get the friction from ONLY BACKGROUND .jpk file experiments.
    case 1
        nameOperation = "backgroundOnly";
        [AFM_onlyBK,metadata_onlyBK,~,filePath,nameScan,idxRemovedPortion_onlyBK]=prepareData(nameOperation,secondMonitorMain,filePath);        
        fileResultPath=prepareDirResults(filePath);
        avg_fc=A1_frictionGlassCalc_method1(AFM_onlyBK,metadata_onlyBK,secondMonitorMain,fileResultPath,nameScan,idxRemovedPortion_onlyBK);
    % method 2 or 3 : get the friction from BACKGROUND+PDA .jpk file experiments.
    case {2, 3} 
        % METHOD 2 : MASKING ONLY
        % METHOD 3 : MASKING + OUTLIER REMOVAL
        if choice ==2
            nameOperation = "backgroundCrystal_maskOnly";
        else
            nameOperation = "backgroundCrystal_maskAndOutlierRemoval";
        end
        [AFM_onlyBK,metadata_onlyBK,AFM_heightIO_onlyBK,filePath,nameScan,idxRemovedPortion_onlyBK]=prepareData(nameOperation,secondMonitorMain,filePath);
        fileResultPath=prepareDirResults(filePath);
        resFit_friction=A1_frictionGlassCalc_method_2_3(AFM_onlyBK,metadata_onlyBK,AFM_heightIO_onlyBK,secondMonitorMain,fileResultPath,choice,nameScan,idxRemovedPortion_onlyBK);
end
clear question options
close all


function varargout=prepareData(nameOperation,secondMonitorMain,filePath)
    % prepare the data to calculate the friction, regardless the method.
    % AWARE: if using only background method, select the proper data. Here there is no check about the type of
    % scan. I.e. NO CHECK IF THE DATA IS BK ONLY or BK+crystal FROM WHICH REMOVE PDA USING METHOD 2 OR 3
    
    % select the main folder
    if isempty(filePath)
        filePath=uigetdir(pwd,sprintf('Locate the main directory where there are all the %s scan files',nameOperation));
    end
    if filePath==0
        error("Main folder not selected")
    end
    titleText='Select one or more only-BK scan experiment folders which each contains the sections saved in the directory "HoverMode_OFF"';
    % custom function to select multiple directories
    foldersScans=uigetdirMultiSelect(filePath,titleText);
    numDirs=length(foldersScans);
    % init the var where store the data
    AFM_onlyBK=cell(1,numDirs); 
    metadata_onlyBK=cell(1,numDirs);
    AFM_heightIO_onlyBK=cell(1,numDirs); 
    nameScans=cell(1,numDirs);
    idxRemovedPortion_onlyBK=cell(1,numDirs);

    for i=1:numDirs
        pathSingleScan=foldersScans{i};
        [~,nameScan,~]=fileparts(pathSingleScan);

        flag_exeA1=true;
        if exist(fullfile(pathSingleScan,"resultsOnlyBK.mat"),"file")
            pathResultsData=fullfile(pathSingleScan,"resultsOnlyBK.mat");
            question=sprintf('Results of %s already exists. Take it? If not, remove the previous one',nameScan);
            if  getValidAnswer(question,'',{'y','n'}) == 1
                load(pathResultsData,"metaData","AFM_data","AFM_heightIO","idxRemovedPortion")
                flag_exeA1=false;
            else
                delete(sprintf("%s/resultsOnlyBK.mat",pathSingleScan))
            end
        end

% method 1: AFM_onlyBK,metadata_onlyBK,secondMonitorMain,filePath
% method 2_3: metaDataHoverModeOFF.Alpha,AFM_HeightFittedMasked_HVOFF,AFM_height_IO_HVOFF,vertforceAVG_HVOff,secondMonitorMain,filePathHV,choice
        
        % if never processed, then pre process the AFM data and save the results
        if flag_exeA1
            [AFM_data,AFM_heightIO,metaData,~,setpointN,idxRemovedPortion]=A1_openANDassembly_JPK(secondMonitorMain,'backgroundOnly','Yes','filePath',pathSingleScan);
            save(fullfile(pathSingleScan,"resultsOnlyBK"),"metaData","AFM_data","AFM_heightIO","setpointN","idxRemovedPortion")
        end
        
        
        % before start pre process the lateral data, it is necessary manage it according to the
        % portions previously removed, otherwise it doesnt make any sense that feature.
        % in case of normal scans, it is not an issue, because the removed portion are trated as "background"
        % by using the minimum value. But here, it is exactly the opposite. So these values must be ignored
        
        % if ~isempty(idxRemovedPortion)
        %     % latDefl expressed in Volt
        %     latDefl_trace   = AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image;
        %     latDefl_retrace = AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_image;
        %     %avgValDataTrace= mean(latDefl_trace(:));
        %     %avgValDataReTrace= mean(latDefl_retrace(:));
        %     for j=1:size(idxRemovedPortion,1)
        %         % latDefl_trace(:,idxRemovedPortion(j,1):idxRemovedPortion(j,2))=avgValDataTrace;
        %         % latDefl_retrace(:,idxRemovedPortion(j,1):idxRemovedPortion(j,2))=avgValDataReTrace;
        %         latDefl_trace(:,idxRemovedPortion(j,1):idxRemovedPortion(j,2))=nan;
        %         latDefl_retrace(:,idxRemovedPortion(j,1):idxRemovedPortion(j,2))=nan;
        %     end
        %     AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image=latDefl_trace;
        %     AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image=latDefl_retrace;
        % end
        
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

function newFolder=prepareDirResults(filePath)
    % create a new directory where store the BK results of every processes scan
    newFolder=fullfile(filePath,"Results of All background scans");
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
