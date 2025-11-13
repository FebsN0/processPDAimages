function [AFM_Images,IO_Image,varargout]=A2_feature_process_1_fitHeightChannel(filtData,iterationMain,idxMon,filepath,varargin)

% The function extracts Images from the experiments.
% It removes baseline and extracts foreground from the AFM image.
%
% INPUT:    1) input = output of A2_CleanUpData2_AFM function which contains Height (measured), Lateral
%                      Deflection and Vertical Deflection, all in TRACE
%           2) optional input:
%               A) Accuracy: Low (default)  | Medium | High
%
% The function uses a series a total of three parts to remove the baseline from the Height Image.
%   1) first order linear polinomial curve fitting for correct the height imahe by this baseline 
%   2) buttorworth filter backgrownd algorithm
%   3) Poly11: linear polynomial surface is fitted to results of Poly1 fitting, the fitted surface is subtracted from
%      the results of Poly1 fitting (poly_filt_data), yielding filt_data_no_Bk_visible_data
%   4) iterative backgrownd removal, in which R^2 and RMS residuals are used to calculate the final backgrownd
% The output is binary image of the height (background + foreground)
%
% Author: Dr. R.D.Ortuso, Levente Juhasz
% University of Geneva, Switzerland.
%
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 27/08/2024
%
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types
    % and properties of inputs. This helps to make functions more robust and user-friendly.
    p=inputParser();    %init instance of inputParser
    % Add required parameter and also check if it is a struct by a inner function end if the Trace_type are
    % all Trace
    addRequired(p, 'filtData', @(x) isstruct(x));
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And

    %then the values                                
    argName = 'fitOrder';       defaultVal = 'Low';       addParameter(p, argName, defaultVal, @(x) ismember(x, {'Low', 'Medium', 'High'}));
    argName = 'SeeMe';          defaultVal = true;        addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'Normalized';     defaultVal = false;        addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));

    % validate and parse the inputs
    parse(p,filtData,varargin{:});
    clearvars argName defaultVal
    
    % if this is seconf time that the A3 is called, like for the second AFM section, keep the accuracy of
    % first section
    norm=p.Results.Normalized;
    if norm, labelHeight=""; factor=1; else, labelHeight="Height (nm)"; factor=1e9; end
    accuracy=p.Results.fitOrder;
    SeeMe=p.Results.SeeMe;
    if strcmp(accuracy,'Low')
        limit=3;
    elseif strcmp(accuracy,'Medium')
        limit=6;
    else
        limit=9;
    end
    % Extract the height channel
    raw_data_Height=filtData(strcmp([filtData.Channel_name],'Height (measured)')).AFM_image;
    % Orient the image by counterclockwise 180° and flip to coencide with the Microscopy image through rotations
    % if the process is the first time, dont rotate again because the pre processed image is already rotated
    if iterationMain==1
        raw_data_Height=flip(rot90(raw_data_Height),2);
    end
    rawH=raw_data_Height;
    
    for i=1:size(filtData,2)
        if i==1             % put the fixed raw height data channel
            AFM_Images(i)=struct(...
                'Channel_name', filtData(i).Channel_name,...
                'Trace_type', filtData(i).Trace_type, ...
                'AFM_image', rawH); %#ok<AGROW>
        else
            if iterationMain==1
                temp_img=flip(rot90(filtData(i).AFM_image),2);
            else
                temp_img=filtData(i).AFM_image;
            end
            AFM_Images(i)=struct(...
                    'Channel_name', filtData(i).Channel_name,...
                    'Trace_type', filtData(i).Trace_type, ...
                    'AFM_image', temp_img); %#ok<AGROW>
        end
    end
    height_1_original=AFM_Images(1).AFM_image;


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% FIRST FITTING: FIRST ORDER PLANE FITTING ON ENTIRE DATA %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [xGrid, yGrid] = meshgrid(1:size(height_1_original,2), 1:size(height_1_original,1));
    % Extract background points without outliers
    [xData, yData, zData] = prepareSurfaceData(xGrid, yGrid, height_1_original);
    % Plane fit setup
    opts = fitoptions('Method', 'LinearLeastSquares');
    opts.Robust = 'LAR'; % robust fitting to reduce outlier effects
    % Fit a 1st-order plane (poly11)
    ft = fittype('poly11');
    [fitresult, gof] = fit([xData, yData], zData, ft, opts);
    % Compute metrics (optional)
    residuals = zData - feval(fitresult, xData, yData);
    SSE = sum(residuals.^2);
    n = length(yData);
    k = numel(coeffnames(fitresult));
    AIC = n * log(SSE / n) + 2 * k;
    % Store results
    firstFit_plane.fitOrder = 'poly11'; firstFit_plane.SSE = gof.sse; firstFit_plane.R2 = gof.adjrsquare; firstFit_plane.AIC = AIC;
    varargout{1} = firstFit_plane;
    % Obtain fitted correction plane
    correction_plane = feval(fitresult, xGrid, yGrid);
    % Apply correction
    height_image_2_corrPlane = height_1_original - correction_plane;
    
    %%%%% END PLANE FITTING
    wb=waitbar(0/size(height_image_2_corrPlane,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(height_image_2_corrPlane,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(height_image_2_corrPlane,2);    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% SECOND FITTING: FIRST ORDER LINExLINE FITTING %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    height_3_fitLine=zeros(size(height_image_2_corrPlane,1),size(height_image_2_corrPlane,2));
    for i=1:size(height_3_fitLine,2)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling'), error('Process cancelled'), end
        end
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double,
        % converting complex to  real and returning data as columns regardless of the input shapes.
        % extract the i-th column of the image ==> fitting on single column (fast lines)
        [xData,yData] = prepareCurveData((1:size(height_image_2_corrPlane,1))',height_image_2_corrPlane(:,i));
        % in case of insufficient number of values for a given line (like entire line removed previously), skip the fitting
        % find better solution to manage these lines...
        if length(xData) <= 2 || length(yData) <= 2
            warning("The %d-th line has not enough data for fitting ==> skipped",i)
            height_3_fitLine(:,i)=height_image_2_corrPlane(:,i);
            continue
        end
        % Linear polynomial curve
        ft = fittype( 'poly1' );
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
        fitresult=fit(xData,yData, ft );
        % like the plan fitting, create new vector of same length as well as line of the height image
        xData = 1:size(height_image_2_corrPlane,1); xData=xData';
        % dont use the offset p2, rather the first value of the i-th column
        baseline_y=(fitresult.p1*xData+height_image_2_corrPlane(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        height_3_fitLine(:,i)=height_image_2_corrPlane(:,i)-baseline_y;
    end
    % Display and save result
    
    % Display and save result
    titleData1 = {'Height channel';'First Correction: 1st order plane fitting'};
    titleData2 = {'Height channel';'Second Correction: 1st order LineByLine fitting'};

    nameFile = 'resultA2_1_HeightPlane_and_LineXLine_Correction';    
    showData(idxMon,SeeMe,height_image_2_corrPlane*factor,norm,titleData1,labelHeight,filepath,nameFile,'data2',height_3_fitLine*factor,'titleData2',titleData2);
    clear i n opts SSE k fitresult ft gof residuals xGrid yGrid xData yData zData titleData nameFile
 
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% REMOVE OUTLIERS THAT CAN NEGATIVELY AFFECT THE FITTING %%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % remove outliers line by line (single entire array with all the lines takes too much time) before plane
    % fitting using the masked AFM data containing only background. Change them with NaN       
    num_lines = size(height_3_fitLine, 2);
    height_4_outliersRemoved=zeros(size(height_3_fitLine));
    for i=1:num_lines
        yData = height_3_fitLine(:, i);
        [pos_outlier] = isoutlier(yData, 'gesd');
        while any(pos_outlier)
            yData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        height_4_outliersRemoved(:,i) = yData;
    end
    % plot. To better visual, change NaN into 0
    %height_4_outliersRemoved(isnan(height_4_outliersRemoved))=0;
    countOutliers=nnz(isnan(height_4_outliersRemoved));
    titleData1={'Height Deflection';'After 1st and 2nd fitting'}; titleData2={"Height Deflection";sprintf("%d Outliers removed (TOT: %d)",countOutliers,numel(height_4_outliersRemoved))};
    nameFig='resultA2_2_Height_RemovedOutliers';
    showData(idxMon,false,height_3_fitLine*factor,norm,titleData1,labelHeight,filepath,nameFig,'data2',height_4_outliersRemoved*factor,'titleData2',titleData2);
    

    waitbar(0/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter...'));
    


%%%%% MAYBE BETTER AVOID THIS AND ADD THE MANUAL SEPARATION AFTER HISTCOUNT

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% BUTTERWORTH FILTERING %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % After polynomial flattening, the image should have an average plane removed, but there can still be low-level background 
    % offsets or uneven residuals. The goal of this snippet is to automatically detect a "background" height threshold — a level 
    % that separates the flat background from the sample features — and to mask out (NaN) all pixels above that threshold.
    %
    % APPROACH: Rather than looking at the image spatially, the script looks at the statistical distribution of height values — i.e., the histogram.
    % The histogram often looks like this in AFM height maps:
    %   - a large peak at low height → background plane,
    %   - smaller counts at higher heights → real surface features
    % A low-pass Butterworth filter is applied to the histogram to smooth it and remove noise/spikes from pixel quantization or roughness variations.
    % Butterworth because it provides a smooth, monotonic response (flat in passband, no oscillations).
    % Ideal for cleaning noisy histogram data to identify peaks.
    
    % Original code uses 10'000 bins, which may be too fine for most AFM height ranges
    % Therefore, automatically adapt the number of bins based on data range and image size.
    numBins = min(5000, max(100, round(numel(height_4_outliersRemoved)/100))); % adaptive bin count
    % distribute the fitted data among bins using N bins and Normalize Y before filtering to make it scale-independent.
    [Y,E] = histcounts(height_4_outliersRemoved,numBins,'Normalization', 'pdf');
    % set the parameters for Butterworth filter ==> little recap: it is a low-pass filter with a frequency
    % response that is as flat as possible in the passband
    
    % Butterworth filter of order 6 with normalized cutoff frequency Wn
    % Return transfer function coefficients to be used in the filter function and then filter the data
    % ORIGINAL LINE: [b,a] = butter(order, fc/(fs/2)); where
    % - fc = 5                                      ==> Cut off frequency
    % - fs = fs = size(height_image_1_original,2)   ==> sampling frequency (number of pixels per line)
    % IMPROVED VERSION: Define fc as a fraction of Nyquist, directly specifying Wn (0–1 scale, where 1 corresponds to the Nyquist frequency).    
    Wn = 0.02;            % normalized cutoff (2% of Nyquist)
    [b,a] = butter(4, Wn);  % 4th order is usually enough
    Y_filtered = filtfilt(b,a,Y); % zero-phase filtering (better symmetry)

    % Second derivative of the filtered histogram to detect the inflection point — the point where the curvature changes sign.
    % That inflection marks the transition from the main background peak to the tail of higher-height values
    % ORIGINAL LINE: Y_filered_diff=diff(diff(Y_filtered)) ==> this approach is crude
    % it just looks for one zero crossing of the second derivative, which can fail if the histogram is multimodal or noisy.
    % IMPROVED VERSION: Use gradient-based peak analysis or findpeaks on the smoothed histogram derivative:
    % This finds the largest negative-to-positive transition, i.e., where the histogram slope changes most sharply
    dY = gradient(Y_filtered);
    [~, locs] = findpeaks(-dY, 'NPeaks', 1, 'SortStr', 'descend');
    bk_limit = locs(1);
    % all pixels above this height (i.e., part of the actual structure) are
    % masked (NaN), leaving only the flat background. add a small margin (e.g. 1–2 bins)
    backgrownd_th = E(bk_limit) + (E(2)-E(1)); % shift 1 bin up
    Bk_poly_filt_data = height_3_fitLine;
    Bk_poly_filt_data(Bk_poly_filt_data > backgrownd_th) = NaN;
    
    figure; hold on
    plot(E(1:end-1), Y_filtered, 'b', 'LineWidth', 1.5);
    xline(backgrownd_th, 'r--', 'LineWidth', 1);
    title('Butterworth-filtered height histogram with detected background limit');
    xlabel('Height'); ylabel('PDF');


    % suppress warning about removing NaN values
    id='curvefit:prepareFittingData:removingNaNAndInf';
    warning('off',id)
    
    x_Bk=1:size(Bk_poly_filt_data,2);
    y_Bk=1:size(Bk_poly_filt_data,1);
    [xData, yData, zData] = prepareSurfaceData( x_Bk, y_Bk, Bk_poly_filt_data );
    ft = fittype( 'poly11' );
    [fitresult, ~] = fit( [xData, yData], zData, ft );
    
    fit_surf=zeros(size(y_Bk,2),size(x_Bk,2));
    a=max(max(Bk_poly_filt_data));
    y_Bk_surf=repmat(y_Bk',1,size(x_Bk,2))*fitresult.p01;
    x_Bk_surf=repmat(x_Bk,size(y_Bk,2),1)*fitresult.p10;
    fit_surf=plus(a,fit_surf);
    fit_surf=plus(y_Bk_surf,fit_surf);
    fit_surf=plus(x_Bk_surf,fit_surf);
    % Subtraction of fitted polynomial background
    filt_data_no_Bk=minus(height_image_2_corrPlane,fit_surf);
    filt_data_no_Bk=filt_data_no_Bk-min(min(filt_data_no_Bk));
    % show the results
    titleData='Height (measured) channel - Surface Tilted effect removed';
    nameFile='resultA2_3_HeightRemovedTiltSurface';
    showData(idxMon,SeeMe,filt_data_no_Bk,norm,titleData,'',filepath,nameFile);



    warning ('off','all');
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    while true      
        
        % Initialize variables
        fit_decision_final = nan(size(filt_data_no_Bk, 2), 4 + limit);
        % create a zero matrix with the same size of the original data
        Bk_iterative = zeros(size(filt_data_no_Bk));
        N_Cycluse_waitbar = size(filt_data_no_Bk,2);
        % build array abscissas for the fitting
        x = (1:size(filt_data_no_Bk,1))';
        % Polynomial baseline fitting (line by line) - Linear least squares fitting to the results. GOAL:
        % extract the background to remove from the data
        for i=1:size(filt_data_no_Bk,2)
            if(exist('wb','var')) && getappdata(wb, 'canceling')
                   error('Process cancelled')
            end
            % First remove outliers (i.e. exclude the true data which represents the features of interest of
            % PDA). Indeed, baseline fitting should only use low-intensity (i.e. background) values. The
            % presence of such outliers create wrong bias during the fitting and can distort polynomial fitting. 
            % Removing them ensures a smoother and more reliable baseline correction!           
            flag_signal_y = filt_data_no_Bk(:,i); % Take the i-th fast scan line           
            % STEP 1: Initial Low-Order Polynomial Fit (e.g., Quadratic)
            % this is new and another way to use a dynamic threshold instead of a fixed value.
            % The initial polynomial fit provides a better guess for outlier removal, preventing extreme peaks from affecting the final polynomial fit.
            % It makes the baseline correction more stable and less affected by noise.
            xData = (1:length(flag_signal_y))';
            validIdx = ~isnan(flag_signal_y);
            polyInit = polyfit(xData(validIdx), flag_signal_y(validIdx), 2);
            baselineInit = polyval(polyInit, xData); % Estimated baseline
            % Step 2: Remove Points Above This Estimated Baseline
            threshold = baselineInit + std(flag_signal_y(validIdx)); % 1 standard deviation above baseline                   
            % The baseline usually lies below the median, so this step removes higher values that may belong to the real signal rather than the baseline.
            %%%%    threshold = median(flag_signal_y);
            % Exclude top 20% instead of median  
            %%%%    threshold = prctile(flag_signal_y, 80);   
            % first round of outliers removal
            flag_signal_y(flag_signal_y >= threshold) = NaN;                      
            % STEP 3: Remove remaining outliers Iteratively, not just the most extreme one.
            % GESD test is useful when the number of outliers is unknown
            [pos_outlier] = isoutlier(flag_signal_y, 'gesd');
            while any(pos_outlier)
                flag_signal_y(pos_outlier) = NaN;
                [pos_outlier] = isoutlier(flag_signal_y, 'gesd');
            end
            % Step 4: Fit Final Polynomial Using AIC-Optimized Degree
            % Prepare valid data for fitting            
            xData = x(~isnan(flag_signal_y));
            yData = flag_signal_y(~isnan(flag_signal_y));
            % Handle insufficient data. Leave empty the i-th bk fast scan line (maybe because the line is
            % entirely made of crystal PDA)
            if length(xData) <= 3
                Bk_iterative(:,i) = NaN;
                continue;
            end            
            % Initialize AIC results
            aic_values = nan(1, limit);
            models = cell(1, limit);            
            % Test polynomial fits up to the limit
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
            fit_decision_final(i, 1) = bestIdx;
            fit_decision_final(i, 2) = aic_values(bestIdx);
            fit_decision_final(i, 3) = sum((yData - polyval(bestModel.Coefficients, xData)).^2); % SSE
            fit_decision_final(i, 4:4 + bestIdx) = bestModel.Coefficients;            
            % Generate baseline using the best polynomial fit
            Bk_iterative(:, i) = polyval(bestModel.Coefficients, x);
            % Progress update
            waitbar(i/N_Cycluse_waitbar, wb, sprintf('AIC-based background fitting - Line %.0f completed %.1f%%', i, i/N_Cycluse_waitbar*100));
        end

        % Handle NaN lines by interpolation. In case of those lines entirely made of NaN
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
        AFM_noBk=filt_data_no_Bk-Bk_iterative;
        AFM_noBk=AFM_noBk-min(AFM_noBk(:));
        % plot the resulting corrected data
        title1='Height (measured) channel - Single Line Fitted';        
        showData(idxMon,SeeMe,AFM_noBk*1e9,false,title1,'Height (nm)',filepath,'resultA2_4_HeightLineFitted_noNorm')    
        showData(idxMon,true,AFM_noBk,true,title1,'',filepath,'resultA2_4_HeightLineFitted_norm')    
        if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
            close gcf, break
        end
    end
    % start the binarization to create the 0/1 height image. At the same time show normal and logical image
    % for better comparison
    AFM_noBk_visible_data=imadjust(AFM_noBk/max(AFM_noBk(:))); % normalize for better show data
    f4=figure;
    subplot(121), imshow(AFM_noBk_visible_data),colormap parula, axis on
    title('Height (measured) channel - Single Line Fitted', 'FontSize',16)
    objInSecondMonitor(f4,idxMon);
    c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
    ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)

    first_In=1;
    closest_indices=[];
    no_sub_div=1000;
    % Binarisation of the bg-subtracted image
    while true
        kernel=strel('square',3); % can be modified
        if(first_In==1)
            % original
            T = adaptthresh(mat2gray(AFM_noBk));
            seg_AFM = imbinarize(mat2gray(AFM_noBk),T);
        else
            clearvars seg_AFM th_segmentation seg_binarized           
            imhistfig=figure('visible','on');hold on,plot(Y)
            if any(closest_indices)
                scatter(closest_indices,Y(closest_indices),40,'r*')
            end
            pan on; zoom on;
            % show dialog box before continue. Select the thresholding
            uiwait(msgbox('Before click to continue the binarization, zoom or pan on the image for a better view',''));
            zoom off; pan off;
            closest_indices=selectRangeGInput(1,1,1:no_sub_div,Y);
            th_segmentation=E(closest_indices);
            close(imhistfig)
            seg_AFM=AFM_noBk;
            seg_AFM(seg_AFM<th_segmentation)=0;
            seg_AFM(seg_AFM>=th_segmentation)=1;
        end       
        seg_binarized=imerode(seg_AFM,kernel);
        seg_binarized=imdilate(seg_binarized,kernel);
        if exist('h1', 'var') && ishandle(h1)
            delete(h1);
        end
        h1=subplot(122);
        imshow(seg_binarized); title('Baseline and foreground processed', 'FontSize',16), colormap parula
        colorbar('Ticks',[0 1],...
         'TickLabels',{'Background','Foreground'},'FontSize',13)

        
        satisfied=questdlg('Keep automatic threshold selection or turn to Manual?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
        if(first_In==1)
            if(strcmp(satisfied,'Manual Selection'))
                [Y,E] = histcounts(AFM_noBk,no_sub_div);
                first_In=0;
            end
        end
        if strcmp(satisfied,'Keep Current')
            break
        end
    end
    % often the 
    question='Satisfied of the effective binarization? If not, run ImageSegmenter ToolBox for better manual binarization';
    options={'Yes','No'};
    if ~getValidAnswer(question,'',options)
        close(f4)
        f5=figure;
        imshow(AFM_noBk_visible_data),colormap parula, axis on
        title('Height (measured) channel - CLOSE THIS WINDOW WHEN SEGMENTATION TERMINATED', 'FontSize',16)
        objInSecondMonitor(f5,idxMon);
        c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        % for some reasons, the exported variable is stored in the base workspace, outside the current
        % function. So take it from there. Save the workspace of before and after and take the new variables.
        tmp1=evalin('base', 'who');
        imageSegmenter(AFM_noBk_visible_data), colormap parula
        waitfor(f5)
        tmp2=evalin('base', 'who');
        varBase=setdiff(tmp2,tmp1);
        for i=1:length(varBase)            
            text=sprintf('%s',varBase{i});
            var = evalin('base', text);
            ftmp=figure;
            imshow(var), colormap parula            
            if getValidAnswer('Is the current figure the right binarized AFM?','',{'Yes','No'})
                close(ftmp)
                seg_binarized=var;
                break
            end
            close(ftmp)
        end
        clear tmp* vtmp var ftmp
    end
     
    % show data
    titleData=sprintf('Baseline and foreground processed - Iteration %d',iterationMain);
    nameFile=sprintf('resultA2_5_BaselineForeground_iteration%d',iterationMain);
    showData(idxMon,SeeMe,seg_binarized,false,titleData,'',filepath,nameFile,'Binarized',true)
    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
    close gcf    
    IO_Image=logical(seg_binarized);
    if(exist('wb','var'))
        delete (wb)
    end
end


