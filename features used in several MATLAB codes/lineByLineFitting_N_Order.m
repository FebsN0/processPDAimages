function varargout = lineByLineFitting_N_Order(data,limit,varargin)
% Polynomial baseline fitting (line by line) - Linear least squares fitting to the results.
% GOAL: extract the background to remove from the data
    warning('off', 'curvefit:prepareFittingData:removingNaNAndInf');
    p=inputParser();
    argName = 'CheckBordersLine';   defaultVal = false;     addOptional(p,argName,defaultVal, @(x) (islogical(x)));
    argName = 'idxMon';             defaultVal = [];        addOptional(p,argName,defaultVal, @(x) (isempty(x) || isnumeric(x)));
    parse(p,varargin{:});
    flagCheckBorder=p.Results.CheckBordersLine;
    num_lines = size(data,2);
    % Initialize variables. Store results of the bestFit model for each fast scan line
    fit_decision_final = struct( ...
    'bestFitOrder', [], ...
    'AIC_bestValue', [], ...
    'bestCoeff', [], ...
    'SSE', [], ...
    'R2', []);
    fit_decision_final = repmat(fit_decision_final, 1, num_lines);
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    allBaseline = zeros(size(data));                        % matrix which will contain the baseline of each fast scan line
    x = (1:size(data,1))';                                  % build array abscissas to calc y=f(x)
        
    % used for lateral channel to check integrity of the fitting
    if flagCheckBorder
        idxMon=p.Results.idxMon;
        flagLineMissingDataBorder=zeros(1,num_lines);
        fAnomaliesCheck=figure;
        objInSecondMonitor(fAnomaliesCheck,idxMon)
        axAnomalies=axes("Parent",fAnomaliesCheck);
        hold(axAnomalies,"on")
    end
    
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)    
    wb=waitbar(0/num_lines,sprintf('AIC-based background fitting - Line %d of %d completed',0,num_lines),...
            'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);   
    for i=1:num_lines
        if(exist('wb','var')) && getappdata(wb, 'canceling')
            delete(wb);   
            error('Process cancelled')
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% REMOVE OUTLIERS %%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % The presence of outliers create wrong bias during the fitting and can distort polynomial fitting. 
        % Removing them ensures a smoother and more reliable baseline correction!      
        fastScanLine = data(:,i); % Take the i-th fast scan line          
        % remove existing NaN
        [xData,yData] = prepareCurveData(x,fastScanLine);
        if length(yData) <= (limit+1)
            allBaseline(:,i) = NaN; % <============= CHECK!!!! interpolation is wrong if in the fast scan line there is PDA values
            % dataCorrected(:,i)=height_image_2_corrPlane(:,i);
            continue;
        end 
        % ----------------------- %
        % STEP 1: Initial Low-Order Polynomial Fit (e.g., Quadratic)
        % this is new and another way to use a dynamic threshold instead of a fixed value.
        % The initial polynomial fit provides a better guess for outlier removal, preventing extreme peaks from affecting the final polynomial fit.
        % It makes the baseline correction more stable and less affected by noise.
        polyInit = polyfit(xData, yData, 2);     % 2nd order coefficients p1*x^2 + p2*x + p3
        baselineInit = polyval(polyInit, xData); 
        % Remove Points Above This Estimated Baseline + 1 standard deviation above baseline
        threshold = baselineInit + std(yData);                             
        yData(yData >= threshold) = NaN;
        [xData,yData] = prepareCurveData(xData,yData);
        % ----------------------- %
        % STEP 2: using isoutlier with GESD test is useful when the number of outliers is unknown
        [pos_outlier] = isoutlier(yData, 'gesd');
        while any(pos_outlier)
            yData(pos_outlier) = NaN;
            xData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        % Before starting the fitting, clean the data definitively
        [xData,yData] = prepareCurveData(xData,yData);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% START FITTING %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%              
        % Handle insufficient data. Leave empty the i-th bk fast scan line (maybe because the line is          
        % entirely made of crystal PDA). Whenever there are few datapoints,
        % the line is almost insignificant, so transform it into NaN
        % vector. SKIP the metric calculations
        if length(yData) <= (limit+1)
            allBaseline(:,i) = NaN; % <============= CHECK!!!! interpolation is wrong if in the fast scan line there is PDA values
            % dataCorrected(:,i)=height_image_2_corrPlane(:,i);
            continue;
        end      
        % Initialize AIC results and prepare the setting for the fitting        
        fit_decision = struct();
        opts = fitoptions('Method','LinearLeastSquares','Robust', 'LAR');
        % Test polynomial fits up to the limit for the specific line
        for z = 1:limit
            % Define polynomial fit type.              
            ft = fittype(sprintf('poly%d', z));
            % normalize indipendent variable x. When xData contains few but very large number, fitting can cause problems:
            % internal least-squares matrix becomes ill-conditioned, meaning numerical precision is lost. Solution is to center x
            x0 = mean(xData);
            xCentered = xData - x0;
            % Fit model using LAR and exclude data where yData >= 5
            [models, gof] = fit(xCentered, yData, ft, opts);                
            if gof.adjrsquare < 0
                gof.adjrsquare = 0.001;
            end                
            % Compute SSE and AIC
            residuals = yData - feval(models, xData);
            SSE = sum(residuals.^2);
            n = length(yData);
            k = z + 1; % Number of parameters (polynomial degree + 1)
            aic_values = n * log(SSE / n) + 2 * k;                
            % Store model and statistics
            fit_decision(z).fitOrder    = z;
            fit_decision(z).aic_values  = aic_values;
            fit_decision(z).models      = models;
            fit_decision(z).sse         = SSE;
            fit_decision(z).r2          = gof.adjrsquare; % Adjusted R^2
        end   
                
        % if true, check if top left and/or top right have enough elements for a proper fit.        
        if flagCheckBorder
            resultsCheckBorders=checkBorders(xData,yData,fit_decision,...
                flagLineMissingDataBorder,i,axAnomalies,data,allBaseline);
            if ~isempty(resultsCheckBorders)
                fittedline=resultsCheckBorders{1};
                fit_decision_final_tmp=resultsCheckBorders{2};
                flagLineMissingDataBorder=resultsCheckBorders{3};
            end            
        else
            [fittedline,fit_decision_final_tmp]=bestFit(x,fit_decision);            
        end

        % Save fitting decisions
        fit_decision_final(i) = fit_decision_final_tmp;       
        % Generate baseline using the best polynomial fit
        allBaseline(:, i) = fittedline;
        % Progress update
        waitbar(i/num_lines, wb, sprintf('AIC-based background fitting - Line %d of %d completed',i, num_lines));
    end
    if flagCheckBorder
        close(fAnomaliesCheck) 
    end
    delete(wb)
    %%%%% MAYBE BETTER DELETE IT!!!     
    % Handle NaN lines by interpolation. In case of those lines entirely made of NaN
    nan_lines = find(isnan(allBaseline(1, :)));
    for i = nan_lines
        left_idx = find(~isnan(allBaseline(1, 1:i-1)), 1, 'last');
        right_idx = find(~isnan(allBaseline(1, i+1:end)), 1, 'first') + i;
        % adiacent interpolation
        if ~isempty(left_idx) && ~isempty(right_idx)
            allBaseline(:, i) = (allBaseline(:, left_idx) + allBaseline(:, right_idx)) / 2;
        elseif ~isempty(left_idx)
            allBaseline(:, i) = allBaseline(:, left_idx);
        elseif ~isempty(right_idx)
            allBaseline(:, i) = allBaseline(:, right_idx);
        end
    end 
    % PREPARE OUTPUT
    varargout{1}=allBaseline;
    varargout{2}=fit_decision_final;
    warning('on', 'curvefit:prepareFittingData:removingNaNAndInf');
end


function [fittedline,fit_decision_final]=bestFit(x,fit_decision)
        % Select best model using AIC
        aic_values=[fit_decision.aic_values];
        [~, bestIdx] = min(aic_values);        
        bestModel = fit_decision(bestIdx).models;
        % calc coeffs: p_1*x^(n-1) + p_2*x^(n-2) + ... + p_(n-1)*x + p_n 
        coeff_values = coeffvalues(bestModel);
        % Save fitting decisions
        % Save fitting decisions
        fit_decision_final = struct( ...
            'bestFitOrder',     fit_decision(bestIdx).fitOrder, ...
            'AIC_bestValue',    fit_decision(bestIdx).aic_values, ...
            'bestCoeff',        coeff_values, ...
            'SSE',              fit_decision(bestIdx).sse, ...
            'R2',               fit_decision(bestIdx).r2);
        fittedline = bestModel(x);     % same as polyval(coeffs, x);
end

function  resultsCheckBorders=checkBorders(xData,yData,fit_decision,flagLineMissingDataBorder,idxCurrLine,axAnomalies,BK_data,BK_baseline)
    % if a big portion (10% of total elements) is missing at least one of the two border, there is the risk of wrong fitting. Further check!
    % NOTE: xData(1) because is already clean from NaN, so it is already an indicator of where there is data, similarly for xData(end)
    x=1:size(BK_data,1);
    [fittedline,fit_decision_final_tmp]=bestFit(x,fit_decision);               
    resultsCheckBorders{1}=fittedline;
    resultsCheckBorders{2}=fit_decision_final_tmp;
    resultsCheckBorders{3}=flagLineMissingDataBorder; % dont update, it's already zero
    % if first or last element of xData (=idx of where BK exp data starts) is 10% far from 1* and N* (entire array lenght) 
    if xData(1) > length(x)*10/100 || (length(x)-xData(end)) > length(x)*10/100
        % additional check: if the average of the last 10% elements of fitted line significantly differ 
        % by over 30% from the 10% of real data to fit        
        startX_endBorder=xData(end-round(length(yData)*5/100));     % last border        
        endX_startBorder=xData(round(length(yData)*5/100));         % start border
    % check at least 
        if (mean(fittedline(end-round(length(yData)*10/100):end)) > mean(yData(xData>=startX_endBorder))*1.3 || ... 
                mean(fittedline(1:round(length(yData)*10/100))) > mean(yData(xData<=endX_startBorder))*1.3) && ...
                std(fittedline)>0.01
            % identify the current best fit order
            bestFitOrder=fit_decision_final_tmp.bestFitOrder;
            % put a flag in case of not enough data in the border which creates the risk of wrong fitting
            flagLineMissingDataBorder(idxCurrLine)=1;
            % anomaly detected. clear the figure contents of previous detected anomaly
            cla(axAnomalies)
            % plot the fitted line and the experimental values
            iteration=1;
            plot(axAnomalies,xData,yData,'*','DisplayName','Experimental Background','Color',globalColor(iteration))
            plot(axAnomalies,fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(iteration),'LineWidth',2,'LineStyle','--')                                        
            legend('FontSize',18), xlim padded, ylim padded, title(sprintf('Line %d',idxCurrLine),'FontSize',14)          
            pause(1)
            
            % plot at least two previous experimental data background to understand how they
            % distributed along the fast scan line. In case the checker happens at the first two
            % iteration, special cases.
            % if first line, just do nothing.                    
            if idxCurrLine==1
                numPrevRows=0;
            elseif idxCurrLine==2 || nnz(flagLineMissingDataBorder(1:idxCurrLine)==0)==1
                numPrevRows=1;
            else
                numPrevRows=2;
            end
            % if it is not first iteration and there enough previous data
            if idxCurrLine~=1 && any(flagLineMissingDataBorder(1:idxCurrLine)==0)
                % take the last or the two last fast lines (both fitted and experimental) for better comparison
                idxPrev=find(flagLineMissingDataBorder(1:idxCurrLine)==0,numPrevRows,"last");      
                yDataPrevLine = BK_data(:, idxPrev);
                % prepare also x vectors
                xDataPrevLine = (1:size(yDataPrevLine,1))';
                xDataPrevLine = [xDataPrevLine xDataPrevLine];
                % Remove masked values (nan)
                for j=1:numPrevRows
                    % remove NaN values
                    [xDatatmp,yDatatmp] = prepareCurveData(xDataPrevLine(:,j),yDataPrevLine(:,j));
                    % Remove outliers
                    [pos_outlier] = isoutlier(yDatatmp, 'gesd');
                    while any(pos_outlier)
                        yDatatmp(pos_outlier) = NaN;
                        [pos_outlier] = isoutlier(yDatatmp, 'gesd');
                    end
                    [xDatatmp,yDatatmp] = prepareCurveData(xDatatmp,yDatatmp);
                    plot(axAnomalies,xDatatmp,yDatatmp,'*','DisplayName',sprintf('ExpBK line %d',idxPrev(j)),'Color',globalColor(j+1))
                    plot(axAnomalies,BK_baseline(:,idxPrev(j)),'Color',globalColor(j+1),'DisplayName',sprintf('FittedBK line %d',idxPrev(j)))
                end
            end
            % +2 because second and/or third colors are used for the prev iteration
            idxColor=numPrevRows+2;              
            question=sprintf(['The avg of one of the borders (%d elements over %d) of the first\nfitted %d-line is higher then the avg of true exp BK borders' ...
                '(%d elements)\nChoose the best option to manage the current line.'],round(length(yData)*10/100),length(yData),idxCurrLine,round(length(yData)*5/100));
            limit=numel(fit_decision);
            % prepare what fit metrics should be considered if the current is not ok 
            idxFitToConsider=true(1,limit);             
            flagContinue=true; 
            while flagContinue
                idxFitToConsider(bestFitOrder)=false;
                options={...
                    sprintf('Exclude the best current fitOrder (%d) and find the next best fit',bestFitOrder),...
                    'Transform the entire line into NaN vector which interpolation will be followed at the end.',...
                    'Keep the current and continue to the next line.'};
                % dont remove stop here to zoom the figure
                operations=getValidAnswer(question,'',options,3);
                switch operations
                    case 3
                        break
                    case 1
                        if nnz(idxFitToConsider)<1            
                            idxstext = arrayfun(@(x) sprintf('fitOrder: %d', x), 1:limit, 'UniformOutput', false);
                            idxFitToConsider=getValidAnswer('Operation not allowed: all the fitOrder already excluded. Choose the final fitOrder.','',idxstext);
                            flagContinue=false;
                        end                           
                    case 2
                        fittedline = NaN; % Mark for interpolation later
                        % empty line
                        fit_decision_final_tmp = struct( ...
                            'bestFitOrder', 'None. Trasformed into NaN', ...
                            'AIC_bestValue', [], ...
                            'bestCoeff', [], ...
                            'SSE', [], ...
                            'R2', []);
                        break
                end
                % if here, then operation 1. exclude the current model and reiterate the best model                
                [fittedline,fit_decision_final_tmp]=bestFit(x,fit_decision(idxFitToConsider));
                bestFitOrder=fit_decision_final_tmp.bestFitOrder;
                if flagContinue
                    iteration=iteration+1;                    
                    plot(axAnomalies,fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(idxColor),'LineWidth',2,'LineStyle','--')
                    idxColor=idxColor+1;
                end
            end                    
            resultsCheckBorders{1}=fittedline;
            resultsCheckBorders{2}=fit_decision_final_tmp;
            resultsCheckBorders{3}=flagLineMissingDataBorder;
        end
    end 
end