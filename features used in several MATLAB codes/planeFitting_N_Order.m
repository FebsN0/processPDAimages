function varargout = planeFitting_N_Order(data,limit)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% plane fitting by exploring 1==>limit (1,2,3,..,limit) %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INPUT:    data = matrix (example a specific channel image)
%           limit = scalar value, max fitOrder of plane fitting exploration (example: limit=3 ==> 1=>2=>3)
%
% OUTPUT:   varargout{1} =  dataCorrected               => original data MINUS correction_plane
%           varargout{2} =  correction_plane            => best generated plane
%           varargout{3} =  fit_decision_final_plane    => metrics of the best generated plane
    warning('off', 'curvefit:prepareFittingData:removingNaNAndInf');
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    wb=waitbar(1/(limit*limit),sprintf('Removing Plane Polynomial Baseline orderX: %d orderY: %d',0,0),...
            'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    
    % PREPARE THE DATA FOR FITTING
    [xGrid, yGrid] = meshgrid(1:size(data,2), 1:size(data,1));
    [xData, yData, zData] = prepareSurfaceData(xGrid,yGrid,data);  
   
    % init and prepare the setting for the fitting
    models = cell(limit+1, limit+1);
    opts = fitoptions('Method', 'LinearLeastSquares');
    opts.Robust = 'LAR';        % robust fitting to reduce outlier effects
    fit_decision = cell(limit+1,limit+1,4);
    fit_decision_final_plane = struct();
    % Test polynomial fits up to the limit
    i=1;
    for px = 0:limit
        for py = 0:limit
            waitbar(i/(limit+1)/(limit+1), wb, sprintf('Removing Plane Polynomial Baseline orderX: %d orderY: %d',px,py));    
            % Check for cancellation
            if getappdata(wb, 'canceling')
                delete(wb);
                error('Process cancelled');
            end 
            if (px == 0 && py == 0) || px>=6 || py>=6
                fit_decision{px+1,py+1,1} = inf; % prevent to take these indexes by finding the min to identify the bestIdx
                continue; % Avoid constant fit
            end
            % Define polynomial fit type for 2D surface
            fitTypeM=sprintf('poly%d%d', px, py);
            ft = fittype(fitTypeM);
            [fitresult, gof] = fit( [xData, yData], zData, ft, opts );
            if gof.adjrsquare < 0
                gof.adjrsquare = 0.001;
            end     
            % Compute SSE and AIC
            residuals = zData - feval(fitresult,xData,yData);
            SSE = sum(residuals.^2);
            n = length(yData);
            k = numel(coeffnames(fitresult)); % Number of parameters; % Number of parameters (polynomial degree + 1)
            aic_values = n * log(SSE / n) + 2 * k;           
            % Store model and statistics
            models{px+1,py+1} = fitresult;
            fit_decision{px + 1, py + 1,1} = aic_values;
            fit_decision{px + 1, py + 1,2} = gof.sse;
            fit_decision{px + 1, py + 1,3} = gof.adjrsquare;
            fit_decision{px + 1, py + 1,4} = fitTypeM;
            i=i+1;                   
        end
    end    
    % Select best model using AIC
    allAICvalues=cell2mat(fit_decision(:,:,1));
    [~, bestIdx] = min(allAICvalues,[],'all');
    [bestPx, bestPy] = ind2sub(size(allAICvalues), bestIdx);
    bestModel = models{bestPx, bestPy};
    % Save fitting decisions
    fit_decision_final_plane.fitOrder = fit_decision{bestPx, bestPy,4};     % fitTypeM
    fit_decision_final_plane.AIC_value = fit_decision{bestPx, bestPy,1};    % AIC
    fit_decision_final_plane.SSE = fit_decision{bestPx, bestPy,2};          % SSE
    fit_decision_final_plane.R2 = fit_decision{bestPx, bestPy,3};           % Adjusted R^2    
    % obtain the fitted plane which will be applied to the raw data
    correction_plane = feval(bestModel, xGrid,yGrid);
    % apply the correction plane to the data.
    dataCorrected = data - correction_plane;
    dataCorrected = dataCorrected-min(dataCorrected(:));
    % prepare the output
    varargout{1}=dataCorrected;
    varargout{2}=correction_plane;
    varargout{3}=fit_decision_final_plane;
    delete(wb)
    
    % Note: previous versions applied also the shifting by min value of the entire lateral deflection matrix.
    % After proper investigation, it has been found out that it is wrong shifting both before and after
    % applying any tipe of correction (plane or lineXline fitting), because the fitting "implies" already the shifting.
    % The following lines are examples of wrong shifting ==> NO SHIFT AT ALL
    % Lateral_Trace_preShift_1                  = Lateral_Trace -min(Lateral_Trace(:));    
    % Lateral_Trace_corrPlane_preShift_2        = Lateral_Trace_preShift_1 - correction_plane;
    % Lateral_Trace_corrPlane_prePostShift_3    = Lateral_Trace_corrPlane_preShift_2-min(Lateral_Trace_corrPlane_preShift_2(:));
    %
    % just apply correction plane to raw data. it is already shifting
    % Lateral_Trace_corrPlane = Lateral_Trace - correction_plane;
    warning('on', 'curvefit:prepareFittingData:removingNaNAndInf');
end