clc, clear, close all
idxMon=objInSecondMonitor;

mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DMPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DOPC_25marchSample";
%mainFolderSingleCondition="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_POPC_25marchSample";

% turn off warning prepareCurve
warning('off',  'curvefit:prepareFittingData:removingNaNAndInf');
question='Choose one of the following options about how to show results of force-fluorescence correlation.';
options={'Show results of all scans of a specific experiment (ex. all scans of TRCDA)',...
    'Show results of interpolated scans of all experiments (ex. TRCDA, TRCDA:DMPC,etc)'};
typeShow=getValidAnswer(question,'',options);
if getValidAnswer("What type of data to show?","",{"Real","Normalized"})==1
    norm=false;
    saveFolderAdditionalText="NotNormalized";
else
    % NORMALIZE ALL THE DATA BEFORE CONTINUE
    norm="DA METTERE IL VALORE";
    saveFolderAdditionalText="Normalized";
end

if norm==false
    ylabelText='Absolute fluorescence Intensity (A.U.)';
else
    ylabelText='Normalized Fluorescence Intensity';
end
clear norm question options
% prepare the figures to show the definitive results
if typeShow==1
    if ~(exist("mainFolderSingleCondition","var") && exist(mainFolderSingleCondition,"dir") && getValidAnswer(sprintf("Is the selected path of the scan to process correct?\n%s",mainFolderSingleCondition),"",{"Y","N"}))             
        mainFolderSingleCondition={uigetdir(pwd,'Locate the dir of a specific experiment condition that contains the results of any scans.')};
    end
    nExps=1;
    nameExps=extractNameExp(mainFolderSingleCondition,nExps);
    textTitleLD_FLUO=sprintf('Lateral Force VS Fluorescence - Comparison of different scans / same sample (%s) - ',nameExps{1});      
    % x Height vs FLUO
    fig_Height_FLUO=figure(Visible="on"); ax_Height_FLUO=axes(fig_Height_FLUO); hold(ax_Height_FLUO,"on")
    xlabel(ax_Height_FLUO,'Height [nm]','FontSize',15), ylabel(ax_Height_FLUO,ylabelText,'FontSize',15)
    title(ax_Height_FLUO,sprintf('Height Vs Fluorescence - Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",24,"Interpreter","none");
    subtitle(ax_Height_FLUO,"Data as Median + 25th-75th Percentile","FontSize",15)
    % x Height vs LateralForce
    fig_Height_LD=figure(Visible="on"); ax_Height_LD=axes(fig_Height_LD); hold(ax_Height_LD,"on")
    xlabel(ax_Height_LD,'Height [nm]','FontSize',15), ylabel(ax_Height_LD,'Lateral Force [nN]','FontSize',15)
    title(ax_Height_LD,sprintf('Height Vs Lateral Force - Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",24,"Interpreter","none");
    subtitle(ax_Height_LD,"Data as Median + 25th-75th Percentile","FontSize",15)
    % baseline trend
    fig_baselineTrend=figure(Visible="on"); ax_baselineTrend=axes(fig_baselineTrend); hold(ax_baselineTrend,"on")
    ylabel(ax_baselineTrend,'Baseline shift [nN]','FontSize',15), xlabel(ax_baselineTrend,'Time [min]','FontSize',15)
    title(sprintf('Baseline Shift Trend - Comparison of different scans / same sample (%s)',nameExps{1}),"FontSize",24,"Interpreter","none");
else
% for the multiple experiment case, show only LF-Fluo correlation curves
    mainFolderSingleCondition=uigetdirMultiSelect(pwd,'Locate the dirs of all experiment conditions that contains the results of any scans.');
    nExps=numel(mainFolderSingleCondition);
    nameExps=extractNameExp(mainFolderSingleCondition,nExps);
    textTitleLD_FLUO="Comparison of different scans of different same samples - ";
end
% x Lateral Force vs Fluorescence. (one for first masking (original) and one for last masking (cleared))
textAdditional={"Data After 1st Mask","Data After 3rd Mask"};
fig_LD_FLUO=cell(1,2); ax_LD_FLUO=cell(1,2);
xlabelText='Lateral Force [nN]';
for i=1:2
    fig_LD_FLUO{i}=figure(Visible="on"); ax_LD_FLUO{i}=axes(fig_LD_FLUO{i}); hold(ax_LD_FLUO{i},"on") %#ok<LAXES>
    xlabel(ax_LD_FLUO{i},xlabelText); ylabel(ax_LD_FLUO{i},ylabelText)
    title(ax_LD_FLUO{i},sprintf("%s%s",textTitleLD_FLUO,textAdditional{i}),"FontSize",24,"Interpreter","none")
    if i==1
        subtitle(ax_LD_FLUO{i},"Data as Median + 25th-75th Percentile","FontSize",15)
    end
end
clear xlabelText ylabelText textAdditional textTitleLD_FLUO
% init
allDelta_1M={}; allDelta_3M={};
arrayXlegend_full_1M=[];                % store the main line of the plot (for the full data of Force-Fluorescence and other in case of TypeShow=1)
arrayXlegend_fitLine_3M_ForceFluorescence=[];   % store the fitted line 
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
    fullDataXfitting = struct('xData', {}, 'yData', {}, 'ystdData_25', {}, 'ystdData_75', {});    
    cntDelta=length(allDelta_1M);    
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
        allDelta_3M{cntDelta+i}= Data_finalResults.DeltaData.Delta_thirdMasking_99percMaxSet; %#ok<SAGROW>        
        allDelta_pixScale(cntDelta+i,1)=metaData_BF.ImageHeight_umeterXpixel;             %#ok<SAGROW>
        allDelta_pixScale(cntDelta+i,2)=metaData_BF.ImageWidth_umeterXpixel;        %#ok<SAGROW>
        subfolder_allscanFolder{cntDelta+i}=SaveFigFolder;                           %#ok<SAGROW>

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the first (full) and third masked (each AFM channel) data fluorescence VS lateral deflection (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % first and third masks        
        fnames=fieldnames(Data_finalResults.LD_FLUO);
        % for full data
        x=Data_finalResults.LD_FLUO.(fnames{1});           % first mask 
        [hp,data]=plotSingleData(x,nameData{i},ax_LD_FLUO{1},clr,1,1,"Full",typeShow);     
        % use the full data for fitting. Once opened the fitting function, there is the possibility to select a range min-max within the value will be used for fitting.
        % Store all data from different scans
        fullDataXfitting(i)=data;
        if (typeShow == 2 && i==1) || typeShow == 1
            arrayXlegend_full_1M=[arrayXlegend_full_1M, hp]; %#ok<AGROW>
        end              
        % no save data and plot for legend because the fitted handle figures will be used instead
        x=Data_finalResults.LD_FLUO.(fnames{3});           % third mask 
        plotSingleData(x,nameData{i},ax_LD_FLUO{2},clr,1,1,"3M",typeShow);
        
        clear data tmp SaveFigFolder
        if typeShow == 1
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS fluorescence %%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
            fnames=fieldnames(Data_finalResults.Height_FLUO);
            x=Data_finalResults.Height_FLUO.(fnames{3});
            plotSingleData(x,nameData{i},ax_Height_FLUO,clr,1e9,1,"Full",typeShow);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS Lateral Force %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%      
            fnames=fieldnames(Data_finalResults.Height_LD);
            x=Data_finalResults.Height_LD.(fnames{3});
            plotSingleData(x,nameData{i},ax_Height_LD,clr,1e9,1,"Full",typeShow);
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
    
    % choose the upper limit to fit the data below and plot it
    [fitResults_all,hp,hl]=chooseAndFit(fullDataXfitting,typeShow,ax_LD_FLUO,idxMon,globalColor(expTh),nameExps{expTh},nameData);
    % store the handle figure to organize the legend names
    if typeShow == 2
        arrayXlegend_fitLine_3M_ForceFluorescence=[arrayXlegend_fitLine_3M_ForceFluorescence, hp(1)]; %#ok<AGROW>
    else

        arrayXlegend_fitLine_3M_ForceFluorescence=hp;
    end
    % store slope data
    slopeAVG(expTh)=mean([fitResults_all(:).slope]); %#ok<SAGROW>
    slopeSTD(expTh)=std([fitResults_all(:).slope]); %#ok<SAGROW>        
    if typeShow==1
        break
    end      
end
clear fullDataXfitting fnames ans
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ADJUST ESTHETIC PART OF THE PLOTTING AND SAVE  %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% location of the results
if typeShow==2
    folderSaveComparison= uigetdir('*.tif',"Where save the final results?");
    filename1="endResult_1_ForceFluorescence_1MData_allExps";
    filename2="endResult_2_ForceFluorescence_3MData_allExps";    
    textSubTitle="";
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nExps
        text_dataSlope = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameExps{n},slopeAVG(n),slopeSTD(n));
        arrayXlegend_fitLine_3M_ForceFluorescence(n).DisplayName = text_dataSlope;
    end   
else
    folderSaveComparison=fullfile(mainFolderSingleCondition,sprintf("resultsCorrelations_ComparisonAllScans_%s",saveFolderAdditionalText));
    if ~exist(folderSaveComparison,"dir")
        mkdir(folderSaveComparison)   
    end
    filename1=sprintf("endResults_1_ForceFluorescence_1MData_allScan_%s",nameExps{1});
    filename2=sprintf("endResults_2_ForceFluorescence_3MData_allScan_%s",nameExps{1});
    filename3=sprintf("endResults_3_HeightFluorescence_allScan_%s",nameExps{1});
    filename4=sprintf("endResults_4_HeightForce_allScan_%s",nameExps{1});
    filename5=sprintf("endResults_5_baselineTrend_allScan_%s",nameExps{1});
    textSubTitle=sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG,slopeSTD);
    % adjust and save fig of data Height-Fluorescence
    adjustPlot(ax_Height_FLUO,[arrayXlegend_full_1M.mainLine],folderSaveComparison,filename3,idxMon)
    % adjust and save fig of data Height-Force
    adjustPlot(ax_Height_LD,[arrayXlegend_full_1M.mainLine],folderSaveComparison,filename4,idxMon)
    % adjust and save fig of baseline trend
    adjustPlot(ax_baselineTrend,[arrayXlegend_full_1M.mainLine],folderSaveComparison,filename5,idxMon)
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:nScans
        text_dataSlope = sprintf(' %s\n Slope\x00B1Offset: = %.2e \x00B1 %.2e',nameData{n},fitResults_all(n).slope,fitResults_all(n).offset);
        arrayXlegend_fitLine_3M_ForceFluorescence(n).DisplayName = text_dataSlope;
    end 
end

% adjust and save fig of full data Force-Fluo (1M)
adjustPlot(ax_LD_FLUO{1},[arrayXlegend_full_1M.mainLine, hl(1)],folderSaveComparison,filename1,idxMon)
% adjust and save fig of cutted data Force-Fluo (3M)
adjustPlot(ax_LD_FLUO{2},arrayXlegend_fitLine_3M_ForceFluorescence,folderSaveComparison,filename2,idxMon,textSubTitle)
clear text_dataSlope n fitResults_all saveFolderAdditionalText textSubTitle array* ax* fig* filename* slope* metaData_AFM metaData_BF metaData_NIKON_definitive clr cntDelta Data_finalResults firstPlot expTh hf hl hp i idxLineSample j allResultsData_pathfile baseline_nN
clc
disp("Comparison Data Correlations Completed. Propagate the TRITIC images from different files so they can be easily compared. Note: this operation will take some time.")
% in order to have fluorescence image scaled in the same way for better representation, lets find the max and mix values of all the scans and propagate all over images
allDelta={allDelta_original,allDelta_1M,allDelta_3M};
allDelta_text={"whole","1stMasked","3rdMasked"};
clear allDelta_original allDelta_1M allDelta_3M 
for j=1:3
    allValues = cellfun(@(x) x(:),allDelta{j}, 'UniformOutput', false);  
    allValues = vertcat(allValues{:});  
    rangeScale=zeros(1,2);
    rangeScale(1) = min(allValues); rangeScale(2)  = max(allValues);
    for i=1:length(allDelta{j})
        if typeShow == 1
            filename=sprintf('resultEND_%d_FluorescencePDA_scaled_onEveryScanSingleExp',5+j);
            titleD1=sprintf("TRITIC-%s (pixel-scaled over scans)",allDelta_text{j});
        else
            filename=sprintf('resultEND_%d_FluorescencePDA_scaled_onEveryExp',8+j);
            titleD1=sprintf("TRITIC-%s (pixel-scaled over samples)",allDelta_text{j});
        end    
        Delta=allDelta{j}{i};
        singleFolder=subfolder_allscanFolder{i};
        showData(idxMon,false,Delta,titleD1,singleFolder,filename,'lenghtAxis',allDelta_pixScale(i,:),'Broadcast',rangeScale)
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
    ystd_25=cell2mat({data.Bin25prctile});
    ystd_75=cell2mat({data.Bin75prctile});
    x=x*xMultiplier; y=y*yMultiplier;
    ystd_25=ystd_25*yMultiplier; ystd_75=ystd_75*yMultiplier;
    % Use prepareCurveData only for the main x/y pair to clean NaN
    [xData, yData] = prepareCurveData(x, y);
    % Apply the same NaN-removal mask to the error bar data
    mask = ~isnan(xData) & ~isnan(yData);
    ystdData_25 = ystd_25(mask); ystdData_25=ystdData_25';
    ystdData_75 = ystd_75(mask); ystdData_75=ystdData_75';

    if typeShow==1
        hpp=shadedErrorBar(xData,yData,[ystdData_25,ystdData_75], ...
            'lineProps',{'x','Color',clr,'DisplayName',nameData}, ...
            'transparent', true, ...
            'patchSaturation', 0.2, ...
            'plotAxes',idAxis);
        if strcmp(typeData,"Full")
            hpp.mainLine.MarkerSize=5; hpp.mainLine.LineStyle="-"; hpp.mainLine.LineWidth=1.5;
        elseif strcmp(typeData,"3M")
            hpp.mainLine.Marker='o'; hpp.mainLine.MarkerFaceColor=clr;        
            hpp.mainLine.MarkerSize=3; hpp.mainLine.LineStyle="none";
        end
        hp=hpp;
    else
        hp=plot(idAxis,xData,yData,'-','LineWidth', .5,'Color',clr,'DisplayName',nameData);
    end
    dataXfitting=struct();
    dataXfitting.xData=xData;
    dataXfitting.yData=yData;
    dataXfitting.ystdData_25=ystdData_25;
    dataXfitting.ystdData_75=ystdData_75;
end

function varargout=chooseAndFit(dataXfitting,typeShow,idAxis,idxMon,clr,nameSample,nameData)
    fitResults=struct();  
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
    idx=selectRangeGInput(2,1,axTmp); 
    idxRangeFitting=sort(idx);
    tmp = dataXfitting(1).xData;
    valueIdxMin=tmp(idxRangeFitting(1)); valueIdxMax=tmp(idxRangeFitting(2)); 
    close(figTmp)
    clear tmp axTmp figTmp idx
    % plot the lines in the axis figure only in the case of single experiment, otherwise too confusing
    if typeShow==1
        nameLineXlegend=' Left/Right Cutoffs (middle for data fitting)';
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
        hp=plot(idAxis{2},xfit,yfit,'Color',clrXfit,'LineWidth',3,'DisplayName',sprintf("Fitted Line - %s",nameData{i}));
        arrayXlegend=[arrayXlegend hp]; %#ok<AGROW>
        % save the fit var to calc the average
        fitResults(i).slope=fitresult.p1; % slope
        fitResults(i).offset=fitresult.p2; % offset       
    end
    varargout{1}=fitResults;
    varargout{2}=arrayXlegend;
end

function adjustPlot(idAxis,arrayXlegend,filepath,filename,idxMon,varargin)
    if ~isempty(varargin) && varargin{1}~=""
        subtitle(idAxis,varargin,'FontSize',16)
    end
    xlim(idAxis,'padded'), ylim(idAxis,'padded')
    idAxis.XAxis.MinorTick = 'on';   
    grid(idAxis,'on'), grid(idAxis,'minor')
    fig = ancestor(idAxis, 'figure');
    objInSecondMonitor(fig,idxMon);
    legend(idAxis,arrayXlegend,'FontSize',13,'Interpreter','none')
    waitfor(warndlg("Adjust the Legend's position before saving for better visual!"))
    saveFigures_FigAndTiff(fig,filepath,filename)
end

function nameExps=extractNameExp(mainFolderSingleCondition,nExps)
    nameExps=cell(1,nExps);
    for i=1:nExps
        tmp=strsplit(mainFolderSingleCondition{i},'\');
        nameExperiment=tmp{end};
        question=sprintf('Name experiment: %s\nIs everything okay?',nameExperiment);
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

