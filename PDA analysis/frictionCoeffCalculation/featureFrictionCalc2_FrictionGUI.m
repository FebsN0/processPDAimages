% This function opens an easy interface to see how different methods to extract friction affect the overall data. 
% The user has to choose one of the two possible methods depending on the choice and input data
%   method 1) INPUT: BK+FR   ==>  masking lateral and vertical data using AFM_height_IO to ignore PDA regions
%
% The second method removes outliers considered as spike signals in correspondence with the PDA crystal's edges using in-built matlab function.
% Moreover, PIXEL REDUCTION is applied to make more robust the statistical calculation prior the outliers removal
% once found a segment (single background region between two PDA regions), depending on the window/pixel
% size, the edges will be "brutally" removed by zeroing (0:PDA-1:BK)
%   method 2a) INPUT: BK+FR  ==>  method 1 + REMOVAL OF OUTLIERS on single segments found in each single fast scan line
%   method 2b) INPUT: BK+FR  ==>  method 1 + REMOVAL OF OUTLIERS on connected segments (multiple single segment attached togheter before
%                                   outliers removal for better statistics) for each single fast scan line
%   method 2c) INPUT: BK+FR  ==>  method 1 + REMOVAL OF OUTLIERS on connected segments of each entire section (in correspondence of same
%                                   setpoint region) ==> multiple segments of multiple fast scan lines all attached togheter
%
%   method 3 (development) INPUT: background ONLY ==>  simplest method
%
% INPUT:    - vertForce : vertical forces (mean trace-retrace)
%           - force     : lateral forces
%           - idxSection: indexes of the sections (matrix). (1,i) = startIdx, (2,i) = endIdx
%           - filePathResultsFriction : folder where to save plots and results
% OUTPUT:   - results

function results = featureFrictionCalc2_FrictionGUI(vertForce,force,mask,idxSection,idxMon,filePathResultsFriction)
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)    
    % Default values
    pixData = [20; 1];
    segmentProcess = 1;
    outlierRemovalMethod=1;
    outlierRemovalMethod_text='none';
    segmentType_text = 'SingleSegmentsProcess';
    method = 1; % default method
        
    % ==== GUI WINDOW ====
    hFig = figure('Name','Friction Extraction','NumberTitle','off', ...
                  'MenuBar','none','ToolBar','none');
    screens = get(0, 'MonitorPositions');
    monitorXfig = screens(idxMon, :);
    % Move to the target monitor manually.
    % NOTE: the positions left and bottom equal to 1 means it is coincident literally with (1,1) which is over the bottom bar
    left   = monitorXfig(1);
    bottom = monitorXfig(2)+50;
    width  = monitorXfig(3);
    height = monitorXfig(4)-80;
    set(hFig, 'Position', [left bottom width height]);
    %clear screens left bottom width height monitorXfig
    
    % ==== METHOD SELECTION ====
    hPanel_Method=uipanel(hFig,'Title','Method settings','FontSize',15,...
        'Units','normalized','Position',[0.02 0.90 0.27 0.08],'FontSize', 15);

    hMethod = uicontrol(hPanel_Method,'Style','popupmenu', ...
        'Units','normalized','Position',[0.02 0.25 0.96 0.5], ...
        'FontSize', 13,'BackgroundColor','blue',...
        'String',{'Method 1: Average fast scan lines + Mask PDA', ...
                  'Method 2: Method 1 + Edges & Outlier Removal'}, ...        
        'Callback',@methodChanged);

    % ==== OUTLIER REMOVAL PANEL (visible only for Method 2) ====
    hPanel_pixOutlierSettings = uipanel(hFig,'Title','Edge & Outlier Removal Settings','FontSize',15,...
        'Units','normalized','Position',[0.02 0.62 0.27 0.26],'Visible','off');

    % type segment within Outlier will be removed
    ha=annotation(hPanel_pixOutlierSettings,'textbox','String','Remove outliers within:','FontSize',13,...
        'Units','normalized','Position',[0.02 0.82 0.96 0.12],'HorizontalAlignment','left','VerticalAlignment','middle','EdgeColor','none'); %#ok<*NASGU>
    hb=uicontrol(hPanel_pixOutlierSettings,'Style','popupmenu', ...
        'String',{'Single segments', ...
                  'Connected segments of the same fast line', ...
                  'Entire section-setpoint'}, ...
        'BackgroundColor','blue',...
        'FontSize',13,'Units','normalized','Position',[0.05 0.72 0.9 0.11], ...
        'Callback',@segmentType);
    % Outlier Removal Method
    hc=annotation(hPanel_pixOutlierSettings,'textbox','String','Method Outlier Removal:','FontSize',13,...
        'Units','normalized','Position',[0.02 0.53 0.96 0.12],'HorizontalAlignment','left','VerticalAlignment','middle','EdgeColor','none');
    hd=uicontrol(hPanel_pixOutlierSettings,'Style','popupmenu', ...
        'String',{'No outlier removal', ...
                  'Percentile (outliers > 99°)', ...
                  'Median Absolute Deviation (outliers > 3*MAD)'},...               % Compares each data point to the median of the dataset using Median Absolute Deviation (MAD)
        'BackgroundColor','blue',...
        'FontSize',13,'Units','normalized','Position',[0.05 0.43 0.9 0.11], ...
        'Callback',@outlierMethod);
    % PIX settings
    he=annotation(hPanel_pixOutlierSettings,'textbox','String','Pixel parameters (for both segment''s borders):','FontSize',13,...
        'Units','normalized','Position',[0.02 0.24 0.96 0.13],'HorizontalAlignment','left','VerticalAlignment','middle','EdgeColor','none');
    labels = {'Max # of pixels to remove for border:', 'Step size:'};
    ypos = [0.12, 0.01];
    for i = 1:2    
        uicontrol(hPanel_pixOutlierSettings,'Style','text','String',labels{i}, ...
            'FontSize',13,'Units','normalized','Position',[0.1 ypos(i) 0.9 0.12],'HorizontalAlignment','left');
        hPix(i) = uicontrol(hPanel_pixOutlierSettings,'Style','edit','String',num2str(pixData(i)),'BackgroundColor','blue', ...
            'FontSize',13,'Units','normalized','Position',[0.75 ypos(i) 0.15 0.12], 'Callback',@pixChanged);
    end

    % ==== AXES FOR RESULT PLOT ====
    hAx_plot = axes('Parent',hFig,'Units','normalized', ...
               'Position',[0.4 0.10 0.55 0.8]);
    
    title(hAx_plot,'Resulting Lateral Forces will appear here');

    % ==== AXES FOR PIXEL TREND ====
    pnl_pixTrend = uipanel('Parent',hFig, ...
    'Units','normalized','Position',[0.03 0.02 0.31 0.43],'Visible','off');
    hAx_pixTrend   = axes('Parent', pnl_pixTrend);
        
    % ==== AXES FOR ERROR, FIT AND/OR EXPERIMENTAL PLOT (overlapped with pixelTrend) ====
    pnl_fitResults = uipanel('Parent',hFig, ...
    'Units','normalized','Position',[0.03 0.02 0.31 0.43],'Visible','off');
    hAx_fitResults = axes('Parent', pnl_fitResults);


    % ==== PLOT, COMPUTE AND STOP BUTTON ====
    btnRun=uicontrol(hFig,'Style','pushbutton','String','Run the selected method', ...
        'FontSize',12,'Units','normalized','Position',[0.055 0.57 0.2 0.04],'Callback',@computeMethod);
    % button to update plots. This is for method 2. At first is disabled until the method 2 is computed
    btnUpPlot=uicontrol(hFig,'Style','pushbutton','String','Click on FC trend and update the plots', ...
        'FontSize',12,'Units','normalized','Position',[0.055 0.52 0.2 0.04],'Callback',@computePlot,'Enable','off'); 
    btnStop=uicontrol(hFig, 'Style', 'pushbutton','String', 'Terminate',...
        'FontSize',12, 'Units', 'normalized','Position', [0.055 0.47 0.2 0.04],'Callback', @(src,evt) uiresume(hFig),'Enable','off');

    % ---- CALLBACK DEFINITIONS ----
    function methodChanged(~,~)
        method = get(hMethod,'Value');
        if method == 2
            set(hPanel_pixOutlierSettings,'Visible','on');
        else
            set(hPanel_pixOutlierSettings,'Visible','off');
        end
    end

    function segmentType(src,~)
        segmentProcess = get(src,'Value');
        switch segmentProcess
            case 1, segmentType_text='SingleSegments';
            case 2, segmentType_text='ConnectedSegment';
            case 3, segmentType_text='EntireSection';
        end
    end

    function outlierMethod(src,~)
        outlierRemovalMethod = get(src,'Value');
        switch outlierRemovalMethod
            case 1, outlierRemovalMethod_text='none';
            case 2, outlierRemovalMethod_text='percentile';
            case 3, outlierRemovalMethod_text='MAD';
        end
    end

    function pixChanged(~,~)
        for j = 1:2
            pixData(j) = str2double(get(hPix(j),'String'));
        end
    end

    % ==== COMPUTE & PLOT ====
    function computePlot(src,~)
        pnl_pixTrend.Visible="on";
        pnl_fitResults.Visible="off";
        % select on the plot FC trend to update the fitting/median plot and resulting force data
        % extract first the data
        data = guidata(hFig);
        if isfield(data, 'results_allPix')
            results_allPix=data.results_allPix;
            fc_allPix=data.fc_allPix;
            pixArray=data.pixArray;
        end
        idx_x=selectRangeGInput(1,1,hAx_pixTrend);
        % remove the previous selected pix
        currScatter=findobj(hAx_pixTrend,"Type","Scatter");
        if ~isempty(currScatter)
            delete(currScatter)
        end
        scatter(hAx_pixTrend,pixArray(idx_x),fc_allPix(idx_x),300,'pentagram','filled', 'MarkerFaceColor', 'red','DisplayName','Selected pix size');    
        pnl_pixTrend.Visible="off";
        pnl_fitResults.Visible="on";
        cla(hAx_plot); cla(hAx_fitResults);
        % once clicked, show the fit plot and resulting force at that selected pix.
        % NOTE: the selected pix also return the definitive result. Just click terminate button and it is obtained
        results=results_allPix(idx_x);
        plotFitResults(results,idxSection,hAx_fitResults);       
        % plot the resulting lateral force
        textAnomaly="";
        if results.flagAnomalyData, textAnomaly=" (ANOMALY IN CALC FRICTION CALC)"; end
        titleData1={sprintf(" Lateral Force - Method %s%s",results.method,textAnomaly);...
            sprintf("Processed on %s - Outlier Removal Method: %s",results.typeSegment,results.typeOutlierMethod)};
        force_best=results.force_data;
        % since it takes a while, block everything
        hFig = ancestor(src,'figure');     % get figure
        allUI = findall(hFig,'Type','uicontrol');  % all controls   
        % Save original states
        origEnable = get(allUI,'Enable');
        % Disable all controls
        set(allUI,'Enable','off');        
        % generate the fig and extract the only existing axes
        fig_tmp=showData(idxMon,false,force_best,titleData1,"","",'saveFig',false,'labelBar','Force [nN]');
        pause(0.1)
        transferTempPlot(fig_tmp, hAx_plot);
        tb = axtoolbar(hAx_plot, {'zoomin','zoomout','pan','restoreview','datacursor'});
        delete(fig_tmp)   
        % Restore controls
        set(allUI,{'Enable'},origEnable);
        btnStop.Enable="on";
    end

    function computeMethod(src,~)
    % This button performs the FULL method computation. Heavy computation happens here.
        clear results
        hFig = ancestor(src,'figure');     % get figure
        allUI = findall(hFig,'Type','uicontrol');  % all controls   
        % Save original states
        origEnable = get(allUI,'Enable');
        % Disable all controls
        set(allUI,'Enable','off');
        % Change appearance of the pressed button
        set(src,'BackgroundColor','green'); % green
        drawnow;  % force refresh
        % SHOW THE RESULTS OF THE METHOD.
        % remove all previous plots
        cla(hAx_plot), cla(hAx_fitResults), cla(hAx_pixTrend)
        try
            % Run your calculation
            if method == 1
                pnl_pixTrend.Visible="off";
                pnl_fitResults.Visible="on";
                results = computeFriction_method1(vertForce,force, idxSection);               
                plotFitResults(results,idxSection,hAx_fitResults);       
                textAnomaly="";
                if results.flagAnomalyData
                    titleData1= {sprintf("Lateral Force - Method %s",results.method);"ANOMALY IN CALC FRICTION CALC)"};
                else
                    titleData1=sprintf("Lateral Force - Method %s",results.method);
                end                                 
                force_best=results.force_data;
                % generate the fig and extract the only existing axes
                fig_tmp=showData(idxMon,false,force_best,titleData1,"","",'saveFig',false,'labelBar','Force [nN]');
                pause(0.1)
                transferTempPlot(fig_tmp, hAx_plot);
                tb = axtoolbar(hAx_plot, {'zoomin','zoomout','pan','restoreview','datacursor'});
                delete(fig_tmp)              
            else
                pnl_fitResults.Visible="off";
                pnl_pixTrend.Visible="on";
                results_allPix = computeFriction_method2(vertForce,force,mask,idxSection,pixData,segmentProcess,segmentType_text,outlierRemovalMethod,outlierRemovalMethod_text);
                % after obtained the results, prepare the friction coeffcient trend data. Better store the struct inside the main figure.
                fc_allPix=zeros(1,length(results_allPix));
                for pix=1:length(results_allPix)
                    res_allPix=[results_allPix(pix).resFit];
                    fc_allPix(pix)=res_allPix.fc;
                end                
                pixArray=[results_allPix.pixelReductionSize];
                % plot all the frictions coefficient in function of pixel size and show also the point in
                % which some sections has less elements than the minimum      
                hold(hAx_pixTrend,'on')
                plot(hAx_pixTrend,pixArray, fc_allPix, 'x-','LineWidth',2,'MarkerSize',10,'Color','blue','DisplayName','FC post Edges/Outliers removal');
                grid(hAx_pixTrend,"on")
                xlabel(hAx_pixTrend,'Pixel size','fontsize',12); ylabel(hAx_pixTrend,'Friction coefficient','fontsize',12);
                titleText='FrictionCoefficient Trend VS pixel reduction';
                title(hAx_pixTrend,titleText,'FontSize',14);                      
                ylim(hAx_pixTrend,"padded"), xlim(hAx_pixTrend,"padded")
                leg=legend(hAx_pixTrend,'show');
                leg.FontSize=9; leg.Location="southeast"; 
                % plot one or more line indicating at which FrictionCoeff the flagAnomaly occured
                % ==> when section-LF has few elements (< accepted number min number of values, very common for large pix size)
                % ==> when fc value is no-sense
                flagAnomalies=[results_allPix.flagAnomalyData];
                pixWithAnomalies=pixArray(flagAnomalies);                
                if ~isempty(pixWithAnomalies)
                    for m=1:length(pixWithAnomalies)
                        numElemXsection=results_allPix([results_allPix.pixelReductionSize]==pixWithAnomalies(m)).numMedianElementsInEachSection;
                        arrayText=sprintf('%d ',flip(numElemXsection));
                        % flip because originally high setpoint from left                
                        displayName=sprintf('Anomaly - #ElemXsection: [%s]',arrayText);
                        xline(hAx_pixTrend,pixWithAnomalies(m),LineWidth=2,Color='red',DisplayName=displayName)
                    end
                end
                % keep "global" the variable results of all pixels
                data = guidata(hFig);
                data.results_allPix=results_allPix;
                data.fc_allPix=fc_allPix;
                data.pixArray=pixArray;
                guidata(hFig, data);
            end
        % If error happens, restore UI before throwing error    
        catch ME            
            set(allUI,{'Enable'},origEnable);
            set(src,'BackgroundColor',[0.1294 0.1294 0.1294]); % default gray
            rethrow(ME);
        end

        % COMPUTATION IS TERMINATED
        % Restore controls
        set(allUI,{'Enable'},origEnable);
        % Restore button color
        set(src,'BackgroundColor',[0.1294 0.1294 0.1294]);
        if method == 1
            btnStop.Enable="on";
            btnUpPlot.Enable="off";
        else
            btnStop.Enable="off";
            btnUpPlot.Enable="on";
        end
    end

    % END PART OF THE CODE. TERMINATE WHEN CLICKED ON TERMINATE. Block interface and save figures
    uiwait(hFig);
    btnStop.String="Saving Figures";
    allUI = findall(hFig,'Type','uicontrol');  % all controls   
    % Save original states
    origEnable = get(allUI,'Enable');
    % Disable all controls
    set(allUI,'Enable','off');
       
    fileName="resultA3_friction_4_resultingLateralForce";
    exportAndSaveAxes(hAx_plot,idxMon,filePathResultsFriction,fileName)
    fileName="resultA3_friction_5_fit_exp_curves_PLots";
    exportAndSaveAxes(hAx_fitResults,idxMon,filePathResultsFriction,fileName)
    if ~strcmp(results.method,"1")
        fileName="resultA3_friction_6_pixReductionTrend";
        exportAndSaveAxes(hAx_pixTrend,idxMon,filePathResultsFriction,fileName)
    end
    close(hFig);
end


%%%% COMMON FUNCTIONS %%%%

function transferTempPlot(fig_tmp, hAx_plot)
    ax_tmp = findobj(fig_tmp, 'Type', 'axes');
    ax_tmp = ax_tmp(1);
    cla(hAx_plot);  % clear old plot
    % Copy plot contents on the axis
    copyobj(allchild(ax_tmp), hAx_plot);
    % Copy aesthetics
    title(hAx_plot, ax_tmp.Title.String);
    xlabel(hAx_plot, ax_tmp.XLabel.String);
    ylabel(hAx_plot, ax_tmp.YLabel.String);
    xlim(hAx_plot, ax_tmp.XLim);
    ylim(hAx_plot, ax_tmp.YLim);
    % --- VERY IMPORTANT: preserve axis orientation ---
    set(hAx_plot, 'YDir', ax_tmp.YDir);   % reverse or normal
    set(hAx_plot, 'XDir', ax_tmp.XDir);    
    axis(hAx_plot, 'image');
    % ---- COLORBAR COPY ----
    cb_tmp = findobj(fig_tmp, 'Type', 'Colorbar');

    if ~isempty(cb_tmp)
        cb_tmp = cb_tmp(1);  % usually only one
        % Create a new colorbar attached to hAx_plot
        cb_new = colorbar(hAx_plot);
        % Copy label
        cb_new.Label.String = cb_tmp.Label.String;
        cb_new.Label.FontSize = cb_tmp.Label.FontSize;
        % Copy ticks
        cb_new.Ticks = cb_tmp.Ticks;
        cb_new.TickLabels = cb_tmp.TickLabels;
        % Copy limits
        cb_new.Limits = cb_tmp.Limits;
        % Copy location (e.g. 'eastoutside', 'southoutside')
        cb_new.Location = cb_tmp.Location;
        % Match colormap
        colormap(hAx_plot, colormap(fig_tmp));
    end
end

function [x_avg,y_avg]=calcMedian_VF_LF(x,y) 
% the function remove nan values for the given fast scan line and then average using median
% INPUT: the data as entire matrix with both fast and slow scan lines
    % init
    x_avg = zeros(1, size(x,2));
    y_avg = zeros(1, size(y,2));
    for i=1:size(x,2)
        tmp1 = x(:,i);
        tmp2 = y(:,i);
        x_avg(i) = median(tmp1,'omitnan');
        y_avg(i) = median(tmp2,'omitnan');        
    end
end

function [flag,numElemSections]=checkNaNelements(vectorAvg,idxSection)
% In case an entire fast scan line is NaN, the resulting averaged element for that fast scan line will 
% be NaN. For safety, count how many non nan elements are left for each section.
% If less than 10% of tot avg elements for section, flag!    
    numElemSections=zeros(1,size(idxSection,2));
    minAcceptableElements=numElemSections;
    for i=1:size(idxSection,2)
        minAcceptableElements(i)=round(10/100*(idxSection(2,i)-idxSection(1,i)+1));
        numElemSections(i)=nnz(~isnan(vectorAvg(idxSection(1,i):idxSection(2,i))));
    end                

    % if a section has number of nan elements higher than the previous updated array
    if numElemSections < minAcceptableElements
        flag=true;
    else
        flag=false;
    end
end

function [pfit,xData,yData]=fittingForceSetpoint(x,y)
% FITTING VERTICAL VS LATERAL DATA (NanoNewton) 
% NOTE --------- THE FUNCTION WORKS ONLY IF MULTIPLE SECTION ARE PROVIDED ----------
% Input:    x and y are the data to fit or the fitted curve in case of plot only.
% Output:   pfit: fitting results.
%           xData,yData: cleared data used for fitting
    % suppress the warning for the fitting
    id='curvefit:fit:iterationLimitReached';
    warning('off',id)
    % Linear fitting
    if fitting
        % prepare the data
        [xData, yData] = prepareCurveData(x,y);
        % Set up fittype and options.
        ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares'); opts.Robust = 'LAR';
        % Fit model to data.
        fitresult = fit( xData, yData, ft, opts);       
        pfit(1)=fitresult.p1; % slope
        pfit(2)=fitresult.p2; % offset
    end    
end   

function plotFitResults(resultsMethod,idxSection,ax)
% if multiple sections, then plot the fitting among section showing both data and fitting curve. Note: friction coeff as slope between the different sections
% NOTE: not inside method1 function because it needs the axis where to show the fitting curve                    
    % clear old plot
    cla(ax)
    % separate the data into sections using idxSection
    numSections=size(idxSection,2);
    LF_sections_avg=zeros(1,numSections);
    LF_sections_std=zeros(1,numSections);
    VF_sections_avg=zeros(1,numSections);
    VF_sections_std=zeros(1,numSections);
    VF=resultsMethod.vertForce_median_vector;
    LF=resultsMethod.force_median_vector;    
    hold(ax,"on")
    if numSections==1
        titleAX=sprintf("Results method %s - fc = %.3f",resultsMethod.method,resultsMethod.resFit.fc);    % method 1 single section
    else
        if resultsMethod.resFit.offset < 0
            signM='-';
        else
            signM='+';
        end
        titleAX=sprintf("Results method %s - fitCurve = %.3f*x %s %0.3f",resultsMethod.method,resultsMethod.resFit.fc,signM,abs(resultsMethod.resFit.offset));        
    end
    legend(ax), xlabel(ax,'Vertical Forces [nN]','FontSize',12), ylabel(ax,'Lateral Forces [nN]','FontSize',12)
    title(ax,titleAX,'FontSize',15)
    for i=1:numSections
        startIdx=idxSection(1,i);
        lastIdx=idxSection(2,i);
        % extract the lateral and vertical deflection of the single section and plot
        LF_section=LF(startIdx:lastIdx);
        VF_section=VF(startIdx:lastIdx);       
        plot(ax,VF,LF,'*','Color',globalColor(i),'MarkerSize',20,'DisplayName',sprintf('ExpData Section %d',i))
        % calc the avg an std of the entire block (vector portion that represent the original matrix)
        LF_sections_avg(i)=mean(LF_section); 
        LF_sections_std(i)=std(LF_section);
        VF_sections_avg(i)=mean(VF_section);
        VF_sections_std(i)=std(VF_section);
    end
    xlim(ax,"padded"),ylim(ax,"padded")
    % flip because the high setpoint is on the left
    LF_sections_avg=flip(LF_sections_avg);
    LF_sections_std=flip(LF_sections_std);
    VF_sections_avg=flip(VF_sections_avg);
    VF_sections_std=flip(VF_sections_std);
    errorbar(ax,VF_sections_avg,LF_sections_avg,LF_sections_std,LF_sections_std,VF_sections_std,VF_sections_std, ...
        'Linewidth',1.3,'capsize',15,'Color',globalColor(2),...
        'markerFaceColor',globalColor(2),'markerEdgeColor',globalColor(2),'MarkerSize',10,...
        'DisplayName','Statistical results (mean-std)');
    if numSections>1
        slope=resultsMethod.resFit(1);
        offset=resultsMethod.resFit(2);
        % in case of multiple section, show the trend among the setpoint. Useless if only one section
        xfit=linspace(min(VF),max(VF),100);
        yfit=xfit*slope+offset;
        plot(ax,xfit, yfit, '-.','color',globalColor(1),'DisplayName','Fitted curve','LineWidth',2);    
    end
    hold(ax,"off")    
end

function exportAndSaveAxes(hAx_plot,idxMon,dirName,fileName)
    % Create new figure
    figNew = figure("Visible","off");
    % Create new axes
    axNew = axes('Parent', figNew);
    % Copy plot children
    copyobj(allchild(hAx_plot), axNew);
    % Copy axes properties
    axNew.XLim = hAx_plot.XLim;
    axNew.YLim = hAx_plot.YLim;
    axNew.YDir = hAx_plot.YDir;
    axNew.XDir = hAx_plot.XDir;
    axNew.DataAspectRatio = hAx_plot.DataAspectRatio;
    title(axNew, hAx_plot.Title.String,'FontSize',20);
    xlabel(axNew, hAx_plot.XLabel.String,'FontSize',15);
    ylabel(axNew, hAx_plot.YLabel.String,'FontSize',15);
    % Copy colorbar if present
    cb = hAx_plot.Colorbar;
    if ~isempty(cb)
        cb = cb(1);
        cbNew = colorbar(axNew);
        cbNew.Label.String = cb.Label.String;
        cbNew.Ticks = cb.Ticks;
        cbNew.TickLabels = cb.TickLabels;
        cbNew.Limits = cb.Limits;
        cbNew.Location = cb.Location;
    end
    objInSecondMonitor(figNew,idxMon)
    saveFigures_FigAndTiff(figNew,dirName,fileName)
end

function data_filtered = remove_Edges_Outlier(data,data_mask,pix,segmentProcess,outlierRemovalMethod) 
%%%%%%%% OUTLIER REMOVAL FOR THE GIVEN FAST SCAN LINE %%%%%%%%
% Delete edges data by searching non-zero data area (segmentLineDataFilt) and put NaN in both edges of the segment
% INPUT:    - data: if segmentProcess=1/2, single fast scan line. If segmentProcess=3, section (matrix)
%           - data_mask: since the data has been previously cleared, there may be areas that can be confused as edges.
%                        Therefore, instead of using directly the data, use the mask to identify the 0/1 changes as true BK/FR changes, therefore, true edges
%           - pix: number of pixels to be removed at both edges of a segment.
%           - segmentProcess: mode of outlier removal:
%               0: No outlier removal.
%               1: Apply outlier removal to each segment after pixel reduction.
%               2: Apply outlier removal to one large connected segment after pixel reduction.
% OUTPUT:   - line_filtered : line without edges and outliers.
%                             Note: the output/filtered line has same size as the input line
% for each element:
%   1) if ~= 0 ==> DETECTION NEW SEGMENT 
%           ==> update StartPos
%           ==> find the end of the segment (first zero value)
%           ==> build the segment and remove outliers
%           ==> skip to end+1 element which is zero and detect a new segment
%   2) if == 0 ==> nothing happens, skip to next iteration    

% check the type of the provided data
    if ((segmentProcess==1 || segmentProcess==2) && ~isvector(data)) || (segmentProcess==3 && isvector(data))
        error("The type of the data does not match with the type of segment")
    end

    
    % trasform the section into vector
    if ismatrix(data)
        data_vector=reshape(data,[],1);
        mask_vector=reshape(data_mask,[],1);
        % track the border of each fast scan line so also the borders will be subjected to removal
        idxBorders=1:size(data,1):length(data_vector);
        idxCurrentFastLine=1;
    else
        data_vector=data;
        mask_vector=data_mask;
    end

    % init
    SegPosList_StartPos = [];
    SegPosList_EndPos = [];
    ConnectedSegment = [];
    Cnt = 1;
    data_filtered_vector = data_vector;
    processSingleSegment=true; i=1;
    while processSingleSegment
    % DETECTION NEW SEGMENT AS BACKGROUND
        if mask_vector(i) == 0
            StartPos = i;   
            % find the idx of the only first zero element from startpos idx. Then the result is the idx of the nonzero
            % element just before the previously found idx of zero element
            EndPos=StartPos+find(mask_vector(StartPos:end)==1,1)-2;
            % in case of section, to avoid that the right border of i-th line is merged with the left border of i+1-th line and interpreted as segment,
            % additional check. If so, treat them separately as two segment
            if segmentProcess==3 && idxCurrentFastLine<=length(idxBorders)
                if StartPos<idxBorders(idxCurrentFastLine) && EndPos>idxBorders(idxCurrentFastLine)
                    EndPos=idxBorders(idxCurrentFastLine)-1;
                elseif any(StartPos==idxBorders)
                    idxCurrentFastLine=idxCurrentFastLine+1;
                end
            end
            % the previous operation will return NaN when the last element is non-zero, thus manage it
            if isempty(EndPos)
                EndPos=length(mask_vector);
                processSingleSegment=false;                
            end
            % Extract the segment from the data (note: it is BACKGROUND data)
            Segment = data_vector(StartPos:EndPos);
            % if the length of segment is less than 4, it is very likely to be a random artefact. 
            % Also, not really realiable when filloutliers is used because few sample
            % remove such values and put 0
            if length(Segment)<4
                data_filtered_vector(StartPos:EndPos) = nan;
            else
                % save the indexes of start and end segment
                SegPosList_StartPos(Cnt) = StartPos;                    %#ok<AGROW>
                SegPosList_EndPos(Cnt) = EndPos;                        %#ok<AGROW>
                Cnt = Cnt + 1;
                % if first iteration, do nothing and use as reference
                if pix > 0
                    % if the half-segment is longer than pix window, then reset first and last part with size = pix
                    % in order to remove edges in both sides (the tip encounters the edges of a single PDA crystal 
                    % twice: trace and in retrace)
                    if ceil(length(Segment)/2) >=pix
                        Segment(1:pix) = nan;                
                        Segment(end-pix+1:end) = nan;
                    else
                    % if the segment is shorter, then reset entire segment
                        Segment(:) = nan;
                    end
                end                
                % PROCESS THE SEGMENT IN ONE OF THREE POSSIBLE WAYS (Detect and replace outliers in data with NaN) 
                % way 1: do nothing. Dont remove outliers. They may be already removed by pixel reduction.
                % way 2: Median findmethod is default: Outliers are defined as elements more than three scaled MAD from the median (robust
                % when there are lot of data, but sometime aggressive and not suitable when BK contains "more" type of BK
                % way 3; remove 99 percentile (NOTE: since single segments already contains few elements, no good to use percentile threshold method)
                if segmentProcess == 1
                    if outlierRemovalMethod == 2
                        Segment = filloutliers(Segment,nan,'percentiles',[0 99]);
                    elseif outlierRemovalMethod == 3
                        Segment = filloutliers(Segment,nan);
                    end
                    data_filtered_vector(StartPos:EndPos) = Segment;
                else
                % method 2 or 3: attach the current segment to the previous found one to build a single large connected segment
                    ConnectedSegment = [ConnectedSegment; Segment];          %#ok<AGROW>
                end   
            end
            % skip to find the next segment
            i=EndPos+1;
        else
            % if the last element=1, break the while loop 
            if i>=length(mask_vector)
                break
            end    
            % if the element=1 (FR), do nothing and move to the next element           
            if segmentProcess==3 && (any(i==(idxBorders)))
                idxCurrentFastLine=idxCurrentFastLine+1;
            end
            i=i+1;
        end
    end
    % Process one large connected segment. Note that if mode = 2 or 3, connected segment lacks of resetted edges of the previous part.
    % Here, ConnectedSegment is just the concatenation of each nonFiltered segments previously found.
    % in this way, the function filloutliers has more data to process so the result should be more consistent. Mehtod of finding outliers is
    % with percentile threshold. Exclude 99 Percentile
    if segmentProcess == 2 || segmentProcess == 3
        if outlierRemovalMethod==2
            ConnectedSegment = filloutliers(ConnectedSegment, nan,'percentiles',[0 99]);
        elseif outlierRemovalMethod==3
            ConnectedSegment = filloutliers(ConnectedSegment, nan);
        end
        % substitute the pieces of connectedSegment with the corresponding part of original fast scan line
        Cnt2 = 1;
        for i=1:length(SegPosList_StartPos)
            % coincide with the number of elements of original segment
            Len = SegPosList_EndPos(i) - SegPosList_StartPos(i) +1;
            data_filtered_vector(SegPosList_StartPos(i):SegPosList_EndPos(i)) = ConnectedSegment(Cnt2:Cnt2+Len-1);
            % start with the next segment
            Cnt2 = Cnt2 + Len;  
        end
    end
    % in case of section data, restore the size
    if ismatrix(data)
        data_filtered=reshape(data_filtered_vector,size(data));
    else
        data_filtered=data_filtered_vector;
    end
end

%%%------- METHOD 1 -------%%%
function resultsMethod1 = computeFriction_method1(vertForce,force,idxSection)
% masking lateral and vertical data using AFM_height_IO to ignore PDA regions
    flagAnomalyFriction=false;
    if size(idxSection,2)==1
        flagSingleSection=true;
    else
        flagSingleSection=false;
    end
    % clean and obtain the averaged vector (fast scan line vector => single value
    [vertForce_med, force_med] = calcMedian_VF_LF(vertForce,force);
    % Check for NaN elements along the vector 
    [flag,numElemSections]=checkNaNelements(force_med,idxSection);
    if flag
        flagAnomalyFriction=true;
        warndlg(sprintf('Aware! In some section there are few elements left\nfor fitting (%s). Adjust the mask or remove less data.',strjoin(string(numElemSections),',')));
    end

    % Fit or compute mean friction
    if ~flagSingleSection
        res = fittingForceSetpoint(vertForce_med, force_med);
        resFit.fc=res(1);
        resFit.offset = res(2);
    else
        % if single section, fitting is useless, therefore friction as average. Not remove nan from vectors to preserve idxSection
        avg_fc = mean(force_med,'omitnan') / mean(vertForce_med,'omitnan');
        resFit.fc = avg_fc;
        resFit.offset = nan;
    end

    %%%%%%%% SECOND CONSTRAINT TO STOP THE PROCESS %%%%%%%%%
    % here apparently everything is ok and there is enough data to continue, but it could happen that the fitting yield anomalous slope.
    % 1) slope higher than 0.95 has no sense
    if avg_fc > 0.95 || avg_fc < 0
        flagAnomalyFriction = true;
    end
    % === Outputs to support GUI plotting ===
    resultsMethod1 = struct( ...
                        'method',"1", ...
                        'pixelReductionSize',0,...
                        'typeSegment',[],...
                        'typeOutlierMethod',[],...
                        'flagAnomalyData',flagAnomalyFriction,...
                        'numMedianElementsInEachSection',numElemSections,...
                        'resFit', resFit, ...
                        'force_median_vector', force_med, ...
                        'vertForce_median_vector', vertForce_med, ...
                        'force_data', force, ...
                        'vertForce_data', vertForce);
end

%%%------- METHOD 2 -------%%%
function results_final = computeFriction_method2(vertForce,force,mask,idxSection,pixData,segmentProcess,segmentType_text,outlierRemovalMethod,outlierRemovalMethod_text)
% The second method removes outliers considered as spike signals in correspondence with the PDA crystal's edges using in-built matlab function.
% Moreover, PIXEL REDUCTION is applied to make more robust the statistical calculation prior the outliers removal
% once found a segment (single background region between two PDA regions), depending on the window/pixel
% size, the edges will be "brutally" removed by zeroing (0:PDA-1:BK)
%   method 2a) INPUT: BK+FR  ==>  method 2 + REMOVAL OF OUTLIERS on single segments found in each single fast scan line
%   method 2b) INPUT: BK+FR  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments (multiple single segment attached togheter before
%                                   outliers removal for better statistics) for each single fast scan line
%   method 2c) INPUT: BK+FR  ==>  method 2 + REMOVAL OF OUTLIERS on connected segments of each entire section (in correspondence of same
%                                   setpoint region) ==> multiple segments of multiple fast scan lines all attached togheter

    % show a dialog box indicating the index of fast scan line along slow direction and which pixel size is processing
    wb=waitbar(0/size(force,2),sprintf('Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',segmentProcess,0,pixData(1),0,0),...
            'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);               
    
    numSections=size(idxSection,2);
    % start the counter to store the results of each pixel in the struct
    Cnt=1;
    % array containing the number of pixels for both borders of a segment that will be removed
    arrayPixSizes=0:pixData(2):pixData(1);    
    % init where store all the results, in order to extract the desired one later
    resultsMethod2_allPIX=struct( ...
                        'method',[], ...
                        'pixelReductionSize',[],...
                        'typeSegment',[],...
                        'typeOutlierMethod',[],...
                        'flagAnomalyData',[],...
                        'numMedianElementsInEachSection',[],...
                        'resFit', [], ...
                        'force_median_vector', [], ...
                        'vertForce_median_vector', [], ...
                        'force_data', [], ...
                        'vertForce_data', [] );

    % start the pixel reduction
    for pix = arrayPixSizes        
        % update dialog box and check if cancel is clicked
        if(exist('wb','var'))
            %if cancel is clicked, stop and delete dialog
            if getappdata(wb,'canceling')
                error('Manually stopped the process')
            end
        end
        waitbar(pix/max(arrayPixSizes),wb,sprintf('Processing the Outliers Removal within %s\nCurrent pixel reduction size %d / %d',segmentType_text,pix,max(arrayPixSizes)));
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%% EDGES AND OUTLIERS REMOVAL %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % init matrix where to store the data after pixel and outliers removal
        force_final_pix = zeros(size(force));
        % copy and then put zeros according to the lateral force
        vertForce_final_pix = zeros(size(vertForce));
        % start the clearing
        % if method removal is on entire section-sameSetpoint, then extract the section and transform it into single vector
        if segmentProcess == 3
            for sec=1:numSections
                startIdx=idxSection(1,sec);
                endIdx=idxSection(2,sec);
                % extratct the data from the section
                force_section=force(:,startIdx:endIdx);
                vertForce_section=vertForce(:,startIdx:endIdx);
                mask_section=mask(:,startIdx:endIdx);
                % start the edge removal depending on the i-th pixel size and then remove outliers
                forceSectionTmp = remove_Edges_Outlier(force_section,mask_section,pix,segmentProcess,outlierRemovalMethod);                 
                force_final_pix(:,startIdx:endIdx)=forceSectionTmp;
                vertForceSectionTmp=vertForce_section;
                vertForceSectionTmp(isnan(forceSectionTmp))=nan;
                vertForce_final_pix(:,startIdx:endIdx)=vertForceSectionTmp;               
            end
        else
        % if method removal is on single segments or connected segments, extact i-th single fast scan line, regardless the section-setpoint
            for lineId=1:size(force,2)
                LF_Line=force(:,lineId);
                VF_Line=vertForce(:,lineId);
                mask_Line=mask(:,lineId);
                % start the edge removal depending on the i-th pixel size and then remove outliers
                LF_Line_cleared = remove_Edges_Outlier(LF_Line,mask_Line,pix,segmentProcess,outlierRemovalMethod); 
                VF_Line_cleared=VF_Line;
                VF_Line_cleared(isnan(LF_Line_cleared))=nan;
                force_final_pix(:,lineId)=LF_Line_cleared;
                vertForce_final_pix(:,lineId)=VF_Line_cleared;                
            end            
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%% CALC FRICTION COEFF (MEDIAN/FITTING) %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % from here, the proces is identical to method 1, therefore, call method 1 function instead of copy/paste
        resultsMethod2_pix = computeFriction_method1(vertForce_final_pix,force_final_pix,idxSection);
        % change some parameters since they are originally empty.
        resultsMethod2_pix.method="2";
        resultsMethod2_pix.pixelReductionSize = pix;
        resultsMethod2_pix.typeOutlierMethod = outlierRemovalMethod_text;
        resultsMethod2_pix.typeSegment = segmentType_text;
        % store the results of every pix size if no break occurred
        resultsMethod2_allPIX(Cnt)=resultsMethod2_pix;            
        % update counter
        Cnt = Cnt+1;
    end
    results_final=resultsMethod2_allPIX;
    % remove bar status
    if exist('wb','var')
        delete(wb)
    end 
end

