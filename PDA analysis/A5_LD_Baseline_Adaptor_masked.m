% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function varargout=A5_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,alpha,idxMon,newFolder,mainPath,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    warning ('off','all'); 
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    
    varargout=cell(1,3);

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'FitOrder';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'Silent';     defaultVal = 'Yes';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));

    parse(p,varargin{:});
    clearvars argName defaultVal
    if strcmp(p.Results.Silent,'Yes'); SeeMe=0; else, SeeMe=1; end
    if strcmp(p.Results.FitOrder,'Low'); limit=3; elseif strcmp(p.Results.FitOrder,'Medium'), limit=6; else, limit=9; end
    
    % select a single line manually to check the LD
    figure, imagesc(AFM_height_IO), objInSecondMonitor(idxMon,gcf)
    uiwait(msgbox(sprintf('Select a point on the mask where analyze the single fast scan line'),''));
    idxLine=selectRangeGInput(1,1,1:size(AFM_height_IO,2),1:size(AFM_height_IO,1));
    close gcf
    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace   = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);
    %Lateral_ReTrace = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'ReTrace')).AFM_image);
    vertical_Trace  = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Vertical Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);    
    % Mask W to cut the PDA from the baseline fitting. Where there is PDA in corrispondece of the mask, then mask the
    % lateral deflection data. Basically, the goal is fitting using the glass which is know to be flat. 
    Lateral_Trace_BK_1_maskOnly= Lateral_Trace;
    Lateral_Trace_BK_1_maskOnly(AFM_height_IO==1)=NaN;
    % check distribution of the LD data
    Lateral_Trace_masked_FRonly = Lateral_Trace;
    Lateral_Trace_masked_FRonly(AFM_height_IO==0)=NaN;
    % organize the data to show in figures
    DataXdistribution= {Lateral_Trace_BK_1_maskOnly,'Raw BK'; ...
                        Lateral_Trace_masked_FRonly,'Raw FR'};
    DataXSingleLine={Lateral_Trace,AFM_height_IO}; 

    idCall=1;
    % show LD value distribution of the entire matrix
    figDistr=checkDistributionDataLD(idCall,SeeMe,idxMon,DataXdistribution);
    % show LD of a single fast scan line (idx manually selected previously)
    figSingleLine=plotSingleLineCheck(idCall,idxMon,DataXSingleLine,idxLine);
    idCall=idCall+1;


    % remove outliers line by line (single entire array with all the lines takes too much time) before plane
    % fitting using the masked AFM data containing only background. Change them with NaN       
    num_lines = size(Lateral_Trace_BK_1_maskOnly, 2);
    Lateral_Trace_BK_2_firstClear=zeros(size(Lateral_Trace_BK_1_maskOnly));
    for i=1:num_lines
        yData = Lateral_Trace_BK_1_maskOnly(:, i);
        [pos_outlier] = isoutlier(yData, 'gesd');
        while any(pos_outlier)
            yData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        Lateral_Trace_BK_2_firstClear(:,i) = yData;
    end
    % plot. To better visual, change NaN into 0
    Lateral_Trace_BK_2_firstClear(isnan(Lateral_Trace_BK_2_firstClear))=0;
    titleData1='Raw Lateral Deflection - Trace'; titleData2='Background with removed outliers';
    nameFig='resultA5_1_RawLateralData_BackgroundNoOutliers';
    showData(idxMon,SeeMe,2,Lateral_Trace,false,titleData1,'Voltage [V]',newFolder,nameFig,'data2',Lateral_Trace_BK_2_firstClear,'titleData2',titleData2)
    % rechange to NaN
    Lateral_Trace_BK_2_firstClear(Lateral_Trace_BK_2_firstClear==0)=NaN;
    % plane fitting
    [xGrid, yGrid] = meshgrid(1:size(Lateral_Trace_BK_2_firstClear,2), 1:size(Lateral_Trace_BK_2_firstClear,1));
    % Estrarre solo i punti di background without outliers
    [xData, yData, zData] = prepareSurfaceData(xGrid,yGrid,Lateral_Trace_BK_2_firstClear);    
    % init and prepare the setting for the fitting
    models = cell(limit+1, limit+1);
    opts = fitoptions('Method', 'LinearLeastSquares');
    opts.Robust = 'LAR';
    fit_decision = zeros(limit+1,limit+1,3);
    fit_decision_final_plane = struct();
    wb=waitbar(1/(limit*limit),sprintf('Removing Plane Polynomial Baseline orderX: %d orderY: %d',0,0),...
            'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
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
            fit_decision(px + 1, py + 1,1) = aic_values;
            fit_decision(px + 1, py + 1,2) = gof.sse;
            fit_decision(px + 1, py + 1,3) = gof.adjrsquare;
            i=i+1;                   
        end
    end
    
    % Select best model using AIC
    [~, bestIdx] = min(fit_decision(:,:,1),[],'all');
    [bestPx, bestPy] = ind2sub(size(fit_decision(:,:,1)), bestIdx);
    bestModel = models{bestPx, bestPy};
    % Save fitting decisions
    fitTypeM=sprintf('poly%d%d', bestPx-1, bestPy-1);
    fit_decision_final_plane.fitOrder = fitTypeM;
    fit_decision_final_plane.SSE = fit_decision(bestPx, bestPy,2); % SSE
    fit_decision_final_plane.R2 = fit_decision(bestPx, bestPy,3); % Adjusted R^2
    % obtain the fitted plane which will be applied to the raw data
    correction_plane = feval(bestModel, xGrid,yGrid);
    clear i n opts SSE k aic_values fit_decision fitresult fitTypeM ft gof models pos_outlier px py residuals varargin xGrid yGrid xData yData zData titleData* nameFig
    % apply the correction plane to the lateral data.
    % Note: previous versions applied also the shifting by min value of the entire lateral deflection matrix.
    % After proper investigation, it has been found out that it is wrong shifting both before and after
    % applying any tipe of correction (plane or lineXline fitting), because the fitting "implies" already the shifting.
    % The following lines are examples of wrong shifting ==> NO SHIFT AT ALL
    % Lateral_Trace_preShift_1                  = Lateral_Trace -min(Lateral_Trace(:));    
    % Lateral_Trace_corrPlane_preShift_2        = Lateral_Trace_preShift_1 - correction_plane;
    % Lateral_Trace_corrPlane_prePostShift_3    = Lateral_Trace_corrPlane_preShift_2-min(Lateral_Trace_corrPlane_preShift_2(:));
    %
    % apply correction plane to raw data
    Lateral_Trace_corrPlane = Lateral_Trace - correction_plane;
    % even after applying correction plane at the no shifted lateral deflection data
    % Lateral_Trace_corrPlane_postShift = Lateral_Trace_corrPlane-min(Lateral_Trace_corrPlane(:));
    % show the results by distribution and single selected line
    Lateral_Trace_corrPlane_BK_1= Lateral_Trace_corrPlane;
    Lateral_Trace_corrPlane_BK_1(AFM_height_IO==1)=NaN;
    % check distribution of the LD data
    Lateral_Trace_corrPlane_FR_1 = Lateral_Trace_corrPlane;
    Lateral_Trace_corrPlane_FR_1(AFM_height_IO==0)=NaN;
    DataXdistribution= {Lateral_Trace_corrPlane_BK_1,'corrected PlaneFitt BK'; ...
                        Lateral_Trace_corrPlane_FR_1,'corrected PlaneFitt FR'};
    DataXSingleLine={Lateral_Trace_corrPlane,'corrected by planeFitting'};
    figDistr=checkDistributionDataLD(idCall,SeeMe,idxMon,DataXdistribution,'prevFig',figDistr);
    figSingleLine=plotSingleLineCheck(idCall,idxMon,DataXSingleLine,idxLine,'prevFig',figSingleLine);
    idCall=idCall+1;

    % plot
    titleData1='Plane Fitted Background';
    titleData2={'Lateral Deflection - Trace'; '(removed fitted plane and shifted)'};
    nameFig='resultA5_2_planeBKfit_LateralDeflection';
    showData(idxMon,true,1,correction_plane,false,titleData1,'Voltage [V]',newFolder,nameFig,'data2',Lateral_Trace_corrPlane,'titleData2',titleData2)    
    if getValidAnswer('Keep the Lateral Deflection with the plane-fitted background removed?','',{'Yes','No'})
        Lateral_Trace_firstCorr = Lateral_Trace_corrPlane;
        text='(Plane fitted BK removed)';
        varargout{2}=fit_decision_final_plane;
    else
        Lateral_Trace_firstCorr = Lateral_Trace;
        text='(Plane fitted BK not removed)';
    end
    % fit lineXline
    if getValidAnswer('Continue with LineXLine fitting?','',{'Yes','No'})
        while true        
            % apply the PDA mask, so the PDA data  will be ignored. Use now the background        
            Lateral_Trace_BK_1_maskOnly = Lateral_Trace_firstCorr;
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
                        ftmp=figure; plot(xValid,yValid,'*','DisplayName','Experimental Background','Color',globalColor(1))
                        hold on
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
                                plot(xValidtmp,yValidtmp,'*','DisplayName',sprintf('ExpBK line %d',idxPrev(j)),'Color',globalColor(j+1))
                                plot(Bk_iterative(:,idxPrev(j)),'Color',globalColor(j+1),'DisplayName',sprintf('FittedBK line %d',idxPrev(j)))
                            end
                        end
                        % +2 because second and/or third colors are used for the prev iteration
                        idxColor=numPrevRows+2;
                        plot(fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(1),'LineWidth',2,'LineStyle','--')                    
                        objInSecondMonitor(ftmp,idxMon)
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
                                plot(fittedline,'DisplayName',sprintf('Best Fitted curve - fitOrder: %d - %d° iteration',bestFitOrder,iteration),'Color',globalColor(idxColor),'LineWidth',2,'LineStyle','--')
                                idxColor=idxColor+1;
                            end
                        end
                        close gcf
                    end
                end 
                fit_decision_final_line(i)=fit_decision_final_tmp;
                Bk_iterative(:, i) = fittedline;
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
            Lateral_Trace_secondCorr = Lateral_Trace_firstCorr - Bk_iterative;
            % Plot the fitted backround:
            titleData1='Line x Line Fitted Background'; titleData2={'Lateral Deflection - Trace';text};
            nameFig='resultA5_3_LineBKfit_LateralDeflection';
            showData(idxMon,true,2,Bk_iterative,true,titleData1,'',newFolder,nameFig,'data2',Lateral_Trace_secondCorr,'titleData2',titleData2)
            if getValidAnswer('Satisfied of the fitting?','',{'y','n'})
                break
            end
        end
        
        varargout{3}=fit_decision_final_line;
        Lateral_Trace_corrLine_BK_2= Lateral_Trace_secondCorr;
        Lateral_Trace_corrLine_BK_2(AFM_height_IO==1)=NaN;
        % check distribution of the LD data
        Lateral_Trace_corrLine_FR_2 = Lateral_Trace_secondCorr;
        Lateral_Trace_corrLine_FR_2(AFM_height_IO==0)=NaN;
        DataXdistribution= {Lateral_Trace_corrLine_BK_2,'corrected LineXline BK'; ...
                            Lateral_Trace_corrLine_FR_2,'corrected LineXline FR'};
        DataXSingleLine={Lateral_Trace_secondCorr,'corrected by LineXLineFitted'};
        figDistr=checkDistributionDataLD(idCall,SeeMe,idxMon,DataXdistribution,'prevFig',figDistr);        
        figSingleLine=plotSingleLineCheck(idCall,idxMon,DataXSingleLine,idxLine,'prevFig',figSingleLine);
    else
        Lateral_Trace_secondCorr = Lateral_Trace_firstCorr;
    end

    % save distribution and singleLine
    nameResults='resultA5_4_DistributionLD_eachCorrectionStep';
    saveFigures(figDistr,newFolder,nameResults)
    nameResults='resultA5_5_singleFastScanLineLD_eachCorrectionStep';
    saveFigures(figSingleLine,newFolder,nameResults)

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
                avg_fc = A5_featureFrictionCalcFromSameScanHVOFF(idxMon,mainPath);
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
    
    % show the fast scan line in Force units (before was Volt)
    figSingleLineForce=figure; 
    hold on
    plot(Baseline_Friction_Force(:,idxLine)*1e9,'DisplayName','OFFSET (VD*fc)','LineWidth',1.5)
    plot(Lateral_Trace_Force(:,idxLine)*1e9,'DisplayName','F=Deflection*Alpha','LineWidth',1.5)
    plot(Corrected_LD_Trace(:,idxLine)*1e9,'DisplayName', 'corrected Force (F+OFFSET)','LineWidth',1.5)
    legend('FontSize',15), grid on, grid minor
    title(sprintf("(FORCE) fast scan line # %d",idxLine),'FontSize',20)
    xlabel('fast scan line [pixel]','FontSize',15)
    ylabel('Lateral Force [nN]','FontSize',15)
    objInSecondMonitor(figSingleLineForce,idxMon);
    nameFig='resultA5_6_singleFastScanLineLD_FORCE';
    saveFigures(figSingleLineForce,newFolder,nameFig)

    % plot the definitive corrected lateral force
    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA5_7_ResultsDefinitiveLateralDeflectionsNewton_normalized';
    showData(idxMon,SeeMe,3,Corrected_LD_Trace,true,titleData,'',newFolder,nameFig)
    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA5_7_ResultsDefinitiveLateralDeflectionsNewton';
    labelFig='Force [nN]';
    showData(idxMon,SeeMe,3,Corrected_LD_Trace*1e9,false,titleData,labelFig,newFolder,nameFig)

    % save the corrected lateral force into cropped AFM image
    AFM_Elab=AFM_cropped_Images;    
    AFM_Elab(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image=Corrected_LD_Trace;

    varargout{1}=AFM_Elab;    
end


%%%%%%%%%%%%%%%%%%%%%
%%%%% FUNCTIONS %%%%%
%%%%%%%%%%%%%%%%%%%%%

function figDistr=checkDistributionDataLD(idCall,SeeMe,idxMon,Data,varargin)
    p=inputParser();
    argName = 'prevFig';    defaultVal = [];    addOptional(p,argName,defaultVal);   
    parse(p,varargin{:});
    if idCall==1
        if SeeMe
            figDistr=figure('Visible','on'); 
        else
            figDistr=figure('Visible','off'); 
        end
        % adjust pic
        legend('FontSize',15), grid on, grid minor
        xlabel('Lateral Deflection [V]','FontSize',15)
        title("Distribution Lateral Deflection and minimum values","FontSize",20)
        objInSecondMonitor(figDistr,idxMon);
       
    else
        figDistr=p.Results.prevFig;
        figure(figDistr)
    end
    hold on
    % extract the data
    DataBK=Data{1,1}; NameBK=Data{1,2};
    DataFR=Data{2,1}; NameFR=Data{2,2};
    % prepare histogram. round not work to excess but to nearest.
    xmin=floor(min(min(DataBK(:)),min(DataFR(:))) * 1000) / 1000;
    xmax=ceil( max(max(DataBK(:)),max(DataFR(:))) * 1000) / 1000;
    edges=(xmin:0.02:xmax);

    % show the original LD of BK
    DataCleaned_BK=DataBK(:); DataCleaned_BK(~isnan(DataCleaned_BK));
    histogram(DataCleaned_BK,'BinEdges',edges,"DisplayName",NameBK)
    % show the original LD of FR
    DataCleaned_FR=DataFR(:); DataCleaned_FR(~isnan(DataCleaned_FR));
    histogram(DataCleaned_FR,'BinEdges',edges,"DisplayName",NameFR)
    % check the abs min
    absMinBK=min(DataCleaned_BK);
    % check the min in corrispondence of 1 percentile
    percentile=1;      
    threshold = prctile(DataCleaned_BK, percentile);
    % show vertical line of different min BK
    xline(absMinBK,':','LineWidth',1.5,     'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min BK:       %.2e',absMinBK))
    xline(threshold,'--','LineWidth',1.5,   'Color',globalColor(idCall),'DisplayName',sprintf('Min 1 percentile BK:   %.2e',threshold))        
    % show vertical line of min FR
    absMinFR=min(DataCleaned_FR);
    xline(absMinFR,'.-','LineWidth',1.5,    'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min FR:       %.2e',absMinFR))
end

function figSingleLine=plotSingleLineCheck(idCall,idxMon,data,idxLine,varargin)
    p=inputParser();
    argName = 'prevFig';    defaultVal = [];    addOptional(p,argName,defaultVal);
    parse(p,varargin{:});
    clearvars argName defaultVal
    
    if idCall==1
        figSingleLine=figure;
        % adjust pic
        legend('FontSize',15), grid on, grid minor
        objInSecondMonitor(figSingleLine,idxMon);
        title(sprintf("fast scan line # %d",idxLine),'FontSize',20)
        xlabel('fast scan line [pixel]','FontSize',15)
        ylabel('Lateral Deflection [V]','FontSize',15)
        hold on
        Lateral_Trace=data{1};
        AFM_height_IO=data{2};        
        y = Lateral_Trace(:,idxLine);
        x = 1:length(y);
        LD_mask=AFM_height_IO(:,idxLine);
        % Imposta limiti verticali per i rettangoli trasparenti
        ymin = 0;        ymax = 1;
        % Imposta limiti orizzontali per i rettangoli trasparenti
        xmin = min(x) - round(0.1*range(x));
        xmax = max(x) + round(0.1*range(x));
        % Trova regioni contigue con stesso valore in LD_mask
        LD_mask_diff = [true; diff(LD_mask(:)) ~= 0; true]; % trova cambi
        idx_edges = find(LD_mask_diff);
        segments = [idx_edges(1:end-1), idx_edges(2:end)-1];
        % Colora le regioni
        for i = 1:size(segments,1)
            idx_start = segments(i,1);
            idx_end = segments(i,2);
            col = LD_mask(idx_start);  % 0 o 1
            
            if col == 1
                c = [0 0 1];  % blu
                typeIO='Foreground';
            else
                c = [1 0 0];  % rosso
                typeIO='Background';
            end        
            % Crea il rettangolo
            xPatch = [x(idx_start) x(idx_end) x(idx_end) x(idx_start)];
            yPatch = [ymin ymin ymax ymax];
            f=fill(xPatch, yPatch, c, 'FaceAlpha', 0.2, 'EdgeColor', 'none','DisplayName',typeIO);
            if i~=1 && i~=2 
                f.Annotation.LegendInformation.IconDisplayStyle = 'off';
            end
        end
        plot(Lateral_Trace(:,idxLine),'DisplayName','Raw LD','LineWidth',1.5)
        xlim([xmin xmax]);
        ylim([ymin ymax]);
    else
        figSingleLine=p.Results.prevFig;
        figure(figSingleLine)
        hold on
        Lateral_Trace=data{1};
        Lateral_Trace_name=data{2};
        plot(Lateral_Trace(:,idxLine),'DisplayName',Lateral_Trace_name,'LineWidth',1.5)
        hold off
        ylim padded
    end
end

function saveFigures(fig,nameDir,nameFig)
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(fig,fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(fig,fullnameFig) 
    close(fig)
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