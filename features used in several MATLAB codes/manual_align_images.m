function offset = manual_align_images(maskImg, rawImg)
% MANUAL_ALIGN_IMAGES: manually align two images using drag or zoom.
% maskImg: binary mask (0/1)
% rawImg: numeric matrix
% offset = [dx, dy] translation applied to rawImg

    % ---- Normalize RAW image ----
    rawImgNorm = mat2gray(rawImg);

    % ---- RGB overlays ----
    maskRGB = cat(3, maskImg, zeros(size(maskImg)), 0*maskImg);       % red mask
    rawRGB_base = cat(3, zeros(size(rawImgNorm)), rawImgNorm, zeros(size(rawImgNorm)));  % green moving

    % ---- Create figure ----
    hFig = figure('Name','Manual Image Alignment',...
                  'NumberTitle','off',...
                  'WindowButtonMotionFcn', @mouseMove,...
                  'WindowButtonUpFcn', @mouseUp,...
                  'WindowButtonDownFcn', @mouseDown);

    % ---- Axes ----
    hAx = axes('Parent', hFig);
    hold(hAx, 'on');
    axis(hAx, 'manual');
    axis(hAx, [1 size(maskImg,2) 1 size(maskImg,1)]);
    set(hAx,'YDir','reverse');

    % ---- Initial offset ----
    dx = 0;
    dy = 0;

    % ---- Display fixed mask ----
    imshow(maskRGB, 'Parent', hAx);

    % ---- Display moving image ----
    hRaw = imshow(rawRGB_base, 'Parent', hAx);
    initialAlpha = 0.6;
    set(hRaw, 'AlphaData', initialAlpha);

    % ---- Mode state ----
    isMoveMode = true;    % default dragging mode
    dragging = false;
    lastPoint = [];

    % ---------------------------------------------------------
    %                  TOP-RIGHT INFO PANEL
    % ---------------------------------------------------------
    uicontrol('Parent', hFig, ...
        'Style', 'frame', ...
        'Units', 'normalized', ...
        'Position', [0.80 0.85 0.18 0.075], ...
        'BackgroundColor', [0.95 0.95 0.95]);

    uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', 'MASK HOVER MODE ON', ...
        'FontWeight', 'bold', ...
        'ForegroundColor', 'red', ...
        'Units', 'normalized', ...
        'Position', [0.80 0.9 0.18 0.025], ...
        'BackgroundColor', 'white');

    uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', {"Height Image HOVER MODE OFF";"(after 1st order plane fit)"}, ...
        'FontWeight', 'bold', ...
        'ForegroundColor', 'green', ...
        'Units', 'normalized', ...
        'Position', [0.80 0.85 0.18 0.05], ...
        'BackgroundColor', 'white');  

    % -------------------------
    %      TRANSPARENCY SLIDER
    % -------------------------
    uicontrol('Parent', hFig, ...
        'Style', 'slider', ...
        'Min', 0, 'Max', 1, 'Value', initialAlpha, ...
        'Units', 'normalized', ...
        'Position', [0.85 0.10 0.12 0.06], ...
        'Callback', @(src,evt) set(hRaw,'AlphaData',src.Value));

    uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', 'Transparency', ...
        'Units', 'normalized', ...
        'Position', [0.85 0.16 0.12 0.04]);

    % -------------------------
    %       DONE BUTTON
    % -------------------------
    uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Done', ...
        'Units', 'normalized', ...
        'Position', [0.85 0.02 0.12 0.06], ...
        'Callback', @(src,evt) uiresume(hFig));

    % -------------------------
    %     MODE TOGGLE BUTTONS
    % -------------------------
    uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Move the HVoff image', ...
        'Units', 'normalized', ...
        'Position', [0.02 0.02 0.14 0.06], ...
        'Callback', @(src,evt) enableMoveMode());

    uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Zoom/Move the entire figure', ...
        'Units', 'normalized', ...
        'Position', [0.16 0.02 0.12 0.06], ...
        'Callback', @(src,evt) enableZoomMode());

    % -------------------------
    %    CALLBACK FUNCTIONS
    % -------------------------

    function mouseDown(~,~)
        if ~isMoveMode
            return; % disable dragging in zoom mode
        end
        dragging = true;
        lastPoint = get(hAx,'CurrentPoint');
    end

    function mouseUp(~,~)
        dragging = false;
    end

    function mouseMove(~,~)
        if ~isMoveMode || ~dragging
            return;
        end

        currPoint = get(hAx,'CurrentPoint');
        delta = currPoint - lastPoint;
        lastPoint = currPoint;

        dx = dx + delta(1,1);
        dy = dy + delta(1,2);

        updateOverlay();
    end

    function updateOverlay()
        set(hRaw, ...
            'XData', [1+dx, size(rawImgNorm,2)+dx], ...
            'YData', [1+dy, size(rawImgNorm,1)+dy]);
        drawnow;
    end

    % -------------------------
    %    MODE HANDLER FUNCTIONS
    % -------------------------
    function enableMoveMode()
        isMoveMode = true;   
        % Disable zoom/pan
        zoom(hFig,'off');
        pan(hFig,'off');
        set(hFig, 'WindowScrollWheelFcn', @(src,evt) []);    
    end

    function enableZoomMode()
        isMoveMode = false;
        % Enable zoom/pan
        zoom(hFig,'on');
        pan(hFig,'on');
        set(hFig, 'WindowScrollWheelFcn', []);
        % Let axes adjust automatically
        axis(hAx,'auto');
    end

    % -------------------------
    %    WAIT AND RETURN
    % -------------------------
    uiwait(hFig);

    offset = [dx, dy];
    close(hFig);

end
