function varargout=A2_0_main_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,HVmodesInfo,idxMon,varargin)
    % suppress some annoying warnings
    warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');
    warning('off','curvefit:fit:IterationLimitReached');            
    warning('off','stats:statrobustfit:IterationLimit');
    modesScan={'normal','friction','afterHeat'};
    p=inputParser(); 
    argName = 'SeeMe';                  defaultVal = true;            addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'Normalization';          defaultVal = false;           addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'modeScan';               defaultVal = 'normal';    addParameter(p,argName,defaultVal, @(x) ismember(string(x),modesScan));
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
    % clarify type of dataset
    if modeScan ==1 || modeScan == 3
        mainHVmode = HVmodesInfo.(sprintf('dir%s', HVmodesInfo.mainData)){1};       
    else
        mainHVmode= HVmodesInfo.dirOFF{1};  
    end
    clear argName defaultVal p varargin modesScan
    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then process? 
    if numFiles>1        
        typeProcessChoice=askTypeProcess(mainPath,SaveFigFolder,mainHVmode);
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
                % take the info regarding Fit Order used in the first section
                if i~=1 && isempty(FitOrder_Height)
                    firstFileHeight=dir(fullfile(startPathSingleSectionFolder,"section_1","*_heightChannelProcessed.mat"));
                    load(fullfile(firstFileHeight.folder,firstFileHeight.name),"FitOrder_Height");
                    if exist(dir(fullfile(startPathSingleSectionFolder,"section_1","*_lateralChannelProcessed.mat")),'file')
                        load(fullfile(firstFileLat.folder,firstFileLat.name),"FitOrder_Lat");
                    end
                end
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
                    question=sprintf("PostHeightChannel file .mat for the section %d - %s - already exists. Take it?",i,mainHVmode);
                    if getValidAnswer(question,"",{'y','n'})
                        if i==1
                            load(fileName1,"AFMdata_postHeightFit","AFM_height_IO","FitOrder_Height")
                        else
                            load(fileName1,"AFMdata_postHeightFit","AFM_height_IO")
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
                    [AFMdata_postHeightFit,AFM_height_IO,FitOrder_Height]=A2_1_processHeight(dataPreProcess,idxMon,SaveFigIthSectionFolder,modeScan,'fitOrder',FitOrder_Height,'imageType',"SingleSection",'metadata',metaDataPreProcess,'SeeMe',false);                
                    % save the results for the specific section, to avoid to perform manual binarization
                    save(fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFMdata_postHeightFit","AFM_height_IO","FitOrder_Height")                
                end
                clear question fileName*
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL (in case of HOVER MODE ON DATA) %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                           
                metaData_AFM=allData(i).metadata; 
                % if data for normal scan is from HVmodeOFF, not required to extract friction coeff ==> just trace-retrace data and it doesnt matter
                % if single section processing or after assembling since V->N conversion is pixelXpixel operation, therefore no planeFit.

                answSkipLat=2; % 1 = skip, 2 = process               
                if strcmp(HVmodesInfo.mainData,"ON") && modeScan==1 && i==1
                % if processing HV mode ON (main) and OFF (friction) exist
                    question=sprintf("Both HoverModeON and HoverModeOFF exist.\nChoose one of the following options to decide how to process lateral deflection data.\nQuestion skipped from next section while same operation is repeated depending on the previously choosen option.");                                   
                    additionaltext="\nNOTE: Friction Coefficients will be separately extracted from the same single section and applied as baseline to the lateral data of the relative section.";       
                    options={"Skip Lateral Deflection processing of single sections.\nFirst, process Height Image of any section and assembly, then processing entire image Lateral deflection.",...
                        sprintf("Process Lateral Deflection for each single section, independently from other sections.%s",additionaltext)};
                    answSkipLat=getValidAnswer(question,'',options);                 
                elseif modeScan==3
                % In case of postHeated samples, skip the lateral processing 
                    answSkipLat=1;
                end                
                fprintf("\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n%%%% PROCESSING LATERAL CHANNEL SECTION %d %%%%\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n",i)                                
                if answSkipLat == 1
                    continue
                else
                    if strcmp(HVmodesInfo.mainData,"OFF")
                        nameFig_base="resultA3";
                        [~,force_2_clear,force_1_masked,vertForce_2_clear,vertForce_1_masked]=A2_2_processLat_1_LatVolt2LatForce(AFMdata_postHeightFit,AFM_height_IO,metaData_AFM,SaveFigIthSectionFolder,nameFig_base,idxMon,modeScan);
                        tmp=AFMdata_postHeightFit;      
                        tmp(end+1).Channel_name="Vertical Force"; %#ok<AGROW>
                        tmp(strcmpi([tmp.Channel_name],'Vertical Force')).AFM_images_3_PostLatProcessed_1_mask=vertForce_1_masked;
                        tmp(strcmpi([tmp.Channel_name],'Vertical Force')).AFM_images_3_PostLatProcessed_2_cleared=vertForce_2_clear;
                        tmp(end+1).Channel_name="Lateral Force"; %#ok<AGROW>
                        tmp(strcmpi([tmp.Channel_name],'Lateral Force')).AFM_images_3_PostLatProcessed_1_mask=force_1_masked;
                        tmp(strcmpi([tmp.Channel_name],'Lateral Force')).AFM_images_3_PostLatProcessed_2_cleared=force_2_clear;
                        AFMdata_final=tmp;
                        allData(i).metadata.frictionCoeff_Used="No FC calculation. Lateral Force directly from data.";
                    else
                        [AFMdata_final,metricsPlane,metricsLine,FitOrder_Lat,FitOrder_Height,avg_fc]=A2_feature_2_processLateralChannel(AFMdata_postHeightFit,AFM_height_IO,metaData_AFM,idxMon,SaveFigIthSectionFolder,mainPath, ...
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
                    end
                end
                allData(i).AFMImage_PostProcess=AFMdata_final;
                allData(i).AFMmask_heightIO=AFM_height_IO;     
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"allData","FitOrder_Height","FitOrder_Height","FitOrder_Lat") 
                close all            
            end
            % processing any single section completed
            if answSkipLat == 2 && ~strcmp(HVmodesInfo.mainData,"OFF")
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
            load(fullfile(pathfile,"heightChannelProcessed.mat"),"AFMdata_postHeightFit","AFM_height_IO","metaDataPreProcess")
        else
            % in case never processed, start the height channel process. 
            dataPreProcess=allData.AFMImage_Raw;
            metaDataPreProcess=allData.metadata;                                
            [AFMdata_postHeightFit,AFM_height_IO]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,SaveFigFolder,modeScan,'imageType','Entire','metadata',metaDataPreProcess,'SeeMe',false);                            
            save(fullfile(pathfile,"heightChannelProcessed.mat"),"AFMdata_postHeightFit","AFM_height_IO","metaDataPreProcess")                
        end
        % in case of frictionScan, stop here the processing. No needed the lateral processing for friction scans
        if modeScan==2 
            varargout{1}=AFMdata_postHeightFit;
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

