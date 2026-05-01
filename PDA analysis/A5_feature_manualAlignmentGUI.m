% the output AFM_data will have new fields compared to the input AFM_data
% AFM_aligned is the version iteratively modified of AFM_scaled
% AFM_image_padded is AFM_aligned but with the size of AFM_IO_padded, which is the same for the BF_IO
function varargout=A5_feature_manualAlignmentGUI(AFM_IO_padded,BF_IO,AFM_start,rect,max_c_it_OI,idxMon,newFolder,varargin)
    p=inputParser(); 
    argName = 'saveFig';    defaultVal = 'Yes';     addParameter(p, argName, defaultVal, @(x) ismember(x,{'No','Yes'}));
    parse(p,varargin{:});
    if(strcmp(p.Results.saveFig,'Yes')), saveFig=1; else, saveFig=0; end

    % Create the main figure  
    hFig = figure('Name', 'Image Manipulation GUI', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 900, 700], 'MenuBar', 'none', ...
                  'ToolBar', 'none', 'Resize', 'off');
    % init a counter for the score trend
    counter=1;
    hCounterText = uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Counter: 0', ...
                             'Units', 'normalized', 'Position', [0.4, 0.25, 0.2, 0.05]);
    % init the trend plot
    maxC_original=max_c_it_OI;
    fig_TrendCC=figure; ax_TrendCC=axes(fig_TrendCC);
    h = animatedline(ax_TrendCC,'Marker','o');
    addpoints(h,0,1)
    ylabel(ax_TrendCC,'Normalized Cross-correlation Score','FontSize',12), xlabel(ax_TrendCC,'# cycles','FontSize',12)
    title(ax_TrendCC,'Trend Cross-correlation score','FontSize',14)
    hScoreCCText = uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Score (normalized): 1', ...
                             'Units', 'normalized', 'Position', [0.4, 0.225, 0.2, 0.05]);
    % keep trach the total rotation and matrix size changes
    totRotation_deg=0;
    hRotText = uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Rotation: 0°', ...
                             'Units', 'normalized', 'Position', [0.4, 0.20, 0.2, 0.05]);
    % init the aligned matrixs. Create a copy of it that will be iteratively modified. AFM_start is the original (scaled)
    nChannels=length(AFM_start);
    AFM_end=AFM_start;
    % find the logical channels
    flagLogical=cellfun(@islogical,AFM_start);
    % Load two images
    fixedImg1 = BF_IO;
    % extract only the AFM mask
    modifiedImg1=AFM_IO_padded(rect(3):rect(4),rect(1):rect(2));
    AFM_IO_resized_original=modifiedImg1; 
    % generate the first AFM_IO_padded to show in the figure
    exeSingleCrossCorr(true)
    % init counter for all the operation. Required to save all operation done in order to modify AFM data
    details_it_reg =[];
    % init the var where save the new coordinates of alignment
    rect=[];  
    % Display the combined image
    hAx = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.05, 0.3, 0.9, 0.65]);
    
    pairAFM_BF=imshowpair(fixedImg1,AFM_IO_padded,'falsecolor', 'Parent', hAx);
    title(hAx, 'BrightField (green) and AFM (purple) Images');

    % Create input fields and buttons for operations
    % button to resize (increase and decrease)
    uicontrol('Parent', hFig, 'Style', 'text', 'String', sprintf('Scale factor\n[rows cols]'), ...
              'Units', 'normalized', 'Position', [0.15, 0.2, 0.1, 0.05]);
    
    hResizeFactor = uicontrol('Parent', hFig, 'Style', 'edit', 'String', '1', ...
                              'Units', 'normalized', 'Position', [0.25, 0.2, 0.1, 0.05]);
    
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Expand', ...
              'Units', 'normalized', 'Position', [0.15, 0.15, 0.2, 0.05], ...
              'Callback', @(src, event) apply_resize(str2double(get(hResizeFactor, 'String'))));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Reduce', ...
              'Units', 'normalized', 'Position', [0.15, 0.1, 0.2, 0.05], ...
              'Callback', @(src, event) apply_resize(-str2double(get(hResizeFactor, 'String'))));

    uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Rotation Angle:', ...
              'Units', 'normalized', 'Position', [0.65, 0.2, 0.1, 0.05]);

    hRotationAngle = uicontrol('Parent', hFig, 'Style', 'edit', 'String', '1', ...
                               'Units', 'normalized', 'Position', [0.75, 0.2, 0.1, 0.05]);

    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Rotate CCW', ...
              'Units', 'normalized', 'Position', [0.65, 0.15, 0.2, 0.05], ...
              'Callback', @(src, event) apply_rotate(str2double(get(hRotationAngle, 'String'))));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Rotate CW', ...
              'Units', 'normalized', 'Position', [0.65, 0.1, 0.2, 0.05], ...
              'Callback', @(src, event) apply_rotate(-str2double(get(hRotationAngle, 'String'))));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Reset', ...
              'Units', 'normalized', 'Position', [0.4, 0.15, 0.2, 0.05], ...
              'Callback', @(src, event) reset());

    % button to terminate the process
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Terminate', ...
              'Units', 'normalized', 'Position', [0.4, 0.05, 0.2, 0.05], ...
              'Callback', @(src, event) on_close());

    % resize operations (increase/decrease matrix size by a defined scale)
    function apply_resize(scale)
        % NOTE: NaN-safe transform
        % imresize interpolates using neighboring pixels, so NaNs propagate into neighbors and expand over iterations. NaN positions are saved in a binary
        % mask, NaNs are temporarily replaced with nanmean before resizing, then the transformed mask restores NaNs to their correct positions.
        nan_mask_mod = isnan(modifiedImg1);
        modifiedImg1(nan_mask_mod) = nanmean(modifiedImg1(:));
        modifiedImg1 = imresize(modifiedImg1, size(modifiedImg1)+scale);
        nan_mask_mod = imresize(double(nan_mask_mod), size(modifiedImg1), 'nearest') > 0.5;
        modifiedImg1(nan_mask_mod) = NaN;
        for flag_AFM = 1:nChannels
            img = AFM_end{flag_AFM};
            new_size = size(img) + scale;
            if flagLogical(flag_AFM)
                AFM_end{flag_AFM} = imresize(img, new_size, 'nearest') > 0.5;
            else
            % Build NaN mask and fill NaNs before resizing
                nan_mask = isnan(img);
                img(nan_mask) = nanmean(img(:));  % or 0, or nanmedian
                % Resize both image and mask
                img_r    = imresize(img,new_size);
                mask_r   = imresize(double(nan_mask), new_size) > 0.5;  % nearest-ish threshold           
                % Restore NaNs
                img_r(mask_r) = NaN;
                % save the result of the image alteration
                AFM_end{flag_AFM} = img_r;
            end
        end
        % save the operation
        details_it_reg(counter,1) = 1;
        details_it_reg(counter,2) = scale;
        % run CC
        exeSingleCrossCorr(false);
        counter = counter+1;
        update_display();
    end       

    % rotate operations (rotate by a defined angle)
    function apply_rotate(angle)
        % NOTE: NaN-safe transform (same rationale as apply_resize)
        % For imrotate, border_mask additionally catches the zero-padded pixels
        % introduced at the edges by 'loose', which are not real data.
        nan_mask_mod = isnan(modifiedImg1);
        modifiedImg1(nan_mask_mod) = nanmean(modifiedImg1(:));
        img_rot = imrotate(modifiedImg1, angle, 'bilinear', 'loose');
        nan_mask_mod = imrotate(double(nan_mask_mod), angle, 'nearest', 'loose') > 0.5;
        border_mask = ~(imrotate(ones(size(modifiedImg1)), angle, 'nearest', 'loose') > 0.5);
        modifiedImg1 = img_rot;       
        modifiedImg1(nan_mask_mod | border_mask) = NaN;
        for flag_AFM = 1:nChannels
            img =  AFM_end{flag_AFM};      
            % Build NaN mask and fill NaNs before rotating
            if flagLogical(flag_AFM)
                AFM_end{flag_AFM} = imrotate(img,angle, 'nearest','loose') > 0.5;
            else
                nan_mask = isnan(img);
                img(nan_mask) = nanmean(img(:));
                img_r  = imrotate(img,              angle, 'bilinear', 'loose');
                mask_r = imrotate(double(nan_mask), angle, 'nearest',  'loose') > 0.5;
                border_mask = (img_r == 0) & ~(imrotate(ones(size(img)), angle, 'nearest', 'loose') > 0.5);
                mask_r = mask_r | border_mask;
                img_r(mask_r) = NaN;
                AFM_end{flag_AFM} = img_r;
            end
        end
        % update the total rotation
        totRotation_deg = totRotation_deg+angle;
        set(hRotText, 'String', ['Rotation: ' num2str(totRotation_deg) '°']);
        % save the operation
        details_it_reg(counter,1) = 0;
        details_it_reg(counter,2) = angle;
        % get CC
        exeSingleCrossCorr(false);
        counter = counter+1;
        update_display();
    end

    % update the AFM and BF images after each operation
    function update_display()
        if exist('pairAFM_BF','var')
            delete(pairAFM_BF)
        end
        pairAFM_BF=imshowpair(fixedImg1,AFM_IO_padded,'falsecolor', 'Parent', hAx);
    end

    % run a cross correlation (xcorr2_fft) and alignment
    function exeSingleCrossCorr(start)
        modifiedImg1_CC = modifiedImg1;
        modifiedImg1_CC(isnan(modifiedImg1_CC)) = 0;
        [max_c_it_OI,~,rect,AFM_IO_padded] = A5_feature_crossCorrelationAlignmentAFM(fixedImg1,modifiedImg1_CC);
        
        % update the counter and the score
        score = max_c_it_OI/maxC_original;
        % update the trend
        if ~start
            pause(1)
            set(hCounterText, 'String', ['Counter: ' num2str(counter)]);
            set(hScoreCCText, 'String', ['Score (normalized): ' num2str(score)]);
            addpoints(h,counter, score)
            drawnow      
        end
    end   

    % in case something goes wrong, restart
    function reset()
        % init every variables
        counter=1;                  set(hCounterText, 'String', ['Counter: ' num2str(0)]);
        details_it_reg =[];
        totRotation_deg=0;             set(hRotText, 'String', ['Rotation: ' num2str(0) '°']);
        score=1;                    set(hScoreCCText, 'String', ['Score (normalized): ' num2str(score)]);
        % original images
        fixedImg1 = BF_IO;
        modifiedImg1 = AFM_IO_resized_original;
        AFM_end=AFM_start;
        % restore the pre-crossCorrelation
        AFM_IO_padded=[];
        exeSingleCrossCorr(true)
        update_display();
        % restart trend plot
        clearpoints(h);
        addpoints(h, 0, 1);
        drawnow
    end
    % last operations when terminated
    function on_close()
        if saveFig
            figure(fig_TrendCC)
            if ~isempty(idxMon), objInSecondMonitor(fig_TrendCC,idxMon); end            
            saveFigures_FigAndTiff(fig_TrendCC,newFolder,"resultA5_4_trendScoreCrossCorrelation_manualApproach")          
        end
        uiresume(hFig);
        delete(hFig);
    end
    % at the bottom of the main function, replace pause(2) with:
    uiwait(hFig);
    pause(2)
    varargout{1}= AFM_IO_padded;
    varargout{2}= AFM_end;
    varargout{3}= details_it_reg;
    varargout{4}= rect;
end


    
    