function A0_main_friction(varargin)
    if isempty(varargin)
        close all
        idxMon=objInSecondMonitor;
        pause(1)
        mainPath=uigetdir(pwd,sprintf('Locate the main scan directory which contains HVoff directory'));     
        % to extract the friction coefficient, choose which method use.
        question=sprintf('Is the data containing PDA or only background?');
        options={ ...
            sprintf('1) only Background'), ...
            sprintf('2) PDA+Background')};
        dataType = getValidAnswer(question, '', options);   
        clear options questions
    else
        mainPath=varargin{1};
        idxMon=varargin{2};
        dataType=varargin{3};
    end
    
    switch dataType
        % get the friction from ONLY BACKGROUND .jpk file experiments.
        case 1
            nameOperation = "backgroundOnly";
        % get the friction from BACKGROUND+PDA .jpk file experiments.
        case 2
            nameOperation = "background_PDA";        
    end

    tmp=strsplit(mainPath,'\');
    nameScan=tmp{end}; nameExperiment=tmp{end-2}; clear tmp
    fprintf(sprintf("\n MAIN CODE OF FRICTION COEFFICIENT CALCULATION Experiment %s - scan %s\n\n",nameExperiment,nameScan))
    HVoffPath=fullfile(mainPath,'HoverMode_OFF');
    % check if data HoverModeOFF post Height fitting has already been made
    if exist(fullfile(HVoffPath,'resultsData_1_extractAFMdata.mat'),"file")
        load(fullfile(HVoffPath,'resultsData_1_extractAFMdata.mat'),"allData","otherParameters");
    % prepare the data , or if already extracted, upload. Even if this
    % function is called under specific section in HoverModeON, extract the
    % data from any section of HoverModeOFF    
    else
        [allData,otherParameters]=A1_openANDprepareAFMdata('filePath',HVoffPath,'frictionData',"Yes");
        save(fullfile(HVoffPath,'resultsData_1_extractAFMdata'),"allData","otherParameters");
    end  
    
    numSections=length(allData);
    % in case the user chose to process single sections, create the dedicated dir
    if numSections>1 && getValidAnswer('Process single sections before assembling?','', {'Yes','No'})
        flagSingleSectionProcess=true;
        SaveFigSingleSectionsFolder=fullfile(mainPath,'HoverMode_OFF',"Results singleSectionProcessing");     
        imageType='SingleSection';
    else
        flagSingleSectionProcess=false;
        filePathResultsFriction=fullfile(HVoffPath,"Results Processing AFM for friction coefficient");
        if ~exist(fullfile(HVoffPath,"Results Processing AFM for friction coefficient"),"dir")
            % create dir where store the friction results for the assembled (no single processed sections) to avoid to save them into the
            % same crowded directory of HVon results.            
            mkdir(filePathResultsFriction)
        end
    end         
    %%% PROCESSING SINGLE SECTIONS
    if flagSingleSectionProcess
        for ithSection=1:numSections
            fprintf("\nFRICTION CALC: Processing section %d\n",ithSection)
            if exist(fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",ithSection),"resultsDataFrictionCoefficient.mat"),'file')     
                continue
            end
            if ithSection==1
                FitOrderHVOFF_Height='';
                offset_HVon_HVoff=[];
            else
                if ~exist('offset_HVon_HVoff','var')
                    [~,nameSection,~]=fileparts(allData(1).filenameSection);
                    load(fullfile(SaveFigSingleSectionsFolder,"section_1",sprintf("%s_heightChannelProcessed.mat",nameSection)),"offset_HVon_HVoff","FitOrderHVOFF_Height")
                end
            end
            flagStartHeightProcess=true;
            % final path of the subfolder where to store figures for each section
            SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",ithSection));
            if ~exist(SaveFigIthSectionFolder,"dir")        
                % create nested folder with subfolders
                mkdir(SaveFigIthSectionFolder)                       
            end        
            filePathResultsFriction=SaveFigIthSectionFolder;
            % check if results of post height channel step of the specific section were already made.
            [~,nameSection,~]=fileparts(allData(ithSection).filenameSection);
            nameFileResultPostHeightProcess=fullfile(filePathResultsFriction,sprintf("%s_heightChannelProcessed.mat",nameSection));                
            if exist(nameFileResultPostHeightProcess,"file")
                question=sprintf("PostHeightChannelProcess file .mat (HoverModeOFF-FrictionPart) for the section %d already exists. Take it?",ithSection);
                if getValidAnswer(question,"",{'y','n'})
                    load(nameFileResultPostHeightProcess,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata","offset_HVon_HVoff")
                    flagStartHeightProcess=false;
                end
                clear fileName question
            end        
            %%%%%%%%% HEIGHT AND MASK PROCESSING %%%%%%%%%
            % in case never processed, start the height channel process. However, since the Height Channel of HoverMode ON has been
            % already processed and in principle it should be same. Check if it is still take it to save time
            if flagStartHeightProcess     
                dataPreProcess=allData(ithSection).AFMImage_Raw;
                metadata=allData(ithSection).metadata;           
                [AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,FitOrderHVOFF_Height,metadata,offset_HVon_HVoff]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,filePathResultsFriction, ...
                'metadata',metadata,'fitOrder',FitOrderHVOFF_Height,'imageType',imageType, ...
                'SeeMe',false,'HoverModeImage','HoverModeOFF','offset_HVon_HVoff',offset_HVon_HVoff,'BackgroundOnly',nameOperation); 
                save(nameFileResultPostHeightProcess,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata","offset_HVon_HVoff")            
            end
            clear nameFileResultPostHeightProcess      
            %%%%% PREPARE THE DATA BEFORE FRICTION CALC %%%%%
            [vertForce_clear,force_clear,force_masked,idxSection]=prepareFrictionData(AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,metadata,filePathResultsFriction);            
            %%%%%%%%% FRICTION CALCULATION %%%%%%%%%
            resFriction = featureFrictionCalc2_FrictionGUI(vertForce_clear,force_clear,AFM_height_IO_HV_OFF,idxSection,idxMon,filePathResultsFriction);
            close all
            save(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient"),"resFriction","force_masked","force_clear")
            correctHeight(AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,resFriction,idxMon,filePathResultsFriction)               
        end
        disp("End Friction Calc")
        % load(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient.mat"),"resFriction","force_masked","force_clear")
        % allData(ithSection).metadata.frictionCoeff=resFriction.resFit.fc;
        % % prepare the info about the used fitting
        % allData(ithSection).force_1_Raw =force_masked;
        % allData(ithSection).force_2_cleared =force_clear;
        % allData(ithSection).force_3_afterFriction =resFriction.force_data;
        % allData(ithSection).AFMmask_heightIO=AFM_height_IO_HV_OFF;     
        % allData(ithSection).heightPre=height_preFriction; 
        % allData(ithSection).heightAfter=height_afterFriction;
        %
        %[AFM_images,AFM_height_IO,metaData] = A2_feature_sortAndAssemblySections(allData,otherParameters,flagSingleSectionProcess,'frictionMain',true); 

    else        
        fprintf("\nFRICTION CALC: Processing file as entire scan area\n")
        if ~exist(fullfile(HVoffPath,"resultsDataFrictionCoefficient.mat"),'file')   
            %%%%%%%%% HEIGHT AND MASK PROCESSING %%%%%%%%%
            [AFM_images,AFM_height_IO,metaData]=A2_processAFMdata(allData,otherParameters,mainPath,filePathResultsFriction,idxMon,'modeScan','frictionScan');
            %%%%% PREPARE THE DATA BEFORE FRICTION CALC %%%%%
            [vertForce_clear,force_clear,force_masked,idxSection]=prepareFrictionData(AFM_images,AFM_height_IO,metaData,filePathResultsFriction,idxMon);
            %%%%%%%%% FRICTION CALCULATION %%%%%%%%%
            resFriction = featureFrictionCalc2_FrictionGUI(vertForce_clear,force_clear,AFM_height_IO,idxSection,idxMon,filePathResultsFriction);
            close all
            save(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient"),"resFriction","force_masked","force_clear")
            correctHeight(AFM_images,AFM_height_IO,resFriction,idxMon,filePathResultsFriction)            
            save(fullfile(HVoffPath,"resultsDataFrictionCoefficient.mat"))
        end
        
    end
    clear AFM_height_IO_HV_OFF AFM_images_postHeightFit_HVOFF dataType filePathResultsFriction flagStartHeightProcess force* FitOrderHVOFF_Height height* ithSection metadata nameFig nameOperation SaveFigIthSectionFolder resFriction nameSection imageType     
end

function [vertForce_clear,force_clear,force_masked,idxSection]=prepareFrictionData(AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,metaData,saveFigPath,idxMon)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% PREPARE THE DATA BEFORE FRICTION CALC. SHOW EVERYTHING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Z%%%%%%%%%%%%%%%%
    % prepare the idx for each section depending on the size of each section stored in the metadata to better
    % distinguish and prepare the fit for each section data. If there are multiple sections in the metadata 
    idxSection=metaData.y_scan_pixels;            
    % in case of data with more sections (assembling before processing), flip setpoint because high setpoint in the AFM data usually start from the left
    setpoints_nN=flip(round(metaData.SetP_N*1e9));
    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)    
    mask=logical(AFM_height_IO_HV_OFF);
    Lateral_Trace_masked   = (AFM_images_postHeightFit_HVOFF(strcmpi([AFM_images_postHeightFit_HVOFF.Channel_name],'Lateral Deflection') & strcmpi([AFM_images_postHeightFit_HVOFF.Trace_type],'Trace')).AFM_images_2_PostProcessed);
    Lateral_Trace_masked(mask)=NaN;
    Lateral_ReTrace_masked = (AFM_images_postHeightFit_HVOFF(strcmpi([AFM_images_postHeightFit_HVOFF.Channel_name],'Lateral Deflection') & strcmpi([AFM_images_postHeightFit_HVOFF.Trace_type],'ReTrace')).AFM_images_2_PostProcessed);
    Lateral_ReTrace_masked(mask)=NaN;
    Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace_masked - Delta;
    vertical_Trace_masked   = (AFM_images_postHeightFit_HVOFF(strcmpi([AFM_images_postHeightFit_HVOFF.Channel_name],'Vertical Deflection') & strcmpi([AFM_images_postHeightFit_HVOFF.Trace_type],'Trace')).AFM_images_2_PostProcessed);
    vertical_Trace_masked(mask)=nan;
    vertical_ReTrace_masked = (AFM_images_postHeightFit_HVOFF(strcmpi([AFM_images_postHeightFit_HVOFF.Channel_name],'Vertical Deflection') & strcmpi([AFM_images_postHeightFit_HVOFF.Trace_type],'ReTrace')).AFM_images_2_PostProcessed);                                         
    vertical_ReTrace_masked(mask)=nan;
    % convert W into force (in Newton units) using alpha calibration factor and show results. Convert N into nN
    alpha=metaData.Alpha;
    force_masked=W*alpha*1e9;
    vertical_Trace_masked=vertical_Trace_masked*1e9;
    vertical_ReTrace_masked=vertical_ReTrace_masked*1e9;
    % show the data before starting
    nameFig="resultA3_friction_1_startData";
    showData(idxMon,false,Lateral_Trace_masked,"Lateral Trace",saveFigPath,nameFig,"labelBar","Voltage [V]",...
        "extraData",{Lateral_ReTrace_masked,force_masked,vertical_Trace_masked,vertical_ReTrace_masked}, ...
        "extraTitles",{"Lateral ReTrace","Lateral Force (preProcessing)","Vertical Trace","Vertical ReTrace"}, ...
        "extraLabel",{"Voltage [V]","Force [nN]","Force [nN]","Force [nN]"});
    % show also distribution of lateral deflection trace-retrace
    figDistr=figure; 
    ax = axes('Parent', figDistr);     
    edges=min(min(Lateral_Trace_masked(:)),min(Lateral_ReTrace_masked(:))):.025:max(max(Lateral_Trace_masked(:)),max(Lateral_ReTrace_masked(:)));    
    histogram(ax,Lateral_Trace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral Trace","Normalization","pdf");
    hold(ax,"on")
    histogram(ax,Lateral_ReTrace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral ReTrace","Normalization","pdf");
    allDataHistog=[Lateral_Trace_masked(:);Lateral_ReTrace_masked(:)];
    pLow = prctile(allDataHistog, 0.5);
    pHigh = prctile(allDataHistog, 99.5);
    xlim(ax, [pLow, pHigh]); ylim(ax,"padded"); xlabel(ax,"Voltage [V]",'FontSize',12), ylabel(ax,"PDF",'FontSize',12)
    legend(ax,"fontsize",13),
    title(ax,"Distribution Lateral Data Trace-Retrace (0.5-99.5 percentile shown).",'FontSize',20)   
    nameFig="resultA3_friction_3_distribution_LateralData";
    grid on, grid minor
    objInSecondMonitor(figDistr,idxMon)
    % apply indipently of the used method different cleaning outliers steps
    %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
    %   second clearing: filter out force with 20% more than the setpoint for the specific section
    %   show also the lateral and vertical data after clearing
    [vertForce_clear,force_clear]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace_masked,vertical_ReTrace_masked,setpoints_nN,force_masked,idxSection,saveFigPath,idxMon);    
    if ~getValidAnswer("Check the cleared lateral data figures.\nContinue with the avg calculation?","",{"y","n"})
        error("Process interrupted by user. Change data.")
    else
        saveFigures_FigAndTiff(figDistr,saveFigPath,nameFig)
    end
end

function correctHeight(AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,resFriction,idxMon,saveFigPath)
    % save height figure to better compare with lateral channel
    height_preFriction=(AFM_images_postHeightFit_HVOFF(strcmpi([AFM_images_postHeightFit_HVOFF.Channel_name],'Height (measured)')).AFM_images_2_PostProcessed);
    height_preFriction(logical(AFM_height_IO_HV_OFF))=NaN;
    height_afterFriction=height_preFriction;
    height_afterFriction(isnan(resFriction.force_data))=nan;
    nameFig="resultA3_friction_7_heightChannelBeforeAfterFrictionCalc";
    showData(idxMon,false,height_preFriction*1e9,"Height Before Friction calc",saveFigPath,nameFig,"labelBar","Height [nm]",...
            "extraData",height_afterFriction*1e9, ...
            "extraTitles","Height After Friction calc", ...
            "extraLabel","Height [nm]");    
end