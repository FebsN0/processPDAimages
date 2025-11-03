% the output AFM_data will have new fields compared to the input AFM_data
% AFM_aligned is the version iteratively modified of AFM_scaled
% AFM_image_padded is AFM_aligned but with the size of AFM_IO_padded, which is the same for the BF_IO
function varargout=A9_feature_manualAlignmentGUI(AFM_IO_padded,BF_IO,AFM_data,rect,max_c_it_OI,idxMon,newFolder,varargin)
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
    f2max=figure;
    h = animatedline('Marker','o');
    addpoints(h,0,1)
    ylabel('Normalized Cross-correlation Score','FontSize',12), xlabel('# cycles','FontSize',12)  
    hScoreCCText = uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Score (normalized): 1', ...
                             'Units', 'normalized', 'Position', [0.4, 0.225, 0.2, 0.05]);
    % keep trach the total rotation and matrix size changes
    rotation_deg=0;
    hRotText = uicontrol('Parent', hFig, 'Style', 'text', 'String', 'Rotation: 0°', ...
                             'Units', 'normalized', 'Position', [0.4, 0.20, 0.2, 0.05]);
    % copy the scaled matrixs so they will be iteratively modified
    for idx=1:size(AFM_data,2)
        AFM_data(idx).AFM_aligned=AFM_data(idx).AFM_scaled;
    end
    % save the original AFM_data
    AFM_data_original=AFM_data;
    % Load two images
    fixedImg1 = BF_IO;
    % extract only the AFM mask
    modifiedImg1=AFM_IO_padded(rect(3):rect(4),rect(1):rect(2));
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
        modifiedImg1 = imresize(modifiedImg1, size(modifiedImg1)+scale);
        for flag_AFM=1:size(AFM_data,2)
            AFM_data(flag_AFM).AFM_aligned=imresize(AFM_data(flag_AFM).AFM_aligned,size(AFM_data(flag_AFM).AFM_aligned)+scale);
        end
        % save the operation
        details_it_reg(counter,1)=1;
        details_it_reg(counter,2)=scale;
        % run CC
        exeSingleCrossCorr(false);
        counter=counter+1;
        update_display();
    end          
    % rotate operations (rotate by a defined angle)
    function apply_rotate(angle)
        modifiedImg1 = imrotate(modifiedImg1, angle,'bilinear','loose');
        for flag_AFM=1:size(AFM_data,2)
            AFM_data(flag_AFM).AFM_aligned=imrotate(AFM_data(flag_AFM).AFM_aligned,angle,'bilinear','loose');
        end
        % update the total rotation
        rotation_deg=rotation_deg+angle;
        set(hRotText, 'String', ['Rotation: ' num2str(rotation_deg) '°']);
        % save the operation
        details_it_reg(counter,1)=0;
        details_it_reg(counter,2)=angle;
        % get CC
        exeSingleCrossCorr(false);
        counter=counter+1;
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
        [max_c_it_OI,~,~,~,rect,AFM_IO_padded] = A9_feature_crossCorrelationAlignmentAFM(fixedImg1,modifiedImg1);
        figure(f2max)
        % update the counter and the score
        score = max_c_it_OI/maxC_original;
        % update the trend
        if ~start
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
        rotation_deg=0;             set(hRotText, 'String', ['Rotation: ' num2str(0) '°']);
        score=1;                    set(hScoreCCText, 'String', ['Score (normalized): ' num2str(score)]);
        % original images
        fixedImg1 = BF_IO;
        modifiedImg1 = AFM_IO;
        AFM_data=AFM_data_original;
        % restore the pre-crossCorrelation
        AFM_IO_padded=[];
        exeSingleCrossCorr(true)
        update_display();
        % restart figures
        close(f2max)
        f2max=figure;
        h = animatedline('Marker','o');
        addpoints(h,0,1)
        ylabel('Normalized Cross-correlation Score','FontSize',12), xlabel('# cycles','FontSize',12) 
    end
    % last operations when terminated
    function on_close()
        if saveFig
            figure(f2max)
            if ~isempty(idxMon), objInSecondMonitor(f2max,idxMon); end
            title('Trend Cross-correlation score','FontSize',14)
            saveas(f2max,sprintf('%s/resultA9_4_trendScoreCrossCorrelation_manualApproach.tif',newFolder))
            % Close the figure
            delete(hFig); delete(f2max)
        end
    end

    uiwait(msgbox('Click to continue when the manual method is terminated',''));
    varargout{1}= AFM_IO_padded;
    varargout{2}= AFM_data;
    varargout{3}= details_it_reg;
    varargout{4}= rect;
end