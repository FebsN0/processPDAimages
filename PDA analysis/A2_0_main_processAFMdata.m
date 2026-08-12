    function varargout=A2_0_main_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,HVmodesInfo,idxMon,varargin)
    % suppress some annoying warnings
    warning('off','MATLAB:polyfit:RepeatedPointsOrRescale');
    warning('off','curvefit:fit:IterationLimitReached');            
    warning('off','stats:statrobustfit:IterationLimit');
    p=inputParser(); 
    argName = 'SeeMe';                  defaultVal = true;            addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'Normalization';          defaultVal = false;           addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'modeScan';               defaultVal = 1;               addParameter(p,argName,defaultVal, @(x) (isnumeric(x) && ismember(x,[1 2 3])));
    parse(p,varargin{:});
    SeeMe=p.Results.SeeMe;
    norm=p.Results.Normalization;
    % define type of experiment
    modeScan=p.Results.modeScan;
    % clarify type of dataset
    if modeScan ==1 || modeScan == 3
        mainHVmode = HVmodesInfo.(sprintf('dir%s', HVmodesInfo.mainData)){1};       
    else
        mainHVmode= HVmodesInfo.dirOFF{1};  
    end
    clear argName defaultVal p varargin
    % count how many sections has been generated
    numFiles=length(allData);
    % QUESTION process single sections then assembly or assembly then process? 
    if numFiles>1
        typeProcessChoice=askTypeProcess(mainPath,SaveFigFolder,mainHVmode);
        flag_processSingleSection=typeProcessChoice.flag;
        % main directory where there are the results of the sections
        startPathSingleSectionFolder=typeProcessChoice.folderSingleSectionData;
        if flag_processSingleSection && modeScan==1 && strcmp(HVmodesInfo.mainData,"ON") && strcmp(HVmodesInfo.frictionData,"OFF") 
        % if processing HV mode ON (main) and OFF (friction) exist
            question=sprintf("Both HoverModeON and HoverModeOFF exist.\nChoose one of the following options to decide how to process lateral deflection data.\nQuestion skipped from next section while same operation is repeated depending on the previously choosen option.");                                   
            opt1="Process Lateral Deflection for each single section ==> Friction Coefficient calculated directly from the relative single section and Lateral Force is obtained";
            opt2="Skip Lateral Deflection processing for each single section ==> Single Friction Coefficient calculated after assembly and applied to the post-assembled Lateral Deflection";                       
            options={opt1,opt2};
            flagProcSingle_FC_Lat=getValidAnswer(question,'',options,1);  
            clear question opt*
        else
            flagProcSingle_FC_Lat=[];
        end
    else
        flag_processSingleSection=false;
        if modeScan==1 && strcmp(HVmodesInfo.mainData,"ON") && strcmp(HVmodesInfo.frictionData,"OFF")
            % since the file is just one, single FC calculation
            flagProcSingle_FC_Lat=2;
        else
            flagProcSingle_FC_Lat=[];
        end
    end
    clear typeProcessChoice
    % if single section processing, process first the i-th section, then assembly. Different options within this conditions:
    %   1) process for each section Height and Lateral. The latter can be further processed as:
    %       1.1) if HoverMode=OFF ==> Lateral Force directly from Lateral Deflection Trace and Retrace Images (it doesn't matter assembly before
    %               or later since it is Line By Line operation
    %       1.2) if HoverMode=ON  ==> two further options BUT BOTH REQUIRES HoverMode OFF data (post first AFM scanning made with HoverMode ON. Original method):
    %           A) for each section of HV_ON, extract Friction Coefficient from Lateral Deflection Trace-Retrace HV_OFF corrisponding with the
    %                   same section area, then apply it to the Lateral Deflection Trace
    %           B) first, assembly HV_OFF data, then extract a single FC fro assembled Raw Lateral Deflection Trace-Retrace that it will be applied to the assembled 
    %                   Raw Lateral Deflection Trace (HV_ON)
    %   2) process for each section only Height (useful to have just better Height channel and clear mask)
    %
    % if processing one file (entire single AFM scan, no sectioning) OR assembly every RAW AFM section data first.
    % First, in case of sections, assembly them ==> single Raw Height and Lateral data. Then, if:
    %   1) HV_OFF ==> Lateral Force directly from Lateral Deflection Trace and Retrace Image
    %   2) HV_ON  ==> Single Friction Coefficient from assembled/entire image of HV_OFF applied to Raw Lateral Deflection Trace
    if flag_processSingleSection  
        for i=1:numFiles    
            % check if results of a specific section were already made.
            [~,nameSection,~]=fileparts(allData(i).filenameSection);
            SaveFigIthSectionFolder=fullfile(startPathSingleSectionFolder,sprintf("section_%d",i)); 
            flagProcessLat=true;            
            % pathfile of processed lateral deflection
            fileLat=fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection));
            % pathfile of processed height
            fileHeight=fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection));   
            % in case of normal scan, check if Lateral Channel has already processed ==> load
            if exist(fileLat,"file") 
                question=sprintf("PostLateralChannel file .mat for the section %d already exists. Take it?",i);
                if getValidAnswer(question,"",{'y','n'})
                    % each section has allData updated to the relative section.
                    load(fileLat,"AFMdata_final","AFM_height_IO","infoFC")
                end
                flagProcessLat=false;
            elseif exist(fileHeight,"file")
                question=sprintf("PostHeightChannel file .mat for the section %d - %s - already exists. Take it?",i,mainHVmode);
                if getValidAnswer(question,"",{'y','n'})
                    load(fileHeight,"AFMdata_postHeightFit","AFM_height_IO")
                end
            else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS HEIGHT CHANNEL AND GENERATE MASK %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                FitOrder_Height='';
                % If not first section, take the info regarding Fit Order used in the first section to avoid the same question of which order to consider
                if i~=1 && isempty(FitOrder_Height)
                    firstFileHeight=dir(fullfile(startPathSingleSectionFolder,"section_1","*_heightChannelProcessed.mat"));
                    load(fullfile(firstFileHeight.folder,firstFileHeight.name),"FitOrder_Height");
                end                                            
                fprintf("\n$$$$$-----------------------------------$$$$\n$$ PROCESSING HEIGHT CHANNEL OF SECTION %d $$\n$$$$$-----------------------------------$$$$\n",i)                    
                % First, given the ith-section, create subfolder where store figures for each section and results                
                if ~exist(SaveFigIthSectionFolder,'dir')
                    mkdir(SaveFigIthSectionFolder)
                end
                % extract the data
                dataPreProcess=allData(i).AFMImage_Raw;
                metaDataPreProcess=allData(i).metadata;                                
                % note: setpointsList = [] because the function is processing single sections
                [AFMdata_postHeightFit,AFM_height_IO,FitOrder_Height]=A2_1_processHeight(dataPreProcess,metaDataPreProcess,idxMon,SaveFigIthSectionFolder,modeScan,'fitOrder',FitOrder_Height,'imageType',"SingleSection",'SeeMe',false);                
                % save the results for the specific section, to avoid to perform manual binarization
                save(fullfile(SaveFigIthSectionFolder,sprintf("%s_heightChannelProcessed.mat",nameSection)),"AFMdata_postHeightFit","AFM_height_IO","FitOrder_Height")                
                clear question fileHeight fileLat
            end
            if modeScan~=3 && flagProcessLat        % In case of postHeated samples, skip the lateral processing 
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%% PROCESS LATERAL DEFLECTION CHANNEL %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
                metaData_AFM=allData(i).metadata;
                % if data for normal scan is from HVmodeOFF, not required to extract friction coeff ==> just trace-retrace data and it doesnt matter
                if strcmp(HVmodesInfo.mainData,"OFF") 
                    fprintf("\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n%%%% PROCESSING LATERAL CHANNEL SECTION %d %%%%\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n",i)                                
                    nameFig_base="resultA3";
                    dataFinal=A2_2_processLat_1_LatVolt2LatForce(AFMdata_postHeightFit,AFM_height_IO,metaData_AFM,SaveFigIthSectionFolder,nameFig_base,idxMon);                        
                    % VERTICAL FORCE AVG
                    tmp=AFMdata_postHeightFit;      
                    tmp(end+1).Channel_name="Vertical Force"; %#ok<AGROW>
                    tmp(end).Trace_type="Average";
                    tmp(strcmpi([tmp.Channel_name],'Vertical Force')).AFM_images_3_PostLatProcessed_0_entire=dataFinal.vertForce_0_entire;
                    % LAT FORCE TRACE
                    tmp(end+1).Channel_name="Lateral Force"; %#ok<AGROW>
                    tmp(end).Trace_type="Trace";
                    tmp(end).AFM_images_3_PostLatProcessed_0_entire=dataFinal.force_0_trace_entire;
                    % LAT FORCE RETRACE
                    tmp(end+1).Channel_name="Lateral Force"; %#ok<AGROW>
                    tmp(end).Trace_type="ReTrace";                        
                    tmp(end).AFM_images_3_PostLatProcessed_0_entire=dataFinal.force_0_retrace_entire;
                    % LAT FORCE MAX PIXEL
                    tmp(end+1).Channel_name="Lateral Force"; %#ok<AGROW>
                    tmp(end).Trace_type="MaxPixelValue";
                    tmp(end).AFM_images_3_PostLatProcessed_0_entire=dataFinal.force_0_entire_PixelmaxValue;     
                    % LAT FORCE AVG
                    tmp(end+1).Channel_name="Lateral Force"; %#ok<AGROW>
                    tmp(end).Trace_type="Average";
                    tmp(end).AFM_images_3_PostLatProcessed_0_entire=dataFinal.force_0_entire_average;                        
                    % store final data
                    AFMdata_final=tmp;
                    infoFC="No FC calculation. Lateral Force directly from data.";
                    save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"AFMdata_final","AFM_height_IO","infoFC")                    
                else
                    % if data for normal scan is from HVmodeON, extract first friction coeff from HVmodeOFF data of the relative same/approximative section of HV_ON 
                    % then apply FC to the Lateral deflection HV_ON to obtain Lateral Force.
                    % NOTE: if the user decided to process first Height, then assembly, then process Lateral data with a single FC,
                    % it is skipped to the next part where it process single entire AFM data
                    if flagProcSingle_FC_Lat==1 
                        fprintf("\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n%%%% PROCESSING LATERAL CHANNEL SECTION %d %%%%\n%%%%%%%%%%%%%%%%%%------------------------%%%%%%%%%%%%%%%%%%\n",i)                                
                        FitOrderHVOFF_Height='';
                        FitOrderHVON_Lat='';
                        % take the info regarding Fit Order used in the first section
                        if i~=1 && isempty(FitOrderHVOFF_Height)
                            firstFileLateral=dir(fullfile(startPathSingleSectionFolder,"section_1","*_lateralChannelProcessed.mat"));
                            load(fullfile(firstFileLateral.folder,firstFileLateral.name),"FitOrderHVON_Lat","FitOrderHVOFF_Height");
                        end   
                        % NOT COMPLETED!
                        [AFMdata_final,infoFC,FitOrderHVON_Lat,FitOrderHVOFF_Height]=A2_2_processLat_2_Withfriction(AFMdata_postHeightFit,AFM_height_IO,metaData_AFM,idxMon,SaveFigIthSectionFolder,mainPath, ...
                            'FitOrderHVON_Lat',FitOrderHVON_Lat,'FitOrderHVOFF_Height',FitOrderHVOFF_Height,'SeeMe',false,'idxSectionHVon',i,'flagSingleSectionProcess',true);
                        save(fullfile(SaveFigIthSectionFolder,sprintf("%s_lateralChannelProcessed.mat",nameSection)),"AFMdata_final","AFM_height_IO","infoFC","FitOrderHVON_Lat","FitOrderHVOFF_Height")
                    end                                     
                end  
            end
            if flagProcSingle_FC_Lat~=2
                allData(i).AFMImage_PostProcess=AFMdata_final;
                allData(i).AFMmask_heightIO=AFM_height_IO;   
                allData(i).metadata.frictionCoeff_Used=infoFC;      
            else
                allData(i).AFMImage_PostProcess=AFMdata_postHeightFit;
                allData(i).AFMmask_heightIO=AFM_height_IO;   
                allData(i).metadata.frictionCoeff_Used="No FC calculation. Friction Coefficient calculated after assembly of LateralDeflection-HVon";  
            end
            close all 
        end
        % processing any single section completed
        if modeScan==2
            uiwait(warndlg("The Height/Lateral Channel processing of every section has completed. Continuing with Friction Calculation"))
            A0_feature_1_FrictionCoefficientCalc(allData,otherParameters,SaveFigFolder,idxMon)
            uiwait(warndlg("Friction main code completed. One ore more friction coefficients are ready to be used."))
            error("Current running Code ends here! Restart A0_main.m and change options/scan")
        end            
    end
    % ASSEMBLY!
    [AFM_images_assembled,metaData_assembled] = A2_sortAndAssemblySections(allData,otherParameters,flag_processSingleSection);
    % show and save figures post assembly BEFORE processing in case of singleSection processing.
    % In case of processing after assembling, it will be done already inside A2_feature_1_processHeightChannel
    fprintf("\nPreparation of assembled pre-processed images.\n\n")
    A1_feature_CleanOrPrepFiguresRawData(AFM_images_assembled,metaData_assembled,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'SeeMe',false,'imageType','Assembled','Normalization',norm,'postProcessed',false)
        
    % in case of no single section processing, now process the assembled image. There may be two cases to reach this point: 
    %   1) entire single AFM image ==> single Height ==> Lateral processing
    %   2) assembled single section AFM images ==> single Height ==> Lateral processing
    if ~flag_processSingleSection
        pathfile=fileparts(SaveFigFolder);
        if exist(fullfile(pathfile,"heightChannelProcessed.mat"),'file')
            load(fullfile(pathfile,"heightChannelProcessed.mat"),"AFMdata_postHeightFit","AFM_height_IO","metaData_assembled")
        else
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% HEIGHT PROCESSING AFTER ASSEMBLY IN CASE OF NO SINGLE SECTION PROCESSING OR ENTIRE AFM IMAGE %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % in case never processed, start the height channel process. 
            if numFiles>1
                imageType='Assembled';
            else
                imageType='Entire';
            end
            [AFMdata_postHeightFit,AFM_height_IO]=A2_1_processHeight(AFM_images_assembled,idxMon,SaveFigFolder,modeScan,'imageType',imageType,'metadata',metaData_assembled,'SeeMe',false);                
            save(fullfile(pathfile,"heightChannelProcessed.mat"),"AFMdata_postHeightFit","AFM_height_IO","metaData_assembled")                
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% LATERAL PROCESSING AFTER ASSEMBLY IN CASE OF NO SINGLE SECTION PROCESSING %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if modeScan~=3
        AFM_height_IO   = AFM_images_assembled(strcmpi([AFM_images_assembled.Channel_name],'Height (measured)')).AFMmask_heightIO;
        if flagProcSingle_FC_Lat~=2
            % every section is fully processed already
            AFM_images_final=AFM_images_assembled;
        else           
            if flagProcSingle_FC_Lat==2
                imageType='Assembled';
                [AFM_images_final,infoFC]=A2_2_processLat_2_Withfriction(AFM_images_assembled,AFM_height_IO,metaData_assembled,imageType,idxMon,SaveFigFolder,mainPath,'SeeMe',false);                  
            else
                AFM_images_final=A2_2_processLat_1_LatVolt2LatForce(AFM_images_assembled,AFM_height_IO,metaData_AFM,SaveFigFolder,nameFig_base,idxMon);       
            end
            metaData_assembled.frictionCoeff_Used=infoFC;
        end
    else
        AFM_images_final=AFM_images_assembled;
    end        
    % show results post processing. Common for both processing type (singleSection or postAssembly)
    fprintf("\nPreparation of assembled post-processed images.\n\n")
    A1_feature_CleanOrPrepFiguresRawData(AFM_images_final,metaData_assembled,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'SeeMe',false,'imageType','Assembled','Normalization',norm,'postProcessed',true,'HVmode',mainHVmode)

    % show and save fig for better visual (height and force)       
    %{
    lengthAxis=[metaData_assembled.x_scan_length_m,metaData_assembled.y_scan_length_m];
    height_final=AFM_images_final(strcmp([AFM_images_final.Channel_name],"Height (measured)")).AFM_images_2_PostProcessed;       
    waitfor(warndlg(sprintf("The next step is only for creating a better visual of the HEIGHT IMAGE through the percentile range selection.\nNOTE: Original data is not altered.")))
    [pValues,height_finalVisual] = percentileClipSlider(idxMon,height_final*1e9, ...
            "Original Image", "Image within selected percentile data", "Height (nm)", lengthAxis,'pLowMax',50, 'pHighMin', 50,"Contrast",true);  
    showData(idxMon,false,height_finalVisual,sprintf("Height Image - Contrast %.2f-%.2f Percentile",pValues),SaveFigFolder,"resultA2_1_Z_HeightBetterVisual",'labelBar',"Height (nm)","lenghtAxis",lengthAxis);              
    force_final=AFM_images_final(strcmp([AFM_images_final.Channel_name],"Lateral Force") & strcmp([AFM_images_final.Trace_type],"MaxPixelValue")).AFM_images_2_PostProcessed;
    waitfor(warndlg(sprintf("The next step is only for creating a better visual of the LATERAL FORCE IMAGE (AVG) through the percentile range selection.\nNOTE: Original data is not altered.")))
    [pValues,force_finalVisual] = percentileClipSlider(idxMon,force_final, ...
            "Original Image", "Image within selected percentile data", "Force (nN)", lengthAxis,'pLowMax',50, 'pHighMin', 50,"Contrast",true);       
    showData(idxMon,false,force_finalVisual,sprintf("Force (AVG) Image - Data Shown %.2f-%.2f Percentile",pValues),SaveFigFolder,"resultA2_6_Z1_ForceBetterVisual",'labelBar',"Force (nN)","lenghtAxis",lengthAxis);
    %}

    % all LD together with same scale bar
    %{
    force_0_entire_trace=AFM_images_final(7).AFM_images_2_PostProcessed;
    force_0_entire_retrace=AFM_images_final(8).AFM_images_2_PostProcessed;
    force_0_entire_PixelmaxValue=AFM_images_final(9).AFM_images_2_PostProcessed;
    force_0_entire_average=AFM_images_final(10).AFM_images_2_PostProcessed;
    imgs={force_0_entire_trace,force_0_entire_retrace,force_0_entire_PixelmaxValue,force_0_entire_average};
    imgs_adjusted=imadjustMultiple(imgs);
    showData(idxMon,false,imgs_adjusted{1},"Lateral Force - Trace",SaveFigFolder,"resultA2_6_Z2_ForceBetterVisual","labelBar","Force [nN]",...
        "extraData",imgs_adjusted(2:4), ...  
        "extraTitles",{"Lateral Force - ReTrace","Lateral Force - MaxPixelV","Lateral Force - Average"}, ...
        "extraLabel",{"Force [nN]","Force [nN]","Force [nN]"},...
        "bigTitle","Force Distribution (LF adjusted contrast)");    
    %}
    % return outputs
    varargout{1}=AFM_images_final;
    varargout{2}=metaData_assembled;
    % reactivate the annoying warnings
    warning('on','MATLAB:polyfit:RepeatedPointsOrRescale');
    warning('on','curvefit:fit:IterationLimitReached');            
    warning('on','stats:statrobustfit:IterationLimit');
end      
    
%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% FUNCTIONS %%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

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

