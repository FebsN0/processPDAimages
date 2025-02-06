% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function AFM_Elab=A5_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,alpha,secondMonitorMain,newFolder,mainPath,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'FitOrder';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'Silent';     defaultVal = 'Yes';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));

    parse(p,varargin{:});
    clearvars argName defaultVal
    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end

    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace   = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);
    %Lateral_ReTrace = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'ReTrace')).AFM_image);
    vertical_Trace  = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Vertical Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);

    Lateral_Trace_clean =Lateral_Trace;
    %Subtract the minimum of the image
    Lateral_Trace_clean_shift= Lateral_Trace_clean - min(min(Lateral_Trace_clean));
    % Mask W to cut the PDA from the baseline fitting. Where there is PDA in corrispondece of the mask, then mask the
    % lateral deflection data. Basically, the goal is fitting using the glass which is know to be flat. 
    
    % plot the original data
    titleData1='Raw Lateral Deflection [V] - Trace'; titleData2={'Lateral Deflection - Trace [V]'; '(shifted toward minimum)'};
    labelBar='Normalized';
    nameFig=fullfile(newFolder,'resultA5_1_RawAndShiftedLateralDeflection.tif');
    showData(secondMonitorMain,SeeMe,1,Lateral_Trace,true,titleData1,labelBar,nameFig,'data2',Lateral_Trace_clean_shift,'titleData2',titleData2)


    % selection of the polynomial order
    if strcmp(p.Results.FitOrder,'Low')
        limit=2;
    elseif strcmp(p.Results.FitOrder,'Medium')
        limit=6;
    else
        limit=9;
    end
    % apply the PDA mask, so the PDA data  will be ignored. Use now the background
    Lateral_Trace_shift_masked= Lateral_Trace_clean_shift;
    Lateral_Trace_shift_masked(AFM_height_IO==1)=5;
    %show dialog box
    wb=waitbar(0/size(Lateral_Trace_shift_masked,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(Lateral_Trace_shift_masked,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    warning ('off','all');    
    % Init
    fit_decision_final = nan(size(Lateral_Trace_shift_masked, 2), 4 + limit);
    Bk_iterative = zeros(size(Lateral_Trace_shift_masked));
    num_lines = size(Lateral_Trace_shift_masked, 2);
    % build array abscissas for the fitting
    x = (1:size(Lateral_Trace_shift_masked,1))';
    for i = 1:num_lines        
        % Check for cancellation
        if getappdata(wb, 'canceling')
            delete(wb);
            error('Process cancelled');
        end        
        % Extract the current scan line
        yData = Lateral_Trace_shift_masked(:, i);
        xData = (1:length(yData))';        
        % Remove masked values (set to 5)
        valid_idx = yData < 5;
        xValid = xData(valid_idx);
        yValid = yData(valid_idx);
        % Exclude top 1% which represents the edges
        threshold = prctile(yValid, 99);   
        % first round of outliers removal
        yValid(yValid >= threshold) = NaN;   
        xValid(yValid >= threshold) = NaN;  

        [pos_outlier] = isoutlier(yValid, 'gesd');
        while any(pos_outlier)
            yValid(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yValid, 'gesd');
        end
        xValid = xValid(~isnan(yValid));
        yValid = yValid(~isnan(yValid));

        if ismember(i,300:1:320)
            curveFitter(xValid,yValid)
        end

        % Handle insufficient data points
        if length(yValid) < 4
            Bk_iterative(:, i) = NaN; % Mark for interpolation later
            continue;
        end        
        % Initialize AIC results
        aic_values = nan(1, limit);
        models = cell(1, limit);
        % Test polynomial fits up to the limit
        for p = 1:limit
            poly_coeffs = polyfitn(xValid, yValid, p);                
            models{p} = poly_coeffs;                  
            % Compute AIC
            residuals= yValid - polyval(poly_coeffs.Coefficients, xValid);
            SSE = sum(residuals.^2);
            n = length(yValid);
            k = length(poly_coeffs.Coefficients); % Number of parameters
            aic_values(p) = n * log(SSE / n) + 2 * k;
        end  
        % Select best model using AIC
        [~, bestIdx] = min(aic_values);
        bestModel = models{bestIdx};            
        % Save fitting decisions
        fit_decision_final(i, 1) = bestIdx;
        fit_decision_final(i, 2) = aic_values(bestIdx);
        fit_decision_final(i, 3) = sum((yData - polyval(bestModel.Coefficients, xData)).^2); % SSE
        fit_decision_final(i, 4:4 + bestIdx) = bestModel.Coefficients;            
        % Generate baseline using the best polynomial fit
        Bk_iterative(:, i) = polyval(bestModel.Coefficients, x);     
        % Update progress bar
        waitbar(i / num_lines, wb, sprintf('Fitting on the line %d...', i));
    end
    delete(wb);    
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
    Lateral_Trace_shift_noBK = Lateral_Trace_clean_shift - Bk_iterative;
    % Plot the fitted backround:
    titleData1='Fitted Background'; titleData2='Fitted Lateral Deflection channel [V] - Trace';
    nameFig=fullfile(newFolder,'resultA5_2_ResultsFittingOnLateralDeflections.tif');
    showData(secondMonitorMain,SeeMe,2,Bk_iterative,true,titleData1,'',nameFig,'data2',Lateral_Trace_shift_noBK,'titleData2',titleData2)

    % choose friction coefficients depending on the case (experimental results done in another moment),
    % or manually put the value
    question=sprintf('Which background friction coefficient use?');
    options={ ...
        sprintf('1) TRCDA (air) = 0.3040'), ...
        sprintf('2) PCDA  (air)  = 0.2626'), ... 
        sprintf('3) TRCDA-DMPC (air) = 0.1455'), ...
        sprintf('4) TRCDA-DOPC (air) = 0.1650'), ...
        sprintf('5) TRCDA-POPC (air) = 0.1250'), ...
        sprintf('6) Enter manually a value'),...
        sprintf('7) Extract the fc from the same scan area with HV mode off')};
    choice = getValidAnswer(question, '', options);
    
    while true
        switch choice
            case 1, avg_fc = 0.3040;
            case 2, avg_fc = 0.2626;
            case 3, avg_fc = 0.1455;
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
                avg_fc = A5_featureFrictionCalcFromSameScanHVOFF(secondMonitorMain,mainPath);
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
    Lateral_Trace_Force= Lateral_Trace_shift_noBK*alpha;
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    
    % plot the definitive corrected lateral force
    titleData='Fitted and corrected Lateral Force [N]';
    nameFig=fullfile(newFolder,'resultA5_3_ResultsDefinitiveLateralDeflectionsNewton.tif');
    showData(secondMonitorMain,1,3,Corrected_LD_Trace,true,titleData,'',nameFig,'closeImmediately',false)
    % save the corrected lateral force into cropped AFM image
    AFM_Elab=AFM_cropped_Images;    
    AFM_Elab(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image=Corrected_LD_Trace;
end
