function [AFM_images_final,AFM_height_IO,metaData]=A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,varargin)

    p=inputParser(); 
    argName = 'SeeMe';          defaultVal = true;              addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'Normalization';  defaultVal = false;             addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'postHeat';       defaultVal = false;             addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    parse(p,varargin{:});
    SeeMe=p.Results.SeeMe;
    norm=p.Results.Normalization;

    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then
    % process? ASK only if the function is running with HOVER MODE ON. In
    % case of HOVER MODE OFF (friction), skip it because it will 
    typeProcessChoice=askTypeProcess(mainPath,SaveFigFolder);
    flag_processSingleSection=typeProcessChoice.flag;
    if flag_processSingleSection
        % main directory where there are the results of the sections
        startPathSingleSectionFolder=typeProcessChoice.folderSingleSectionData;
    end
    clear typeProcessChoice
    % if single section processing, process first the i-th section, then assembly. The assembly part is same for both methods (yes/no single section processing)
    if flag_processSingleSection
        for i=1:numFiles
            if i==1
                FitOrderHVON_Height='';
                FitOrderHVON_Lat='';
                FitOrderHVOFF_Height='';        
            end
        
            if i~=1 && isempty(FitOrderHVOFF_Height)
                firstFileLat=dir(fullfile(startPathSingleSectionFolder,"section_1","*_lateralChannelProcessed.mat"));
                load(fullfile(firstFileLat.folder,firstFileLat.name),"FitOrderHVON_Height","FitOrderHVON_Lat","FitOrderHVOFF_Height");
            end
            TypeSectionProcess="SingleSection";
            % check if results were already made.
            [~,nameSection,~]=fileparts(allData(i).filenameSection);
            % path of the subfolder where to store figures for each section
            SaveFigIthSectionFolder=fullfile(startPathSingleSectionFolder,sprintf("section_%d",i));
            fileName1=fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection));
            fileName2=fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection));
            flagProcHeight=true;
            % if Lateral Channel has already processed, load. NOTE: only
            % for the first run (HOVER MODE ON), since the second run
            % (HOVER MODE OFF), process is different
            if exist(fileName2,"file")
                question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    % each section has allData updated to the relative section.
                    load(fileName2,"allData")
                    continue
                end
            elseif exist(fileName1,"file")
                question=sprintf("PostHeightChannel file .mat (HoverModeON-normal) for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    if i==1
                        load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO","FitOrderHVON_Height")
                    else
                        load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO")
                    end
                    flagProcHeight=false;
                end
            end
            fprintf("\n$$$$$-----------------$$$$\n$$ PROCESSING SECTION %d $$\n$$$$$-----------------$$$$\n",i)
            if flagProcHeight
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS HEIGHT CHANNEL AND GENERATE MASK %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
                % First, given the ith-section, create subfolder where store figures for each section and results                
                if ~exist(SaveFigIthSectionFolder,'dir')
                    mkdir(SaveFigIthSectionFolder)
                end
                % extract the data
                dataPreProcess=allData(i).AFMImage_Raw;
                metaDataPreProcess=allData(i).metadata;                                
                % note: setpointsList = [] because the function is processing single sections
                [AFM_HeightFittedMasked,AFM_height_IO,FitOrderHVON_Height]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,SaveFigIthSectionFolder,'fitOrder',FitOrderHVON_Height,'imageType',TypeSectionProcess,'metadata',metaDataPreProcess,'SeeMe',false);                
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO","FitOrderHVON_Height")                
            end
            clear question fileName*
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           
            metaData_AFM=allData(i).metadata; 


            if ~p.Results.postHeat % save time in case of postHeat AFM data
                [AFM_LatDeflecFitted_Force,metricsPlane,metricsLine,FitOrderHVON_Lat,FitOrderHVOFF_Height,avg_fc]=A2_feature_2_processLateralChannel(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM,idxMon,SaveFigIthSectionFolder,mainPath, ...
                    'FitOrderHVON_Lat',FitOrderHVON_Lat,'FitOrderHVOFF_Height',FitOrderHVOFF_Height,'SeeMe',false,'idxSectionHVon',i,'flagSingleSectionProcess',true);
                allData(i).metadata.frictionCoeff_Used=avg_fc;
                % prepare the info about the used fitting
                if ~isempty(metricsLine)
                    infoLine=" - LineByLineFit";
                else
                    infoLine="";
                end
                infoPlane=metricsPlane.fitOrder;
                allData(i).metadata.fittingInfo=sprintf("PlaneFit: %s%s",infoPlane,infoLine);
                allData(i).AFMImage_PostProcess=AFM_LatDeflecFitted_Force;
                allData(i).AFMmask_heightIO=AFM_height_IO;     
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"allData","FitOrderHVON_Height","FitOrderHVOFF_Height","FitOrderHVON_Lat") 
            end
            close all            
        end
    end

    % ASSEMBLY!
    [AFM_images,AFM_height_IO,metaData] = A2_feature_sortAndAssemblySections(allData,otherParameters,flag_processSingleSection);  
    
    % in case of no single section processing, now process the assembled image
    if ~flag_processSingleSection
        [AFM_images_postHeight,AFM_height_IO]=A2_feature_1_processHeightChannel(AFM_images,idxMon,SaveFigFolder,'SeeMe',SeeMe,'Normalization',norm, ...
            'imageType','Assembled','metadata',metaData);
        AFM_images_final=A2_feature_2_processLateralChannel(AFM_images_postHeight,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigFolder,mainPath, ...
            'FitOrder',accuracy,'SeeMe',SeeMe,'Normalization',norm);        
    else
        % show and save figures post assembly BEFORE processing in case of singleSection processing.
        % In case of processing after assembling, it will be done already inside A2_feature_1_processHeightChannel
        A1_feature_CleanOrPrepFiguresRawData(AFM_images,'AFM_IO',AFM_height_IO,'metadata',metaData, ...
        'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'SeeMe',false, ...
        'imageType','Assembled','Normalization',norm,'postProcessed',false)
        AFM_images_final=AFM_images;
    end
    % show results post processing. Common for both processing type (singleSection or postAssembly)
    A1_feature_CleanOrPrepFiguresRawData(AFM_images_final,'AFM_IO',AFM_height_IO,'metadata',metaData, ...
        'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'SeeMe',false, ...
        'imageType','Assembled','Normalization',norm,'postProcessed',true)
end      
    
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTION %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

function typeProcessChoice=askTypeProcess(varargin)    
    mainPath=varargin{1};
    startPathResults=fullfile(mainPath,"HoverMode_ON","Results singleSectionProcessing");
    flag_processSingleSection=true;    
    % if exist, dont ask and start automatically section processing
    if ~exist(startPathResults,"dir")
        % For the normal AFM postprocessing, ask if PROCESS PRE ASSEMBLY.
        % If YES, create another directory containing a directory for each section where to store the results of single sections processing
        question= sprintf('Process single sections before assembling?');
        if getValidAnswer(question,'', {'Yes','No'})
            mkdir(startPathResults)
        else
            flag_processSingleSection=false;
            startPathResults=varargin{2};
        end             
    else
        fprintf("\nSingle section processing directory already exist. Automatically start the single section processing!\n\n")
    end
    typeProcessChoice.folderSingleSectionData=startPathResults;
    typeProcessChoice.flag=flag_processSingleSection;    
end

