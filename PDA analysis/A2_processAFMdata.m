function [dataAFM_assembled,AFM_height_IO_assembled,metadata,setpointN]=A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon)
  
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
    for i=1:numFiles
        if i==1
            FitOrderHVON_Height='';
            FitOrderHVON_Lat='';
            FitOrderHVOFF_Height='';        
        end
        % if single section processing, process first the i-th section, then assembly. The assembly part is same for both methods (yes/no single section processing)
        if flag_processSingleSection
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
            flagEnd=false;
            % if Lateral Channel has already processed, load. NOTE: only
            % for the first run (HOVER MODE ON), since the second run
            % (HOVER MODE OFF), process is different
            if exist(fileName2,"file")
                question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    load(fileName2,"allData")
                    flagEnd=true;
                end
            elseif exist(fileName1,"file")
                question=sprintf("PostHeightChannel file .mat (HoverModeON-normal) for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    if i==1
                        load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO","FitOrderHVON_Height")
                    else
                        load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO")
                    end
                end
            else
                % in case the HeightAFMprocess and LateralAFMprocess have never been done, then start it.
                % First, given the ith-section, create subfolder where store figures for each section and results                
                mkdir(SaveFigIthSectionFolder)
                % extract the data
                dataPreProcess=allData(i).AFMImage_Raw;
                metaDataPreProcess=allData(i).metadata;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS HEIGHT CHANNEL AND GENERATE MASK %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % note: setpointsList = [] because the function is processing single sections
                [AFM_HeightFittedMasked,AFM_height_IO,FitOrderHVON_Height]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,SaveFigIthSectionFolder,'fitOrder',FitOrderHVON_Height,'imageType',TypeSectionProcess,'metadata',metaDataPreProcess,'SeeMe',false);                
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO","FitOrderHVON_Height")                
            end
            clear question fileName*
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~flagEnd
                metaData_AFM=allData(i).metadata; 
                [AFM_LatDeflecFitted_Force,~,~,FitOrderHVON_Lat,FitOrderHVOFF_Height,avg_fc]=A2_feature_2_processLateralChannel(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigIthSectionFolder,mainPath, ...
                    'FitOrderHVON_Lat',FitOrderHVON_Lat,'FitOrderHVOFF_Height',FitOrderHVOFF_Height,'SeeMe',false,'idxSectionHVon',i,'flagSingleSectionProcess',true);
                allData(i).metadata.frictionCoeff_Used=avg_fc;
                allData(i).AFMImage_PostProcess=AFM_LatDeflecFitted_Force;
                allData(i).AFMmask_heightIO=AFM_height_IO;     
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"allData","FitOrderHVON_Height","FitOrderHVOFF_Height","FitOrderHVON_Lat") 
            end
            close all
        end
    end

    % ASSEMBLY!

    [dataAFM_assembled,AFM_height_IO_assembled,metadata,setpointN] = sortAndAssemblySections(allData,otherParameters,SaveFigFolder,flag_processSingleSection);
    


    % in case of no single section processing, now process the assembled image
    if ~flag_processSingleSection
        AFM_LatDeflecFitted=A5_LD_Baseline_Adaptor_masked(dataAFM_assembled,AFM_height_IO_assembled,metaData_AFM.Alpha,idxMon,folderResultsImg,mainPath,'FitOrder',accuracy,'Silent','No');
    end
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

