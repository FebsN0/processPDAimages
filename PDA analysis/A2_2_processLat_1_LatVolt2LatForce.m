function [dataForce,idxSection]=A2_2_processLat_1_LatVolt2LatForce(AFM_data,AFM_height_IO,metadata,saveFigPath,nameFig_base,idxMon)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% PREPARE THE DATA BEFORE CONVERTING LATERAL DEFLECTION (V) INTO LATERAL FORCE (nN) + SHOW EVERYTHING %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Z%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % originally, mask:1 = PDA, mask:0 = BK ==> since we transform into nan those pixels in corrispondence of 1 value of the mask,
    % invert 0->1 and 1->0 in case of normal scan. When there is friction processing, no conversion

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
    %------- STEP 1: shift the Lateral Deflection toward zero considering trace and retrace. Because of laser drift, the value of the laser when
    % idle is not zero.
    % First step: extract Background data only and remove edges that have spike values
    pix = 5; % number of pixels to be brutally removed at the edges
    segmentProcess = 3; % case 1: SingleSegments, case 2: ConnectedSegment, case 3: EntireSection
    outlierRemovalMethod = 1; % no additionalRemoval
    % ~mask instead of mask to delete BK data
    Lateral_Trace_2_cleared = remove_Edges_Outlier(Lateral_Trace_1,mask,pix,segmentProcess,outlierRemovalMethod);
    Lateral_ReTrace_2_cleared = remove_Edges_Outlier(Lateral_ReTrace_1,mask,pix,segmentProcess,outlierRemovalMethod);
    Lateral_Trace_BK_2_cleared=Lateral_Trace_2_cleared;
    Lateral_Trace_BK_2_cleared(mask)=nan; % remove FR data
    Lateral_ReTrace_BK_2_cleared=Lateral_ReTrace_2_cleared;
    Lateral_ReTrace_BK_2_cleared(mask)=nan; % remove FR data
    %------- STEP 2: take the fast scan line and average. Then shift the real raw lateral deflection by that average value
    DeltaTmp=(Lateral_Trace_BK_2_cleared+Lateral_ReTrace_BK_2_cleared)/2;
    DeltaDef=mean(DeltaTmp,1,"omitnan");
    Lateral_Trace_3_shifted=Lateral_Trace_1-DeltaDef;
    Lateral_ReTrace_3_shifted=Lateral_ReTrace_1-DeltaDef;
    nameFig=nameFig_base+"_2_LateralDeflection_Full_Final_StatsResults";
    afmDistribution_skewness_analysis(Lateral_Trace_3_shifted,Lateral_ReTrace_3_shifted,saveFigPath,nameFig,"Voltage","Full FinalFixed-Data");  
    % obtain the mirrored retrace dataset (different from trace) along medAxisBK which is now 0 because datasets are already shifted
    Lateral_ReTrace_4_mirrored = -Lateral_ReTrace_3_shifted;
    %------- STEP 3: convert the final data into force
    alpha=metadata.Alpha;    
    force_0_entire_trace=Lateral_Trace_3_shifted*alpha*1e9; %Convert N into nN
    force_0_entire_retrace=Lateral_ReTrace_4_mirrored*alpha*1e9; %Convert N into nN
    force_0_entire_PixelmaxValue=max(force_0_entire_trace,force_0_entire_retrace);
    % mask the data, take only FR 
    force_1_masked_trace=force_0_entire_trace;
    force_1_masked_trace(~mask)=nan;
    force_1_masked_retrace=force_0_entire_retrace;
    force_1_masked_retrace(~mask)=nan;
    force_1_masked_PixelmaxValue=force_0_entire_PixelmaxValue;
    force_1_masked_PixelmaxValue(~mask)=nan;
    % adjust xlim
    allDataHistog=[force_0_entire_trace(:);force_0_entire_retrace(:)];
    pLow = prctile(allDataHistog, .5);
    pHigh = prctile(allDataHistog, 99.5);    
    figForceDist=figure;
    for i=1:2
        ax = nexttile;
        hold(ax, 'on'); 
        if i==1
            % take only all datapoint
            vect_f_tr=force_0_entire_trace(:);
            vect_f_rt=force_0_entire_retrace(:);        
            vect_f_max=force_0_entire_PixelmaxValue(:);        
        else           
            % exclude nan
            vect_f_tr=force_1_masked_trace(:);
            vect_f_rt=force_1_masked_retrace(:);
            vect_f_max=force_1_masked_PixelmaxValue(:);
            vect_f_tr=vect_f_tr(~isnan(vect_f_tr));
            vect_f_rt=vect_f_rt(~isnan(vect_f_rt)); 
            vect_f_max=vect_f_max(~isnan(vect_f_max));
        end
        [f_tr, xi_tr] = ksdensity(vect_f_tr);
        [f_rt, xi_rt] = ksdensity(vect_f_rt); 
        [f_max, xi_max] = ksdensity(vect_f_max);
        fill_between(ax, xi_tr, f_tr, globalColor(1), 0.25);     
        fill_between(ax, xi_rt, f_rt, globalColor(2), 0.25);
        fill_between(ax, xi_max, f_max, globalColor(3), 0.25);
        plot(ax, xi_tr,     f_tr,    '-', 'Color', globalColor(1), 'LineWidth', 2.0, 'DisplayName', 'Force-Trace');
        plot(ax, xi_rt,     f_rt,    '-', 'Color', globalColor(2), 'LineWidth', 2.0, 'DisplayName', 'Force-ReTrace');
        plot(ax, xi_max,    f_max,   ':', 'Color', globalColor(3), 'LineWidth', 1.0, 'DisplayName', 'Force-MaxPixel');
        % Mean/median lines
        med_tr  = median(vect_f_tr);
        med_rt  = median(vect_f_rt);
        med_max = median(vect_f_max);
        plot(ax, [med_tr  med_tr],  [0 max(f_tr)],  ':', 'Color', globalColor(1), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_tr));
        plot(ax, [med_rt  med_rt],  [0 max(f_rt)],  ':', 'Color', globalColor(2), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_rt));            
        plot(ax, [med_rt  med_max], [0 max(f_max)], ':', 'Color', globalColor(3), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_max));
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
    nameFig=nameFig_base+"_3_LateralForce_KDEcomparisons";
    saveFigures_FigAndTiff(figForceDist,saveFigPath,nameFig)

    % show the full data
    nameFig=nameFig_base+"_4_Forces_fullData";
    showData(idxMon,false,vertForce_0_entire,"Vertical Force",saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_0_entire_trace,force_0_entire_retrace,force_0_entire_PixelmaxValue}, ...
        "extraTitles",{"Lateral Force - Trace","Lateral Force - ReTrace","Lateral Force - MaxPixelV"}, ...
        "extraLabel",{"Force [nN]","Force [nN]","Force [nN]"},...
        "bigTitle","Force Distribution");    
    
    % prepare the output
    dataForce.vertForce_0_entire=vertForce_0_entire;   
    dataForce.force_0_trace_entire=force_0_entire_trace;
    dataForce.force_0_retrace_entire=force_0_entire_retrace;   
    dataForce.force_0_entire_PixelmaxValue=force_0_entire_PixelmaxValue;  
    
    % in order to preserve the data after alignment with BF IO image, better to not exclude values... But only in the end, after assembly and
    % alignment, before the Force-Fluorescence correlation
    
    % clean and show definitive force data using Foreground data    
    %{
    dataForce.vertForce_1_clear=[];
    dataForce.force_1_trace_clear=[];
    dataForce.force_1_retrace_clear=[];

    [vertForce_2_clear,force_2_trace_clear,force_2_retrace_clear,numRemovedElements_allSteps]=A2_2_processLat_1_feature_ClearAndPlotForce(vertical_Trace,vertical_ReTrace,force_0_entire_trace,force_0_entire_retrace,mask,idxMon);           
    commondtitle=sprintf("Data after clearing. VD-4nN (%.2f%%), LD outliers (%.2f%%), ManualRemoval (%.2f%%)",numRemovedElements_allSteps(1),numRemovedElements_allSteps(2),numRemovedElements_allSteps(3));    
    nameFig=nameFig_base+"_5_Forces_clearedData";
    textDefinitive=["Vertical Force";"Lateral Force Trace";"Lateral Force ReTrace"];
    showData(idxMon,false,vertForce_2_clear,textDefinitive(1),saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_2_trace_clear,force_2_retrace_clear}, ...
        "extraTitles",{textDefinitive(2),textDefinitive(3)}, ...
        "extraLabel",{"Force [nN]","Force [nN]"}, ...
        "bigTitle",commondtitle); 
    % save the final data    
    dataForce.vertForce_1_clear=vertForce_2_clear;
    dataForce.force_1_trace_clear=force_2_trace_clear;
    dataForce.force_1_retrace_clear=force_2_retrace_clear;    
    % show data masked
    nameFig=nameFig_base+"_6_Forces_maskedData";
    textDefinitive=["Vertical Force (masked)";"Lateral Force Trace (masked)";"Lateral Force ReTrace (masked)"];
    vertForce_mask=vertForce_2_clear;       vertForce_mask(~mask)=nan;
    force_tr_mask =force_2_trace_clear;     force_tr_mask(~mask)=nan;
    force_rt_mask =force_2_retrace_clear;   force_rt_mask(~mask)=nan;
    showData(idxMon,false,vertForce_mask,textDefinitive(1),saveFigPath,nameFig,"labelBar","Force [nN]",...
        "extraData",{force_tr_mask,force_rt_mask}, ...
        "extraTitles",{textDefinitive(2),textDefinitive(3)}, ...
        "extraLabel",{"Force [nN]","Force [nN]"}); 
    %}
end
