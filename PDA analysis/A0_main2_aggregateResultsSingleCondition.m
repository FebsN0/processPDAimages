clc, clear, close all
idxMon=objInSecondMonitor;

% USEFUL COMMAND TO EXCLUDE DATAPOINT FROM AN OPENED FIGURE
% data=gca;
% allLines = findobj(data, 'Type', 'line');
% names = get(allLines, 'DisplayName');
% mask = contains(names, 'Sample', 'IgnoreCase', true) & ~contains(names, 'Fitted');
% datapoint = allLines(mask);
% delete(datapoint)
% axtoolbar(data, 'default');


mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DMPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DOPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_POPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026";

% turn off warning prepareCurve
warning('off',  'curvefit:prepareFittingData:removingNaNAndInf');
question='Choose one of the following options about how to show results of force-fluorescence correlation.';
options={'Show results of all scans of a specific experiment (ex. all scans of TRCDA)',...
    'Show results of interpolated scans of all experiments (ex. TRCDA, TRCDA:DMPC,etc)'};
typeShow=getValidAnswer(question,'',options);
norm=false;
if getValidAnswer("What type of data to show?","",{"Real","Normalized"})==1
    saveFolderAdditionalText="NotNormalized";
else
    norm=true;
    % NORMALIZE ALL THE DATA BEFORE CONTINUE
    NormFactors=A0_feature_Normalization;
    % select the type of normalization
    NormFactors_def=struct();
    if getValidAnswer("Which type of Normalization?","",{"From FULL TRITIC","From Masked TRITIC"})==1
        fieldsToCopy = {'name', 'avgFull'};
        saveFolderAdditionalText="Normalized_Full";
    else
        fieldsToCopy = {'name', 'avgMask'};
        saveFolderAdditionalText="Normalized_Mask";
    end
    for k = 1:numel(NormFactors)
        NormFactors_def(k).name = NormFactors(k).(fieldsToCopy{1});
        NormFactors_def(k).normFactor = NormFactors(k).(fieldsToCopy{2});        
    end      
end
clear NormFactors k fieldsToCopy
if norm==false
    ylabelText='Absolute fluorescence Intensity (A.U.)';
else
    ylabelText='Normalized Fluorescence Intensity';
end
clear question options
% prepare the figures to show the definitive results
if typeShow==1
    if ~(exist("mainFolderSingleCondition","var") && exist(mainFolderSingleCondition,"dir") && getValidAnswer(sprintf("Is the selected path of the scan to process correct?\n%s",mainFolderSingleCondition),"",{"Y","N"}))             
        mainFolderSingleCondition={uigetdir(pwd,'Locate the dir of a specific experiment condition that contains the results of any scans.')};
    end
    nExps=1;
    nameExps=extractNameExp(mainFolderSingleCondition,nExps);
    textSubTitleLD_FLUO=sprintf('Comparison of different scans / same sample (%s) - ',nameExps{1});      
    % x Height vs FLUO
    fig_Height_FLUO=figure(Visible="on"); ax_Height_FLUO=axes(fig_Height_FLUO); hold(ax_Height_FLUO,"on")
    xlabel(ax_Height_FLUO,'Height [nm]','FontSize',15), ylabel(ax_Height_FLUO,ylabelText,'FontSize',15)
    title(ax_Height_FLUO,'Height Vs Fluorescence',"FontSize",24)   
    subtitle(ax_Height_FLUO,sprintf('Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",15,"Interpreter","none")
    % x Height vs LateralForce
    fig_Height_LD=figure(Visible="on"); ax_Height_LD=axes(fig_Height_LD); hold(ax_Height_LD,"on")
    xlabel(ax_Height_LD,'Height [nm]','FontSize',15), ylabel(ax_Height_LD,'Lateral Force [nN]','FontSize',15)
    title(ax_Height_LD,'Height Vs Lateral Force',"FontSize",24)   
    subtitle(ax_Height_LD,sprintf('Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",15,"Interpreter","none")
    % baseline trend
    fig_baselineTrend=figure(Visible="on"); ax_baselineTrend=axes(fig_baselineTrend); hold(ax_baselineTrend,"on")
    ylabel(ax_baselineTrend,'Baseline shift [nN]','FontSize',15), xlabel(ax_baselineTrend,'Time [min]','FontSize',15)
    title(ax_baselineTrend,'Baseline Shift Trend',"FontSize",24)   
    subtitle(ax_baselineTrend,sprintf('Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",15,"Interpreter","none")
else
% for the multiple experiment case, show only LF-Fluo correlation curves
    if ~(exist("mainFolderSingleCondition","var") && exist(mainFolderSingleCondition,"dir"))
        mainFolderSingleCondition=pwd;
    end
    mainFolderSingleCondition=uigetdirMultiSelect(mainFolderSingleCondition,'Select the dirs which contain the ForceFluorescence results (multi experiments selection).');
    nExps=numel(mainFolderSingleCondition);
    nameExps=extractNameExp(mainFolderSingleCondition,nExps);
    textSubTitleLD_FLUO="Comparison of different scans of different same samples - ";
end
% x Lateral Force vs Fluorescence. (one for first masking (original) and one for last masking (cleared))
textAdditional={"LatForce-trace After 1st Mask","LatForce-trace After 3rd Mask",...
    "LatForce-retrace After 1st Mask","LatForce-retrace After 3rd Mask",...
    "LatForce-AVG After 1st Mask","LatForce-AVG After 3rd Mask",...
    "LatForce-maxPixelValue After 1st Mask","LatForce-maxPixelValue After 3rd Mask",};
fig_LD_FLUO=cell(1,numel(textAdditional)); ax_LD_FLUO=cell(1,numel(textAdditional));
xlabelText='Lateral Force [nN]';
subtitleText=cell(1,numel(textAdditional));
for i=1:numel(textAdditional)
    fig_LD_FLUO{i}=figure(Visible="on"); ax_LD_FLUO{i}=axes(fig_LD_FLUO{i}); hold(ax_LD_FLUO{i},"on") %#ok<LAXES>
    xlabel(ax_LD_FLUO{i},xlabelText); ylabel(ax_LD_FLUO{i},ylabelText)
    subtitleText{i}=sprintf("%s%s",textSubTitleLD_FLUO,textAdditional{i});
end
clear xlabelText ylabelText textAdditional
% init
allDelta_1M={}; allDelta_3M={};
arrayXother = [];
arrayXlegend_full_1M=[];                % store the main line of the plot (for the full data of Force-Fluorescence and other in case of TypeShow=1)
arrayXlegend_fitLine_3M_ForceFluorescence=struct();   % store the fitted line
for expTh=1:nExps
    clc
    fprintf("Processing results of all scans of the experiment %s\n\n",nameExps{expTh})
    % Automatically find all resultsData_7_END files among the scans
    hits = dir(fullfile(mainFolderSingleCondition{expTh}, '**', 'resultsData_7_END_Force_Fluorescence_Correlation.mat'));
    if isempty(hits)
        warning("No 'resultsData_7_END_Force_Fluorescence_Correlation.mat' files found under:\n  %s", mainFolderSingleCondition{expTh});
    else
        allResultsData_pathfile = cell(numel(hits), 1);
        for k = 1:numel(hits)
            allResultsData_pathfile{k} = fullfile(hits(k).folder, hits(k).name);
            fprintf("\tFound result data in filepath: %s\n", fileparts(hits(k).folder));
        end
    end    
    clear hits k
    nScans=numel(allResultsData_pathfile); 
    nameData=cell(1,length(allResultsData_pathfile));
    % Reset the struct array
    fullDataXfitting_trace = struct('xData', {}, 'yData', {});   
    fullDataXfitting_retrace = struct('xData', {}, 'yData', {});   
    fullDataXfitting_avg = struct('xData', {}, 'yData', {});   
    fullDataXfitting_mpv = struct('xData', {}, 'yData', {});   
    cntDelta=length(allDelta_1M);  
    % in case of normalization, prepare the normalization factors (full or masked TRITIC)
    if norm
        question=sprintf("Exp: %s. Select the proper name from Normalization DataFile.",nameExps{expTh});        
        resultsChoice=selectOptionsDialog(question,false,{NormFactors_def.name},'Titles',{'Name from Normalization file'});
        normFactor =  NormFactors_def(resultsChoice{1}).normFactor;
        fprintf("\nData name:\t%s\nNorm name:\t%s\nValue normalization:\t%g\n",nameExps{expTh},NormFactors_def(resultsChoice{1}).name,normFactor)   
    end
    for i=1:nScans            
        % if only one type of data, better visual using different color, but in case of more type/different
        % samples, use single color for each type/sample
        if typeShow==1
            clr=globalColor(i);
            tmp=strsplit(allResultsData_pathfile{i},'\');   
            tmp = sprintf('Scan #%s',tmp{end-2});            
        else
            clr=globalColor(expTh);
            tmp=sprintf('Sample %s',nameExps{expTh});
        end
        nameData{i}=tmp;
        % load only fluorescence and lateral deflection
        load(allResultsData_pathfile{i},"Data_finalResults","metaData_AFM","metaData_NIKON_definitive","SaveFigFolder")
        metaData_BF=metaData_NIKON_definitive.BF;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data Delta (first and third masking) %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        allDelta_original{cntDelta+i}= Data_finalResults.DeltaData.Delta_original;         %#ok<SAGROW>
        allDelta_1M{cntDelta+i}= Data_finalResults.DeltaData.Delta_firstMasking;         %#ok<SAGROW>
        allDelta_3M{cntDelta+i}= Data_finalResults.DeltaData.Delta_thirdMasking_MaxSet; %#ok<SAGROW>        
        allDelta_pixScale(cntDelta+i,1)=metaData_BF.ImageHeight_umeterXpixel;             %#ok<SAGROW>
        allDelta_pixScale(cntDelta+i,2)=metaData_BF.ImageWidth_umeterXpixel;        %#ok<SAGROW>
        subfolder_allscanFolder{cntDelta+i}=SaveFigFolder;                           %#ok<SAGROW>

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the first (full) and third masked (each AFM channel) data fluorescence VS lateral deflection - trace (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % repeat the process twice to see Lateral Force Trace and Lateral Force MaxPixelValue
        fieldsLDData={"LD_FLUO_tr","LD_FLUO_rt","LD_FLUO_avg","LD_FLUO_maxPixelV"};
        for j=1:numel(fieldsLDData)
            % first and third masks        
            fnames=fieldnames(Data_finalResults.(fieldsLDData{j}));
            % for full data
            x=Data_finalResults.(fieldsLDData{j}).(fnames{1});           % first mask 
            if norm
                tmp=[x.BinMedian];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [x.BinMedian] = deal(tmp{:});                        
            end
            [hp_trace,data]=plotSingleData(x,nameData{i},ax_LD_FLUO{j*2-1},clr,1,1,"Full",typeShow);     
            % use the full data for fitting. Once opened the fitting function, there is the possibility to select a range min-max within the value will be used for fitting.
            % Store all data from different scans
            switch j
                case 1
                    fullDataXfitting_trace(i)=data;
                case 2
                    fullDataXfitting_retrace(i)=data;
                case 3
                    fullDataXfitting_avg(i)=data;
                otherwise
                    fullDataXfitting_mpv(i)=data;
            end
                
            if (typeShow == 2 && i==1 && j==1) || (typeShow == 1 && j==1)
                arrayXlegend_full_1M=[arrayXlegend_full_1M, hp_trace]; %#ok<AGROW>
            end              
            % no save data and plot for legend because the fitted handle figures will be used instead
            x=Data_finalResults.(fieldsLDData{j}).(fnames{3});           % third mask 
            if norm
                tmp=[x.BinMedian];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [x.BinMedian] = deal(tmp{:});                        
            end
            plotSingleData(x,nameData{i},ax_LD_FLUO{j*2},clr,1,1,"3M",typeShow);
        end

        clear data tmp SaveFigFolder
        if typeShow == 1
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS fluorescence %%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
            fnames=fieldnames(Data_finalResults.Height_FLUO);
            x=Data_finalResults.Height_FLUO.(fnames{3});
            hother=plotSingleData(x,nameData{i},ax_Height_FLUO,clr,1e9,1,"none",typeShow);
            arrayXother=[arrayXother,hother]; %#ok<AGROW>
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS Lateral Force %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
            fnames=fieldnames(Data_finalResults.Height_LD);
            x=Data_finalResults.Height_LD.(fnames{3});
            plotSingleData(x,nameData{i},ax_Height_LD,clr,1e9,1,"none",typeShow);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the Baseline trend and show %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%              
            totTimeScan = (metaData_AFM.x_scan_pixels/metaData_AFM.Scan_Rate_Hz)/60;
            totTimeSection = totTimeScan/length(metaData_AFM.SetP_N);
            % first plot the baseline given in the metadata
            arrayTime=0:totTimeSection:totTimeScan-totTimeSection;
            baseline_nN=metaData_AFM.Baseline_N*1e9;
            if length(baseline_nN) > 1
                % plot the baseline trend from metadata                
                plot(ax_baselineTrend,arrayTime,baseline_nN,'-*','LineWidth',2,'MarkerSize',10,'MarkerEdgeColor',clr,'Color',clr,'DisplayName',nameData{i})
            end
        end
        clear x totTime*
    end
    % END ALL SCANS PROCESSING

    %%%% TRACE
    % choose the upper limit to fit the data below and plot it
    [fitResults_all_trace,hp_trace,hl_trace,xrange]=chooseAndFit(fullDataXfitting_trace,typeShow,{ax_LD_FLUO{1},ax_LD_FLUO{2}},idxMon,globalColor(expTh),nameExps{expTh},nameData);
    % store slope data of trace mode
    slopeAVG_trace(expTh)=mean([fitResults_all_trace(:).slope]); %#ok<SAGROW>
    slopeSTD_trace(expTh)=std([fitResults_all_trace(:).slope]); %#ok<SAGROW>   
    %%%% RETRACE
    % using the same previous selected range, fit again
    [fitResults_all_retrace,hp_retrace]=chooseAndFit(fullDataXfitting_mpv,typeShow,{ax_LD_FLUO{3},ax_LD_FLUO{4}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
    % store slope data of MaxPixelValue mode
    slopeAVG_retrace(expTh)=mean([fitResults_all_retrace(:).slope]); %#ok<SAGROW>
    slopeSTD_retrace(expTh)=std([fitResults_all_retrace(:).slope]); %#ok<SAGROW>   
    %%%% AVG
    % using the same previous selected range, fit again
    [fitResults_all_avg,hp_avg]=chooseAndFit(fullDataXfitting_mpv,typeShow,{ax_LD_FLUO{5},ax_LD_FLUO{6}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
    % store slope data of MaxPixelValue mode
    slopeAVG_avg(expTh)=mean([fitResults_all_avg(:).slope]); %#ok<SAGROW>
    slopeSTD_avg(expTh)=std([fitResults_all_avg(:).slope]); %#ok<SAGROW>      
    %%%% MAX PIXEL VALUE
    % using the same previous selected range, fit again
    [fitResults_all_maxPixV,hp_mpv]=chooseAndFit(fullDataXfitting_mpv,typeShow,{ax_LD_FLUO{7},ax_LD_FLUO{8}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
    % store slope data of MaxPixelValue mode
    slopeAVG_mpv(expTh)=mean([fitResults_all_maxPixV(:).slope]); %#ok<SAGROW>
    slopeSTD_mpv(expTh)=std([fitResults_all_maxPixV(:).slope]); %#ok<SAGROW>   
    
    % store the handle figure to organize the legend names
    if typeShow == 2
        arrayXlegend_fitLine_3M_ForceFluorescence.trace=[arrayXlegend_fitLine_3M_ForceFluorescence.trace, hp_trace(1)]; 
        arrayXlegend_fitLine_3M_ForceFluorescence.retrace=[arrayXlegend_fitLine_3M_ForceFluorescence.retrace, hp_retrace(1)]; 
        arrayXlegend_fitLine_3M_ForceFluorescence.avg=[arrayXlegend_fitLine_3M_ForceFluorescence.avg, hp_avg(1)]; 
        arrayXlegend_fitLine_3M_ForceFluorescence.mpv=[arrayXlegend_fitLine_3M_ForceFluorescence.mpv, hp_mpv(1)]; 
    else
        arrayXlegend_fitLine_3M_ForceFluorescence.trace=hp_trace;
        arrayXlegend_fitLine_3M_ForceFluorescence.retrace=hp_retrace;
        arrayXlegend_fitLine_3M_ForceFluorescence.avg=hp_avg;
        arrayXlegend_fitLine_3M_ForceFluorescence.mpv=hp_mpv;
    end         
    if typeShow==1
        break
    end      
end
clear fullDataXfitting_trace fullDataXfitting_mpv fnames ans
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ADJUST ESTHETIC PART OF THE PLOTTING AND SAVE  %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% location of the results
if typeShow==2
    folderSaveComparison= fullfile(fileparts(mainFolderSingleCondition{1}),sprintf("finalComparisonForceFluorescenceCurves_%s",saveFolderAdditionalText));
    filename1="endResult_1_ForceTrace_Fluorescence_1MData_allExps";
    filename2="endResult_2_ForceTrace_Fluorescence_3MData_allExps";
    filename3="endResults_3_ForceMaxPixV_Fluorescence_1MData_allExps";
    filename4="endResults_4_ForceMaxPixV_Fluorescence_3MData_allExps";
    textSubTitle_pt2_trace=""; textSubTitle_pt2_mpv="";
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nExps
        text_dataSlope_trace = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_trace(n),slopeSTD_trace(n));
        text_dataSlope_mpv = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_mpv(n),slopeSTD_mpv(n));
        arrayXlegend_fitLine_3M_ForceFluorescence_trace(n).DisplayName = text_dataSlope_trace; %#ok<SAGROW>
        arrayXlegend_fitLine_3M_ForceFluorescence_mpv(n).DisplayName = text_dataSlope_mpv; %#ok<SAGROW>
    end   
    arrayXlegend_full_1M_final=arrayXlegend_full_1M;
else
    folderSaveComparison=fullfile(mainFolderSingleCondition,sprintf("resultsCorrelations_ComparisonAllScans_%s",saveFolderAdditionalText));
    if ~exist(folderSaveComparison,"dir")
        mkdir(folderSaveComparison)   
    end
    filename1=sprintf("endResults_1_ForceTrace_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename2=sprintf("endResults_2_ForceTrace_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename3=sprintf("endResults_3_ForceMaxPixV_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename4=sprintf("endResults_4_ForceMaxPixV_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename5=sprintf("endResults_5_HeightFluorescence_allScan_%s",nameExps{1});
    filename6=sprintf("endResults_6_HeightForce_allScan_%s",nameExps{1});
    filename7=sprintf("endResults_7_baselineTrend_allScan_%s",nameExps{1});
    textSubTitle_pt2_trace=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_trace,slopeSTD_trace);
    textSubTitle_pt2_mpv=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_mpv,slopeSTD_mpv);
    % adjust and save fig of data Height-Fluorescence
    adjustPlot(ax_Height_FLUO,arrayXother,idxMon)
    waitfor(warndlg("Adjust the legend position of the figures first saving for better visual!"))  
    saveFigures_FigAndTiff(fig_Height_FLUO,folderSaveComparison,filename5,'closeImmediately',false)    
    % adjust and save fig of data Height-Force
    adjustPlot(ax_Height_LD,arrayXother,idxMon)
    waitfor(warndlg("Adjust the legend position of the figures first saving for better visual!"))  
    saveFigures_FigAndTiff(fig_Height_LD,folderSaveComparison,filename6,'closeImmediately',false)    
    % adjust and save fig of baseline trend
    adjustPlot(ax_baselineTrend,arrayXother,idxMon)
    waitfor(warndlg("Adjust the legend position of the figures first saving for better visual!"))  
    saveFigures_FigAndTiff(fig_baselineTrend,folderSaveComparison,filename7)    
    close(fig_Height_FLUO), close(fig_Height_LD)
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nScans
        text_dataSlope_trace = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_trace(n).slope,fitResults_all_trace(n).offset);
        text_dataSlope_mpv = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_maxPixV(n).slope,fitResults_all_maxPixV(n).offset);
        arrayXlegend_fitLine_3M_ForceFluorescence_trace(n).DisplayName = text_dataSlope_trace; %#ok<SAGROW>
        arrayXlegend_fitLine_3M_ForceFluorescence_mpv(n).DisplayName = text_dataSlope_mpv; %#ok<SAGROW>
    end 
    arrayXlegend_full_1M_final=[arrayXlegend_full_1M, hl_trace(1)];
end

textTitleLD_FLUO='Lateral Force VS Fluorescence';
% adjust and save fig of full data ForceTrace-Fluo (1M)
adjustPlot(ax_LD_FLUO{1},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{1})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{2};textSubTitle_pt2_trace};
adjustPlot(ax_LD_FLUO{2},arrayXlegend_fitLine_3M_ForceFluorescence_trace,idxMon,textTitleLD_FLUO,textSubTitle)
% adjust and save fig of full data ForceMaxPixelValue-Fluo (1M)
adjustPlot(ax_LD_FLUO{3},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{3})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{4};textSubTitle_pt2_mpv};
adjustPlot(ax_LD_FLUO{4},arrayXlegend_fitLine_3M_ForceFluorescence_mpv,idxMon,textTitleLD_FLUO,textSubTitle)


% adjust the limits of full data
xlimNew=[min(ax_LD_FLUO{1}.XLim(1),ax_LD_FLUO{3}.XLim(1)) max(ax_LD_FLUO{1}.XLim(2),ax_LD_FLUO{3}.XLim(2))];
ax_LD_FLUO{1}.XLim=xlimNew;
ax_LD_FLUO{3}.XLim=xlimNew;
ylimNew=[min(ax_LD_FLUO{1}.YLim(1),ax_LD_FLUO{3}.YLim(1)) max(ax_LD_FLUO{1}.YLim(2),ax_LD_FLUO{3}.YLim(2))];
ax_LD_FLUO{1}.YLim=ylimNew;
ax_LD_FLUO{3}.YLim=ylimNew;
% save fig
for i=1:2:4
    figure(fig_LD_FLUO{i})
    waitfor(warndlg("Adjust the legend position of the figures first saving for better visual!"))  
    saveFigures_FigAndTiff(fig_LD_FLUO{i},folderSaveComparison,eval(sprintf("filename%d",i)),'closeImmediately',false)    
end
close(fig_LD_FLUO{1},fig_LD_FLUO{3})


waitfor(warndlg("Adjust the XLIM/YLIM and legend of the figures first saving for better visual!"))  
% adjust the limits of cleared data
xlimNew=[max(ax_LD_FLUO{2}.XLim(1),ax_LD_FLUO{4}.XLim(1)) min(ax_LD_FLUO{2}.XLim(2),ax_LD_FLUO{4}.XLim(2))];
ax_LD_FLUO{2}.XLim=xlimNew;
ax_LD_FLUO{4}.XLim=xlimNew;
ylimNew=[max(ax_LD_FLUO{2}.YLim(1),ax_LD_FLUO{4}.YLim(1)) min(ax_LD_FLUO{2}.YLim(2),ax_LD_FLUO{4}.YLim(2))];
ax_LD_FLUO{2}.YLim=ylimNew;
ax_LD_FLUO{4}.YLim=ylimNew;
% save
for i=2:2:4
    saveFigures_FigAndTiff(fig_LD_FLUO{i},folderSaveComparison,eval(sprintf("filename%d",i)))    
end


clear text_dataSlope_trace n fitResults_all_trace saveFolderAdditionalText textSubTitle_pt2_trace array* ax* fig* filename* slope* metaData_AFM metaData_BF metaData_NIKON_definitive clr cntDelta Data_finalResults firstPlot expTh hf hl_trace hp_trace i idxLineSample j allResultsData_pathfile baseline_nN
clc, close all

if getValidAnswer("Do want to imadjust and propagate the TRITIC images so they can be visually comparable?\nNOTE: the operation requires some time, especially in case of multiple experiments.",'',{"Y","N"})
    % in order to have fluorescence image scaled in the same way for better representation, lets find the max and mix values of all the scans and propagate all over images
    allDelta={allDelta_original,allDelta_1M,allDelta_3M};
    allDelta_text={"whole","1stMasked","3rdMasked"};
    clear allDelta_original allDelta_1M allDelta_3M 
    for j=1:3
        % find global range across all images. Show data inside the percentile range for better visual
        all_values = cellfun(@(x) x(:), allDelta{j}, 'UniformOutput', false);
        all_values = vertcat(all_values{:});    
        shared_min = prctile(all_values, 0.35);   % robust, mimics ImageJ auto
        shared_max = prctile(all_values, 99.65);  
        rangeScale= [shared_min,shared_max];
        for i=1:length(allDelta{j})
            if typeShow == 1
                filename=sprintf('resultEND_%d_FluorescencePDA_scaled_onEveryScanSingleExp',5+j);
                titleD1=sprintf("DELTA-%s (pixel-scaled over scans)",allDelta_text{j});
            else
                filename=sprintf('resultEND_%d_FluorescencePDA_scaled_onEveryExp',8+j);
                titleD1=sprintf("DELTA-%s (pixel-scaled over samples)",allDelta_text{j});
            end    
            Delta=allDelta{j}{i};
            singleFolder=subfolder_allscanFolder{i};
            showData(idxMon,false,Delta,titleD1,singleFolder,filename,'lenghtAxis',allDelta_pixScale(i,:),'Broadcast',rangeScale)
        end
    end
end
clear allValues filename titleD1 labelBar singleFolder rangeScale allDelta_pixScale Delta ans subfolder_allscanFolder
%%
%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% FUNCTIONS %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%

function [hp,dataXfitting]=plotSingleData(data,nameData,idAxis,clr,xMultiplier,yMultiplier,typeData,typeShow)
%%%%%% extract the data and show only %%%%%%
    x=cell2mat({data.BinCenter});
    y=cell2mat({data.BinMedian});
    x=x*xMultiplier; y=y*yMultiplier;
    % Use prepareCurveData only for the main x/y pair to clean NaN
    [xData, yData] = prepareCurveData(x, y);     
    if typeShow==1
        hp=plot(idAxis,xData,yData,'x','Color',clr,'DisplayName',nameData,'MarkerSize',5,'LineStyle',"-",'LineWidth',1.5);
        if strcmp(typeData,"Full")            
            hp.Marker='o';
            hp.MarkerEdgeColor = clr;
            hp.MarkerFaceColor ='none'; 
            hp.LineStyle="none";
            hp.MarkerSize=2;
        elseif strcmp(typeData,"3M")
            hp.Marker='o'; hp.MarkerFaceColor=clr;        
            hp.MarkerSize=1; hp.LineStyle="none";
        end
    else
        hp=plot(idAxis,xData,yData,'o','MarkerSize',1,'Color',clr,'DisplayName',nameData);
    end
    dataXfitting=struct();
    dataXfitting.xData=xData;
    dataXfitting.yData=yData;
end

function varargout=chooseAndFit(dataXfitting,typeShow,idAxis,idxMon,clr,nameSample,nameData,varargin)
    fitResults=struct();  
    if nargout==4
        % create the figure of the full data, select a range within consider the fitting and then close it without affecting the original
        figTmp=figure; axTmp  = axes(figTmp); hold(axTmp,"on");
        grid(axTmp,'on'), grid(axTmp,'minor'), xlim(axTmp,"padded"), ylim(axTmp,"padded")
        title(axTmp,sprintf('LD vs Fluorescence of every scan of the sample %s',nameSample),'FontSize',20,'Interpreter','none')
        for i=1:length(dataXfitting)
            x=dataXfitting(i).xData;
            y=dataXfitting(i).yData;
            plot(axTmp,x,y,'*','MarkerFaceColor',globalColor(i))     
        end    
        % show with a tmp figure the dataset
        objInSecondMonitor(figTmp,idxMon);        
        waitfor(warndlg(sprintf(['Adjust/pan/zoom view for better visual before clicking "OK".\n' ...
            'Click twice anywhere on the chart to set the minimum and maximum x-value for fitting.\n' ...
            'Data between the two clicked point will be considered for the fitting operation.']),'Warning'))                
        % idx refers to the first plot, so take the first dataset
        [idx,objForXData]=selectRangeGInput(2,1,axTmp); 
        idxRangeFitting=sort(idx);
        tmp = objForXData.XData;
        valueIdxMin=tmp(idxRangeFitting(1)); valueIdxMax=tmp(idxRangeFitting(2)); 
        close(figTmp)
        clear tmp axTmp figTmp idx
        varargout{4}=[valueIdxMin valueIdxMax];
    else
        valueIdxMin=varargin{1}(1); valueIdxMax=varargin{1}(2);
    end
    % plot the lines in the axis figure only in the case of single experiment, otherwise too confusing
    if typeShow==1
        nameLineXlegend=sprintf('Cutoffs (%d÷%d nN)',round(valueIdxMin),round(valueIdxMax));
        % plot the lines in the full data figure. Save the index plot to update the legend
        hl=xline(idAxis{1},[valueIdxMin,valueIdxMax],'--','LineWidth',1,'DisplayName',nameLineXlegend,'Color','k');
        varargout{3}=hl;
    else
        varargout{3}=[];
    end
    
    % Fitting
    ft = fittype( 'poly1' );
    opts = fitoptions( 'Method', 'LinearLeastSquares' );
    opts.Robust = 'LAR';
    arrayXlegend=[];
    hold(idAxis{2}, 'on');
    % For each scan, calc the fitting parameters and project it (slope) in the figure 3M. So, use as X line for f(x) the data from it instead from full data
    axTmp=idAxis{2}; lines=findobj(axTmp,'Type','line');
    for i=1:length(dataXfitting)
        xData = dataXfitting(i).xData;
        yData = dataXfitting(i).yData;
        % find the idx-range for each dataset (scan)
        [~, idxMin] = min(abs(xData - valueIdxMin)); 
        [~, idxMax] = min(abs(xData - valueIdxMax)); 
        % fit using the data within the selected range
        [fitresult, ~] = fit(xData(idxMin:idxMax), yData(idxMin:idxMax), ft, opts );
        xfit=lines(i).XData;
        yfit=xfit*fitresult.p1+fitresult.p2;        
        if typeShow==1
            clrXfit=globalColor(i);
        else
            clrXfit=clr;
        end
        hp=plot(idAxis{2},xfit,yfit,'--','Color',clrXfit,'LineWidth',1.5,'DisplayName',sprintf("Fitted Line - %s",nameData{i}));
        arrayXlegend=[arrayXlegend hp]; %#ok<AGROW>
        % save the fit var to calc the average
        fitResults(i).slope=fitresult.p1; % slope
        fitResults(i).offset=fitresult.p2; % offset       
    end
    varargout{1}=fitResults;
    varargout{2}=arrayXlegend;
end

function adjustPlot(idAxis,arrayXlegend,idxMon,varargin)   
    if ~isempty(varargin)
        title(idAxis,varargin{1},"FontSize",22)
        if numel(varargin{2})==2       
            subtitle(idAxis,sprintf("%s\n%s",varargin{2}{1},varargin{2}{2}),'FontSize',16,'Interpreter','none')
        else
            subtitle(idAxis,varargin{2}{1},'FontSize',16,'Interpreter','none')
        end
    end
    % move all the lines if any to the top
    fitLines = findobj(idAxis, 'Type', 'line', 'LineStyle', '--');
    if ~isempty(fitLines)        
        uistack(fitLines, 'top');
    end
    xlim(idAxis,'padded'), ylim(idAxis,'padded')
    idAxis.XAxis.MinorTick = 'on';   
    grid(idAxis,'on'), grid(idAxis,'minor')
    fig = ancestor(idAxis, 'figure');
    objInSecondMonitor(fig,idxMon);
    legend(idAxis,arrayXlegend,'FontSize',13,'Interpreter','none')     
end

function nameExps=extractNameExp(mainFolderSingleCondition,nExps)
    nameExps=cell(1,nExps);
    for i=1:nExps
        tmp=strsplit(mainFolderSingleCondition{i},'\');
        nameExperiment=tmp{end};
        question=sprintf('Name experiment: %s\nIs the name correct? They will be used in the figures.',nameExperiment);
        display(tmp)
        if ~getValidAnswer(question,'',{'Yes','No'},2)
            while true
                res=inputdlg("Name experiment (ex. TRCDA)","Enter manually names",[1 80],{nameExperiment});
                if any(cellfun(@(x) isempty(x), res))
                    disp('Input not valid')
                else
                    nameExperiment=res{1};
                    break
                end
            end
        end
        nameExps{i}=nameExperiment;
    end    
end
