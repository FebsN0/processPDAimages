function varargout=A2_2_processLat_1_LatVolt2LatForce(AFM_data,AFM_height_IO,metadata,saveFigPath,nameFig_base,idxMon,modeScan)
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
    varargout{1}=idxSection;
    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (BK-PDA)    
    mask=logical(AFM_height_IO);
    Lateral_Trace_masked   = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);
    Lateral_Trace_masked(mask)=NaN;
    Lateral_ReTrace_masked = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);
    Lateral_ReTrace_masked(mask)=NaN;
    Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace_masked - Delta;
    vertical_Trace_masked   = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);
    vertical_Trace_masked(mask)=nan;
    vertical_ReTrace_masked = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);                                         
    vertical_ReTrace_masked(mask)=nan;
    % convert W into force (in Newton units) using alpha calibration factor and show results. Convert N into nN
    alpha=metadata.Alpha;
    force_1_masked=W*alpha*1e9;
    vertical_Trace_masked=vertical_Trace_masked*1e9;
    vertical_ReTrace_masked=vertical_ReTrace_masked*1e9;
    vertForce_1_masked=(vertical_Trace_masked+vertical_ReTrace_masked)/2;
    % show the data before starting
    nameFig=nameFig_base+"_1_LateralDataForce";
    showData(idxMon,false,Lateral_Trace_masked,"Lateral Trace",saveFigPath,nameFig,"labelBar","Voltage [V]",...
        "extraData",{Lateral_ReTrace_masked,force_1_masked,vertical_Trace_masked,vertical_ReTrace_masked}, ...
        "extraTitles",{"Lateral ReTrace","Lateral Force","Vertical Trace","Vertical ReTrace"}, ...
        "extraLabel",{"Voltage [V]","Force [nN]","Force [nN]","Force [nN]"});
    % show also distribution of lateral deflection trace-retrace and force into additional fig
    figDistr=figure('Visible','on');        
    tl = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact',"Parent",figDistr);
    axDistV  = nexttile(tl);
    axDistN = nexttile(tl);
    sgtitle(figDistr,textTitle,'FontSize',18,'Interpreter','none');
    % DISTRIBUTION OF VOLTAGE DATA
    hold(axDistV,"on")
    edges=min(min(Lateral_Trace_masked(:)),min(Lateral_ReTrace_masked(:))):.025:max(max(Lateral_Trace_masked(:)),max(Lateral_ReTrace_masked(:)));    
    histogram(axDistV,Lateral_Trace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral Trace","Normalization","pdf");
    histogram(axDistV,Lateral_ReTrace_masked,'BinEdges',edges,'FaceAlpha', 0.3,"DisplayName","Lateral ReTrace","Normalization","pdf");
    allDataHistog=[Lateral_Trace_masked(:);Lateral_ReTrace_masked(:)];
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
    nameFig2=nameFig_base+"_2_LateralDataDistributionValues";
    grid(axDistN,"on"), grid(axDistN,"minor")
    objInSecondMonitor(axDistV,idxMon)
    % apply indipently of the used method different cleaning outliers steps
    %   first clearing: filter out anomalies among vertical data by threshold betweem trace and retrace
    %   second clearing: filter out force with 20% more than the setpoint for the specific section
    %   show also the lateral and vertical data after clearing
    nameFig=nameFig_base+"_3_LateralVerticalData_postCleared";
    [vertForce_2_clear,force_2_clear]=A2_2_processLat_1_feature_ClearAndPlotForce(vertical_Trace_masked,vertical_ReTrace_masked,force_1_masked,idxSection,saveFigPath,nameFig,idxMon);    
    saveFigures_FigAndTiff(figDistr,saveFigPath,nameFig2)
    varargout{2}=force_2_clear;
    varargout{3}=force_1_masked;
    varargout{4}=vertForce_2_clear;
    varargout{5}=vertForce_1_masked;
end
