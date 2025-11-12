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
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS HEIGHT CHANNEL (common for HOVER MODE ON and OFF) %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                [AFM_HeightFittedMasked,AFM_height_IO]=processHeightAFMdata(dataPreProcess,SaveFigIthSectionFolder,idxMon,accuracyHeight,'imageType',TypeSectionProcess);                
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(pathDataSingleSections,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO")                
            end
            clear question fileName*
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~flagEnd && ~frictionCalc
                metaData_AFM=allData(i).metadata; 
                AFM_LatDeflecFitted_Force=A5_LD_Baseline_Adaptor_masked(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigIthSectionFolder,mainPath,'FitOrder',accuracyLateral,'Silent','No');
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


function [AFM_HeightFittedMasked,AFM_height_IO]=processHeightAFMdata(dataPreProcess,SaveFigFolder,idxMon,accuracyHeight,varargin)
    p=inputParser();
    argName = 'setpointsList';  defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'SeeMe';          defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'imageType';      defaultVal = 'Entire';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';  defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'metadata';       defaultVal = [];        addParameter(p,argName,defaultVal);
    parse(p,varargin{:});

    if p.Results.SeeMe,  SeeMe=1; else, SeeMe=0; end                    
    typeProcess=p.Results.imageType;
    if p.Results.Normalization; norm=1; else, norm=0; end
    setpointN=p.Results.setpointsList;
    clearvars argName defaultVal p

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% PROCESS HEIGHT CHANNEL %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    iterationMain=1;
    while true
        % show the data prior the adjustments
        A1_feature_CleanOrPrepFiguresRawData(dataPreProcess,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'metadata',metaData,'imageType',typeProcess,'SeeMe',SeeMe,"setpointsList",setpointN,'Normalization',norm);
        % first process: OBTAIN MASK 0/1 of the Height channel
        [AFM_HeightFitted,AFM_height_IO]=A2_feature_process_1_fitHeightChannel(dataPreProcess,iterationMain,idxMon,SaveFigFolder,"fitOrder",accuracyHeight,"SeeMe",SeeMe);
        % Using the AFM_height_IO, fit the background again, yielding a more accurate height image by using the
        % 0\1 height image
        [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_process_2_fitHeightChannelWithMask(AFM_HeightFitted,AFM_height_IO,iterationMain,idxMon,SaveFigFolder,"SeeMe",SeeMe);
        % ask if re-run the process to obtain better AFM height image 0/1
        if ~getValidAnswer('Run again A3 and A4 to create better optimized mask and height AFM image?','',{'y','n'},2)
            break
        else
            iterationMain=iterationMain+1;
            dataPreProcess=AFM_HeightFittedMasked;
        end
    end
end






