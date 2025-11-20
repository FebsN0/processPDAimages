% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function varargout=A2_feature_2_processLateralChannel(AFM_data,AFM_height_IO,alpha,idxMon,newFolder,mainPath,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    warning ('off','all'); 
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)       

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'FitOrderHVON_Lat';           defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'FitOrderHVOFF_Height';       defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'SeeMe';                      defaultVal = true;      addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'Normalization';              defaultVal = false;     addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'flagSingleSectionProcess';   defaultVal = false;     addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'idxSectionHVon';             defaultVal = [];        addOptional(p,argName,defaultVal);

    parse(p,varargin{:});
    % setup optional input
    if p.Results.SeeMe; SeeMe=1; else, SeeMe=0; end    
    if p.Results.Normalization, norm=1; unitDataLabel="" ;else, norm=0; unitDataLabel='Voltage [V]'; end
    unitDataLabel=string(unitDataLabel);
    if p.Results.flagSingleSectionProcess, flagSingleSectionProcess=1; else, flagSingleSectionProcess=0; end
    if ~isempty(p.Results.idxSectionHVon), idxSectionHVon=p.Results.idxSectionHVon; end  
    
    % for the first time or first section, request the max fitOrder
    if isempty(p.Results.FitOrderHVON_Lat)
        FitOrderHVON_Lat=chooseAccuracy("Choose the level of fit Order for lineXline baseline (i.e. Background) of AFM Lateral Deflection Data.");
    else
        FitOrderHVON_Lat=p.Results.FitOrderHVON_Lat;
    end
    if strcmp(FitOrderHVON_Lat,'Low'), limit=3; elseif strcmp(fitOrder,'Medium'), limit=6; else, limit=9; end       
    FitOrderHVOFF_Height=p.Results.FitOrderHVOFF_Height;
    clearvars argName defaultVal p varargin
    
    % select a single line manually to check the LD
    fLineChoose=figure; axFig=axes('Parent',fLineChoose); imagesc(AFM_height_IO), axis equal, xlim tight, ylim tight, objInSecondMonitor(fLineChoose,idxMon)
    uiwait(msgbox(sprintf('Select two points on the mask where analyze two different single fast scan lines'),''));
    idxLine=sort(selectRangeGInput(2,1,axFig));
    close(fLineChoose), clear fLineChoose
    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace   = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image);
    %Lateral_ReTrace = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'ReTrace')).AFM_image);
    vertical_Trace  = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image);    
    % Mask W to cut the PDA from the baseline fitting. Where there is PDA in corrispondece of the mask, then mask the
    % lateral deflection data. Basically, the goal is fitting using the glass which is know to be flat. 
    Lateral_Trace_BK_1_maskOnly= Lateral_Trace;
    Lateral_Trace_BK_1_maskOnly(AFM_height_IO==1)=NaN;
    
    % remove outliers line by line (single entire array with all the lines takes too much time) before plane
    % fitting using the masked AFM data containing only background. Change them with NaN       
    num_lines = size(Lateral_Trace_BK_1_maskOnly, 2);
    Lateral_Trace_BK_2_firstClear=zeros(size(Lateral_Trace_BK_1_maskOnly));
    countOutliers=0;
    for i=1:num_lines
        yData = Lateral_Trace_BK_1_maskOnly(:, i);
        [pos_outlier] = isoutlier(yData, 'gesd');
        while any(pos_outlier)
            countOutliers=countOutliers+length(find(pos_outlier));
            yData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        Lateral_Trace_BK_2_firstClear(:,i) = yData;
    end
    % plot. To better visual, change NaN into 0
    Lateral_Trace_BK_2_firstClear(isnan(Lateral_Trace_BK_2_firstClear))=0;
    titleData1='Raw Lateral Deflection - Trace'; titleData2={"Background";sprintf("Masked and %d Outliers removed",countOutliers)};
    nameFig='resultA2_9_RawLateralData_BackgroundNoOutliers';
    showData(idxMon,false,Lateral_Trace,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
        'extraData',{Lateral_Trace_BK_2_firstClear},'extraTitles',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
    pause(1)
    
    % check distribution of the LD data
    Lateral_Trace_masked_FRonly = Lateral_Trace;
    Lateral_Trace_masked_FRonly(AFM_height_IO==0)=NaN;
    % organize the data to show in figures
    DataXdistribution= {Lateral_Trace_BK_1_maskOnly,'Raw BK'; ...
                        Lateral_Trace_masked_FRonly,'Raw FR'};
    DataXSingleLine={Lateral_Trace,AFM_height_IO}; 
    clear Lateral_Trace_masked_FRonly countOutliers titleData* nameFig
    % show LD value distribution of the entire matrix
    figDistr=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution);
    % show LD of a single fast scan line (idx manually selected previously)
    figSingleLine=plotSingleLineCheck(idxMon,DataXSingleLine,idxLine);

    % rechange to NaN
    Lateral_Trace_BK_2_firstClear(Lateral_Trace_BK_2_firstClear==0)=NaN;    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% PLANE FITTING ON LATERAL DEFLECTION BACKGROUND (masked LAT image) %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [~,correction_plane,metricsBestPlaneFit]=planeFitting_N_Order(Lateral_Trace_BK_2_firstClear,limit);
    varargout{2}=metricsBestPlaneFit;
    % correct the raw original data by applyting the correction_plane
    Lateral_Trace_corrPlane = Lateral_Trace - correction_plane;    
    % show the results by distribution and single selected line
    Lateral_Trace_corrPlane_BK_1= Lateral_Trace_corrPlane;
    Lateral_Trace_corrPlane_BK_1(AFM_height_IO==1)=NaN;
    % check distribution of the LD data
    Lateral_Trace_corrPlane_FR_1 = Lateral_Trace_corrPlane;
    Lateral_Trace_corrPlane_FR_1(AFM_height_IO==0)=NaN;    
    % plot distribution, lineAnalysis and image
    DataXdistribution= {Lateral_Trace_corrPlane_BK_1,'1st correction - PlaneFit BK'; ...
                        Lateral_Trace_corrPlane_FR_1,'1st correction - PlaneFit FR'};
    DataXSingleLine={Lateral_Trace_corrPlane,'1st correction - PlaneFit'};
    figDistr=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution,'prevFig',figDistr,'idCall',2);
    pause(1)
    figSingleLine=plotSingleLineCheck(idxMon,DataXSingleLine,idxLine,'prevFig',figSingleLine);
    pause(1)
    titleData1='Plane Fitted Background';
    titleData2={'Lateral Deflection'; 'Removed fitted plane'};
    nameFig='resultA2_10_planeBKfit_LateralDeflectionCorr';
    figTmp=showData(idxMon,true,correction_plane,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
        'extraData',{Lateral_Trace_corrPlane},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
    pause(1)
    answ=getValidAnswer('Continue with LineXLine fitting?','',{'Yes','No'});
    close(figTmp)
    Lateral_Trace_secondCorr = Lateral_Trace_corrPlane;
    % fit lineXline, with the further line check in case the border parts of a line contains significant amount of no data (i.e. no BK but only FR) 
    % potentially bringing to wrong fit
    varargout{3}="LineByLine Fitting not available (user skipped this step)";
    if answ   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% LINE-BY-LINE FITTING ON LATERAL DEFLECTION BACKGROUND (masked LAT image) %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
        delete(allWaitBars)
        wb=waitbar(1/(limit*limit),sprintf('Removing Plane Polynomial Baseline orderX: %d orderY: %d',0,0),...
                'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wb,'canceling',0);
    
        % apply the PDA mask, so the PDA data  will be ignored. Use now the background        
        Lateral_Trace_BK_1_maskOnly = Lateral_Trace_corrPlane;
        Lateral_Trace_BK_1_maskOnly(AFM_height_IO==1)=5;          
        % Init
        f1='fitOrder';f2='SSE';f3='R2';f4='coeffs';
        f4_valCoeffs=nan(size(Lateral_Trace_BK_1_maskOnly, 2),limit+1);
        fit_decision_final_line = struct(f1,[],f2,[],f3,[],f4,f4_valCoeffs);                  
        Bk_iterative = zeros(size(Lateral_Trace_BK_1_maskOnly));
        num_lines = size(Lateral_Trace_BK_1_maskOnly, 2);
        % build array abscissas for the fitting
        x = (1:size(Lateral_Trace_BK_1_maskOnly,1))';
        flagLineMissingDataBorder=zeros(1,num_lines);
        fAnomaliesCheck=figure;
        objInSecondMonitor(fAnomaliesCheck,idxMon)
        axAnomalies=axes("Parent",fAnomaliesCheck);
        hold(axAnomalies,"on")
        for i = 1:num_lines      
            % Check for cancellation
            if getappdata(wb, 'canceling')
                delete(wb);
                error('Process cancelled');
            end
            % Update progress bar
            waitbar(i / num_lines, wb, sprintf('Fitting on the line %d...', i));
            % Extract the current scan line
            yData = Lateral_Trace_BK_1_maskOnly(:, i);
            xData = (1:length(yData))';        
            % Remove masked values (set to 5)
            xValid = xData(yData ~= 5);
            yValid = yData(yData ~= 5);
            % Remove outliers
            [pos_outlier] = isoutlier(yValid, 'gesd');
            while any(pos_outlier)
                yValid(pos_outlier) = NaN;
                [pos_outlier] = isoutlier(yValid, 'gesd');
            end
            xValid = xValid(~isnan(yValid));
            yValid = yValid(~isnan(yValid));           
            % Handle insufficient data points
            if length(yValid) < 4
                Bk_iterative(:, i) = NaN; % Mark for interpolation later
                continue;
            end
            % Initialize AIC results
            models = cell(1, limit);
            % prepare the setting for the fitting
            opts = fitoptions('Method', 'LinearLeastSquares');
            opts.Robust = 'LAR';
            fit_decision = zeros(3, limit);
            % Test polynomial fits up to the limit
            aic_values=zeros(1,limit);
            for z = 1:limit
                % Define polynomial fit type
                ft = fittype(sprintf('poly%d', z));                
                % Fit model using LAR and exclude data where yData >= 5
                [fitresult, gof] = fit(xValid, yValid, ft, opts);                
                if gof.adjrsquare < 0
                    gof.adjrsquare = 0.001;
                end                
                % Compute SSE and AIC
                residuals = yData - feval(fitresult, xData);
                SSE = sum(residuals.^2);
                n = length(yData);
                k = z + 1; % Number of parameters (polynomial degree + 1)
                aic_values(z) = n * log(SSE / n) + 2 * k;                
                % Store model and statistics
                models{z} = fitresult;
                fit_decision(1, z) = z;
                fit_decision(2, z) = SSE;     % AIC
                fit_decision(3, z) = gof.adjrsquare; % Adjusted R^2
            end  
            % extract the best fit results depending on the model
            [fittedline,bestFitOrder,fit_decision_final_tmp]=bestFit(x,aic_values,models,fit_decision);
            % if a big portion is missing at the border, there is the risk of wrong fittin. Further check!
            % if the last 200 elements
            if xValid(1) > length(yData)*10/100 || (length(yData)-xValid(end)) > length(yData)*10/100
                % last border
                startX_endBorder=xValid(end-round(length(yData)*5/100));
                % start border
                endX_startBorder=xValid(round(length(yData)*5/100));
                if mean(fittedline(end-round(length(yData)*10/100):end)) > mean(yValid(xValid>=startX_endBorder))*1.3 || ... 
                        mean(fittedline(1:round(length(yData)*10/100))) > mean(yValid(xValid<=endX_startBorder))*1.3 
                    % put a flag in case of missing data in the border which creates the risk of wrong fitting
                    flagLineMissingDataBorder(i)=1;
                    % plot the fitted line and the experimental values
                    iteration=1;
                    plot(axAnomalies,xValid,yValid,'*','DisplayName','Experimental Background','Color',globalColor(1))
                    pause(1)
                    
                    % plot at least two previous experimental data background to understand how they
                    % distributed along the fast scan line. In case the checker happens at the first two
                    % iteration, special cases.
                    % if first line, just do nothing.                    
                    if i==1
                        numPrevRows=0;
                    elseif i==2 || nnz(flagLineMissingDataBorder(1:i)==0)==1
                        numPrevRows=1;
                    else
                        numPrevRows=2;
                    end
                    % if it is not first iteration
                    if i~=1 && any(flagLineMissingDataBorder(1:i)==0)
                        idxPrev=find(flagLineMissingDataBorder(1:i)==0,numPrevRows,"last");      
                        yDataPrevLine = Lateral_Trace_BK_1_maskOnly(:, idxPrev);
                        xDataPrevLine = (1:size(yDataPrevLine,1))';
                        xDataPrevLine = [xDataPrevLine xDataPrevLine]; %#ok<AGROW>
                        % Remove masked values (set to 5)
                        for j=1:numPrevRows
                            xValidtmp = xDataPrevLine(yDataPrevLine(:,j) ~= 5,j);
                            yValidtmp = yDataPrevLine(yDataPrevLine(:,j) ~= 5,j);
                            % Remove outliers
                            [pos_outlier] = isoutlier(yValidtmp, 'gesd');
                            while any(pos_outlier)
                                yValidtmp(pos_outlier) = NaN;
                                [pos_outlier] = isoutlier(yValidtmp, 'gesd');
                            end
                            xValidtmp = xValidtmp(~isnan(yValidtmp));
                            yValidtmp = yValidtmp(~isnan(yValidtmp));    
                            plot(axAnomalies,xValidtmp,yValidtmp,'*','DisplayName',sprintf('ExpBK line %d',idxPrev(j)),'Color',globalColor(j+1))
                            plot(axAnomalies,Bk_iterative(:,idxPrev(j)),'Color',globalColor(j+1),'DisplayName',sprintf('FittedBK line %d',idxPrev(j)))
                        end
                    end
                    % +2 because second and/or third colors are used for the prev iteration
                    idxColor=numPrevRows+2;
                    plot(axAnomalies,fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(1),'LineWidth',2,'LineStyle','--')                                        
                    legend('FontSize',18), xlim padded, ylim padded, title(sprintf('Line %d',i),'FontSize',14)
                    question=sprintf(['The avg of one of the borders (%d elements over %d) of the first\nfitted %d-line is higher then the avg of true exp BK borders' ...
                        '(%d elements)\nChoose the best option to manage the current line.'],round(length(yData)*10/100),length(yData),i,round(length(yData)*5/100));
                    idxs=1:limit; flagContinue=true; 
                    while flagContinue
                        options={sprintf('Exclude the best fitOrder (Current fitOrder: %d) and re-process the line',bestFitOrder),'Transform the entire line into NaN vector which interpolation will be followed at the end.','Keep the current and continue to the next line.'};
                        % dont remove stop here to zoom the figure
                        operations=getValidAnswer(question,'',options,3);
                        switch operations
                            case 3                                
                                break
                            case 1
                                if isscalar(idxs)            
                                    idxstext = arrayfun(@(x) sprintf('fitOrder: %d', x), 1:limit, 'UniformOutput', false);
                                    idxs=getValidAnswer('Operation not allowed: all the fitOrder already excluded. Choose the final fitOrder.','',idxstext);
                                    flagContinue=false;
                                else
                                    idxs= idxs(idxs~=bestFitOrder);
                                end                           
                            case 2
                                fittedline = NaN; % Mark for interpolation later
                                break
                        end
                        [fittedline,bestFitOrder,fit_decision_final_tmp]=bestFit(x,aic_values(idxs),models(idxs),fit_decision(:,idxs));
                        if flagContinue
                            iteration=iteration+1;                            
                            plot(axAnomalies,fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(idxColor),'LineWidth',2,'LineStyle','--')
                            idxColor=idxColor+1;
                        end
                    end
                    % clear the figure contents
                    cla(axAnomalies)
                end
            end 
            fit_decision_final_line(i)=fit_decision_final_tmp;
            Bk_iterative(:, i) = fittedline;
        end        
        close(fAnomaliesCheck)
        % Handle missing lines by interpolating from neighbors, also when more consecutive lines are totally NaN
        % If that happens, then take the closest non NaN vectors and interpolate
        nan_lines = find(isnan(Bk_iterative(1, :)));
        for i = nan_lines
            left_idx = find(~isnan(Bk_iterative(1, 1:i-1)), 1, 'last');
            right_idx = find(~isnan(Bk_iterative(1, i+1:end)), 1, 'first') + i;
            % adiacent interpolation
            if ~isempty(left_idx) && ~isempty(right_idx)
                Bk_iterative(:, i) = (Bk_iterative(:, left_idx) + Bk_iterative(:, right_idx)) / 2;
            elseif ~isempty(left_idx)
                Bk_iterative(:, i) = Bk_iterative(:, left_idx);
            elseif ~isempty(right_idx)
                Bk_iterative(:, i) = Bk_iterative(:, right_idx);
            end
        end    
        % Remove background
        Lateral_Trace_secondCorr = Lateral_Trace_corrPlane - Bk_iterative;
        % Plot the fitted backround:               
        titleData1='Line x Line Fitted Background'; titleData2={"Lateral Deflection - Trace";"Plane+LineByLine Fitted"};
        nameFig='resultA2_11_LineBKfit_LateralDeflection';
        figTmp=showData(idxMon,true,Bk_iterative,titleData1,'','','normalized',norm,'labelBar',unitDataLabel,'saveFig',false, ...
            'extraData',{Lateral_Trace_secondCorr},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
        % plot distribution and lineAnalysis
        Lateral_Trace_corrLine_BK_2= Lateral_Trace_secondCorr;
        Lateral_Trace_corrLine_BK_2(AFM_height_IO==1)=NaN;
        % check distribution of the LD data
        Lateral_Trace_corrLine_FR_2 = Lateral_Trace_secondCorr;
        Lateral_Trace_corrLine_FR_2(AFM_height_IO==0)=NaN;
        DataXdistribution= {Lateral_Trace_corrLine_BK_2,'2nd correction - LineXLineFit BK'; ...
                            Lateral_Trace_corrLine_FR_2,'2nd correction - LineXLineFit FR'};
        DataXSingleLine={Lateral_Trace_secondCorr,'2nd correction - LineXLineFit'};
        figDistrTmp=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution,'prevFig',figDistr,'idCall',3);        
        figSingleLineTmp=plotSingleLineCheck(idxMon,DataXSingleLine,idxLine,'prevFig',figSingleLine);
        pause(1)
        if getValidAnswer('Satisfied of the fitting? If not, keep the original and skip to the next part.','',{'y','n'})
            close(figTmp)                 
            varargout{3}=fit_decision_final_line;  
            % take the definitive last figures
            figDistr=figDistrTmp;
            figSingleLine=figSingleLineTmp;
        else
           titleData1='Line x Line Fitted Background'; titleData2={'Lateral Deflection - Trace';"Plane+LineByLine Fitted (NOT TAKEN))"};
           
        end
        showData(idxMon,false,Bk_iterative,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
        'extraData',{Lateral_Trace_secondCorr},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
    end
    % Finalise the distribution and signleLineAnalysis figures
    % adjust xlim, especially show the 99.5 percentile of the data in the distribution
    ax = findobj(figDistr, 'Type', 'Axes');           % find axes inside the figure
    hList = findobj(ax, 'Type', 'Histogram');         % locate the histograms
    % since there more than one histogram, store the data in cell array
    allData = cell2mat(arrayfun(@(h) h.Data(:), hList, 'UniformOutput', false));
    pLow = prctile(allData, 1);
    pHigh = prctile(allData, 99.5);
    xlim(ax, [min(allData)-abs(pLow), pHigh]); ylim(ax,"padded");
    clear allData pLow pHigh ax hList
    % save distribution and singleLine
    nameResults='resultA2_12_DistributionLD_eachCorrectionStep';
    saveFigures(figDistr,newFolder,nameResults)
    nameResults='resultA2_13_singleFastScanLineLD_eachCorrectionStep';
    saveFigures(figSingleLine,newFolder,nameResults)
    close all
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%--------- CONVERSION LATERAL DEFLECTIO [V] ==> LATERAL FORCE [N] ---------%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % choose friction coefficients depending on the case (experimental results done in another moment), or manually put the value
    question=sprintf('Which background friction coefficient use?');
    options={ ...
        sprintf('1) TRCDA (air) = 0.3040'), ...
        sprintf('2) PCDA  (air)  = 0.2626'), ... 
        sprintf('3) TRCDA-DMPC (air) = 0.1305'), ...
        sprintf('4) TRCDA-DOPC (air) = 0.1650'), ...
        sprintf('5) TRCDA-POPC (air) = 0.1250'), ...
        sprintf('6) Enter manually a value'),...
        sprintf('7) Extract the fc from the same scan area with HV mode off')};
    choice = getValidAnswer(question, '', options);
    
    while true
        switch choice
            case 1, avg_fc = 0.3040;
            case 2, avg_fc = 0.2626;
            case 3, avg_fc = 0.1305;
            case 4, avg_fc = 0.1650;
            case 5, avg_fc = 0.1250;                     
            case 6
                while true
                    avg_fc = str2double(inputdlg('Enter a value for the glass fricction coefficient','',[1 50]));
                    if any(isnan(avg_fc)) || avg_fc <= 0 || avg_fc >= 1
                        questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                    else
                        break
                    end
                end
            case 7
                if ~exist(fullfile(mainPath,'HoverMode_OFF'),"dir")
                    error('The directory HoverMode_OFF doesn''t exist. Select another option')
                end
                [avg_fc,FitOrderHVOFF_Height] = A2_feature_2_1_FrictionCalcFromSameScanHVOFF(idxMon,mainPath,flagSingleSectionProcess,idxSectionHVon,'FitOrderHVOFF_Height',FitOrderHVOFF_Height);
                if isempty(avg_fc)
                    fprintf('For some reasons, the scan in HoverMode OFF is messed up. Choose a standard value if possible')
                    continue
                end
        end
        break
    end
    clear choice question options wb   
    % Friction force = friction coefficient * Normal Force
    Baseline_Friction_Force= vertical_Trace*avg_fc;
    % Friction force = calibration coefficient * Lateral Trace (V)
    Lateral_Trace_Force= Lateral_Trace_secondCorr*alpha;
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    
    % show the fast scan line in Force units (before was Volt) for the
    % choosen idx line
    figSingleLineForce=figure("Visible","off"); 
    hold on
    plot(Baseline_Friction_Force(:,idxLine)*1e9,'DisplayName','OFFSET (VD*fc)','LineWidth',1.5)
    plot(Lateral_Trace_Force(:,idxLine)*1e9,'DisplayName','F=Deflection*Alpha','LineWidth',1.5)
    plot(Corrected_LD_Trace(:,idxLine)*1e9,'DisplayName', 'corrected Force (F+OFFSET)','LineWidth',1.5)
    legend('FontSize',15), grid on, grid minor
    title(sprintf("(FORCE) Fast scan line # %d",idxLine),'FontSize',20)
    xlabel('Fast scan line [pixel]','FontSize',15)
    ylabel('Lateral Force [nN]','FontSize',15)
    numElements=length(Baseline_Friction_Force(:,idxLine));
    xmin = -round(0.1*numElements);
    xmax =  numElements+round(0.1*numElements);
    xlim([xmin xmax]);
    objInSecondMonitor(figSingleLineForce,idxMon);
    nameFig='resultA2_14_singleFastScanLineLD_FORCE';
    saveFigures(figSingleLineForce,newFolder,nameFig)

    % plot the definitive corrected lateral force
    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA2_15_ResultsDefinitiveLateralDeflectionsNewton_normalized';
    showData(idxMon,SeeMe,Corrected_LD_Trace,titleData,newFolder,nameFig,'normalized',true)

    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA2_16_ResultsDefinitiveLateralDeflectionsNewton';
    labelFig='Force [nN]';
    showData(idxMon,SeeMe,Corrected_LD_Trace*1e9,titleData,newFolder,nameFig,'labelBar',labelFig)

    % save the corrected lateral force into cropped AFM image
    AFM_Elab=AFM_data;    
    AFM_Elab(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_image=Corrected_LD_Trace;
    varargout{1}=AFM_Elab; 
    varargout{4}=FitOrderHVON_Lat;
    varargout{5}=FitOrderHVOFF_Height;
end


%%%%%%%%%%%%%%%%%%%%%
%%%%% FUNCTIONS %%%%%
%%%%%%%%%%%%%%%%%%%%%

function figDistr=checkDistributionDataLD(SeeMe,idxMon,Data,varargin)
    p=inputParser();
    argName = 'prevFig';    defaultVal = [];   addOptional(p,argName,defaultVal);   
    argName = 'idCall';     defaultVal = 1;    addOptional(p,argName,defaultVal);   
    parse(p,varargin{:});
    if isempty(p.Results.prevFig)
        if SeeMe
            figDistr=figure('Visible','on'); 
        else
            figDistr=figure('Visible','off'); 
        end
        % adjust pic
        legend('FontSize',15), grid on, grid minor
        xlabel('Lateral Deflection [V]','FontSize',15)
        title("Distribution Lateral Deflection and minimum values","FontSize",20)
        subtitle("(99.5 percentile of the entire data)","FontSize",15)
        objInSecondMonitor(figDistr,idxMon);        
        pause(1)        
    else
        figDistr=p.Results.prevFig;
        figure(figDistr)              
    end
    idCall=p.Results.idCall;
    ax = findall(figDistr, 'type', 'axes');    
    hold(ax,"on")
    % extract the data
    DataBK=Data{1,1}; DataBK=DataBK(~isnan(DataBK)); NameBK=Data{1,2};
    DataFR=Data{2,1}; DataFR=DataFR(~isnan(DataFR)); NameFR=Data{2,2};
    % prepare histogram. round not work to excess but to nearest.
    xmin=floor(min(min(DataBK(:)),min(DataFR(:))) * 1000) / 1000;
    xmax=ceil( max(max(DataBK(:)),max(DataFR(:))) * 1000) / 1000;
    edges=(xmin:0.01:xmax);

    % show the original LD of BK
    DataCleaned_BK=DataBK(:); DataCleaned_BK(~isnan(DataCleaned_BK));
    histogram(ax,DataCleaned_BK,'BinEdges',edges,"DisplayName",NameBK)
    % show the original LD of FR
    DataCleaned_FR=DataFR(:); DataCleaned_FR(~isnan(DataCleaned_FR));
    histogram(ax,DataCleaned_FR,'BinEdges',edges,"DisplayName",NameFR)
    % check the abs min
    absMinBK=min(DataCleaned_BK);
    % check the min in corrispondence of 1 percentile
    percentile=1;      
    threshold = prctile(DataCleaned_BK, percentile);
    % show vertical line of different min BK
    xline(ax,absMinBK,':','LineWidth',1.5,     'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min BK:       %.2e',absMinBK))
    xline(ax,threshold,'--','LineWidth',1.5,   'Color',globalColor(idCall),'DisplayName',sprintf('Min 1 percentile BK:   %.2e',threshold))        
    % show vertical line of min FR
    absMinFR=min(DataCleaned_FR);
    xline(ax,absMinFR,'.-','LineWidth',1.5,    'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min FR:       %.2e',absMinFR))
    pause(2)
end

function figSingleLine=plotSingleLineCheck(idxMon,data,idxLine,varargin)
    p=inputParser();
    argName = 'prevFig';    defaultVal = [];    addOptional(p,argName,defaultVal);
    parse(p,varargin{:});
    clearvars argName defaultVal
    numberLines=length(idxLine);              
    if isempty(p.Results.prevFig)
        Lateral_Trace=data{1};
        AFM_height_IO=data{2};     
        x = 1:size(AFM_height_IO,1);
        % prepare the main fig
        figSingleLine=figure('Name','Fast Scan Lines Analysis'); % dont hide, it can be useful in deciding if perform lineXline fitting
        tiledlayout(figSingleLine,numberLines,1,'TileSpacing','compact'); % create n rows to show separately different lines
        objInSecondMonitor(figSingleLine,idxMon);
        %%%%%%----------------------------------
        %%%%%% start the line plottings %%%%%%%%
        %%%%%%----------------------------------
        for i=1:numberLines
            y = Lateral_Trace(:,idxLine(i));
            % identify the masked regions so they can be easily recognised
            y_mask=AFM_height_IO(:,idxLine(i));            
            % prepare the subfig
            currLine=nexttile; cla(currLine);             
            plot(currLine,y,'DisplayName','Raw LD','LineWidth',1.5)      
            hold(currLine,"on")       
            % set limits for transparent rects
            ymin = min(0,min(y) - round(0.1*range(y)));
            ymax = max(1,max(y) + round(0.1*range(y)));
            xmin = min(x) - round(0.1*range(x));
            xmax = max(x) + round(0.1*range(x));
            % Find contiguous regions with same value in the mask (find changes)
            LD_mask_diff = [true; diff(y_mask(:)) ~= 0; true];
            idx_edges = find(LD_mask_diff);
            segments = [idx_edges(1:end-1), idx_edges(2:end)-1];
            % color region for each found segment
            for j = 1:size(segments,1)
                idx_start = segments(j,1);
                idx_end = segments(j,2);
                col = y_mask(idx_start);  % 0 o 1                
                if col == 1
                    c = [0 0 1];  % blue
                    typeIO='Foreground';
                else
                    c = [1 0 0];  % red
                    typeIO='Background';
                end        
                % create rectangules on the plot to distinguish BF from FR
                xPatch = [x(idx_start) x(idx_end) x(idx_end) x(idx_start)];
                yPatch = [ymin ymin ymax ymax];
                f=fill(currLine,xPatch, yPatch, c, 'FaceAlpha', 0.2, 'EdgeColor', 'none','DisplayName',typeIO);
                if j~=1 && j~=2 
                    f.Annotation.LegendInformation.IconDisplayStyle = 'off';
                end
            end
            % adjust pic
            title(currLine,sprintf("Fast scan line #%d",idxLine(i)), 'FontSize',15);
            legend(currLine,'FontSize',11), grid on, grid minor 
            xlabel(currLine,'Fast scan line [pixel]','FontSize',10)
            ylabel(currLine,'Lateral Deflection [V]','FontSize',10)
            xlim(currLine,[xmin xmax]);
            ylim(currLine,[ymin ymax]);
            hold(currLine,"off") 
        end        
    else
        Lateral_Trace=data{1};
        Lateral_Trace_name=data{2};
        % take the existing fig and find all axes inside
        figSingleLine=p.Results.prevFig;
        figure(figSingleLine)    
        axAll = findall(figSingleLine, 'type', 'axes');
        % Sort up-to-bottom
        [~, idx] = sort(arrayfun(@(ax) ax.Position(2), axAll),'descend');
        axAll = axAll(idx);        
        for i=1:numberLines
            y=Lateral_Trace(:,idxLine(i));
            axSelected=axAll(i);
            axes(axSelected) %#ok<LAXES>
            hold(axSelected, 'on');        
            plot(axSelected,y,'DisplayName',Lateral_Trace_name,'LineWidth',1.5)
            hold(axSelected, 'off');
            ylim(axSelected,'padded')
        end
    end
    pause(1)
end

function saveFigures(fig,nameDir,nameFig)
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(fig,fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(fig,fullnameFig) 
    close(fig)
    pause(1)
end

function [fittedline,bestFitOrder,fit_decision_final_line_tmp]=bestFit(x,aic_values,models,fit_decision) %#ok<INUSD>
        % Select best model using AIC
        [~, bestIdx] = min(aic_values);
        bestModel = models{bestIdx};
        % Save fitting decisions
        fit_decision_final_line_tmp=struct();
        bestFitOrder=fit_decision(1, bestIdx);
        fit_decision_final_line_tmp.fitOrder = bestFitOrder; % order
        fit_decision_final_line_tmp.SSE = fit_decision(2, bestIdx); % SEE
        fit_decision_final_line_tmp.R2 = fit_decision(3, bestIdx); % R^2
        % Store polynomial coefficients
        commPart = '';
        j = 1;
        % Extract coefficient vector
        coeff_values = coeffvalues(bestModel);
        for n = bestFitOrder:-1:0
            commPart = sprintf('%s + %s', commPart, sprintf('bestModel.p%d*(x).^%d', j, n));
            fit_decision_final_line_tmp.coeffs(1:length(coeff_values))= coeff_values;
            j = j + 1;
        end
        % Compute fitted values for the baseline
        fittedline=eval(commPart);
end