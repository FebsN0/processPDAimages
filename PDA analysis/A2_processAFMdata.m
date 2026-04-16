function varargout=A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,varargin)
    % suppress some annoying warnings
    warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');
    warning('off','curvefit:fit:IterationLimitReached');            
    warning('off','stats:statrobustfit:IterationLimit');
    modesScan={'normal','friction','afterHeat'};
    p=inputParser(); 
    argName = 'SeeMe';          defaultVal = true;              addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'Normalization';  defaultVal = false;             addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'modeScan';       defaultVal = 'normalScan';      addParameter(p,argName,defaultVal, @(x) ismember(string(x),{'normalScan','frictionScan','postHeatScan'}));
    parse(p,varargin{:});
    SeeMe=p.Results.SeeMe;
    norm=p.Results.Normalization;
    % define type of experiment
    if strcmp(p.Results.modeScan,modesScan{1})
        modeScan=1;        % normal
    elseif strcmp(p.Results.modeScan,modesScan{2})
        modeScan=2;        % friction
    else
        modeScan=3;        % afterHeat
    end
    clear argName defaultVal p varargin
    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then
    % process? ASK only if main data of normal scans are made in HVon or HVoff. Previous version with friciton calc assumed data were from HVoff while
    % normal scan data from HVon
    listing=dir(mainPath);
    mask = ~cellfun(@isempty, regexpi({listing.name}, '^HOVERMODE_'));
    if nnz(mask)==2
        if getValidAnswer("Multiple HoverMode found. Select the mode from which take the data to process.","",{"Hover Mode ON","Hover Mode OFF"})==1
            HVmode="HoverMode_ON";
        else
            HVmode="HoverMode_OFF";
        end
    elseif nnz(mask)==1
            HVmode=listing(mask).name;
    else
        error("No any HVmode directory found!")
    end
    if numFiles>1
        typeProcessChoice=askTypeProcess(mainPath,SaveFigFolder,HVmode);
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
                    FitOrder_Height='';
                    FitOrder_Lat='';
                end
                % take the info from the first section.
                if i~=1 && isempty(FitOrder_Height)
                    firstFileHeight=dir(fullfile(startPathSingleSectionFolder,"section_1","*_heightChannelProcessed.mat"));
                    load(fullfile(firstFileHeight.folder,firstFileHeight.name),"FitOrder_Height");
                    if exist(dir(fullfile(startPathSingleSectionFolder,"section_1","*_lateralChannelProcessed.mat")),'file')
                        load(fullfile(firstFileLat.folder,firstFileLat.name),"FitOrder_Lat");
                    end
                end
                TypeSectionProcess="SingleSection";
                % if not processed, keep true, otherwise false
                flagProcHeight=true;
                % check if results of a specific section were already made.
                [~,nameSection,~]=fileparts(allData(i).filenameSection);
                SaveFigIthSectionFolder=fullfile(startPathSingleSectionFolder,sprintf("section_%d",i)); 
                % pathfile of processed height
                fileName1=fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection));   
                % in case of normal scan, check if Lateral Channel has already processed ==> load
                if modeScan==1 && exist(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"file") 
                    question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                    if getValidAnswer(question,"",{'y','n'})
                        % each section has allData updated to the relative section.
                        load(fileName2,"allData")
                        continue
                    end
                end
                % in any scan type, check if Height Channel has already processed ==> load
                if exist(fileName1,"file")
                    question=sprintf("PostHeightChannel file .mat (HoverModeON-normal) for the section %d already exists. Take it?",i);
                    if getValidAnswer(question,"",{'y','n'})
                        if i==1
                            load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO","FitOrder_Height")
                        else
                            load(fileName1,"AFM_HeightFittedMasked","AFM_height_IO")
                        end
                        % skip height processing. In case of normal scan, start lateral processing
                        flagProcHeight=false;
                    end
                end            
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS HEIGHT CHANNEL AND GENERATE MASK %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
                if flagProcHeight
                    fprintf("\n$$$$$-----------------------------------$$$$\n$$ PROCESSING HEIGHT CHANNEL OF SECTION %d $$\n$$$$$-----------------------------------$$$$\n",i)                    
                    % First, given the ith-section, create subfolder where store figures for each section and results                
                    if ~exist(SaveFigIthSectionFolder,'dir')
                        mkdir(SaveFigIthSectionFolder)
                    end
                    % extract the data
                    dataPreProcess=allData(i).AFMImage_Raw;
                    metaDataPreProcess=allData(i).metadata;                                
                    % note: setpointsList = [] because the function is processing single sections
                    [AFM_HeightFittedMasked,AFM_height_IO,FitOrder_Height]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,SaveFigIthSectionFolder,modeScan,'fitOrder',FitOrder_Height,'imageType',TypeSectionProcess,'metadata',metaDataPreProcess,'SeeMe',false);                
                    % save the results for the specific section, to avoid to perform manual binarization
                    save(fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFM_HeightFittedMasked","AFM_height_IO","FitOrder_Height")                
                end
                clear question fileName*
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           
                fprintf("\n$$$$$-----------------$$$$\n$$ PROCESSING LATERAL CHANNEL SECTION %d $$\n$$$$$-----------------$$$$\n",i)
                metaData_AFM=allData(i).metadata; 
                if ~exist("answSkipLat","var") && exist(fullfile(mainPath,"HoverMode_OFF"),"dir")
                    question=sprintf("Found HVoff for the same current section. Skip the Lateral Image Processing of %d-th section?",i);
                    options={"Yes. Continue the Height Image Processing of all other sections first,\n" + ...
                        "so the friction coefficient can be extracted separately by using same masks for HVoff."; ...
                             "No. Continue with the Lateral Image Processing."};
                    answSkipLat=getValidAnswer(question,'',options);
                end
                if answSkipLat==1
                    continue
                end
    
                if ~strcmp(modeScan,'postHeatScan') % save time in case of postHeat AFM data
                    [AFM_LatDeflecFitted_Force,metricsPlane,metricsLine,FitOrder_Lat,FitOrder_Height,avg_fc]=A2_feature_2_processLateralChannel(AFM_HeightFittedMasked,AFM_height_IO,metaData_AFM,idxMon,SaveFigIthSectionFolder,mainPath, ...
                        'FitOrderHVON_Lat',FitOrder_Lat,'FitOrderHVOFF_Height',FitOrder_Height,'SeeMe',false,'idxSectionHVon',i,'flagSingleSectionProcess',true);
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
                    save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"allData","FitOrder_Height","FitOrder_Height","FitOrder_Lat") 
                end
                close all            
            end
        
            if answSkipLat == 1
                uiwait(warndlg("The HeightChannel processing of every section has terminated. Continue with Friction Calculation script for the same scan"))
                A0_main_friction(mainPath,idxMon,2)
                uiwait(warndlg("Friction main code completed. One ore more friction coefficients are ready to be used. Restart A0_main.m code and reply 'No' in the skipping lateral postprocessing"))
                error("Current running Code ends here! Restart A0_main.m")
            end            
        end
        % ASSEMBLY!
        [AFM_images_assembled,metaData] = A2_feature_sortAndAssemblySections(allData,otherParameters,flag_processSingleSection,modeScan);             
        % in case of no single section processing, now process the assembled image
        if ~flag_processSingleSection
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%% HEIGHT PROCESSING AFTER ASSEMBLY %%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [AFM_images_postHeight,AFM_height_IO]=A2_feature_1_processHeightChannel(AFM_images_assembled,idxMon,SaveFigFolder,modeScan,'SeeMe',SeeMe,'Normalization',norm, ...
                'imageType','Assembled','metadata',metaData);
            if modeScan==1
                AFM_images_final=A2_feature_2_processLateralChannel(AFM_images_postHeight,AFM_height_IO,metaData_AFM.Alpha,idxMon,SaveFigFolder,mainPath, ...
                    'FitOrder',accuracy,'SeeMe',SeeMe,'Normalization',norm);  
            else
                AFM_images_final=AFM_images_postHeight;
            end
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
        % avoid saving because already saving outside this function in A0_main_fluorescence.m
        if modeScan~=3
            save(fullfile(SaveFigFolder,"data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData")
        end
    else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% HEIGHT PROCESSING %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        pathfile=fileparts(SaveFigFolder);
        if exist(fullfile(pathfile,"heightChannelProcessed.mat"),'file')
            load(fullfile(pathfile,"heightChannelProcessed.mat"),"AFM_HeightFittedMasked","AFM_height_IO","metaDataPreProcess")
        else
            % in case never processed, start the height channel process. 
            dataPreProcess=allData.AFMImage_Raw;
            metaDataPreProcess=allData.metadata;                                
            [AFM_HeightFittedMasked,AFM_height_IO]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,SaveFigFolder,modeScan,'imageType','Entire','metadata',metaDataPreProcess,'SeeMe',false);                            
            save(fullfile(pathfile,"heightChannelProcessed.mat"),"AFM_HeightFittedMasked","AFM_height_IO","metaDataPreProcess")                
        end
        % in case of frictionScan, stop here the processing. No needed the lateral processing for friction scans
        if modeScan==2 
            varargout{1}=AFM_HeightFittedMasked;
            varargout{2}=AFM_height_IO;
            varargout{3}=metaDataPreProcess;
            return
        end
        % continue lateral processing
 
    end
    % return outputs
    varargout{1}=AFM_images_final;
    varargout{2}=AFM_height_IO;
    varargout{3}=metaData;
    % reactivate the annoying warnings
    warning('on','MATLAB:polyfit:RepeatedPointsOrRescale');
    warning('on','curvefit:fit:IterationLimitReached');            
    warning('on','stats:statrobustfit:IterationLimit');
end      
    
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTION %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

function typeProcessChoice=askTypeProcess(varargin)    
    mainPath=varargin{1};
    HVmode=varargin{3};
    startPathResults=fullfile(mainPath,HVmode,"Results singleSectionProcessing");
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

