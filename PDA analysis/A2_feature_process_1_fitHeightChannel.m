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
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% REMOVE OUTLIERS (remove anomalies like high spikes) %%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % this solution is more adaptive and less aggressive than removing 99.5
    % percentile. Remove outliers line by line ==> more prone to remove spikes!
    num_lines = size(height_1_original, 2);
    height_2_outliersRemoved=zeros(size(height_1_original));
    countOutliers=0;
    for i=1:num_lines
        yData = height_1_original(:, i);
        [pos_outlier] = isoutlier(yData, 'gesd');        
        while any(pos_outlier)
            countOutliers=countOutliers+nnz(pos_outlier);
            yData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        height_2_outliersRemoved(:,i) = yData;
    end
    fprintf("\nBefore First 1st order plan fitting, %d outliers have been removed!\n",countOutliers)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% FIRST FITTING: FIRST ORDER PLANE FITTING ON ENTIRE DATA %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [height_image_3_corrPlane,planeFit] = planeFitting_N_Order(height_2_outliersRemoved,1);  
    height_image_3_corrPlane=height_image_3_corrPlane-min(height_image_3_corrPlane(:));
    % Display and save result
    titleData1 = {'First Order Plane';'Fitted on Raw Height Channel'};
    titleData2 = {'Height channel';'First Correction: 1st order plane fitting and shifted toward zero'};
    nameFile = 'resultA2_1_Plane1order_correctedHeight';    
    showData(idxMon,SeeMe,planeFit*factor,norm,titleData1,labelHeight,filepath,nameFile,'data2',height_image_3_corrPlane*factor,'titleData2',titleData2);   
           
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% BUTTERWORTH FILTERING : an automatic binarization but not for binarize the image, rather for better fitting %%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
    numBins = min(5000, max(100, round(numel(height_image_3_corrPlane)/100))); % adaptive bin count
    % distribute the fitted data among bins using N bins and Normalize Y before filtering to make it scale-independent.
    [Y,E_height] = histcounts(height_image_3_corrPlane,numBins,'Normalization', 'pdf');
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
    E_height=E_height*1e9;
    background_th = E_height(bk_limit);     % express in nm
    thresholdApproach="Automatic";
    % HOWEVER, it doesnt work always, so also manual selection
    fbutter=figure; hold on
    plot(E_height(1:end-1), Y_filtered, 'b', 'LineWidth', 2,'DisplayName','Butterworth-filtered Height');
    xline(background_th, 'r--', 'LineWidth', 1.5,'DisplayName','Background Automatic (2nd derivative) threshold');       
    title('First background detection with butterworth-filtered Height','FontSize',16); legend('FontSize',15)
    xlabel('Height (nm)','FontSize',14); ylabel('PDF (Probability Density Function on Count','FontSize',14);
    xlim tight, grid on
    objInSecondMonitor(fbutter,idxMon)
    pause(2)
    question=sprintf(['Is the threshold to separate Background from Foreground good enough?\n'...
        'NOTE: it is not necessary to be precise because this step is not for binarization,\nbut at least should approximately separate the two regions.']);
    if ~getValidAnswer(question,"",{'Yes','No'})
        uiwait(msgbox('Click on the plot to define the threshld to separate Background from Foreground',''));
        closest_indices=selectRangeGInput(1,1,E_height(1:end-1), Y_filtered);
        background_th=E_height(closest_indices);
        xline(background_th, 'g--', 'LineWidth', 1.5,'DisplayName','Background Manual threshold'); 
        thresholdApproach="Manual";
    end        
    saveFigures_FigAndTiff(fbutter,filepath,'resultA2_3_ButterworthFilteredHeight_backgroundDetection')   
    % all pixels above this height (i.e., part of the actual structure) are
    % masked (NaN), leaving only the flat background    
    BK_butterworthFiltered = height_image_3_corrPlane;
    BK_butterworthFiltered(BK_butterworthFiltered > background_th*1e-9) = NaN;
    clear fbutter closest_indices background_th numBins Y E_height Wn b a Y_filtered dY locs bk_limit
    titleData=sprintf('Background Height - Butterworth Filtered Height and separated by %s threshold',thresholdApproach);     
    nameFile='resultA2_4_BackgroundHeight_butterworth';   
    showData(idxMon,SeeMe,BK_butterworthFiltered*factor,norm,titleData,labelHeight,filepath,nameFile);
  
    % suppress warning about removing NaN values
    %  id='curvefit:prepareFittingData:removingNaNAndInf';
    %  warning('off',id)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% THIRD FITTING: N ORDER PLANE FITTING ON BUTTERWORTH FILTERED BACKGROUND %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    [BK_butterworthFiltered_Fitted,planeCorrection,metrics] = planeFitting_N_Order(BK_butterworthFiltered,limit);
    height_4_firstBKfit=height_image_3_corrPlane-planeCorrection;       
    % shift the entire data toward zero (background should be zero)
    height_4_firstBKfit=height_4_firstBKfit-(min(height_4_firstBKfit(:)));
    % show the results
    titleData1={'Plane fitted';sprintf('Order Plane: %s',metrics.fitOrder)};
    titleData2={'Background Height';'Butterworth Filtered Height and Plan Fitted'};     
    nameFile='resultA2_4_Plane_Background';   
    showData(idxMon,SeeMe,planeCorrection*factor,norm,titleData1,labelHeight,filepath,nameFile,'data2',BK_butterworthFiltered_Fitted*factor,'titleData2',titleData2);
    titleData={'Height Channel corrected';'Butterworth-filtered, BK detection, fitted Height shifted toward zero.'};  
    nameFile='resultA2_5_correctedHeight_afterButterworthBKfit';
    showData(idxMon,SeeMe,height_4_firstBKfit*factor,norm,titleData,labelHeight,filepath,nameFile);
    clear titleData* nameFile
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% FORTH FITTING: N ORDER LINE-BY-LINE FITTING THE NEW PLANE-FITTED HEIGHT %%%%
    %%%  (Note: not masked. It turned out using the previous BK as mask is worse) %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    height_5_lineXlineFIT = lineByLineFitting_N_Order(height_4_firstBKfit,limit);
    height_5_lineXlineFIT = height_5_lineXlineFIT-min(height_5_lineXlineFIT(:));
    % plot the resulting corrected data
    title1='Height (measured) channel - Single Line Fitted and shifted toward zero';        
    showData(idxMon,SeeMe,height_5_lineXlineFIT*1e9,false,title1,'Height (nm)',filepath,'resultA2_6_HeightLineFitted_noNorm');
    showData(idxMon,SeeMe,height_5_lineXlineFIT,true,title1,'',filepath,'resultA2_6_HeightLineFitted_norm');  

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BINARIZATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % start the binarization to create the 0/1 height image. At the same time show normal and logical image
    % for better comparison
    AFM_noBk_visible_data=imadjust(height_5_lineXlineFIT/max(height_5_lineXlineFIT(:))); % normalize for better show data
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
            T = adaptthresh(mat2gray(height_5_lineXlineFIT));
            seg_AFM = imbinarize(mat2gray(height_5_lineXlineFIT),T);
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
            th_segmentation=E_height(closest_indices);
            close(imhistfig)
            seg_AFM=height_5_lineXlineFIT;
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
                [Y,E_height] = histcounts(height_5_lineXlineFIT,no_sub_div);
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
    nameFile=sprintf('resultA2_7_BaselineForeground_iteration%d',iterationMain);
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


%%%%%%%%%%%%%%%%%
%%% FUNCTIONS %%%
%%%%%%%%%%%%%%%%%

function varargout = planeFitting_N_Order(data,limit)
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
    % apply correction plane to raw data
    % Lateral_Trace_corrPlane = Lateral_Trace - correction_plane;
end

function  varargout = lineByLineFitting_N_Order(data,limit)
% Polynomial baseline fitting (line by line) - Linear least squares fitting to the results.
% GOAL: extract the background to remove from the data
    
    % warning ('off','all');

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
        if length(xData) <= 3
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

