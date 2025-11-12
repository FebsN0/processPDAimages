function [AFM_Images,IO_Image]=A2_feature_process_1_fitHeightChannel(filtData,iterationMain,idxMon,filepath,varargin)

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
    argName = 'fitOrder';  defaultVal = 'Low';        addParameter(p, argName, defaultVal, @(x) ismember(x, {'Low', 'Medium', 'High'}));
    argName = 'SeeMe';     defaultVal = 'Yes';         addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,filtData,varargin{:});
    clearvars argName defaultVal
    
    % if this is seconf time that the A3 is called, like for the second AFM section, keep the accuracy of
    % first section
    accuracy=p.Results.fitOrder;

    if(strcmp(p.Results.Silent,'Yes'));  SeeMe=0; else, SeeMe=1; end
    
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

    height_image=AFM_Images(1).AFM_image;
    wb=waitbar(0/size(height_image,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(height_image,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(height_image,2);    
    
    % Polynomial baseline fitting (line by line) ==> remove the "tilted" effect, which is order 1
    poly_filt_data=zeros(size(height_image,1),size(height_image,2));
    for i=1:size(height_image,2)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling'), error('Process cancelled'), end
        end
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double,
        % converting complex to  real and returning data as columns regardless of the input shapes.
        % extract the i-th column of the image ==> fitting on single column (fast lines)
        [xData,yData] = prepareCurveData((1:size(height_image,1))',height_image(:,i));
        % in case of insufficient number of values for a given line (like entire line removed previously), skip the fitting
        % find better solution to manage these lines...
        if length(xData) <= 2 || length(yData) <= 2
            warning("The %d-th line has not enough data for fitting ==> skipped",i)
            poly_filt_data(:,i)=height_image(:,i);
            continue
        end
        % Linear polynomial curve
        ft = fittype( 'poly1' );
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
        fitresult=fit(xData,yData, ft );
        % like the plan fitting, create new vector of same length as well as line of the height image
        xData = 1:size(height_image,1); xData=xData';
        % dont use the offset p2, rather the first value of the i-th column
        baseline_y=(fitresult.p1*xData+height_image(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        flag_poly_filt_data=height_image(:,i)-baseline_y;
        poly_filt_data(:,i)=flag_poly_filt_data-min(min(flag_poly_filt_data));
    end
    
    titleData='Height (measured) channel - Line Tilted effect removed';
    nameFile='resultA3_1_HeightRemovedTiltLine';
    showData(idxMon,SeeMe,poly_filt_data,true,titleData,'',filepath,nameFile)
    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
    close gcf

    waitbar(0/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter...'));
    % distribute the fitted data among bins using N bins. OUTUPUT: Y=bin counts; E= bin edges
    % many will be zero (background), whereas other will be low to high height
    [Y,E] = histcounts(poly_filt_data,10000);
    % set the parameters for Butterworth filter ==> little recap: it is a low-pass filter with a frequency
    % response that is as flat as possible in the passband
    fc = 5; % Cut off frequency
    fs = size(height_image,2); % Sampling rate
    % Butterworth filter of order 6 with normalized cutoff frequency Wn
    % Return transfer function coefficients to be used in the filter function
    [b,a] = butter(6,fc/(fs/2)); 
    Y_filtered = filter(b,a,Y); % filtered signal using the Butterworth coefficients
    Y_filered_diff=diff(diff(Y_filtered));      % substract twice the right next element in array
    
    bk_limit=1;
    N_Cycluse_waitbar=size(Y_filered_diff,2);
    % Identifying Backgrownd value
    for i=2:size(Y_filered_diff,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter ... Identifying Backgrownd %2.1f %%',i/N_Cycluse_waitbar*100));
        if(Y_filered_diff(1,i-1)<=0)&&(Y_filered_diff(1,i)>0)
            bk_limit=i;
            waitbar(1,wb,sprintf('Backgrownd Identified!'));
            break
        end
    end
    
    %%% MAYBE NOT NECESSARY ANYMORE: not really clear how much useful it is... it is like what have done
    %%% before, but 3dimensional to remove tilted plane instead of from single fast line.
    %%% I have compared the figures of before and after the following snippet and there are apparently no
    %%% difference (of course the matric are different)
    % Fitting of linear polynomial surface to the result of Poly1 fit
    backgrownd_th=E(1,bk_limit);
    Bk_poly_filt_data=poly_filt_data;
    Bk_poly_filt_data(Bk_poly_filt_data>backgrownd_th)=NaN;
    
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
    filt_data_no_Bk=minus(poly_filt_data,fit_surf);
    filt_data_no_Bk=filt_data_no_Bk-min(min(filt_data_no_Bk));
    % show the results
    titleData='Height (measured) channel - Surface Tilted effect removed';
    nameFile='resultA3_2_HeightRemovedTiltSurface';
    showData(idxMon,SeeMe,filt_data_no_Bk,true,titleData,'',filepath,nameFile)
    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
    close gcf

    warning ('off','all');
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    while true      
        if strcmp(accuracy,'Low')
            limit=3;
        elseif strcmp(accuracy,'Medium')
            limit=6;
        else
            limit=9;
        end
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
        showData(idxMon,SeeMe,AFM_noBk*1e9,false,title1,'Height (nm)',filepath,'resultA3_3_HeightLineFitted_noNorm')    
        showData(idxMon,true,AFM_noBk,true,title1,'',filepath,'resultA3_3_HeightLineFitted_norm')    
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
    nameFile=sprintf('resultA3_4_BaselineForeground_iteration%d',iterationMain);
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


