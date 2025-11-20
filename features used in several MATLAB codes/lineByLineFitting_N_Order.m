function varargout = lineByLineFitting_N_Order(data,limit)
% Polynomial baseline fitting (line by line) - Linear least squares fitting to the results.
% GOAL: extract the background to remove from the data
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    N_Cycluse_waitbar = size(data,2);
    wb=waitbar(0/N_Cycluse_waitbar,sprintf('AIC-based background fitting - Line %d of %d completed',0,N_Cycluse_waitbar),...
            'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
   
    % Initialize variables
    fit_decision_final = struct();     % var where to store results of the bestFit model for each fast scan line
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    allBaseline = zeros(size(data));                        % matrix which will contain the baseline of each fast scan line
    x = (1:size(data,1))';                                  % build array abscissas to calc y=f(x)
    for i=1:size(data,2)
        if(exist('wb','var')) && getappdata(wb, 'canceling')
               error('Process cancelled')
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% REMOVE OUTLIERS %%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % exclude the true data which represents the features of interest of PDA. 
        % Indeed, baseline fitting should ONLY use low-intensity (i.e. background) values. The
        % presence of such outliers create wrong bias during the fitting and can distort polynomial fitting. 
        % Removing them ensures a smoother and more reliable baseline correction!           
        fastScanLine = data(:,i); % Take the i-th fast scan line          
        xData=(1:length(fastScanLine))';
        % STEP 1: Initial Low-Order Polynomial Fit (e.g., Quadratic)
        % this is new and another way to use a dynamic threshold instead of a fixed value.
        % The initial polynomial fit provides a better guess for outlier removal, preventing extreme peaks from affecting the final polynomial fit.
        % It makes the baseline correction more stable and less affected by noise.
        validIdx = ~isnan(fastScanLine);
        polyInit = polyfit(xData(validIdx), fastScanLine(validIdx), 2);     % 2nd order coefficients p1*x^2 + p2*x + p3
        % Estimated baseline
        baselineInit = polyval(polyInit, xData); 
        % Step 2: Remove Points Above This Estimated Baseline + 1 standard deviation above baseline
        threshold = baselineInit + std(fastScanLine(validIdx));                     
        % first round of outliers removal
        fastScanLine(fastScanLine >= threshold) = NaN;                      
        % STEP 3: Remove remaining outliers Iteratively, not just the most extreme one.
        % GESD test is useful when the number of outliers is unknown
        [pos_outlier] = isoutlier(fastScanLine, 'gesd');
        while any(pos_outlier)
            fastScanLine(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(fastScanLine, 'gesd');
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%% START FITTING %%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % now the fastScanLine is enriched with NaN values and it is ready for the baseline fitting
        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double,
        % converting complex to  real and returning data as columns regardless of the input shapes.
        [xData,yData] = prepareCurveData(x,fastScanLine);

        % Handle insufficient data. Leave empty the i-th bk fast scan line (maybe because the line is          
        % entirely made of crystal PDA). Whenever there are few datapoints,
        % the line is almost insignificant, so transform it into NaN
        % vector. SKIP the metric calculations
        if length(xData) <= (limit+1)
            allBaseline(:,i) = NaN; % <============= CHECK!!!! interpolation is wrong if in the fast scan line there is PDA values
            % dataCorrected(:,i)=height_image_2_corrPlane(:,i);
            continue;
        end      

        % Initialize AIC results
        aic_values = nan(1, limit);
        models = cell(1, limit);            
        % Test polynomial fits up to the limit for the specific line
        for z = 1:limit
            polyModel = polyfitn(xData, yData, z);
            models{z} = polyModel;            
            % Compute AIC
            n = length(yData);
            sse = sum((yData - polyval(polyModel.Coefficients, xData)).^2);
            k = length(polyModel.Coefficients); % Number of parameters
            aic_values(z) = n * log(sse / n) + 2 * k;
        end            
        % Select best model using AIC
        [~, bestIdx] = min(aic_values);
        bestModel = models{bestIdx};            
        % Save fitting decisions
        fit_decision_final(i).bestIdx = bestIdx;
        fit_decision_final(i).AIC_bestValue = aic_values(bestIdx);
        fit_decision_final(i).SSE = sum((yData - polyval(bestModel.Coefficients, xData)).^2); % SSE
        fit_decision_final(i).coefficients = bestModel.Coefficients;            
        % Generate baseline using the best polynomial fit
        allBaseline(:, i) = polyval(bestModel.Coefficients, x);
        % Progress update
        waitbar(i/N_Cycluse_waitbar, wb, sprintf('AIC-based background fitting - Line %d of %d completed',i, N_Cycluse_waitbar));
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
    dataCorrected=data-allBaseline;
    % PREPARE OUTPUT
    varargout{1}=dataCorrected;
    varargout{2}=allBaseline;
    varargout{3}=fit_decision_final;
end