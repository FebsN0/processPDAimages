function [dataForce,idxSection]=A2_2_processLat_1_LatVolt2LatForce(AFM_data,AFM_height_IO,metadata,saveFigPath,nameFig_base,idxMon,modeScan)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% PREPARE THE DATA BEFORE CONVERTING LATERAL DEFLECTION (V) INTO LATERAL FORCE (nN) + SHOW EVERYTHING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Z%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % originally, mask:1 = PDA, mask:0 = BK ==> since we transform into nan those pixels in corrispondence of 1 value of the mask,
    % invert 0->1 and 1->0 in case of normal scan. When there is friction processing, no conversion
    if modeScan==1
        AFM_height_IO=~AFM_height_IO;
        typeMask="BK";
    else
        typeMask="PDA";
    end
    mask=logical(AFM_height_IO);
    % prepare the idx for each section depending on the size of each section stored in the metadata to better
    % distinguish and prepare the fit for each section data. If there are multiple sections in the metadata 
    idxSection=metadata.y_scan_pixels;
    % extract vertical data
    vertical_Trace = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);
    vertical_ReTrace = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);                                            
    % correct vertical forces
    vertForce_0_entire=(vertical_Trace+vertical_ReTrace)/2;
    vertForce_0_entire=vertForce_0_entire*1e9;
    % extract lateral data     
    Lateral_Trace_1   = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostHeightProcessed);    
    Lateral_ReTrace_1 = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'ReTrace')).AFM_images_2_PostHeightProcessed);
    % DISTRIBUTION OF VOLTAGE DATA and its statistics
    nameFig=nameFig_base+"_1_LateralDeflection_Full_StatsResults";
    afmDistribution_skewness_analysis(Lateral_Trace_1,Lateral_ReTrace_1,saveFigPath,nameFig,"Voltage","Full Data");    
    %%%%%%%%%%% NOTE %%%%%%%%%%%
    % some changes will be introduced here. In order to make a straigh comparison, keep the previous method (W=trace-delta), other than the new one
    % i.e. shift the entire dataset by the median of BK.
    %%% OLD METHOD: 
    Delta = (Lateral_Trace_1 + Lateral_ReTrace_1) / 2;   
    W_trace_old = Lateral_Trace_1 - Delta;
    % W_retrace_old = Lateral_ReTrace_1 - Delta; ==> no reason to calc W_retrace because perfectly simmetrical to W_trace
    %%% NEW METHOD
    % extract lateral data of only BK trace-retrace and then calc the median axis (average of the medians of trace and retrace raw lateral deflection-BK images)
    %Lateral_Trace_BK_1 = Lateral_Trace_1;
    %Lateral_Trace_BK_1(~mask)=nan; % remove FR data
    %Lateral_ReTrace_BK_1 = Lateral_ReTrace_1;
    %Lateral_ReTrace_BK_1(~mask)=nan; % remove FR data
    %nameFig=nameFig_base+"_2_LateralDeflection_BKonly_StatsResults";
    %afmDistribution_skewness_analysis(Lateral_Trace_BK_1,Lateral_ReTrace_BK_1,saveFigPath,nameFig,"Voltage","BK-only");      
    % Clean lateral deflection data removing the spikes at the edges
    pix = 5; % number of pixels to be brutally removed at the edges
    segmentProcess = 3; % case 1: SingleSegments, case 2: ConnectedSegment, case 3: EntireSection
    outlierRemovalMethod = 1; % no additionalRemoval
    % ~mask instead of mask to delete BK data
    Lateral_Trace_2_cleared = remove_Edges_Outlier(Lateral_Trace_1,~mask,pix,segmentProcess,outlierRemovalMethod);
    Lateral_ReTrace_2_cleared = remove_Edges_Outlier(Lateral_ReTrace_1,~mask,pix,segmentProcess,outlierRemovalMethod);
    Lateral_Trace_BK_2_cleared=Lateral_Trace_2_cleared;
    Lateral_Trace_BK_2_cleared(~mask)=nan; % remove FR data
    Lateral_ReTrace_BK_2_cleared=Lateral_ReTrace_2_cleared;
    Lateral_ReTrace_BK_2_cleared(~mask)=nan; % remove FR data
    %nameFig=nameFig_base+"_3_LateralDeflection_BKonly_EdgesCleared_StatsResults";
    %afmDistribution_skewness_analysis(Lateral_Trace_BK_2_cleared,Lateral_ReTrace_BK_2_cleared,saveFigPath,nameFig,"Voltage","BK-only-EdgesCleared");     
    % find the plane over BK dataset 
    %%%%%%%%%%%%%%%%%%%%%%---------------------------
    %%% METHOD 1 (my method, plane fitting only)
    planeTrace=planeFitting_N_Order(Lateral_Trace_BK_2_cleared,3);
    planeReTrace=planeFitting_N_Order(Lateral_ReTrace_BK_2_cleared,3);
    % not full fit correction because it shifts all the dataset towards the x-y axis ==> removing DC offset
    Lateral_Trace_BK_3_detilt=Lateral_Trace_BK_2_cleared-(planeTrace-mean(planeTrace(:),"omitnan"));
    Lateral_ReTrace_BK_3_detilt=Lateral_ReTrace_BK_2_cleared-(planeReTrace-mean(planeReTrace(:),"omitnan"));   
    % save the axis median between the two distribution ==> this will be the zero axis!
    nameFig=nameFig_base+"_2_LateralDeflection_BKonly_Detilted_StatsResults";
    resStats=afmDistribution_skewness_analysis(Lateral_Trace_BK_3_detilt,Lateral_ReTrace_BK_3_detilt,saveFigPath,nameFig,"Voltage","BK-only");   
    % detilting original raw data of both trace and retrace
    Lateral_Trace_3_detilt=Lateral_Trace_1-(planeTrace-mean(planeTrace(:),"omitnan"));
    Lateral_ReTrace_3_detilt=Lateral_ReTrace_1-(planeReTrace-mean(planeReTrace(:),"omitnan"));   
    nameFig=nameFig_base+"_3_LateralDeflection_Full_Detilted_StatsResults";
    afmDistribution_skewness_analysis(Lateral_Trace_3_detilt,Lateral_ReTrace_3_detilt,saveFigPath,nameFig,"Voltage","Full Detilted-Data");            
    % Shift the dataset by mirrorAxis relative of detilted background data
    medAxisBK=resStats.medianAxis;
    Lateral_Trace_4_shifted=Lateral_Trace_3_detilt-medAxisBK;
    Lateral_ReTrace_4_shifted=Lateral_ReTrace_3_detilt-medAxisBK;
    nameFig=nameFig_base+"_4_LateralDeflection_Full_Final_StatsResults";
    afmDistribution_skewness_analysis(Lateral_Trace_4_shifted,Lateral_ReTrace_4_shifted,saveFigPath,nameFig,"Voltage","Full Final-Data");  
    % obtain the mirrored retrace dataset (different from trace) along medAxisBK which is now 0 because datasets are already shifted
    Lateral_ReTrace_5_mirrored = -Lateral_ReTrace_4_shifted;
    %%%%%%%%%%%%%%%%%%%%%%---------------------------
    %%% METHOD 2 (Kaori method, lineXline fitting and avg)
    baseline_lineFitTrace=lineByLineFitting_N_Order(Lateral_Trace_BK_2_cleared,3);
    baseline_lineFitReTrace=lineByLineFitting_N_Order(Lateral_ReTrace_BK_2_cleared,3);    
    avgBaselineT=mean(baseline_lineFitTrace);
    avgBaselineR=mean(baseline_lineFitReTrace);
    avgBaselineBoth = mean([avgBaselineT;avgBaselineR]);  
    Lateral_Trace_3_shifted = Lateral_Trace_1-avgBaselineBoth;
    Lateral_ReTrace_3_shifted = Lateral_ReTrace_1-avgBaselineBoth;
    Lateral_ReTrace_4_mirrored = -Lateral_ReTrace_3_shifted;
    nameFig=nameFig_base+"_4_LateralDeflection_Full_Shifted_StatsResults";
    afmDistribution_skewness_analysis(Lateral_Trace_3_shifted,Lateral_ReTrace_3_shifted,saveFigPath,nameFig,"Voltage","Full Shifted-Data");
    %%%%%%%%%%%%%%%%%%%%%%---------------------------
    % convert the final data into force
    alpha=metadata.Alpha;
    % keep old approach
    force_0_entire_old=W_trace_old*alpha*1e9; %Convert N into nN
    % new method 1
    force_0_entire_trace_new1=Lateral_Trace_4_shifted*alpha*1e9; %Convert N into nN
    force_0_entire_retrace_new1=Lateral_ReTrace_5_mirrored*alpha*1e9; %Convert N into nN
    % new method 2
    force_0_entire_trace_new2=Lateral_Trace_3_shifted*alpha*1e9; %Convert N into nN
    force_0_entire_retrace_new2=Lateral_ReTrace_4_mirrored*alpha*1e9; %Convert N into nN

    % mask the data    
    force_1_masked_old=force_0_entire_old;
    force_1_masked_old(mask)=nan;
    force_1_masked_trace1=force_0_entire_trace_new1;
    force_1_masked_trace1(mask)=nan;
    force_1_masked_retrace1=force_0_entire_retrace_new1;
    force_1_masked_retrace1(mask)=nan;
    force_1_masked_trace2=force_0_entire_trace_new2;
    force_1_masked_trace2(mask)=nan;
    force_1_masked_retrace2=force_0_entire_retrace_new2;
    force_1_masked_retrace2(mask)=nan;
    vertForce_1_masked=vertForce_0_entire;
    vertForce_1_masked(mask)=nan;
    % adjust xlim
    allDataHistog=[force_0_entire_old(:);force_0_entire_trace_new1(:);force_0_entire_retrace_new1(:)];
    pLow = prctile(allDataHistog, .5);
    pHigh = prctile(allDataHistog, 99.5);    
    figForceDist=figure;
    for i=1:2
        ax = nexttile;
        hold(ax, 'on'); 
        if i==1
            vect_f_old=force_0_entire_old(:);
            vect_f_tr1=force_0_entire_trace_new1(:);
            vect_f_rt1=force_0_entire_retrace_new1(:);
            vect_f_tr2=force_0_entire_trace_new2(:);
            vect_f_rt2=force_0_entire_retrace_new2(:);
            % take only FR datapoint
        else
            vect_f_old=force_1_masked_old(:);
            vect_f_tr1=force_1_masked_trace1(:);
            vect_f_rt1=force_1_masked_retrace1(:);
            vect_f_tr2=force_1_masked_trace2(:);
            vect_f_rt2=force_1_masked_retrace2(:);
            vect_f_old=vect_f_old(~isnan(vect_f_old));
            vect_f_tr1=vect_f_tr1(~isnan(vect_f_tr1));
            vect_f_rt1=vect_f_rt1(~isnan(vect_f_rt1));
            vect_f_tr2=vect_f_tr2(~isnan(vect_f_tr2));
            vect_f_rt2=vect_f_rt2(~isnan(vect_f_rt2));
        end
        [f_old, xi_old] = ksdensity(vect_f_old);
        [f_tr1, xi_tr1] = ksdensity(vect_f_tr1);
        [f_rt1, xi_rt1] = ksdensity(vect_f_rt1); 
        [f_tr2, xi_tr2] = ksdensity(vect_f_tr2);
        [f_rt2, xi_rt2] = ksdensity(vect_f_rt2);  
        fill_between(ax, xi_old, f_old, globalColor(1), 0.25);   
        fill_between(ax, xi_tr1, f_tr1, globalColor(2), 0.25);     
        fill_between(ax, xi_rt1, f_rt1, globalColor(3), 0.25);     
        fill_between(ax, xi_tr2, f_tr2, globalColor(4), 0.25);     
        fill_between(ax, xi_rt2, f_rt2, globalColor(5), 0.25);     
        
        plot(ax, xi_old,     f_old,    '-', 'Color', globalColor(1), 'LineWidth', 2.0, 'DisplayName', 'Force-Old');
        plot(ax, xi_tr1,     f_tr1,    '-', 'Color', globalColor(2), 'LineWidth', 2.0, 'DisplayName', 'Force-Trace 1');
        plot(ax, xi_rt1,     f_rt1,    '-', 'Color', globalColor(3), 'LineWidth', 2.0, 'DisplayName', 'Force-ReTrace 1');
        plot(ax, xi_tr2,     f_tr2,    '-', 'Color', globalColor(4), 'LineWidth', 2.0, 'DisplayName', 'Force-Trace 2');
        plot(ax, xi_rt2,     f_rt2,    '-', 'Color', globalColor(5), 'LineWidth', 2.0, 'DisplayName', 'Force-ReTrace 2');
        % Mean/median lines
        med_old = median(vect_f_old);
        med_tr1  = median(vect_f_tr1);
        med_rt1  = median(vect_f_rt1);
        med_tr2  = median(vect_f_tr2);
        med_rt2  = median(vect_f_rt2);
        plot(ax, [med_old  med_old],  [0 max(f_old)],  ':', 'Color', globalColor(1), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_old));
        plot(ax, [med_tr1  med_tr1],  [0 max(f_tr1)],  ':', 'Color', globalColor(2), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_tr1));
        plot(ax, [med_rt1  med_rt1],  [0 max(f_rt1)],  ':', 'Color', globalColor(3), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_rt1));     
        plot(ax, [med_tr2  med_tr2],  [0 max(f_tr2)],  ':', 'Color', globalColor(4), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_tr2));
        plot(ax, [med_rt2  med_rt2],  [0 max(f_rt2)],  ':', 'Color', globalColor(5), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_rt2));     
      
        legend(ax, 'AutoUpdate','off','EdgeColor',[0.3 0.3 0.3], 'Location','northeast','FontSize',14);
        xlim(ax, [pLow, pHigh]);
        xlabel(ax,"Lateral Force (nN)","FontSize",14),ylabel(ax,"KDE","FontSize",14)
        if i==1
            title(ax, 'KDE distributions of Lateral Force (full data)','FontSize', 16); grid(ax,"on")
        else
            title(ax, 'KDE distributions of Lateral Force (FR-only)','FontSize', 16); grid(ax,"on")
        end
    end
    objInSecondMonitor(figForceDist,idxMon)
    nameFig=nameFig_base+"_5_LateralForce_KDEcomparisons";
    saveFigures_FigAndTiff(figForceDist,saveFigPath,nameFig)

    % show the full data
    nameFig=nameFig_base+"_6_Forces_fullData";
    showData(idxMon,false,force_0_entire_old,"Lateral Force (OldMethod)",saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_0_entire_trace_new1,force_0_entire_retrace_new1}, ...
        "extraTitles",{"Lateral Force - Trace","Lateral Force - ReTrace"}, ...
        "extraLabel",{"Force [nN]","Force [nN]"});
    
    % prepare the output
    dataForce.vertForce_0_entire=vertForce_0_entire;
    dataForce.vertForce_1_masked=vertForce_1_masked;
    dataForce.vertForce_2_clear=[];
    dataForce.force_0_entire_old=force_0_entire_old;
    dataForce.force_0_trace_entire=force_0_entire_trace_new1;
    dataForce.force_0_retrace_entire=force_0_entire_retrace_new1;
    dataForce.force_1_masked_old=force_1_masked_old;
    dataForce.force_1_trace_masked=force_1_masked_trace1;    
    dataForce.force_1_retrace_masked=force_1_masked_retrace1;
    dataForce.force_2_clear_old=[];
    dataForce.force_2_trace_clear=[];
    dataForce.force_2_retrace_clear=[];
    % show the masked data
    nameFig=nameFig_base+"_7_Forces_MaskedData";
    formats=["Lateral Force-old (%s-masked)";"Lateral Force - Trace (%s-masked)";"Lateral Force - ReTrace (%s-masked)"];
    textDefinitive=compose(formats,typeMask);
    showData(idxMon,false,force_1_masked_old,textDefinitive(1),saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_1_masked_trace1,force_1_masked_retrace1}, ...
        "extraTitles",{textDefinitive(2),textDefinitive(3)}, ...
        "extraLabel",{"Force [nN]","Force [nN]"});
    % clean and show definitive force data
    nameFig=nameFig_base+"_8_Forces_clearedData";
    [vertForce_2_clear,force_2_clear_old,force_2_trace_clear,force_2_retrace_clear]=A2_2_processLat_1_feature_ClearAndPlotForce(vertical_Trace,vertical_ReTrace,force_1_masked_old,force_1_masked_trace1,force_1_masked_retrace1,idxSection,saveFigPath,nameFig,idxMon);    
    textDefinitive=["Vertical Force (cleared)";"Lateral Force (cleared)"];
    showData(idxMon,false,vertForce_2_clear,textDefinitive(1),saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_2_clear}, ...
        "extraTitles",{textDefinitive(2)}, ...
        "extraLabel",{"Force [nN]"}); 
    
    
    

    % save the final data
    dataForce.vertForce_2_clear=vertForce_2_clear;
    dataForce.force_2_clear=force_2_clear;
end


function fill_between(ax, x, y, col, alpha)
% Fill area under a curve.
    p=patch(ax, [x, fliplr(x)], [y, zeros(1,numel(y))], ...
        col, 'FaceAlpha', alpha, 'EdgeColor','none');
    p.Annotation.LegendInformation.IconDisplayStyle="off";
end