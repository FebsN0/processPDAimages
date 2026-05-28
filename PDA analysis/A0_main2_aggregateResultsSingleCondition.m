clc, clear, close all
idxMon=objInSecondMonitor;

% turn off warning prepareCurve
warnID = 'curvefit:prepareFittingData:removingNaNAndInf';
warning('off', warnID);

typeShow=getValidAnswer('Show one or more type of data?','',{'One type only (ex. only TRCDA different scans)','More different types (ex. TRCDA, TRCDA:DMPC,etc)'});
% prepare fig
if typeShow==1
    % x Height vs FLUO
    f3=figure; ax3=axes(f3); hold(ax3,'on');
    % x Height vs LateralForce
    f4=figure; ax4=axes(f4); hold(ax4,'on');
    % baseline trend
    f5=figure; ax5=axes(f5); hold(ax5,'on');
end

% f1_1 and f1_3 for LD-FLUO (FULL, noNorm - Norm)
f1_1=figure; f1_2=figure;
ax1_1=axes(f1_1); hold(ax1_1, 'on');
ax1_2=axes(f1_2); hold(ax1_2, 'on');
% f2_1 and f2_2 for LD-FLUO (Masked, noNorm - Norm)
f2_1=figure; f2_2=figure;
ax2_1=axes(f2_1); ax2_2=axes(f2_2);
hold(ax2_1, 'on'); hold(ax2_2, 'on');

% init
allDelta={};
cnt=1; % counter x for samples
arrayXlegend_mask_noNorm=[]; arrayXlegend_mask_norm=[];
arrayXlegend_full_noNorm=[]; arrayXlegend_full_norm=[];
arrayXlegend_mask_upperLimit_noNorm=[]; arrayXlegend_mask_upperLimit_norm=[];
arrayXlegend_Height_LD=[]; arrayXlegend_Height_FLUO=[];
arrayXlegend_baseline=[];
arrayXlegend_fitLine_noNorm=[]; arrayXlegend_fitLine_norm=[];
while true
    mainFolderSingleCondition=uigetdirMultiSelect(pwd,'Select one or more scans of the same sample directory. Close to exit.');
    if isempty(mainFolderSingleCondition)
        break
    end
    while true
        name=inputdlg('Enter the name of the data type (example: TRCDA or TRCDA:DMPC, etc)');
        if ~isempty(name{1})
            break
        end
    end    
    nameType{cnt}=name; %#ok<SAGROW>
    clear name
    disp(nameType{cnt}{1})
    commonPattern = 'Results Processing AFM and fluorescence images';
    % Get a list of all subfolders in the selected directory
    allSubfolders = []; % inizializza struttura vuota

    for i = 1:length(mainFolderSingleCondition)
        folder = mainFolderSingleCondition{i};
        thisSubfolders = dir(fullfile(folder, '**', '*'));
        % Aggiungi i risultati al vettore complessivo
        allSubfolders = [allSubfolders; thisSubfolders];
    end
    % Filter to only include subfolders matching the common pattern
    matchedSubfolders = allSubfolders([allSubfolders.isdir] & contains({allSubfolders.name}, commonPattern));    
    % Initialize a cell array to store file paths
    allResultsData = {};
    % Loop through the matched subfolders
    for k = 1:length(matchedSubfolders)
        % Construct the full path of the current subfolder and then search the specific file
        subfolderPath = fullfile(matchedSubfolders(k).folder, matchedSubfolders(k).name);
        if typeShow == 1
            parts=split(subfolderPath,'\');
            subfolder_scanID{k} = parts{end-1}; %#ok<SAGROW>
        end
        filesInSubfolder = dir(fullfile(subfolderPath, 'resultsData_A10_end.mat'));
        % If the file exists, append it to the list
        if ~isempty(filesInSubfolder)
            for j = 1:length(filesInSubfolder)
                allResultsData{end+1} = fullfile(filesInSubfolder(j).folder, filesInSubfolder(j).name); %#ok<SAGROW>
            end
        end
    end
    clear commonPattern allSubfolders matchedSubfolders subfolderPath parts filesInSubfolder
    % Reset the struct array
    dataXfitting_noNorm = struct('xData', {}, 'yData', {}, 'ystdData', {});    
    dataXfitting_norm=struct('xData', {}, 'yData', {}, 'ystdData', {}); 
    cntDelta=length(allDelta);
    nameScans=cell(1,length(allResultsData));
    for i=1:length(allResultsData)
        % if only one type of data, better visual using different color, but in case of more type/different
        % samples, use single color for each type/sample
        if typeShow==1
            clr=globalColor(i);
            nameData = sprintf('Scan #%s',subfolder_scanID{i});            
        else
            clr=globalColor(cnt);
            nameData=sprintf('Sample %s',nameType{cnt}{1});
        end
        nameScans{i}=nameData;
        % load only fluorescence and lateral deflection
        load(allResultsData{i},"Data_finalResults","metaData_AFM","metaData_BF","folderResultsImg")
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data Delta (shifted but not masked) and store them %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        allDelta{cntDelta+i}= Data_finalResults.DeltaData.Delta_ADJ_minShifted;         %#ok<SAGROW>
        allDelta_pixScale(cntDelta+i)=metaData_BF.ImageHeight_umeterXpixel;             %#ok<SAGROW>
        subfolder_allscanFolder{cntDelta+i}=folderResultsImg;                           %#ok<SAGROW>

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the second masked (each AFM channel) data fluorescene VS lateral deflection (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % x = force (N) ==> xMultiplier = 1e9 ==> nN
        % y = FLUO (absolute) ==> yMultiplier = none (=1)
        hp=plotSingleData(Data_finalResults.LD_FLUO.LD_FLUO_2M,nameData,ax1_1,clr,1e9,1,true,typeShow);
        if (typeShow == 2 && i==1) || typeShow == 1
            arrayXlegend_full_noNorm=[arrayXlegend_full_noNorm, hp]; %#ok<AGROW>
        end              
        % norm data
        hp=plotSingleData(Data_finalResults.LD_FLUO.LD_FLUO_2M_norm,nameData,ax1_2,clr,1e9,1,true,typeShow);
        if (typeShow == 2 && i==1) || typeShow == 1
            arrayXlegend_full_norm=[arrayXlegend_full_norm, hp]; %#ok<AGROW>
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the third masked (99 perc + <maxSP) data lateral deflection VS fluorescene (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % no save data for legend because the fitted handle figures will be
        % used
        [~,data]=plotSingleData(Data_finalResults.LD_FLUO.LD_FLUO_3M,nameData,ax2_1,clr,1e9,1,false,typeShow);
        dataXfitting_noNorm(i)=data;
        % norm data
        [~,data]=plotSingleData(Data_finalResults.LD_FLUO.LD_FLUO_3M_norm,nameData,ax2_2,clr,1e9,1,false,typeShow);
        dataXfitting_norm(i)=data;
        
        if typeShow == 1
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS fluorescence %%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%               
            % x = height (m) ==> xMultiplier = 1e9 ==> nm
            hp=plotSingleData(Data_finalResults.Height_FLUO.Height_FLUO_3M,nameData,ax3,clr,1e9,1,true,typeShow);
            arrayXlegend_Height_FLUO=[arrayXlegend_Height_FLUO, hp]; %#ok<AGROW>                   
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the data Height VS Lateral Force %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%       
            % x = height (m) ==> xMultiplier = 1e9 ==> nm
            % y = force (N)  ==> yMultiplier = 1e9 ==> nN
            hp=plotSingleData(Data_finalResults.Height_LD.Height_LD_3M,nameData,ax4,clr,1e9,1e9,true,typeShow);
            arrayXlegend_Height_LD=[arrayXlegend_Height_LD, hp]; %#ok<AGROW>
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%% extract the Baseline trend and show %%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%              
            % baseline
            totTimeScan = (metaData_AFM.x_scan_pixels/metaData_AFM.Scan_Rate_Hz)/60;
            totTimeSection = totTimeScan/length(metaData_AFM.SetP_N);
            % first plot the baseline given in the metadata
            arrayTime=0:totTimeSection:totTimeScan-totTimeSection;
            baseline_nN=metaData_AFM.Baseline_N*1e9;
            if length(baseline_nN) > 1
                % plot the baseline trend from metadata                
                hp=plot(ax5,arrayTime,baseline_nN,'-*','LineWidth',2,'MarkerSize',10,'MarkerEdgeColor',clr,'Color',clr,'DisplayName',nameData);
                arrayXlegend_baseline=[arrayXlegend_baseline, hp]; %#ok<AGROW>                
            end
        end       
    end
    % choose the upper limit to fit the data below and plot it
    idx=[];    
    [fitResults_all_noNorm,hl,hp,idx]=chooseAndFit(dataXfitting_noNorm,typeShow,ax2_1,idxMon,true,idx,globalColor(cnt),nameType{cnt}{1},nameScans);
    arrayXlegend_mask_upperLimit_noNorm(cnt)=hl; %#ok<SAGROW>
    % store the handle figure to organize the legend names
    if typeShow == 2
        arrayXlegend_fitLine_noNorm=[arrayXlegend_fitLine_noNorm, hp(1)]; %#ok<AGROW>
    else
        arrayXlegend_fitLine_noNorm=hp;
    end
    % norm
    [fitResults_all_norm,hl,hp]=chooseAndFit(dataXfitting_norm,typeShow,ax2_2,idxMon,false,idx,globalColor(cnt),nameType{cnt}{1},nameScans);
    arrayXlegend_mask_upperLimit_norm(cnt)=hl; %#ok<SAGROW>
        % store the handle figure to organize the legend names
    if typeShow == 2
        arrayXlegend_fitLine_norm=[arrayXlegend_fitLine_norm, hp(1)]; %#ok<AGROW>
    else
        arrayXlegend_fitLine_norm=hp;
    end
    % store slope data
    slopeAVG_noNorm(cnt)=mean([fitResults_all_noNorm(:).slope]); %#ok<SAGROW>
    slopeSTD_noNorm(cnt)=std([fitResults_all_noNorm(:).slope]); %#ok<SAGROW>
    slopeAVG_norm(cnt)=mean([fitResults_all_norm(:).slope]); %#ok<SAGROW>
    slopeSTD_norm(cnt)=std([fitResults_all_norm(:).slope]); %#ok<SAGROW>
    if typeShow==1
        break
    end
    cnt=cnt+1;
end

% build the final arrays to show in the legend: first the data lines and then the upper limit vertical line
arrayXlegend_mask_noNorm=[arrayXlegend_fitLine_noNorm arrayXlegend_mask_upperLimit_noNorm]; 
arrayXlegend_mask_norm=[arrayXlegend_fitLine_norm arrayXlegend_mask_upperLimit_norm]; 

clear metaData_AFM metaData_BF clr cntDelta Data_finalResults firstPlot fitResults flagFirstSelectRangeXfit
clear hf hl hp i idxLineSample j k subfolder_scanID allResultsData baseline_nN nameData
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ADJUST ESTHETIC PART OF THE PLOTTING AND SAVE  %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% location of the results
if typeShow==2
    foldername= uigetdir('*.tif',"Where save the final results?");
    textTitle='Comparison of different scans of different same samples';
else
    foldername=sprintf('%s\\resultsA11_ComparisonAllScans',mainFolderSingleCondition);
    mkdir(foldername)
    textTitle=sprintf('Comparison of different scans of the same sample (%s)',nameType{1}{1});
end

xlabelText='Lateral Force [nN]';
ylabelText='Absolute fluorescence increase (A.U.)';
filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_noNorm.tif');
adjustPlot(ax1_1,xlabelText,ylabelText,textTitle,arrayXlegend_full_noNorm,filepath,idxMon)

ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_norm.tif');
adjustPlot(ax1_2,xlabelText,ylabelText,textTitle,arrayXlegend_full_norm,filepath,idxMon)

if typeShow==1
    textTitle={sprintf('LD-Fluorescence comparison of different scans of the same sample (%s)',nameType{1}{1}); sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_noNorm,slopeSTD_noNorm)};
    ylabelText='Absolute fluorescence increase (A.U.)';
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_noNorm.tif');
    adjustPlot(ax2_1,xlabelText,ylabelText,textTitle,arrayXlegend_mask_noNorm,filepath,idxMon)
    % norm data
    textTitle={sprintf('LD-Fluorescence comparison of different scans of the same sample (%s)',nameType{1}{1}); sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_norm,slopeSTD_norm)};
    ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_norm.tif');
    adjustPlot(ax2_2,xlabelText,ylabelText,textTitle,arrayXlegend_mask_norm,filepath,idxMon)
else
    % no norm
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:cnt-1
        text_dataSlope = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_noNorm(n),slopeSTD_noNorm(n));
        arrayXlegend_mask_noNorm(n).DisplayName = text_dataSlope;
    end   
    textTitle='LD-Fluorescence Comparison of different samples';
    ylabelText='Absolute fluorescence increase (A.U.)';    
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_noNorm.tif');    
    adjustPlot(ax2_1,xlabelText,ylabelText,textTitle,arrayXlegend_mask_noNorm,filepath,idxMon)
    % norm
    for n = 1:cnt-1
        text_dataSlope = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_norm(n),slopeSTD_norm(n));
        arrayXlegend_mask_norm(n).DisplayName = text_dataSlope; 
    end
    ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_norm.tif');    
    adjustPlot(ax2_2,xlabelText,ylabelText,textTitle,arrayXlegend_mask_norm,filepath,idxMon)
 
end

if typeShow==1
    % Height VS FLUO
    xlabelText='Height [nm]';
    ylabelText='Absolute fluorescence increase (A.U.)';
    filepath=fullfile(foldername,'RESULTSfinal_HeightVsFLUO.tif');
    textTitle=sprintf('Height Vs Fluorescence - comparison of different scans (sample %s)',nameType{1}{1});
    adjustPlot(ax3,xlabelText,ylabelText,textTitle,arrayXlegend_Height_FLUO,filepath,idxMon)
    % Height VS LD
    ylabelText='Lateral Force [nN]';    
    filepath=fullfile(foldername,'RESULTSfinal_HeightVsLD.tif');
    textTitle=sprintf('Height Vs Lateral Force - comparison of different scans (sample %s)',nameType{1}{1});
    adjustPlot(ax4,xlabelText,ylabelText,textTitle,arrayXlegend_Height_LD,filepath,idxMon)
    % trend baseline
    ylabelText='Baseline shift [nN]';
    xlabelText='Time [min]';
    filepath=fullfile(foldername,'RESULTSfinal_baseline.tif');
    textTitle=sprintf('Baseline Shift Trend - comparison of different scans (sample %s)',nameType{1}{1});
    adjustPlot(ax5,xlabelText,ylabelText,textTitle,arrayXlegend_baseline,filepath,idxMon)
end
clear array* ax* f1* f2* f3 f4 textTitle xlabelText ylabelText filepath foldername slope* cnt nameType fitResults*
%%
% in order to have fluorescence image scaled in the same way for better
% representation, lets find the max and mix values of all the scans
allValues = cellfun(@(x) x(:),allDelta, 'UniformOutput', false);  
allValues = vertcat(allValues{:});                         
rangeScale=zeros(1,2);
rangeScale(1) = min(allValues); rangeScale(2)  = max(allValues);

for i=1:length(allDelta)
    if typeShow == 1
        filename='resultA11_1_FluorescencePDA_scaled_onSingleSample';
        titleD1='Tritic whole (before masking - scaled over scans)';
    else
        filename='resultA11_2_FluorescencePDA_scaled_onEverything';
        titleD1='Tritic whole (before masking - scaled over samples)';
    end    
    labelBar='Absolute Fluorescence';
    Delta=allDelta{i};
    singleFolder=subfolder_allscanFolder{i};
    showData(idxMon,false,Delta,false,titleD1,labelBar,singleFolder,filename,'meterUnit',allDelta_pixScale(i),'scale',rangeScale)
end
clear allValues filename titleD1 labelBar singleFolder rangeScale
%%
%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% FUNCTIONS %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%

function [hp,dataXfitting]=plotSingleData(data,nameData,idAxis,clr,xMultiplier,yMultiplier,flagFullData,typeShow)
%%%%%% extract the data and show only %%%%%%
    x=cell2mat({data.BinCenter});
    y=cell2mat({data.MeanBin});
    ystd=cell2mat({data.STDBin});
    x=x*xMultiplier; y=y*yMultiplier; ystd=ystd*yMultiplier;
    [xData,yData,ystdData] = prepareCurveData(x,y,ystd);
    if typeShow==1
        hpp=shadedErrorBar(xData,yData, ystdData, ...
            'lineProps',{'x', 'LineWidth', .5,'Color',clr,'DisplayName',nameData}, ...
            'transparent', true, ...
            'patchSaturation', 0.3, ...
            'plotAxes',idAxis);
        if flagFullData
            hpp.mainLine.MarkerSize=5; hpp.mainLine.LineStyle="-"; hpp.mainLine.LineWidth=1.5; hpp.mainLine.MarkerFaceColor="auto";
        end
        hp=hpp;
    else
        hp=plot(idAxis,xData,yData,'-','LineWidth', .5,'Color',clr,'DisplayName',nameData);
    end
    dataXfitting=struct();
    dataXfitting.xData=xData;
    dataXfitting.yData=yData;
    dataXfitting.ystdData=ystdData;
end

function [fitResults,hl,arrayXlegend,idx]=chooseAndFit(dataXfitting,typeShow,idAxis,secondMonitorMain,firstPlot,idx,clr,nameSample,nameData)
    fitResults=struct();
    if firstPlot
        figTmp=figure; hold on
        title(sprintf('LD vs Fluorescence of every scan of the sample %s',nameSample),'FontSize',20,'Interpreter','none')
        % originally, the fitting was based on the entire data_LDvsFLUO_perc99maxVD dataset
        % However, it is important to remind that lateralForce = friction*verticalForce
        % therefore, fitting until last setpoint is not really correct. For
        % example, if friction coefficient was 0.3, then the max
        % lateralForce is 33 nN if the last setpoint was 110.
        % It is co
        % mplicated and not consisted fitting depending directly on the friction coefficient
        % because each AFM lateral deflection channel has own friction coefficient because of HOVER
        % MODE OFF which depends on the specific AFM scanned area
        % For this reason, a more manual approach is suggested by clicking
        % the point until which the data is used for fitting.
        for i=1:length(dataXfitting)
            xData = dataXfitting(i).xData;
            yData = dataXfitting(i).yData;
            plot(xData,yData,'*','MarkerFaceColor',globalColor(i))                        
        end
        objInSecondMonitor(figTmp,idxMon);        
        xlim padded, ylim padded
        grid on, grid minor
        uiwait(msgbox('Click on the plot to decide the upper limit in x axis for the fitting','Success','modal'))   
        figure(figTmp)
        xlimits=xlim; ylimits=ylim;
        xarr=linspace(xlimits(1),xlimits(2),length(xData));
        yarr=linspace(ylimits(1),ylimits(2),length(yData));                
        idx=selectRangeGInput(1,1,xarr,yarr);   
        close(figTmp)
    end
    % plot the lines in the axis figure
    if typeShow==1
        nameLineXlegend='Upper range for fitting';
        lineClr='k';    
    else
        nameLineXlegend=sprintf('xmaxXfit - %s',nameSample);
        lineClr=clr;
    end
    % be sure that xR have the same values
    xR=zeros(1,length(dataXfitting));
    for i=1:length(dataXfitting)
        xData = dataXfitting(i).xData;
        xR(i)=round(xData(idx));
    end
    if ~all(xR == xR(1))
        warning('the vertical lines are not the same. Some problems..')
    end    
    hl=xline(idAxis,round(xData(idx)),'--','LineWidth',1,'DisplayName',nameLineXlegend,'Color',lineClr);            
    % Fitting
    ft = fittype( 'poly1' );
    opts = fitoptions( 'Method', 'LinearLeastSquares' );
    opts.Robust = 'LAR';
    arrayXlegend=[];
    for i=1:length(dataXfitting)
        xData = dataXfitting(i).xData;
        yData = dataXfitting(i).yData;
        [fitresult, ~] = fit(xData(1:idx), yData(1:idx), ft, opts );
        xfit=linspace(xData(1),xData(end),length(xData));
        yfit=xfit*fitresult.p1+fitresult.p2;
        hold(idAxis, 'on');
        if typeShow==1
            clrXfit=globalColor(i);
        else
            clrXfit=clr;
        end
        hp=plot(idAxis,xfit,yfit,'Color',clrXfit,'LineWidth',3,'DisplayName',nameData{i});
        arrayXlegend=[arrayXlegend hp]; %#ok<AGROW>
        % save the fit var to calc the average
        fitResults(i).slope=fitresult.p1; % slope
        fitResults(i).offset=fitresult.p2; % offset
    end
end

function adjustPlot(idAxis,xlabelText,ylabelText,textTitle,arrayXlegend,filepath,idxMon)
    xlim(idAxis,'padded'), ylim(idAxis,'padded')
    idAxis.XAxis.MinorTick = 'on';   
    grid(idAxis,'on'), grid(idAxis,'minor')
    fig = ancestor(idAxis, 'figure');
    objInSecondMonitor(fig,idxMon);
    legend(idAxis,arrayXlegend,'Location', 'best','FontSize',12,'Interpreter','none')
    title(idAxis,textTitle,'FontSize',23,'Interpreter','none');
    idAxis.XAxis.FontSize = 15; idAxis.YAxis.FontSize = 15; 
    ylabel(idAxis,ylabelText,'FontSize',20), xlabel(idAxis,xlabelText,'FontSize',20)
    saveas(fig,filepath)
    %close(fig)
end