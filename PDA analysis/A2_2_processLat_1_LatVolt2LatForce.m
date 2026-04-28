function [dataForce,idxSection]=A2_2_processLat_1_LatVolt2LatForce(AFM_data,AFM_height_IO,metadata,saveFigPath,nameFig_base,idxMon,modeScan)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% PREPARE THE DATA BEFORE CONVERTING LATERAL DEFLECTION (V) INTO LATERAL FORCE (nN) + SHOW EVERYTHING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Z%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % originally, mask:1 = PDA, mask:0 = BK ==> since we transform into nan those pixels in corrispondence of 1 value of the mask,
    % invert 0->1 and 1->0 in case of normal scan. When there is friction processing, no conversion
    if modeScan==1
        AFM_height_IO=~AFM_height_IO;
        textTitle="Distribution of Lateral Data in corrispondence of PDA";
    else
        textTitle="Distribution of Lateral Data in corrispondence of Background";
    end
    % prepare the idx for each section depending on the size of each section stored in the metadata to better
    % distinguish and prepare the fit for each section data. If there are multiple sections in the metadata 
    idxSection=metadata.y_scan_pixels;
    % extract vertical data
    vertical_Trace = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);
    vertical_ReTrace = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);                                            
    % correct vertical forces
    vertForce_0_entire=(vertical_Trace+vertical_ReTrace)/2;
    vertForce_0_entire=vertForce_0_entire*1e9;
    % show vertical data
    nameFig=nameFig_base+"_1_VerticalForce_fullData";
    showData(idxMon,false,vertical_Trace*1e9,"Vertical Trace",saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{vertical_ReTrace*1e9,vertForce_0_entire}, ...
        "extraTitles",{"Vertical ReTrace","Vertical Force (avg)"},...
        "extraLabel",{"Force [nN]","Force [nN]"});
    % extract lateral data     
    Lateral_Trace   = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);    
    Lateral_ReTrace = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);
    Delta = (Lateral_Trace + Lateral_ReTrace) / 2;
    % Calc W (half-width loop) and then force (convert W into force (in Newton units) using alpha calibration factor and show results.
    W = Lateral_Trace - Delta;
    alpha=metadata.Alpha;
    force_0_entire=W*alpha*1e9; %Convert N into nN
    % show the data
    nameFig=nameFig_base+"_2_LateralForce_fullData";
    showData(idxMon,false,Lateral_Trace,"Lateral Trace",saveFigPath,nameFig,"labelBar","Volt [V]",...
        "extraData",{Lateral_ReTrace,force_0_entire}, ...
        "extraTitles",{"Lateral ReTrace","Lateral Force"}, ...
        "extraLabel",{"Volt [V]","Force [nN]"});
    % mask the data
    mask=logical(AFM_height_IO);
    force_1_masked=force_0_entire;
    force_1_masked(mask)=nan;
    vertForce_1_masked=vertForce_0_entire;
    vertForce_1_masked(mask)=nan;
    % prepare the output
    dataForce.vertForce_0_entire=vertForce_0_entire;
    dataForce.vertForce_1_masked=vertForce_1_masked;
    dataForce.vertForce_2_clear=[];
    dataForce.force_0_entire=force_0_entire;
    dataForce.force_1_masked=force_1_masked;
    dataForce.force_2_clear=[];
    % show the data before starting
    nameFig=nameFig_base+"_3_ForcesMaskedData";
    showData(idxMon,false,vertForce_1_masked,"Vertical Force (BK-masked)",saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",force_1_masked,"extraTitles","Lateral Force (BK-masked)","extraLabel","Force [nN]");
    % show also distribution of lateral deflection trace-retrace and force into additional fig
    figDistr=figure('Visible','on');        
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact',"Parent",figDistr);
    axDistV  = nexttile(tl);
    axDistN = nexttile(tl);
    sgtitle(figDistr,textTitle,'FontSize',18,'Interpreter','none');
    % DISTRIBUTION OF VOLTAGE DATA
    hold(axDistV,"on")
    edges=min(min(Lateral_Trace(:)),min(Lateral_ReTrace(:))):.025:max(max(Lateral_Trace(:)),max(Lateral_ReTrace(:)));    
    histogram(axDistV,Lateral_Trace,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral Trace","Normalization","pdf");
    histogram(axDistV,Lateral_ReTrace,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral ReTrace","Normalization","pdf");
    allDataHistog=[Lateral_Trace(:);Lateral_ReTrace(:)];
    pLow = prctile(allDataHistog, 0.5);
    pHigh = prctile(allDataHistog, 99.5);
    grid(axDistV,"on"), grid(axDistV,"minor")
    xlim(axDistV, [pLow, pHigh]); xlabel(axDistV,"Voltage [V]",'FontSize',12), ylabel(axDistV,"PDF",'FontSize',12)
    legend(axDistV,"fontsize",13),
    title(axDistV,"Lateral Deflection Trace-Retrace (0.5-99.5 percentile shown)",'FontSize',18)   
    % DISTRIBUTION OF VOLTAGE DATA
    hold(axDistN,"on")
    edges=min(force_1_masked(:),[],"all","omitnan"):3:max(force_1_masked(:),[],"all","omitnan");    
    h=histogram(axDistN,force_1_masked,'BinEdges',edges,'FaceAlpha',1,"Normalization","pdf");
    h.Annotation.LegendInformation.IconDisplayStyle="off";
    force_masked_vectCleaned=force_1_masked(~isnan(force_1_masked(:)));
    pMean=mean(force_masked_vectCleaned);
    pMedian = median(force_masked_vectCleaned);
    p99 = prctile(force_masked_vectCleaned,99);
    p90 = prctile(force_masked_vectCleaned,90);
    p75 = prctile(force_masked_vectCleaned,75);
    xline(axDistN,pMean,'--',"LineWidth",4,"DisplayName",sprintf("Mean: %.2f nN",pMean),"Color",globalColor(2))
    xline(axDistN,pMedian,'--',"LineWidth",4,"DisplayName",sprintf("Median: %.2f nN",pMedian),"Color",globalColor(3))    
    xline(axDistN,p75,'--',"LineWidth",4,"DisplayName",sprintf("75th percentile: %.2f nN",p75),"Color",globalColor(4))
    xline(axDistN,p90,'--',"LineWidth",4,"DisplayName",sprintf("90th percentile: %.2f nN",p90),"Color",globalColor(5))
    xline(axDistN,p99,'--',"LineWidth",4,"DisplayName",sprintf("99th percentile: %.2f nN",p99),"Color",globalColor(6))
    xlim(axDistN,"padded"); xlabel(axDistN,"Force [nN]",'FontSize',12), ylabel(axDistN,"PDF",'FontSize',12)
    legend(axDistN,"Fontsize",13),
    title(axDistN,"Lateral Force",'FontSize',18)    
    nameFig2=nameFig_base+"_4_LateralDataDistributionValues";
    grid(axDistN,"on"), grid(axDistN,"minor")
    objInSecondMonitor(axDistV,idxMon)
    % apply indipently of the used method different cleaning outliers steps
    %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
    %   second clearing: filter out force with 20% more than the setpoint for the specific section
    %   show also the lateral and vertical data after clearing
    nameFig=nameFig_base+"_5_LateralVerticalData_postCleared";
    [vertForce_2_clear,force_2_clear]=A2_2_processLat_1_feature_ClearAndPlotForce(vertical_Trace,vertical_ReTrace,force_1_masked,idxSection,saveFigPath,nameFig,idxMon);    
    saveFigures_FigAndTiff(figDistr,saveFigPath,nameFig2)
    % save the final data
    dataForce.vertForce_2_clear=vertForce_2_clear;
    dataForce.force_2_clear=force_2_clear;
end
