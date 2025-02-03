% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function [AFM_Elab,Bk_iterative]=A5_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,alpha,secondMonitorMain,newFolder,mainPath,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Accuracy';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
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
    if SeeMe
        f1=figure('Visible','on');
    else
        f1=figure('Visible','off');
    end
           
    subplot(121)
    imshow((imadjust(Lateral_Trace/max(max(Lateral_Trace))))), colormap parula; colorbar,
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize = 15;
    title('Raw Lateral Deflection [V] - Trace','FontSize',18)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    axis equal, xlim([0 size(Lateral_Trace,2)]), ylim([0 size(Lateral_Trace,1)])

    subplot(122)
    imshow((imadjust(Lateral_Trace_clean_shift/max(max(Lateral_Trace_clean_shift))))), colormap parula; colorbar,
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize = 15;
    title({'Lateral Deflection - Trace [V]'; '(shifted toward minimum)'},'FontSize',18)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    axis equal, xlim([0 size(Lateral_Trace,2)]), ylim([0 size(Lateral_Trace,1)])    
    objInSecondMonitor(secondMonitorMain,f1);
    saveas(f1,sprintf('%s/resultA5_1_RawAndShiftedLateralDeflection.tif',newFolder))
    close(f1)

    % selection of the polynomial order
    if strcmp(p.Results.Accuracy,'Low')
        limit=3;
    elseif strcmp(p.Results.Accuracy,'Medium')
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
    Bk_iterative = zeros(size(Lateral_Trace_shift_masked));
    num_lines = size(Lateral_Trace_shift_masked, 2);
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
        % Handle insufficient data points
        if length(yValid) < 4
            Bk_iterative(:, i) = NaN; % Mark for interpolation later
            continue;
        end        
        % Try polynomial fits from degree 1 to max polynomial order (limit)
        best_aic = inf;
        best_fit = zeros(size(yData));        
        for p = 1:limit
            % Fit polynomial of degree p
            poly_coeffs = polyfit(xValid, yValid, p);
            y_fit = polyval(poly_coeffs, xData);            
            % Compute residuals and AIC
            residuals = yValid - polyval(poly_coeffs, xValid);
            SSE = sum(residuals.^2);
            n = length(yValid);
            AIC = n * log(SSE / n) + 2 * (p + 1);            
            % Update best fit if AIC is lower
            if AIC < best_aic
                best_aic = AIC;
                best_fit = y_fit;
            end
        end        
        % Store best-fit baseline
        Bk_iterative(:, i) = best_fit;        
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
            avg_fc = A5_featureFrictionCalc(secondMonitorMain,newFolder,SeeMe);
    end
    clear choice question options wb

    % Friction force = friction coefficient * Normal Force
    Baseline_Friction_Force= vertical_Trace*avg_fc;
    % Friction force = calibration coefficient * Lateral Trace (V)
    Lateral_Trace_Force= Lateral_Trace_shift_noBK*alpha;
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    
    % Plot the fitted backround:
    if SeeMe
        f2=figure('Visible','on');       
    else
        f2=figure('Visible','off');      
    end
   
    subplot(121)
    imshow((imadjust(Bk_iterative/max(max(Bk_iterative))))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    title('Fitted Background','FontSize',15)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    % remove the background from the image (friction on glass should be zero afterwards):
    subplot(122)
    imshow((imadjust(Lateral_Trace_shift_noBK/max(max(Lateral_Trace_shift_noBK))))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    title('Fitted Lateral Deflection channel [V] - Trace ','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f2);
    saveas(f2,sprintf('%s/resultA5_2_ResultsFittingOnLateralDeflections.tif',newFolder))
    close(f2)
    f3=figure;
    imshow(imadjust(Corrected_LD_Trace/max(max(Corrected_LD_Trace)))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    title('Fitted and corrected Lateral Force [N]','FontSize',17)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f3);
    saveas(f3,sprintf('%s/resultA5_3_ResultsDefinitiveLateralDeflectionsNewton.tif',newFolder))
    close(f3)
    AFM_Elab=AFM_cropped_Images;
    % save the corrected lateral force into cropped AFM image
    AFM_Elab(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image=Corrected_LD_Trace;

    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
end
