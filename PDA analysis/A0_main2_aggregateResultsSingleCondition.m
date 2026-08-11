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


%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DMPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DOPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_POPC_25marchSample";
mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026";

% turn off warning prepareCurve
warning('off',  'curvefit:prepareFittingData:removingNaNAndInf');
question='Choose one of the following options about how to show results of force-fluorescence correlation.';
options={'Show results of all scans of a specific experiment (ex. all scans of TRCDA)',...
    'Show results of interpolated scans of all experiments (ex. TRCDA, TRCDA:DMPC,etc)'};
typeShow=getValidAnswer(question,'',options);
norm=false;
allAFMdata=struct();
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
    fig_Height_FLUO=figure(Visible="off"); ax_Height_FLUO=axes(fig_Height_FLUO); hold(ax_Height_FLUO,"on")
    xlabel(ax_Height_FLUO,'Height [nm]','FontSize',15), ylabel(ax_Height_FLUO,ylabelText,'FontSize',15)
    title(ax_Height_FLUO,'Height Vs Fluorescence',"FontSize",24)   
    subtitle(ax_Height_FLUO,sprintf('Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",15,"Interpreter","none")
    % x Height vs LateralForce
    fig_Height_LD=figure(Visible="off"); ax_Height_LD=axes(fig_Height_LD); hold(ax_Height_LD,"on")
    xlabel(ax_Height_LD,'Height [nm]','FontSize',15), ylabel(ax_Height_LD,'Lateral Force [nN]','FontSize',15)
    title(ax_Height_LD,'Height Vs Lateral Force',"FontSize",24)   
    subtitle(ax_Height_LD,sprintf('Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",15,"Interpreter","none")
    % baseline trend
    fig_baselineTrend=figure(Visible="off"); ax_baselineTrend=axes(fig_baselineTrend); hold(ax_baselineTrend,"on")
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
    fig_LD_FLUO{i}=figure(Visible="off"); ax_LD_FLUO{i}=axes(fig_LD_FLUO{i}); hold(ax_LD_FLUO{i},"on") %#ok<LAXES>
    xlabel(ax_LD_FLUO{i},xlabelText,'FontSize',15); ylabel(ax_LD_FLUO{i},ylabelText,'FontSize',15)
    subtitleText{i}=sprintf("%s%s",textSubTitleLD_FLUO,textAdditional{i});
end
clear textAdditional
% init
allDelta_1M={}; allDelta_3M={};
arrayXother = [];
arrayXlegend_full_1M=[];                % store the main line of the plot (for the full data of Force-Fluorescence and other in case of TypeShow=1)
arrayXlegend_fitLine_3M_ForceFluorescence=struct();   % store the fitted line
arrayXlegend_fitLine_3M_ForceFluorescence.trace=[];
arrayXlegend_fitLine_3M_ForceFluorescence.retrace=[];
arrayXlegend_fitLine_3M_ForceFluorescence.avg=[];
arrayXlegend_fitLine_3M_ForceFluorescence.mpv=[];
for expTh=1:nExps
    clc
    fprintf("Processing results of all scans of the experiment %s\n\n",nameExps{expTh})
    % Automatically find all resultsData_7_END files among the scans
    hits = dir(fullfile(mainFolderSingleCondition{expTh}, '**', 'resultsData_7_END_Force_Fluorescence_Correlation.mat'));
    if isempty(hits)
        warning("No 'resultsData_7_END_Force_Fluorescence_Correlation.mat' files found under:\n  %s", mainFolderSingleCondition{expTh});
    else
        allResultsData_pathfile = cell(numel(hits), 1);
        allAFMdata_pathfile = cell(numel(hits), 1);
        for k = 1:numel(hits)
            allResultsData_pathfile{k} = fullfile(hits(k).folder, hits(k).name);
            if ~exist(fullfile(hits(k).folder,'resultsData_2_assemblyProcessAFMdata.mat'),'file')
                error("some anomalies. there is no file containing AFM data")
            else
                allAFMdata_pathfile{k} = fullfile(hits(k).folder,'resultsData_2_assemblyProcessAFMdata.mat');
            end
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
            fig_LD_FLUO_sameScan=figure("Visible","off");
            ax_LD_FLUO_sameScan=axes(fig_LD_FLUO_sameScan); %#ok<LAXES>
            hold(ax_LD_FLUO_sameScan,"on")
            xlabel(ax_LD_FLUO_sameScan,xlabelText,'FontSize',15);
            ylabel(ax_LD_FLUO_sameScan,ylabelText,'FontSize',15);
            title(ax_LD_FLUO_sameScan,"Comparison different type of Lateral Force",'FontSize',20);           
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
            data=Data_finalResults.(fieldsLDData{j}).(fnames{1});           % first mask 
            if norm
                tmp=[data.BinMedian];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [data.BinMedian] = deal(tmp{:});                        
            end
            [hp_trace,dataPlot]=plotSingleData(data,nameData{i},ax_LD_FLUO{j*2-1},clr,1,1,"Full",typeShow);     
            % use the full data for fitting. Once opened the fitting function, there is the possibility to select a range min-max within the value will be used for fitting.
            % Store all data from different scans
            switch j
                case 1
                    fullDataXfitting_trace(i)=dataPlot;
                case 2
                    fullDataXfitting_retrace(i)=dataPlot;
                case 3
                    fullDataXfitting_avg(i)=dataPlot;
                otherwise
                    fullDataXfitting_mpv(i)=dataPlot;
            end                
            if (typeShow == 2 && i==1 && j==1) || (typeShow == 1 && j==1)
                arrayXlegend_full_1M=[arrayXlegend_full_1M, hp_trace]; %#ok<AGROW>
            end              
            % no save data and plot for legend because the fitted handle figures will be used instead
            data=Data_finalResults.(fieldsLDData{j}).(fnames{3});           % third mask 
            if norm
                tmp=[data.BinMedian];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [data.BinMedian] = deal(tmp{:});   
                tmp=[data.Bin25prctile];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [data.Bin25prctile] = deal(tmp{:}); 
                tmp=[data.Bin75prctile];
                tmp=tmp/normFactor;
                tmp = num2cell(tmp);
                [data.Bin75prctile] = deal(tmp{:}); 
            end            
            plotSingleData(data,nameData{i},ax_LD_FLUO{j*2},clr,1,1,"3M",typeShow);
            % plot comparison LD types
            if typeShow==1
                plotSingleData(data,fieldsLDData{j},ax_LD_FLUO_sameScan,globalColor(j),1,1,"shadowOnly",typeShow);   
            end
        end
        if typeShow==1
        % finish the different type of LD comparison       
            adjustPlot(ax_LD_FLUO_sameScan,[],idxMon)   
            saveFigures_FigAndTiff(fig_LD_FLUO_sameScan,SaveFigFolder,'resultEND_9_comparisonLDtypes')    
        end
        clear dataPlot tmp fig_LD_FLUO_sameScan ax_LD_FLUO_sameScan SaveFigFolder
        if typeShow == 1
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS fluorescence %%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
            fnames=fieldnames(Data_finalResults.Height_FLUO);
            data=Data_finalResults.Height_FLUO.(fnames{3});
            hother=plotSingleData(data,nameData{i},ax_Height_FLUO,clr,1e9,1,"none",typeShow);
            arrayXother=[arrayXother,hother]; %#ok<AGROW>
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS Lateral Force %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
            fnames=fieldnames(Data_finalResults.Height_LD);
            data=Data_finalResults.Height_LD.(fnames{3});
            plotSingleData(data,nameData{i},ax_Height_LD,clr,1e9,1,"none",typeShow);
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
        clear data totTime*
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the AFM Lateral and Height Data to process later %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        load(allAFMdata_pathfile{i},"AFMdata")
        field="AFM_images_2_PostProcessed";
        allAFMdata(cntDelta+i).nameExp=nameExps{expTh};
        tmp=strsplit(allResultsData_pathfile{i},'\'); tmp = sprintf('Scan #%s',tmp{end-2});
        allAFMdata(cntDelta+i).scanID=tmp;
        % take the mask and mask the data        
        allAFMdata(cntDelta+i).Mask=AFMdata(strcmp([AFMdata.Channel_name],"Height (measured)")).('AFMmask_heightIO');
        allAFMdata(cntDelta+i).Height=AFMdata(strcmp([AFMdata.Channel_name],"Height (measured)")).(field);
        allAFMdata(cntDelta+i).LatForce_tr=AFMdata(strcmp([AFMdata.Channel_name],"Lateral Force") & strcmp([AFMdata.Trace_type],"Trace")).(field); 
        allAFMdata(cntDelta+i).LatForce_rt=AFMdata(strcmp([AFMdata.Channel_name],"Lateral Force") & strcmp([AFMdata.Trace_type],"ReTrace")).(field);
        allAFMdata(cntDelta+i).LatForce_mV=AFMdata(strcmp([AFMdata.Channel_name],"Lateral Force") & strcmp([AFMdata.Trace_type],"MaxPixelValue")).(field);
        allAFMdata(cntDelta+i).LatForce_avg=AFMdata(strcmp([AFMdata.Channel_name],"Lateral Force") & strcmp([AFMdata.Trace_type],"Average")).(field); 
        allAFMdata(cntDelta+i).VertForce_avg=AFMdata(strcmp([AFMdata.Channel_name],"Vertical Force") & strcmp([AFMdata.Trace_type],"Avg")).(field); 
        
    end
    % END ALL SCANS PROCESSING WITHIN SAME EXPERIMENT
    %%%% TRACE
    % choose the upper limit to fit the data below and plot it. Use the same range for all experiments
    if ~exist("xrange","var")
        [fitResults_all_trace,hp_trace,hl_trace,xrange]=chooseAndFit(fullDataXfitting_trace,typeShow,{ax_LD_FLUO{1},ax_LD_FLUO{2}},idxMon,globalColor(expTh),nameExps{expTh},nameData);
    else
        [fitResults_all_trace,hp_trace]=chooseAndFit(fullDataXfitting_trace,typeShow,{ax_LD_FLUO{1},ax_LD_FLUO{2}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
    end
    % store slope data of trace mode
    slopeAVG_trace(expTh)=mean([fitResults_all_trace(:).slope]); %#ok<SAGROW>
    slopeSTD_trace(expTh)=std([fitResults_all_trace(:).slope]); %#ok<SAGROW>   
    %%%% RETRACE
    % using the same previous selected range, fit again
    [fitResults_all_retrace,hp_retrace]=chooseAndFit(fullDataXfitting_retrace,typeShow,{ax_LD_FLUO{3},ax_LD_FLUO{4}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
    % store slope data of MaxPixelValue mode
    slopeAVG_retrace(expTh)=mean([fitResults_all_retrace(:).slope]); %#ok<SAGROW>
    slopeSTD_retrace(expTh)=std([fitResults_all_retrace(:).slope]); %#ok<SAGROW>   
    %%%% AVG
    % using the same previous selected range, fit again
    [fitResults_all_avg,hp_avg]=chooseAndFit(fullDataXfitting_avg,typeShow,{ax_LD_FLUO{5},ax_LD_FLUO{6}},idxMon,globalColor(expTh),nameExps{expTh},nameData,xrange);
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
end
clear AFMdata fullDataXfitting_* fnames ans xlabelText ylabelText allAFMdata_pathfile          

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ADJUST ESTHETIC PART OF THE PLOTTING AND SAVE  %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
textAdditional={"LatForce-trace After 1st Mask","LatForce-trace After 3rd Mask",...
    "LatForce-retrace After 1st Mask","LatForce-retrace After 3rd Mask",...
    "LatForce-AVG After 1st Mask","LatForce-AVG After 3rd Mask",...
    "LatForce-maxPixelValue After 1st Mask","LatForce-maxPixelValue After 3rd Mask",};
%% location of the results
if typeShow==2
    folderSaveComparison= fullfile(fileparts(mainFolderSingleCondition{1}),sprintf("finalComparisonForceFluorescenceCurves_%s",saveFolderAdditionalText));
    filename1="endResult_1_1_ForceTrace_Fluorescence_1MData_allExps";
    filename2="endResult_1_2_ForceTrace_Fluorescence_3MData_allExps";
    filename3="endResult_2_1_ForceReTrace_Fluorescence_1MData_allExps";
    filename4="endResult_2_2_ForceReTrace_Fluorescence_3MData_allExps";
    filename5="endResult_3_1_ForceAVG_Fluorescence_1MData_allExps";
    filename6="endResult_3_2_ForceAVG_Fluorescence_3MData_allExps";
    filename7="endResult_4_1_ForceMaxPixV_Fluorescence_1MData_allExps";
    filename8="endResult_4_2_ForceMaxPixV_Fluorescence_3MData_allExps";
    textSubTitle_pt2_trace="";
    textSubTitle_pt2_retrace="";
    textSubTitle_pt2_avg="";
    textSubTitle_pt2_mpv="";
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nExps
        text_dataSlope_trace = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_trace(n),slopeSTD_trace(n));
        text_dataSlope_retrace = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_retrace(n),slopeSTD_retrace(n));
        text_dataSlope_avg = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_avg(n),slopeSTD_avg(n));
        text_dataSlope_mpv = sprintf(' %s \n AvgSlope \x00B1 StdSlope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG_mpv(n),slopeSTD_mpv(n));
        arrayXlegend_fitLine_3M_ForceFluorescence.trace(n).DisplayName = text_dataSlope_trace; 
        arrayXlegend_fitLine_3M_ForceFluorescence.retrace(n).DisplayName = text_dataSlope_retrace; 
        arrayXlegend_fitLine_3M_ForceFluorescence.avg(n).DisplayName = text_dataSlope_avg; 
        arrayXlegend_fitLine_3M_ForceFluorescence.mpv(n).DisplayName = text_dataSlope_mpv;
    end   
    arrayXlegend_full_1M_final=arrayXlegend_full_1M;
else
    folderSaveComparison=fullfile(mainFolderSingleCondition,sprintf("resultsCorrelations_ComparisonAllScans_%s",saveFolderAdditionalText));
    if ~exist(folderSaveComparison,"dir")
        mkdir(folderSaveComparison)   
    end
    filename1 =sprintf("endResults_1_1_ForceTrace_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename2 =sprintf("endResults_1_2_ForceTrace_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename3 =sprintf("endResults_2_1_ForceRetrace_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename4 =sprintf("endResults_2_2_ForceRetrace_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename5 =sprintf("endResults_3_1_ForceAVG_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename6 =sprintf("endResults_3_2_ForceAVG_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename7 =sprintf("endResults_4_1_ForceMaxPixV_Fluorescence_1MData_allScan_%s",nameExps{1});
    filename8 =sprintf("endResults_4_2_ForceMaxPixV_Fluorescence_3MData_allScan_%s",nameExps{1});
    filename9 =sprintf("endResults_5_HeightFluorescence_allScan_%s",nameExps{1});
    filename10=sprintf("endResults_6_HeightForce_allScan_%s",nameExps{1});
    filename11=sprintf("endResults_7_baselineTrend_allScan_%s",nameExps{1});
    textSubTitle_pt2_trace=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_trace,slopeSTD_trace);
    textSubTitle_pt2_retrace=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_retrace,slopeSTD_retrace);
    textSubTitle_pt2_avg=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_avg,slopeSTD_avg);
    textSubTitle_pt2_mpv=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_mpv,slopeSTD_mpv);
    % adjust and save fig of data Height-Fluorescence
    adjustPlot(ax_Height_FLUO,arrayXother,idxMon)
    saveFigures_FigAndTiff(fig_Height_FLUO,folderSaveComparison,filename9,'closeImmediately',false)    
    % adjust and save fig of data Height-Force
    adjustPlot(ax_Height_LD,arrayXother,idxMon)
    saveFigures_FigAndTiff(fig_Height_LD,folderSaveComparison,filename10,'closeImmediately',false)    
    % adjust and save fig of baseline trend
    adjustPlot(ax_baselineTrend,arrayXother,idxMon)     
    saveFigures_FigAndTiff(fig_baselineTrend,folderSaveComparison,filename11)    
    close(fig_Height_FLUO), close(fig_Height_LD)
    
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nScans
        text_dataSlope_trace = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_trace(n).slope,fitResults_all_trace(n).offset);
        text_dataSlope_retrace = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_retrace(n).slope,fitResults_all_retrace(n).offset);
        text_dataSlope_avg = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_avg(n).slope,fitResults_all_avg(n).offset);
        text_dataSlope_mpv = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all_maxPixV(n).slope,fitResults_all_maxPixV(n).offset);
        arrayXlegend_fitLine_3M_ForceFluorescence.trace(n).DisplayName = text_dataSlope_trace;
        arrayXlegend_fitLine_3M_ForceFluorescence.retrace(n).DisplayName = text_dataSlope_retrace;
        arrayXlegend_fitLine_3M_ForceFluorescence.avg(n).DisplayName = text_dataSlope_avg;
        arrayXlegend_fitLine_3M_ForceFluorescence.mpv(n).DisplayName = text_dataSlope_mpv;
    end 
    arrayXlegend_full_1M_final=[arrayXlegend_full_1M, hl_trace(1)];
end

textTitleLD_FLUO='Lateral Force VS Fluorescence';
% TRACE
% adjust and save fig of full data ForceTrace-Fluo (1M)
adjustPlot(ax_LD_FLUO{1},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{1})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{2};textSubTitle_pt2_trace};
adjustPlot(ax_LD_FLUO{2},arrayXlegend_fitLine_3M_ForceFluorescence.trace,idxMon,textTitleLD_FLUO,textSubTitle)

% RETRACE
% adjust and save fig of full data ForceTrace-Fluo (1M)
adjustPlot(ax_LD_FLUO{3},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{3})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{4};textSubTitle_pt2_retrace};
adjustPlot(ax_LD_FLUO{4},arrayXlegend_fitLine_3M_ForceFluorescence.retrace,idxMon,textTitleLD_FLUO,textSubTitle)

% AVG
% adjust and save fig of full data ForceMaxPixelValue-Fluo (1M)
adjustPlot(ax_LD_FLUO{5},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{5})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{6};textSubTitle_pt2_avg};
adjustPlot(ax_LD_FLUO{6},arrayXlegend_fitLine_3M_ForceFluorescence.avg,idxMon,textTitleLD_FLUO,textSubTitle)

% MAX PIXEL VALUE
% adjust and save fig of full data ForceMaxPixelValue-Fluo (1M)
adjustPlot(ax_LD_FLUO{7},arrayXlegend_full_1M_final,idxMon,textTitleLD_FLUO,subtitleText{7})
% adjust and save fig of cutted data Force-Fluo (3M)
textSubTitle={subtitleText{8};textSubTitle_pt2_mpv};
adjustPlot(ax_LD_FLUO{8},arrayXlegend_fitLine_3M_ForceFluorescence.mpv,idxMon,textTitleLD_FLUO,textSubTitle)

% adjust the limits of full data
ax_LD_FLUO_full=ax_LD_FLUO(1:2:8);
xlimNew=[min(cellfun(@(x) min(x.XLim(1)), ax_LD_FLUO_full)) max(cellfun(@(x) max(x.XLim(2)), ax_LD_FLUO_full))];
ylimNew=[min(cellfun(@(x) min(x.YLim(1)), ax_LD_FLUO_full)) max(cellfun(@(x) max(x.YLim(2)), ax_LD_FLUO_full))];
for i=1:2:8
    ax_LD_FLUO{i}.XLim=xlimNew;
    ax_LD_FLUO{i}.YLim=ylimNew;
    saveFigures_FigAndTiff(fig_LD_FLUO{i},folderSaveComparison,eval(sprintf("filename%d",i)),'closeImmediately',false)  
end
close(fig_LD_FLUO{1},fig_LD_FLUO{3},fig_LD_FLUO{5},fig_LD_FLUO{7})
clear ax_LD_FLUO_full arrayX* nameData

ax_LD_FLUO_cut=ax_LD_FLUO(2:2:8);
% adjust the limits of cleared data
for i=1:numel(ax_LD_FLUO_cut)
    fig_tmp=get(ax_LD_FLUO_cut{i}, 'Parent');
    fig_tmp.Visible="on";
end
waitfor(warndlg("Adjust the axis of the figures for better visual!"))  
xlimNew=[min(cellfun(@(x) min(x.XLim(1)), ax_LD_FLUO_cut)) max(cellfun(@(x) max(x.XLim(2)), ax_LD_FLUO_cut))];
ylimNew=[min(cellfun(@(x) min(x.YLim(1)), ax_LD_FLUO_cut)) max(cellfun(@(x) max(x.YLim(2)), ax_LD_FLUO_cut))];
for i=2:2:8
    ax_LD_FLUO{i}.XLim=xlimNew;
    ax_LD_FLUO{i}.YLim=ylimNew;
    saveFigures_FigAndTiff(fig_LD_FLUO{i},folderSaveComparison,eval(sprintf("filename%d",i)))
    pause(1)
end
clear text_dataSlope_trace n fitResults_all_* saveFolderAdditionalText textSubTitle_pt2_trace array* ax* fig* 
clear filename* slope* metaData_AFM metaData_BF metaData_NIKON_definitive clr cntDelta Data_finalResults firstPlot expTh hf hl_* hp_* i
clear idxLineSample j allResultsData_pathfile baseline_nN text* tmp xlimNew ylimNew xrange field* subtitleText hother fullDataXfitting_avg
% complete the height distribution comparison
plotAFMHeightHistograms(allAFMdata,folderSaveComparison,idxMon)
% extract friction coefficients
frictionCoeff_fromVertLatCalc(allAFMdata,folderSaveComparison,subfolder_allscanFolder,idxMon,typeShow)
clc, close all

if getValidAnswer("Do want to imadjust and propagate the TRITIC images so they can be visually comparable?\nNOTE: the operation requires some time, especially in case of multiple experiments.",'',{"Y","N"})
    % in order to have fluorescence image scaled in the same way for better representation, lets find the max and mix values of all the scans and propagate all over images
    allDelta={allDelta_original,allDelta_1M,allDelta_3M};    
    allDelta_text={"Whole Image","1stMasked","3rdMasked"};
    if norm
        textNormColorbar="Delta Fluorescence (normalized)";
        tmp="norm";
    else
        textNormColorbar="Absolute Delta Fluorescence";
        tmp="notNorm";
    end    
    for j=1:3
        filename=sprintf('resultEND_13_%d_%s_%s_FluorescencePDA',j,tmp,allDelta_text{j});
        titleText=sprintf("ΔFluorescence - %s",allDelta_text{j});
        sameColorBarScale(allDelta{j},filename,titleText,subfolder_allscanFolder,textNormColorbar,allDelta_pixScale(1,:)*1e-6,typeShow,idxMon,true)
    end
end
clear allDelta_original allDelta_1M allDelta_3M nameData nExps norm nScans  
clear allValues filename titleD1 labelBar singleFolder rangeScale allDelta_pixScale Delta ans subfolder_allscanFolder j typeShow titleText textNormColorbar
%%
%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% FUNCTIONS %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%

function [hp,dataXfitting,markP]=plotSingleData(data,nameData,idAxis,clr,xMultiplier,yMultiplier,typeData,typeShow)
%%%%%% extract the data and show only %%%%%%
    x=cell2mat({data.BinCenter});
    y=cell2mat({data.BinMedian});
    x=x*xMultiplier; y=y*yMultiplier;
    % Use prepareCurveData only for the main x/y pair to clean NaN
    [xData, yData] = prepareCurveData(x, y);
    if ~strcmp(typeData,"Full")
        y25=cell2mat({data.Bin25prctile});
        y75=cell2mat({data.Bin75prctile});
        % Apply the same NaN-removal mask to the error bar data
        mask = ~isnan(xData) & ~isnan(yData);
        y25 = y25(mask); y25=y25';
        y75 = y75(mask); y75=y75';
        y25=y25*yMultiplier; y75=y75*yMultiplier;
        errUp   = y75 - yData;
        errDown = yData - y25;
    end
    markP=[];
    if strcmp(typeData,"3M")
        hp=shadedErrorBar(xData,yData,[errUp, errDown], ...
        'lineProps',{'o','Color',clr,'DisplayName',nameData}, ...
        'transparent', true, ...
        'patchSaturation', 0.2, ...
        'plotAxes',idAxis);                        
        hp.mainLine.Marker='o'; hp.mainLine.MarkerFaceColor=clr;        
        hp.mainLine.MarkerSize=1; hp.mainLine.LineStyle="none";
    elseif typeShow==1                
        if strcmp(typeData,"Full")   
            hp=plot(idAxis,xData,yData,'x','Color',clr,'DisplayName',nameData,'MarkerSize',5,'LineStyle',"-",'LineWidth',1.5);
            hp.Marker='o';
            hp.MarkerEdgeColor = clr;
            hp.MarkerFaceColor ='none'; 
            hp.LineStyle="none";
            hp.MarkerSize=2;
        elseif strcmp(typeData,"3M")
            hp=shadedErrorBar(xData,yData,[errUp, errDown], ...
            'lineProps',{'o','Color',clr,'DisplayName',nameData}, ...
            'transparent', true, ...
            'patchSaturation', 0.2, ...
            'plotAxes',idAxis);                        
            hp.mainLine.Marker='o'; hp.mainLine.MarkerFaceColor=clr;        
            hp.mainLine.MarkerSize=1; hp.mainLine.LineStyle="none";
        elseif strcmp(typeData,"shadowOnly")
            hp=shadedErrorBar(xData,yData,[errUp, errDown], ...
            'lineProps',{'LineStyle','none','Color',clr}, ...
            'transparent', true, ...
            'patchSaturation', 0.2, ...
            'plotAxes',idAxis,'annotation',false);            
            markP=plot(xData,yData,'o','MarkerSize',1.5,'Color',clr,'DisplayName',nameData,'MarkerFaceColor',clr);
        else
            hp=plot(idAxis,xData,yData,'x','Color',clr,'DisplayName',nameData,'MarkerSize',5,'LineStyle',"-",'LineWidth',1.5);
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
    mainMarker = findobj(idAxis,'Type', 'line','-not','Tag','shadedErrorBar_mainLine');
    for i = 1:numel(mainMarker)
        uistack(mainMarker(i),'top')
    end

    xlim(idAxis,'padded'), ylim(idAxis,'padded')
    idAxis.XAxis.MinorTick = 'on';   
    grid(idAxis,'on'), grid(idAxis,'minor')
    fig = ancestor(idAxis, 'figure');
    objInSecondMonitor(fig,idxMon);
    if ~isempty(arrayXlegend)
        legend(idAxis,arrayXlegend,'FontSize',13,'Interpreter','none','Location','best');    
    else
        legend(idAxis,'FontSize',15,'Interpreter','none','Location','best');
    end
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

function plotAFMHeightHistograms(allAFMdata,folderSaveFig,idxMon)
    expNames   = {allAFMdata.nameExp};
    uniqueExps = unique(expNames, 'stable');
    if isscalar(uniqueExps)
        % --- Single experiment: group by ScanID ---
        scanIDs     = unique({allAFMdata.scanID},'stable');
        groupLabels = unique(scanIDs, 'stable');
        groupIdx    = cellfun(@(s) strcmp(scanIDs, s), groupLabels, 'UniformOutput', false);
        titleStr    = sprintf("Distribution Height-Masked of %s",uniqueExps{1});       
    else
        % --- Multiple experiments: merge all scans per experiment ---
        groupLabels = uniqueExps;
        groupIdx    = cellfun(@(e) strcmp(expNames, e), uniqueExps, 'UniformOutput', false);
        titleStr    = 'Distribution Height-Masked of all experiments';        
    end
    f_heightDistribution=figure('Visible','on'); axDistHeight=axes(f_heightDistribution);
    hold(axDistHeight,"on")
    xlabel(axDistHeight,sprintf('Height [nm]'),'FontSize',15), ylabel(axDistHeight,'Percentage %','FontSize',15)
    grid(axDistHeight,"on"), grid(axDistHeight,"minor")
    title(axDistHeight,titleStr,'FontSize',20)
    
    % --- Build merged Height vector per group first ---
    nGroups = numel(groupLabels);
    vect    = cell(nGroups, 1);
    medianVect = zeros(nGroups, 1);
    for i = 1:nGroups
        entries    = allAFMdata(groupIdx{i});
        heightVecs = arrayfun(@(e) e.Height(logical(e.Mask))*1e9, entries, 'UniformOutput', false);
        vect{i}    = vertcat(heightVecs{:});
        medianVect(i) = median(vect{i});
    end
    % --- Shared bin edges across all groups ---
    edges = min(cellfun(@(x) min(x), vect)) : 2 : max(cellfun(@(x) max(x), vect));    
    allVect=cell2mat(vect);
    totMedian=median(allVect);
    tot25=prctile(allVect,25);    tot75=prctile(allVect,75);
    for i = 1:nGroups
        xl=xline(medianVect(i),'--','Color',globalColor(i),'LineWidth',1.5);
        xl.Annotation.LegendInformation.IconDisplayStyle = 'off';
        histogram(vect{i}, edges, ...
            'DisplayName', sprintf('%s - median: %.1f nm',groupLabels{i},medianVect(i)), ...
            'Normalization', 'probability', ...
            'FaceColor', globalColor(i), 'FaceAlpha', 0.3);        
    end
    if isscalar(uniqueExps)
        subtitleStr =sprintf('Shown Data within 0.5-99.5 Percentile.\nTotal Median: %.1f nm - 25th: %.1f - 75th: %.1f',totMedian,tot25,tot75);        
    else
        subtitleStr = 'Shown Data within 0.5-99.5 Percentile. Each exp represents all scans together';
    end
    subtitle(axDistHeight,subtitleStr,'FontSize',13)
    legend(axDistHeight,'FontSize',15,'Interpreter','none')
    singleVect=vertcat(vect{:});  
    pLow = prctile(singleVect, .5);
    pHigh = prctile(singleVect, 99.5); 
    xlim(axDistHeight, [pLow, pHigh]);
    objInSecondMonitor(f_heightDistribution,idxMon);     
    saveFigures_FigAndTiff(f_heightDistribution,folderSaveFig,'heightDistributionComparison')           
end

function frictionCoeff_fromVertLatCalc(allAFMdata,folderSaveFig,subfolder_allscanFolder,idxMon,typeShow)
    expNames   = {allAFMdata.nameExp};
    uniqueExps = unique(expNames, 'stable');
    if isscalar(uniqueExps)
        flag_singleExp = true;
        % --- Single experiment: group by ScanID ---
        scanIDs     = unique({allAFMdata.scanID},'stable');
        groupLabels = unique(scanIDs, 'stable');
        groupIdx    = cellfun(@(s) strcmp(scanIDs, s), groupLabels, 'UniformOutput', false);
        titleStr    = sprintf("Box-and-Whisker Plot of Friction Coefficient of every scans of the experiment %s",uniqueExps{1});       
    else
        % --- Multiple experiments: merge all scans per experiment ---
        flag_singleExp = false;
        groupLabels = uniqueExps;
        groupIdx    = cellfun(@(e) strcmp(expNames, e), uniqueExps, 'UniformOutput', false);
        titleStr    = 'Box-and-Whisker Plot of Friction Coefficient of every scans/experiments';        
    end
    f_boxWhisker=figure('Visible','off'); axBoxWhisker=axes(f_boxWhisker);
    hold(axBoxWhisker,"on")
    ylabel(axBoxWhisker,'Friction Coefficient Value','FontSize',15)
    axBoxWhisker.YGrid="on"; axBoxWhisker.YMinorGrid="on";
    % copy all children of source figure into new figure    
    f_boxWhisker_unfilt=figure('Visible','off'); axBoxWhisker_unfilt=axes(f_boxWhisker_unfilt);
    hold(axBoxWhisker_unfilt,"on")
    ylabel(axBoxWhisker_unfilt,'Friction Coefficient Value','FontSize',15)
    axBoxWhisker_unfilt.YGrid="on"; axBoxWhisker_unfilt.YMinorGrid="on";    

    % --- Build merged Height vector per group first ---
    nGroups = numel(groupLabels);
    vects_FC    = cell(nGroups, 1);
    vects_FC_unfilt = vects_FC;
    vects_name = cell(nGroups, 1);
    count=1;
    FC_all=cell(1,length(allAFMdata));
    LF_avg_all=cell(1,length(allAFMdata));
    Height_all=cell(1,length(allAFMdata));
    for i = 1:nGroups
        FC_vec_clean=[];
        FC_vec_unfiltered=[];
        entries     = allAFMdata(groupIdx{i});
        % when it is single experiment, it's just one entry
        for j=1:length(entries)
            LatForce=entries(j).LatForce_avg;
            VertForce=entries(j).VertForce_avg;
            HeightSingle=entries(j).Height;
            mask=logical(entries(j).Mask);
            LatForce_BK=LatForce;
            LatForce_BK(mask)=nan;
            VertForce_BK=VertForce;
            VertForce_BK(mask)=nan;
            LatForce_BK_clear=zeros(size(LatForce_BK));
            VertForce_BK_clear=LatForce_BK_clear;
            % remove edge and outliers: 5 pixels from the edges, MAD method for outlier removal over connectedSegment   
            % since it is an entire block made of multiple section, SegmentProcess=3 is not effective. Need to process each fast scan line
            for lineId=1:size(LatForce_BK,2)
                LF_Line=LatForce_BK(:,lineId);
                VF_Line=VertForce_BK(:,lineId);
                mask_Line=mask(:,lineId);
                % start the edge removal depending on the i-th pixel size and then remove outliers
                LF_Line_cleared = remove_Edges_Outlier(LF_Line,mask_Line,5,2,3); 
                VF_Line_cleared=VF_Line;
                VF_Line_cleared(isnan(LF_Line_cleared))=nan;
                LatForce_BK_clear(:,lineId)=LF_Line_cleared;
                VertForce_BK_clear(:,lineId)=VF_Line_cleared;                
            end 
            FC=LatForce_BK_clear./VertForce_BK_clear;
            FC_all{count}=FC;
            LF_avg_all{count}=LatForce;
            Height_all{count}=HeightSingle*1e9;
            count=count+1;
            %showData(idxMon,false,FC,sprintf("Friction Coefficient Background - %s - %s",entries.nameExp,entries.scanID),fullfile(folderSaveFig,"FC_images"),sprintf("FCimage_%s_%s",entries.nameExp,entries.scanID))
            tmp_clean=reshape(FC,1,[]);
            tmp_clean=tmp_clean(~isnan(tmp_clean));
            FC_vec_clean=[FC_vec_clean tmp_clean];
            % calc unfiltered FC too
            tmp=LatForce_BK./VertForce_BK;
            tmp_unfiltered=tmp(~isnan(tmp));
            FC_vec_unfiltered=[FC_vec_unfiltered; tmp_unfiltered];            
        end          
        vects_FC{i} = reshape(FC_vec_clean,[],1);
        vects_FC_unfilt{i} = reshape(FC_vec_unfiltered,[],1);
        if flag_singleExp
            vects_name{i}=entries.scanID;
        else
            vects_name{i}=entries.nameExp;
        end
    end
    % start the box char whisker
    xpos=1:nGroups;
    for i = 1:nGroups
        xi = repmat(i, size(vects_FC{i}));  % x positions for group i
        boxchart(axBoxWhisker, xi, vects_FC{i}, ...
            'BoxFaceColor', globalColor(i), 'WhiskerLineColor',globalColor(i),'WhiskerLineStyle','-.',...
            'LineWidth',1.5,'MarkerStyle','*','MarkerSize',3,...
            'BoxEdgeColor', globalColor(i),...
            'DisplayName',sprintf("%s",vects_name{i}));   % adjust other colors as needed
        xi_unf = repmat(i, size(vects_FC_unfilt{i}));  % x positions for group i
        boxchart(axBoxWhisker_unfilt, xi_unf, vects_FC_unfilt{i}, ...
            'BoxFaceColor', globalColor(i), 'WhiskerLineColor',globalColor(i),'WhiskerLineStyle','-.',...
            'LineWidth',1.5,'MarkerStyle','*','MarkerSize',3,...
            'BoxEdgeColor', globalColor(i),...
            'DisplayName',sprintf("%s",vects_name{i}));   % adjust other colors as needed    
        drawnow;
        % show the median value
        medVal = median(vects_FC{i}, 'omitnan');
        medVal_unfilt = median(vects_FC_unfilt{i}, 'omitnan');
        if isnan(medVal), continue; end     
        
        boxOffset = 0.33;  % adjust based on your boxchart width (default BoxWidth is 0.5, i.e. half-width 0.25)
        text(axBoxWhisker, xpos(i)+boxOffset, medVal, sprintf('%.2f', medVal), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', 'w', ...            % change if white not visible
            'BackgroundColor', 'k', ...  % optional contrast box
            'Margin', 2, ...
            'FontSize', 14,'FontWeight', 'bold');
        text(axBoxWhisker_unfilt, xpos(i)+boxOffset, medVal_unfilt, sprintf('%.2f', medVal_unfilt), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'Color', 'w', ...            % change if white not visible
            'BackgroundColor', 'k', ...  % optional contrast box
            'Margin', 2, ...
            'FontSize', 14,'FontWeight', 'bold');
        % now shift it down by half its own height so it's centered on medVal
    end
    xlim(axBoxWhisker,"padded"); ylim(axBoxWhisker,"padded");
    axBoxWhisker.XTick = 1:numel(vects_name);
    axBoxWhisker.XTickLabel = vects_name;           % cell array of names
    axBoxWhisker.TickLabelInterpreter = 'none';     % apply to X/Y tick labels
    axBoxWhisker.FontSize = 15;    
    title(axBoxWhisker,sprintf("%s\nFC post Edge-Removal Algorithm",titleStr),'FontSize',20)  
    objInSecondMonitor(f_boxWhisker,idxMon);     
    saveFigures_FigAndTiff(f_boxWhisker,folderSaveFig,'boxChartWhisker_FCvalues_postEdgeOutlierAlg')    

    xlim(axBoxWhisker_unfilt,"padded"); ylim(axBoxWhisker_unfilt,"padded");
    axBoxWhisker_unfilt.XTick = 1:numel(vects_name);
    axBoxWhisker_unfilt.XTickLabel = vects_name;           % cell array of names
    axBoxWhisker_unfilt.TickLabelInterpreter = 'none';     % apply to X/Y tick labels
    axBoxWhisker_unfilt.FontSize = 15;    
    title(axBoxWhisker_unfilt,sprintf("%s (Raw FC)",titleStr),'FontSize',20)  
    objInSecondMonitor(f_boxWhisker_unfilt,idxMon);     
    saveFigures_FigAndTiff(f_boxWhisker_unfilt,folderSaveFig,'boxChartWhisker_FCvalues_RAW')  
    % obtain figure with same colorbar
    sameColorBarScale(FC_all,'resultEND_10_FrictionCoeffValue_matrix',"Friction Coefficients Pixel-By-Pixel",subfolder_allscanFolder,"Friction Coefficient Value",[],typeShow,idxMon,false)
    sameColorBarScale(LF_avg_all,'resultEND_11_LateralForce_AVG',"Lateral Force (AVG)",subfolder_allscanFolder,"Force [nN]",[],typeShow,idxMon,false)    
    sameColorBarScale(Height_all,'resultEND_12_Height',"Height Channel",subfolder_allscanFolder,"Height [nm]",[],typeShow,idxMon,false)       
end

function sameColorBarScale(data,filename,titleText,allSaveFigFolder,labelBarText,pixScale,typeShow,idxMon,scaleBar)
    % find global range across all FC images. Show data inside the percentile range for better visual
    all_values = cellfun(@(x) x(:), data, 'UniformOutput', false);
    all_values = vertcat(all_values{:});    
    shared_min = prctile(all_values, 1);   % robust, mimics ImageJ auto
    shared_max = prctile(all_values, 99);  
    rangeScale= [shared_min,shared_max];
    if typeShow == 1
        filename=sprintf('%s_onEveryScanSingleExp',filename);
        titleText=sprintf("%s\nNOTE: Images with shared colorbar across scans and contrast-adjusted to the 1st–99th percentiles.",titleText);
    else
        filename=sprintf('%s_onEveryScanEveryExp',filename);
        titleText=sprintf("%s\nNOTE: Images with shared colorbar across scans and experiments and contrast-adjusted to the 1st–99th percentiles",titleText);
    end
    for i=1:length(data)        
        tmp=data{i};
        singleSaveFigFolder=allSaveFigFolder{i};
        showData(idxMon,false,tmp,titleText,singleSaveFigFolder,filename,'Broadcast',rangeScale,"labelBar",labelBarText,'lenghtAxis',pixScale,'addScaleBar',scaleBar);
    end
end
