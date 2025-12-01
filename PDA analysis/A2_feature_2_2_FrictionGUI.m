% easy interface to see how different methods to extract friction affect the overall data
% INPUT:    - vertForce : vertical forces (mean trace-retrace)
%           - force     : lateral forces
%           - idxSection: indexes of the sections (matrix). (1,i) = startIdx, (2,i) = endIdx
%           - filePathResultsFriction : folder where to save plots and results
%
% OUTPUT:   - results

function results = A2_feature_2_2_FrictionGUI(vertForce,force,idxSection,idxMon,filePathResultsFriction)
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)    
    % Default values
    pixData = [20; 1; 20];
    fOutlierRemoval = 1;
    fOutlierRemoval_text = 'SingleSegmentsProcess';
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
    annotation(hFig,'textbox','Units','normalized','Position', [0.075 0.95 0.2 0.22], 'String', 'Select Method:','FontSize', 15, ...
                'HorizontalAlignment', 'center','VerticalAlignment', 'baseline','EdgeColor', 'green','FitBoxToText', 'on','BackgroundColor','red');

    hMethod = uicontrol(hFig,'Style','popupmenu', ...
        'Units','normalized','Position',[0.02 0.89 0.27 0.05], ...
        'FontSize', 15,'BackgroundColor','blue',...
        'String',{'1) Average fast scan lines + Mask PDA', ...
                  '2) Method 1 + Edges & Outlier Removal'}, ...        
        'Callback',@methodChanged);

    % ==== OUTLIER REMOVAL PANEL (visible only for Method 2) ====
    hPanel = uipanel(hFig,'Title','Edge & Outlier Removal Settings','FontSize',15,...
        'Units','normalized','Position',[0.02 0.65 0.27 0.25],'Visible','off');

    % Outlier Removal Type
    annotation(hPanel,'textbox','Units','normalized','Position',[0.025 0.83 0.95 0.1],'HorizontalAlignment','center','VerticalAlignment','middle',...
    'String','Remove outliers within:','FontSize',15,...
     'BackgroundColor','red');

    uicontrol(hPanel,'Style','popupmenu', ...
        'String',{'1) Single segments', ...
                  '2) Connected segment (entire fast line)', ...
                  '3) Whole section'}, ...
        'FontSize',15,'Units','normalized','Position',[0.025 0.68 0.95 0.15], ...
        'Callback',@outlierChanged);
    
    annotation(hPanel,'textbox','Units','normalized','Position',[0.025 0.55 0.95 0.1],'HorizontalAlignment','center','VerticalAlignment','middle',...
    'String','Pixel parameters (for both segment''s borders):','FontSize',15,...
     'BackgroundColor','red');

    % pixData inputs
    labels = {'Max # of pixels to remove for border:', 'Step size:', 'Min elements for fitting:'};
    ypos = [0.4, 0.25, 0.10];
    yposBox = [0.42, 0.265, 0.105];
    for i = 1:3
        annotation(hPanel,'textbox','String',labels{i}, ...
            'FontSize',15,'Units','normalized','Position',[0.025 ypos(i) 0.95 0.12],'HorizontalAlignment','left','VerticalAlignment','middle',...
            'BackgroundColor','red');
        hPix(i) = uicontrol(hPanel,'Style','edit','String',num2str(pixData(i)), ...
            'FontSize',15,'Units','normalized','Position',[0.75 yposBox(i) 0.15 0.12], 'Callback',@pixChanged);
    end

    % ==== AXES FOR RESULT PLOT ====
    hAx_plot = axes('Parent',hFig,'Units','normalized', ...
               'Position',[0.4 0.10 0.55 0.8]);
    title(hAx_plot,'Result will appear here');

    % ==== AXES FOR PIXEL TREND ====
    hAx_pixTrend = axes('Parent',hFig,'Units','normalized',...
        'Position',[0.025 0.1 0.35 0.4],'Visible','off');
    
    % ==== AXES FOR ERROR, FIT AND/OR EXPERIMENTAL PLOT (overlapped with pixelTrend) ====
    hAx_fitResults = axes('Parent',hFig,'Units','normalized',...
        'Position',[0.025 0.1 0.35 0.4],'Visible','off');

    % ==== PLOT, COMPUTE AND STOP BUTTON ====
    uicontrol(hFig,'Style','pushbutton','String','Run the selected method', ...
        'FontSize',10,'Units','normalized','Position',[0.01 0.58 0.12 0.04],'Callback',@computeMethod);
    % button to update plots. This is for method 2. At first is disabled until the method 2 is computed
    btnUpPlot=uicontrol(hFig,'Style','pushbutton','String','Update the plot', ...
        'FontSize',10,'Units','normalized','Position',[0.14 0.58 0.1 0.04],'Callback',@computePlot,'Enable','off'); 
    uicontrol(hFig, 'Style', 'pushbutton','String', 'Terminate',...
        'FontSize',10, 'Units', 'normalized','Position', [0.25 0.58 0.08 0.04],'Callback', @(src,evt) uiresume(hFig));

    % ---- CALLBACK DEFINITIONS ----
    function methodChanged(~,~)
        method = get(hMethod,'Value');
        if method == 2
            set(hPanel,'Visible','on');
        else
            set(hPanel,'Visible','off');
        end
    end

    function outlierChanged(src,~)
        fOutlierRemoval = get(src,'Value');
        switch fOutlierRemoval
            case 1, fOutlierRemoval_text='SingleSegments';
            case 2, fOutlierRemoval_text='ConnectedSegment';
            case 3, fOutlierRemoval_text='EntireSection';
        end
    end

    function pixChanged(~,~)
        for j = 1:3
            pixData(j) = str2double(get(hPix(j),'String'));
        end
    end

    % ==== COMPUTE & PLOT ====
    function computePlot(src,~)
        hFig = ancestor(src,'figure');     % get figure
        allUI = findall(hFig,'Type','uicontrol');  % all controls   
        % Save original states
        origEnable = get(allUI,'Enable');
        % Disable all controls
        set(allUI,'Enable','off');
        % Change appearance of the pressed button
        set(src,'BackgroundColor','green'); % green
        drawnow;  % force refresh
        
        try
            % ---------------------------------------------------------
            % --- your long computation here ---
            % ---------------------------------------------------------
            runYourMethod();   % or your code
            pause(0.2);        % (just example to show effect)

        catch ME
            % If error happens, restore UI before throwing error
            set(allUI,{'Enable'},origEnable);
            set(src,'BackgroundColor',[0.94 0.94 0.94]); % default gray
            rethrow(ME);
        end





        % Clear current axes
        cla(hAx_plot);
        guidata(hFig, results);
        if ~isempty(pixelTrend)
            plot(hAx_fitResults, pixelTrend, 'LineWidth', 2);
            title(hAx_fitResults, 'Pixel Trend');
            xlabel(hAx_fitResults,'Iteration');
            ylabel(hAx_fitResults,'Pixels removed');
        else
            title(hAx_fitResults, 'Pixel trend unavailable for Method 1');
        end  
        
        % COMPUTATION IS TERMINATED
        % Restore controls
        set(allUI,{'Enable'},origEnable);
        % Restore button color
        set(src,'BackgroundColor',[0.1294 0.1294 0.1294]);
    end

    function computeMethod(src,~)
    % This button performs the FULL method computation. Heavy computation happens here.
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
        cla(hAx_plot);
        cla(hAx_fitResults); 
        try
            % ---------------------------------------------------------
            % --- your long computation here ---
            % ---------------------------------------------------------
            % Run your calculation
            if method == 1
                set(btnUpPlot, 'Enable', 'off');
                hAx_pixTrend.Visible="off";
                hAx_fitResults.Visible="on";
                results = computeFriction_method1(vertForce,force, idxSection);               
                plotFitResults(results,idxSection,hAx_fitResults);       
            else
                hAx_fitResults.Visible="off";
                hAx_pixTrend.Visible="on";
                results_tmp = computeFriction_method2(vertForce,force,idxSection,pixData,fOutlierRemoval,fOutlierRemoval_text);
                
                % --- Store all results for future updates ---
                % definitiveRes.avg_fc      = results.resFit(1);
                % definitiveRes.slope       = results.resFit(2);
                % % definitiveRes.pixelTrend  = pixelTrend;      % optional
                % definitiveRes.extra       = results;
                
                % enables the button to update the axes when a new pix-fc is selected
                set(btnUpPlot, 'Enable', 'on'); 
            end
            
        catch ME
            % If error happens, restore UI before throwing error
            set(allUI,{'Enable'},origEnable);
            set(src,'BackgroundColor',[0.1294 0.1294 0.1294]); % default gray
            rethrow(ME);
        end

        textAnomaly="";
        if results.flagAnomalyData, textAnomaly=" (ANOMALY IN CALC FRICTION CALC)"; end
       
        if strcmp(results.method,"1")
            titleData1=sprintf(" Lateral Force - Method %s%s",results.method,textAnomaly);
        else
            titleData1={sprintf("Lateral Force - Method %s%s",results.method,textAnomaly);sprintf("Outliers removed within %s - Pixel reduction: %d",fOutlierRemoval_text,pixSelected)};
        end
        force_best=results.force_best;
        % generate the fig and extract the only existing axes
        fig_tmp=showData(idxMon,false,force_best,titleData1,"","",'saveFig',false,'labelBar','Force [nN]');
        pause(0.1)
        transferTempPlot(fig_tmp, hAx_plot);
        delete(fig_tmp)

        % COMPUTATION IS TERMINATED
        % Restore controls
        set(allUI,{'Enable'},origEnable);
        % Restore button color
        set(src,'BackgroundColor',[0.1294 0.1294 0.1294]);
    end

% END PART OF THE CODE. TERMINATE WHEN CLICKED ON TERMINATE. Block interface and save figures
    uiwait(hFig);
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

function plotFitResults(resultsMethod,idxSection,ax,varargin)
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
    VF=resultsMethod.vertForce_avg_best;
    LF=resultsMethod.force_avg_best;    
    hold(ax,"on")
    if ~isempty(varargin)
        titleAX=sprintf("Results method %s",resultsMethod.method);
    elseif numSections==1
        titleAX=sprintf("Results method 1 - fc = %.3f",resultsMethod.resFit(1));    % method 1 single section
    else
        if resultsMethod.resFit(2) < 0
            signM='-';
        else
            signM='+';
        end
        titleAX=sprintf("Results method 1 - fitCurve = %.3f*x %s %0.3f",resultsMethod.resFit(1),signM,abs(resultsMethod.resFit(2)));    % method 1 single section
    end
    legend(ax), xlabel(ax,'Vertical Forces [nN]','FontSize',12), ylabel(ax,'Lateral Forces [nN]','FontSize',12)
    title(ax,titleAX,'FontSize',15), xlim(ax,"padded"),ylim(ax,"padded")
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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% METHOD 1 %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function resultsMethod1 = computeFriction_method1(vertForce,force,idxSection)
% masking lateral and vertical data using AFM_height_IO to ignore PDA regions
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
        warndlg(sprintf('Aware! In some section there are few elements left\nfor fitting (%s). Adjust the mask or remove less data.',strjoin(string(numElemSections),',')));
    end
    % Remove NaN elements
    force_med_best      = force_med(~isnan(force_med));
    vertForce_med_best  = vertForce_med(~isnan(vertForce_med));
    % output, data for plotting
    vertForce_best = vertForce; 
    force_best     = force;

    % Fit or compute mean friction
    if ~flagSingleSection
        resFit = fittingForceSetpoint(vertForce_med_best, force_med_best);
        avg_fc = resFit(1);
    else
        % if single section, fitting is useless, therefore friction as average
        avg_fc = mean(force_med_best) / mean(vertForce_med_best);
        resFit(1) = avg_fc;
        resFit(2) = nan;
    end

    % Detect anomaly in friction coefficient value 
    if avg_fc > 0.95 || avg_fc < 0
        flagAnomalyFriction = true;
    else
        flagAnomalyFriction=false;
    end
    % === Outputs to support GUI plotting ===
    resultsMethod1 = struct( ...
                        'method',"1", ...
                        'pixParameters',[],...
                        'flagAnomalyData',flagAnomalyFriction,...
                        'resFit', resFit, ...
                        'force_avg_best', force_med_best, ...
                        'vertForce_avg_best', vertForce_med_best, ...
                        'force_best', force_best, ...
                        'vertForce_best', vertForce_best );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%% METHOD 2 %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function resultsMethod2 = computeFriction_method2(vertForce,force,idxSection,pixData,fOutlierRemoval,fOutlierRemoval_text)
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
    wb=waitbar(0/size(force_clear,2),sprintf('Processing the Outliers Removal Mode %d (pixel size %d / %d) \n\t Line %.0f Completeted  %2.1f %%',fOutlierRemoval,0,pixData(1),0,0),...
             'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);               
    



    if exist('wb','var')
        delete(wb)
    end 
end
