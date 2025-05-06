clc, clear, close all
secondMonitorMain=objInSecondMonitor;

typeShow=getValidAnswer('Show one or more type of data?','',{'One type only (ex. only TRCDA different scans)','More different types (ex. TRCDA, TRCDA:DMPC,etc)'});
% prepare fig
if typeShow==1
    flagHeightVsLD = getValidAnswer('Show also the Lateral Force Vs Height comparison?','',{'Yes','No'},2);
    flagBaselineComparison = getValidAnswer('Show also the Baseline comparison among the scans?','',{'Yes','No'},2);
    if flagHeightVsLD
        f3=figure; ax3=axes(f3); hold(ax3, 'on');
    end
    if flagBaselineComparison
        f4=figure; ax4=axes(f4); hold(ax4, 'on');
    end
end

% f1_1 and f1_3 for LD-FLUO (FULL, noNorm - Norm)
f1_1=figure; f1_2=figure;
ax1_1=axes(f1_1); ax1_2=axes(f1_2);
hold(ax1_1, 'on'); hold(ax1_2, 'on');
% f2_1 and f2_2 for LD-FLUO (Masked, noNorm - Norm)
f2_1=figure; f2_2=figure;
ax2_1=axes(f2_1); ax2_2=axes(f2_2);
hold(ax2_1, 'on'); hold(ax2_2, 'on');

% init
allDelta={};
cnt=1; % counter x for samples
arrayXlegend_mask_noNorm=[]; arrayXlegend_mask_norm=[];
arrayXlegend_full_noNorm=[]; arrayXlegend_full_norm=[];
while true
    mainFolderSingleCondition=uigetdir(pwd,'Select for the same type the main folder containing the subfolders ''Results Processing AFM and fluorescence images'' of different scans. Close to exit.');
    if mainFolderSingleCondition == 0
        break
    end
    nameType{cnt}=inputdlg('Enter the name of the data type (example: TRCDA or TRCDA:DMPC, etc)'); %#ok<SAGROW>
    disp(nameType{cnt}{1})
    commonPattern = 'Results Processing AFM and fluorescence images';
    % Get a list of all subfolders in the selected directory
    allSubfolders = dir(fullfile(mainFolderSingleCondition, '**', '*'));
    % Filter to only include subfolders matching the common pattern
    matchedSubfolders = allSubfolders([allSubfolders.isdir] & contains({allSubfolders.name}, commonPattern));    
    % Initialize a cell array to store file paths
    allResultsData = {};
    % for each sample (but not for each scan), select again the upper limit
    % of the data in the x axis for the fitting
    flagFirstSelectRangeXfit=true; idxLineSample=[];
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
    % init
    cntDelta=length(allDelta);
    for i=1:length(allResultsData)
        % when it is the first cycle of the same sample (i.e. first scan data for each sample), plot only once the upper limit for the fitting
        if i==1
            firstPlot=true;
        else
            firstPlot=false;
        end
        % if only one type of data, better visual using different color, but in case of more type/different
        % samples, use single color for each type/sample
        if typeShow==1
            clr=globalColor(i);
            nameData=subfolder_scanID{i};
        else
            clr=globalColor(cnt);
            nameData=nameType{cnt}{1};
        end
        % load only fluorescence and lateral deflection
        load(allResultsData{i},"Data_finalResults","metaData_AFM","metaData_BF","folderResultsImg")
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data fluorescene and store them %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        allDelta{cntDelta+i}= Data_finalResults.DeltaData.original;         %#ok<SAGROW>
        allDelta_pixScale(cntDelta+i)=metaData_BF.ImageHeight_umeterXpixel; %#ok<SAGROW>
        subfolder_allscanFolder{cntDelta+i}=folderResultsImg;               %#ok<SAGROW>

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the FULL data fluorescene VS lateral deflection (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % x = force (N) ==> xMultiplier = 1e9 ==> nN
        % y = FLUO (absolute) ==> yMultiplier = none (=1)
        hp=plotSingleDataFull(Data_finalResults.LD_FLUO,typeShow,nameData,ax1_1,clr,1e9,1);
        if (typeShow == 2 && i==1) || typeShow == 1
            arrayXlegend_full_noNorm=[arrayXlegend_full_noNorm, hp.mainLine]; %#ok<AGROW>
        end
               
        % use norm data
        % x = force (N) ==> xMultiplier = 1e9 ==> nN
        % y = FLUO (absolute) ==> yMultiplier = none (=1)
        hp=plotSingleDataFull(Data_finalResults.LD_FLUO_norm,typeShow,nameData,ax1_2,clr,1e9,1);
        if (typeShow == 2 && i==1) || typeShow == 1
            arrayXlegend_full_norm=[arrayXlegend_full_norm, hp.mainLine]; %#ok<AGROW>
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the masked data fluorescene VS lateral deflection (absolute fluo and norm) and show only %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        [hp,hl,hf,flagFirstSelectRangeXfit,idxLineSample,fitResults]=plotSingleDataMasked(Data_finalResults.LD_FLUO_perc99maxVD,typeShow,nameData,nameType{cnt}{1},ax2_1,secondMonitorMain,flagFirstSelectRangeXfit,idxLineSample,clr,firstPlot);
        % for the given sample, store the plot data. If typeShow=1, then entire vector will be used.
        % Otherwise, only the first element when legend will be called
        if typeShow == 1 && i == 1
            arrayXlegend_mask_noNorm=[hl,hp.mainLine,hf];
        elseif typeShow == 1 
            arrayXlegend_mask_noNorm=[arrayXlegend_mask_noNorm,hp.mainLine,hf]; %#ok<AGROW>
        elseif typeShow == 2 && i==1
            arrayXlegend_mask_noNorm=[arrayXlegend_mask_noNorm,hf];          %#ok<AGROW>
        end
        fitResults_all_noNorm(i)=fitResults; %#ok<SAGROW>
        % use norm data
        [hp,hl,hf,~,~,fitResults]=plotSingleDataMasked(Data_finalResults.LD_FLUO_perc99maxVD_norm,typeShow,nameData,nameType{cnt}{1},ax2_2,secondMonitorMain,flagFirstSelectRangeXfit,idxLineSample,clr,firstPlot);
        if typeShow == 1 && i == 1
            arrayXlegend_mask_norm=[hl,hp.mainLine,hf];
        elseif typeShow == 1 
            arrayXlegend_mask_norm=[arrayXlegend_mask_norm,hp.mainLine,hf]; %#ok<AGROW>
        elseif typeShow == 2 && i==1
            arrayXlegend_mask_norm=[arrayXlegend_mask_norm,hf];          %#ok<AGROW>
        end
        fitResults_all_norm(i)=fitResults; %#ok<SAGROW>

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the data Lateral Force VS Height %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if typeShow == 1 && flagHeightVsLD
            % x = force (N)  ==> xMultiplier = 1e9 ==> nN
            % y = height (m) ==> yMultiplier = 1e9 ==> nm
            hp=plotSingleDataFull(Data_finalResults.Height_LD_perc99maxVD,typeShow,nameData,ax3,clr,1e9,1e9);
            if cnt==1 && i==1
                arrayXlegend_HeightLD=hp.mainLine;
            elseif (cnt~=1 && i==1) || typeShow == 1
                arrayXlegend_HeightLD=[arrayXlegend_HeightLD, hp.mainLine]; %#ok<AGROW>
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% extract the baseline trend %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if typeShow == 1 && flagBaselineComparison
            totTimeScan = (metaData_AFM.x_scan_pixels/metaData_AFM.Scan_Rate_Hz)/60;
            totTimeSection = totTimeScan/length(metaData_AFM.SetP_N);
            % first plot the baseline given in the metadata
            arrayTime=0:totTimeSection:totTimeScan-totTimeSection;
            baseline_nN=metaData_AFM.Baseline_N*1e9;
            if length(baseline_nN) > 1
                % plot the baseline trend from metadata
                nameplot = sprintf('Scan #%s',nameData);
                hp=plot(ax4,arrayTime,baseline_nN,'-*','LineWidth',2,'MarkerSize',10,'MarkerEdgeColor',clr,'Color',clr,'DisplayName',nameplot);
                if cnt==1 && i==1
                    arrayXlegend_baseline=hp;
                elseif (cnt~=1 && i==1) || typeShow == 1
                    arrayXlegend_baseline=[arrayXlegend_baseline, hp]; %#ok<AGROW>
                end
            end
        end
    end
    slopeAVG_noNorm(cnt)=mean([fitResults_all_noNorm(:).slope]); %#ok<SAGROW>
    slopeSTD_noNorm(cnt)=std([fitResults_all_noNorm(:).slope]); %#ok<SAGROW>
    slopeAVG_norm(cnt)=mean([fitResults_all_norm(:).slope]); %#ok<SAGROW>
    slopeSTD_norm(cnt)=std([fitResults_all_norm(:).slope]); %#ok<SAGROW>
    if typeShow==1
        break
    end
    cnt=cnt+1;
end

clear metaData_AFM metaData_BF clr cntDelta Data_finalResults firstPlot fitResults flagBaselineComparison flagHeightVsFluo flagFirstSelectRangeXfit
clear hf hl hp i idxLineSample j k subfolder_scanID nameplot allResultsData baseline_nN nameData
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% ADJUST ESTHETIC PART OF THE PLOTTING AND SAVE  %%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% location of the results
if typeShow==2
    foldername= uigetdir('*.tif',"Where save the final results?");
    textTitle='Comparison of different scans of different same samples';
else
    foldername=mainFolderSingleCondition;
    textTitle=sprintf('Comparison of different scans of the same sample (%s)',nameType{1}{1});
end

xlabelText='Lateral Force [nN]';
ylabelText='Absolute fluorescence increase (A.U.)';
filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_noNorm.tif');
adjustPlot(ax1_1,xlabelText,ylabelText,textTitle,arrayXlegend_full_noNorm,filepath,secondMonitorMain)

ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_norm.tif');
adjustPlot(ax1_2,xlabelText,ylabelText,textTitle,arrayXlegend_full_norm,filepath,secondMonitorMain)

if typeShow==1
    textTitle={sprintf('LD-Fluorescence comparison of different scans of the same sample (%s)',nameType{1}{1}); sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_noNorm,slopeSTD_noNorm)};
    ylabelText='Absolute fluorescence increase (A.U.)';
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_noNorm.tif');
    adjustPlot(ax2_1,xlabelText,ylabelText,textTitle,arrayXlegend_mask_noNorm,filepath,secondMonitorMain)
    % norm data
    textTitle={sprintf('LD-Fluorescence comparison of different scans of the same sample (%s)',nameType{1}{1}); sprintf('Slope (avg \x00B1 std) = %.2e \x00B1 %.2e',slopeAVG_norm,slopeSTD_norm)};
    ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_norm.tif');
    adjustPlot(ax2_2,xlabelText,ylabelText,textTitle,arrayXlegend_mask_norm,filepath,secondMonitorMain)
else
    % no norm
    % adjust text to put in the legend. Show only one type of information for each sample
    for n = 1:cnt-1
        text_dataSlope = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_noNorm(n),slopeSTD_noNorm(n));
        arrayXlegend_mask_noNorm(n).DisplayName = text_dataSlope; %#ok<SAGROW>
    end   
    textTitle='LD-Fluorescence Comparison of different samples';
    ylabelText='Absolute fluorescence increase (A.U.)';    
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_noNorm.tif');    
    adjustPlot(ax2_1,xlabelText,ylabelText,textTitle,arrayXlegend_mask_noNorm,filepath,secondMonitorMain)
    % norm
    for n = 1:cnt-1
        text_dataSlope = sprintf(' %s \n - slope: = %.2e \x00B1 %.2e',nameType{n}{1},slopeAVG_norm(n),slopeSTD_norm(n));
        arrayXlegend_mask_norm(n).DisplayName = text_dataSlope; %#ok<SAGROW>
    end
    ylabelText=string(sprintf('Normalised Fluorescence (%%)'));
    filepath=fullfile(foldername,'RESULTSfinal_LDvsFLUO_99percMaxSetpoint_norm.tif');    
    adjustPlot(ax2_2,xlabelText,ylabelText,textTitle,arrayXlegend_mask_norm,filepath,secondMonitorMain)
 
end

if exist("f3",'var')
    ylabelText='Lateral Force [nN]';
    xlabelText='Height [nm]';
    filepath=fullfile(foldername,'RESULTSfinal_HeightVsLD.tif');
    textTitle=sprintf('Height Vs Lateral Force - comparison of different scans (sample %s)',nameType{1}{1});
    adjustPlot(ax3,xlabelText,ylabelText,textTitle,arrayXlegend_HeightLD,filepath,secondMonitorMain)
end

if exist("f4",'var')
    ylabelText='Baseline shift [nN]';
    xlabelText='Time [min]';
    filepath=fullfile(foldername,'RESULTSfinal_baseline.tif');
    textTitle=sprintf('Baseline Shift Trend - comparison of different scans (sample %s)',nameType{1}{1});
    adjustPlot(ax4,xlabelText,ylabelText,textTitle,arrayXlegend_baseline,filepath,secondMonitorMain)
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
    showData(secondMonitorMain,false,1,Delta,false,titleD1,labelBar,singleFolder,filename,'meterUnit',allDelta_pixScale(i),'scale',rangeScale)
end
clear allValues filename titleD1 labelBar singleFolder rangeScale
%%
%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% FUNCTIONS %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%

function hp=plotSingleDataFull(data,typeShow,nameData,idAxis,clr,xMultiplier,yMultiplier)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% extract the data and show only %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    x=cell2mat({data.BinCenter});
    y=cell2mat({data.MeanBin});
    ystd=cell2mat({data.STDBin});
    % x is usually force. So, it is expressed in Newton ==> express in nanoNewton
    x=x*xMultiplier; y=y*yMultiplier;
    [xData,yData,ystdData] = prepareCurveData(x,y,ystd);
    if typeShow == 1
        nameplot = sprintf('scan %s',nameData);
    else
        nameplot = sprintf('sample %s',nameData);
        %hp.Annotation.LegendInformation.IconDisplayStyle = 'off';
    end
    hp=shadedErrorBar(xData,yData, ystdData, ...
        'lineProps',{'x', 'LineWidth', .5,'Color',clr,'DisplayName',nameplot}, ...
        'transparent', true, ...
        'patchSaturation', 0.3, ...
        'plotAxes',idAxis);
    hp.mainLine.MarkerSize=5; hp.mainLine.LineStyle="-"; hp.mainLine.LineWidth=1.5; hp.mainLine.Marker="o"; hp.mainLine.MarkerFaceColor="auto";
end

function [hp,hl,hf,flagFirstSelectRangeXfit,idx,fitResults]=plotSingleDataMasked(data,typeShow,nameData,nameType,idAxis,secondMonitorMain,flagFirstSelectRangeXfit,idx,clr,firstPlot)
    x=cell2mat({data.BinCenter});
    y=cell2mat({data.MeanBin});
    ystd=cell2mat({data.STDBin});
    % the force is expressed in Newton ==> express in nanoNewton
    x=x*1e9;
    [xData,yData,ystdData] = prepareCurveData(x,y,ystd);
    if typeShow == 1
        nameplot = sprintf('scan %s',nameData);
    else
        nameplot = sprintf('sample %s',nameData);
        %hp.Annotation.LegendInformation.IconDisplayStyle = 'off';
    end
    hp=shadedErrorBar(xData,yData, ystdData, ...
        'lineProps',{'x', 'LineWidth', .5,'Color',clr,'DisplayName',nameplot}, ...
        'transparent', true, ...
        'patchSaturation', 0.3, ...
        'plotAxes',idAxis);

    % originally, the fitting was based on the entire data_LDvsFLUO_perc99maxVD dataset
    % However, it is important to remind that lateralForce = friction*verticalForce
    % therefore, fitting until last setpoint is not really correct. For
    % example, if friction coefficient was 0.3, then the max
    % lateralForce is 33 nN if the last setpoint was 110.
    % It is complicated and not consisted fitting depending directly on the friction coefficient
    % because each AFM lateral deflection channel has own friction coefficient because of HOVER
    % MODE OFF which depends on the specific AFM scanned area
    % For this reason, a more manual approach is suggested by clicking
    % the point until which the data is used for fitting
    if flagFirstSelectRangeXfit
        figTmp=figure;
        shadedErrorBar(xData,yData, ystdData, ...
        'lineProps',{'x', 'LineWidth', .5,'Color',clr,'DisplayName',nameplot}, ...
        'transparent', true, ...
        'patchSaturation', 0.3);

        objInSecondMonitor(secondMonitorMain,figTmp);
        hold on
        xlim padded, ylim padded
        grid on, grid minor
        uiwait(msgbox('click on the plot to decide the upper limit in x axis for the fitting','Success','modal'))
        figure(figTmp)
        idx=selectRangeGInput(1,1,xData,yData);
        flagFirstSelectRangeXfit=false;
        close(figTmp)
    end    
    if firstPlot
        if typeShow==1
            nameLineXlegend='Upper range for fitting';
            lineClr='k';
        else
            nameLineXlegend=sprintf('Upper range for fitting - sample %s',nameType);
            lineClr=clr;
        end
        hl=xline(idAxis,round(xData(idx)),'--','LineWidth',1,'DisplayName',nameLineXlegend,'Color',lineClr);            
    else
        hl=[];
    end
    % Fit:
    ft = fittype( 'poly1' );
    opts = fitoptions( 'Method', 'LinearLeastSquares' );
    opts.Robust = 'LAR';
    [fitresult, ~] = fit(xData(1:idx), yData(1:idx), ft, opts );
    xfit=linspace(xData(1),xData(end),length(xData));
    yfit=xfit*fitresult.p1+fitresult.p2;
    if typeShow == 1
        nameplot = sprintf('Fitted Curve - %s',nameData);        
    else
        nameplot = 'Fitted Curve';
    end
    hold(idAxis, 'on');
    hf= plot(idAxis,xfit,yfit,'Color',clr,'DisplayName',nameplot,'LineWidth',3);
    % save the fit var to calc the average
    fitResults.slope=fitresult.p1; % slope
    fitResults.offset=fitresult.p2; % offset
end

function adjustPlot(idAxis,xlabelText,ylabelText,textTitle,arrayXlegend,filepath,secondMonitorMain)
    xlim(idAxis,'padded'), ylim(idAxis,'padded')
    idAxis.XAxis.MinorTick = 'on';   
    grid(idAxis,'on'), grid(idAxis,'minor')
    fig = ancestor(idAxis, 'figure');
    objInSecondMonitor(secondMonitorMain,fig);
    legend(idAxis,arrayXlegend,'Location', 'best','FontSize',15,'Interpreter','none')
    title(idAxis,textTitle,'FontSize',23,'Interpreter','none');
    idAxis.XAxis.FontSize = 15; idAxis.YAxis.FontSize = 15; 
    ylabel(idAxis,ylabelText,'FontSize',20), xlabel(idAxis,xlabelText,'FontSize',20)
    saveas(fig,filepath)
    close(fig)
end