function [avg_fc,FitOrderHVOFF_Height] = A2_feature_2_1_FrictionCalcFromSameScanHVOFF(idxMon,mainPath,flagSingleSectionProcess,varargin)
    p=inputParser();
    argName = 'FitOrderHVOFF_Height';       defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'idxSectionHVon';             defaultVal = [];     addOptional(p,argName,defaultVal, @(x) (isnumeric(x) || isempty(x)));
    parse(p,varargin{:});
    FitOrderHVOFF_Height=p.Results.FitOrderHVOFF_Height;    
    idxSectionHVon=p.Results.idxSectionHVon;
    clear p varargin argName defaultVal
    flagStartHeightProcess=true;
    % check if data HoverModeOFF post Height fitting has already been made
    if exist(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat'),"file")
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat')); %#ok<LOAD>     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% CHECK LATER        
        flagStartHeightProcess=false;
    elseif exist(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat'),"file")
        load(fullfile(mainPath,'HoverMode_OFF\resultsData_1_extractAFMdata.mat'),"allData");
    % prepare the data , or if already extracted, upload. Even if this
    % function is called under specific section in HoverModeON, extract the
    % data from any section of HoverModeOFF    
    else
        HVoffPath=fullfile(mainPath,'HoverMode_OFF');
        allData=A1_openANDprepareAFMdata('filePath',HVoffPath,'frictionData',"Yes");
        save(fullfile(HVoffPath,'resultsData_1_extractAFMdata'),"allData");
    end    
    % in case the user chose to process single sections, create the dedicated dir
    if flagSingleSectionProcess
        SaveFigSingleSectionsFolder=fullfile(mainPath,'HoverMode_OFF',"Results singleSectionProcessing");     
        % final path of the subfolder where to store figures for each section
        SaveFigIthSectionFolder=fullfile(SaveFigSingleSectionsFolder,sprintf("section_%d",idxSectionHVon));
        if ~exist(SaveFigIthSectionFolder,"dir")        
            % create nested folder with subfolders
            mkdir(SaveFigIthSectionFolder)                       
        end        
        filePathResultsFriction=SaveFigIthSectionFolder;
        imageType='SingleSection';
        clear SaveFigIthSectionFolder SaveFigSingleSectionsFolder pathDataSingleSectionsHV_OFF
    else
        if ~exist(fullfile(HVoffPath,"Results Processing AFM for friction coefficient"),"dir")
            % create dir where store the friction results for the assembled (no single processed sections) to avoid to save them into the
            % same crowded directory of HVon results.
            filePathResultsFriction=fullfile(HVoffPath,"Results Processing AFM for friction coefficient");
            mkdir(filePathResultsFriction)
            imageType='Assembled';
        end
    end           
    clear HVoffPath
    % if this function is called under the specific section of HoverMode ON (therefore, processing single section before assembling), the concept
    % of estimate friction will be different from an assembled AFM image. If the postHeight channel has been already processed, it is stored
    % in HoverMode_OFF\resultsData_2_postHeight.mat    
    if flagSingleSectionProcess
        % check if results of post height channel step of the specific section were already made.
        [~,nameSection,~]=fileparts(allData(idxSectionHVon).filenameSection);
        fileName=fullfile(filePathResultsFriction,sprintf("%s_heightChannelProcessed.mat",nameSection));                
        if exist(fileName,"file")
            question=sprintf("PostHeightChannelProcess file .mat (HoverModeOFF-FrictionPart) for the section %d already exists. Take it?",idxSectionHVon);
            if getValidAnswer(question,"",{'y','n'})
                load(fileName,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata")
                flagStartHeightProcess=false;
            end
            clear fileName question
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% HEIGHT PROCESSING %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % in case never processed, start the height channel process. However, since the Height Channel of HoverMode ON has been
    % already processed and in principle it should be same. Check if it is still take it to save time
    if flagStartHeightProcess     
        if flagSingleSectionProcess
            dataPreProcess=allData(idxSectionHVon).AFMImage_Raw;
            metadata=allData(idxSectionHVon).metadata;
            % path + filename = save the results for the specific section, to avoid to perform manual binarization everytime
            nameFileResultPostHeightProcess=fullfile(filePathResultsFriction,sprintf("%s_heightChannelProcessed.mat",nameSection));
        else
            % assembly part before process height
            %dataPreProcess
            %metadata
            nameFileResultPostHeightProcess=fullfile(mainPath,'HoverMode_OFF\resultsData_2_postHeight.mat');
        end
        [AFM_images_postHeightFit_HVOFF,AFM_height_IO_HV_OFF,FitOrderHVOFF_Height,metadata]=A2_feature_1_processHeightChannel(dataPreProcess,idxMon,filePathResultsFriction, ...
            'metadata',metadata,'fitOrder',FitOrderHVOFF_Height,'imageType',imageType, ...
            'SeeMe',false,'HoverModeImage','HoverModeOFF');        
        save(nameFileResultPostHeightProcess,"AFM_images_postHeightFit_HVOFF","AFM_height_IO_HV_OFF","FitOrderHVOFF_Height","metadata","filePathResultsFriction")            
    end
    clear nameFileResultPostHeightProcess flagStartHeightProcess allData   
    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% PREPARE THE DATA BEFORE FRICTION CALC. SHOW EVERYTHING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Z%%%%%%%%%%%%%%%%
    % prepare the idx for each section depending on the size of each section stored in the metadata to better
    % distinguish and prepare the fit for each section data. If there are multiple sections in the metadata 
    if exist(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient.mat"),'file')
        load(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient"),"resFriction")
    else
        sectionSizes=metadata.y_scan_pixels;        
        idxSection=zeros(2,length(sectionSizes));        
        for i= 1:length(sectionSizes)  
            if i==1
                idxSection(1,i)= 1;
            else
                idxSection(1,i)= idxSection(1,i-1)+1;
            end
            idxSection(2,i)= idxSection(1,i)+sectionSizes(i)-1;
        end
        % in case of data with more sections (assembling before processing), flip setpoint because high setpoint in the AFM data usually start from the left
        setpoints_nN=flip(round(metadata.SetP_N*1e9));
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
        alpha=metadata.Alpha;
        forc_masked=W*alpha*1e9;
        vertical_Trace_masked=vertical_Trace_masked*1e9;
        vertical_ReTrace_masked=vertical_ReTrace_masked*1e9;
        % show the data before starting
        nameFig="resultA3_friction_1_startData";
        showData(idxMon,false,Lateral_Trace_masked,"Lateral Trace",filePathResultsFriction,nameFig,"labelBar","Voltage [V]",...
            "extraData",{Lateral_ReTrace_masked,forc_masked,vertical_Trace_masked,vertical_ReTrace_masked}, ...
            "extraTitles",{"Lateral ReTrace","Lateral Force (preProcessing)","Vertical Trace","Vertical ReTrace"}, ...
            "extraLabel",{"Voltage [V]","Force [nN]","Force [nN]","Force [nN]"});
        % show also distribution of lateral deflection trace-retrace
        figDistr=figure; 
        ax = axes('Parent', figDistr);     
        edges=min(min(Lateral_Trace_masked(:)),min(Lateral_ReTrace_masked(:))):.025:max(max(Lateral_Trace_masked(:)),max(Lateral_ReTrace_masked(:)));    
        histogram(ax,Lateral_Trace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral Trace","Normalization","pdf");
        hold(ax,"on")
        histogram(ax,Lateral_ReTrace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral ReTrace","Normalization","pdf");
        allData=[Lateral_Trace_masked(:);Lateral_ReTrace_masked(:)];
        pLow = prctile(allData, 0.5);
        pHigh = prctile(allData, 99.5);
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
        [vertForce_clear,force_clear]=featureFrictionCalc1_clearingAndPlotData(vertical_Trace_masked,vertical_ReTrace_masked,setpoints_nN,forc_masked,idxSection,filePathResultsFriction,idxMon);    
        if ~getValidAnswer("Check the cleared lateral data figures.\nContinue with the avg calculation?","",{"y","n"})
            error("Process interrupted by user. Change data.")
        else
            saveFigures_FigAndTiff(figDistr,filePathResultsFriction,nameFig)
        end
        clear edges vertical_ReTrace_masked vertical_Trace_masked forc_masked alpha W Delta mask Lateral_Trace_masked Lateral_ReTrace_masked ax figDistr allData pLow pHigh nameFig
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% FRICTION CALCULATION %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
        resFriction = featureFrictionCalc2_FrictionGUI(vertForce_clear,force_clear,AFM_height_IO_HV_OFF,idxSection,idxMon,filePathResultsFriction);
        save(fullfile(filePathResultsFriction,"resultsDataFrictionCoefficient"),"resFriction")
    end
    avg_fc=resFriction.resFit.fc;
    close all
end
