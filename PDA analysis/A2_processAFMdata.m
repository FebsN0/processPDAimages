function [dataAFM_assembled,AFM_height_IO_assembled,metadata,setpointN]=A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,varargin)
    p=inputParser();
    argName = 'accuracyHeight';    defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'accuracyLateral';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'frictionData';      defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    parse(p,varargin{:});    
    
    accuracyHeight=p.Results.accuracyHeight;
    accuracyLateral=p.Results.accuracyLateral;
    if strcmp(p.Results.frictionData,"No"), frictionCalc=false; else, frictionCalc=true; end
    clearvars argName defaultVal p varargin
    
    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then
    % process? ASK only if the function is running with HOVER MODE ON. In
    % case of HOVER MODE OFF (friction), skip it because it will 
    typeProcessChoice=askTypeProcess(mainPath);
    flag_processSingleSection=typeProcessChoice.flag;
    if flag_processSingleSection
        SaveFigSingleSectionsFolder=typeProcessChoice.folderSingleSectionData;
        % prepare the diretory where to store the figures
        [pathDataSingleSections,~,~]=fileparts(SaveFigSingleSectionsFolder);       
    end
    clear typeProcessChoice

    % first process, then assembly
    if flag_processSingleSection           
        for i=1:numFiles
            % check if results were already made.
            [~,nameSection,~]=fileparts(allData(i).filenameSection);
            % path of the subfolder where to store figures for each section
            SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",i));
            fileName1=fullfile(pathDataSingleSections,sprintf("%s_heightChannelProcessed.mat",nameSection));
            fileName2=fullfile(pathDataSingleSections,sprintf("%s_lateralChannelProcessed.mat",nameSection));
            flagEnd=false;
            % if Lateral Channel has already processed, load. NOTE: only
            % for the first run (HOVER MODE ON), since the second run
            % (HOVER MODE OFF), process is different
            if exist(fileName2,"file") && ~frictionCalc
                question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    load(fileName2,"AFM_LatDeflecFitted_Force")
                    flagEnd=true;
                end
            elseif exist(fileName1,"file")
                if frictionCalc
                    question=sprintf("PostHeightChannel file .mat (HoverModeOFF-FrictionPart) for the section %d already exists. Take it?",i);
                else
                    question=sprintf("PostHeightChannel file .mat (HoverModeON-normal) for the section %d already exists. Take it?",i);
                end
                if getValidAnswer(question,"",{'y','n'})
                    load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO")
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
                [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_1_processHeightChannel(dataPreProcess,metaDataPreProcess,idxMon,SaveFigIthSectionFolder,'fitOrder',accuracyHeight,'imageType',TypeSectionProcess);                
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(pathDataSingleSections,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO")                
            end
            clear question fileName*
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~flagEnd && ~frictionCalc
                metaData_AFM=allData(i).metadata; 
                AFM_LatDeflecFitted_Force=A2_feature_2_processLateralChannel(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigIthSectionFolder,mainPath,'FitOrder',accuracyLateral,'SeeMe',true,'idxSectionHVon',i);
                save(fullfile(pathDataSingleSections,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"AFM_LatDeflecFitted_Force") 
            end  

            if ~frictionCalc
                allData(i).AFMImage_PostProcess=AFM_LatDeflecFitted_Force;
                allData(i).AFMmask_heightIO=AFM_height_IO;     
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
    flag_processSingleSection=false;
    % For the normal AFM postprocessing, ask if PROCESS PRE ASSEMBLY.
    % If YES, create another directory containing a directory for each section where to store the results of single sections processing
    question= sprintf('Process single sections before assembling?');
    if getValidAnswer(question,'', {'Yes','No'})
        mainPath=varargin{1};
        flag_processSingleSection=true;
        % prepare the directories where store the data of single section
        % and its figures. SaveFigFolder is only for assembled data. It
        % will be used after assembling
        pathDataSingleSections=fullfile(mainPath,"HoverMode_ON","dataSingleSections");
        SaveFigSingleSectionsFolder=fullfile(pathDataSingleSections,"Results singleSectionsProcessing");
        if ~exist(pathDataSingleSections,"dir")            
            mkdir(pathDataSingleSections)            
        end
        if ~exist(SaveFigSingleSectionsFolder,"dir")        
            mkdir(SaveFigSingleSectionsFolder)
        end     
        typeProcessChoice.folderSingleSectionData=SaveFigSingleSectionsFolder;
    end
    typeProcessChoice.flag=flag_processSingleSection;    
end

