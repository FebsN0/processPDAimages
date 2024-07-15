function imageIO_manipulation_gui(BF_IO_reduced,AFM_padded)
    
    hFig = figure('Name', 'Image Manipulation GUI', 'NumberTitle', 'off', ...
                  'Position', [100, 100, 800, 600], 'MenuBar', 'none', ...
                  'ToolBar', 'none', 'Resize', 'off');

    % Load two images
    img1 = BF_IO_reduced;
    img2 = AFM_padded;  % Initialize the modified image
    modifiedImg2 = img2;

    % Apply false color to the images
    img1Color = img1; % Red for img1
    modifiedImg2Color = modifiedImg2; % Green for img2

    
    % Display the combined image
    hAx = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.05, 0.3, 0.9, 0.65]);
    hImg = imshow(imfuse(img1Color, modifiedImg2Color, 'falsecolor'), 'Parent', hAx);
    title(hAx, 'Overlayed Images with False Color');

    % Create buttons for operations
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Expand', ...
              'Units', 'normalized', 'Position', [0.15, 0.15, 0.2, 0.1], ...
              'Callback', @(src, event) apply_resize(+1));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Reduce', ...
              'Units', 'normalized', 'Position', [0.15, 0.05, 0.2, 0.1], ...
              'Callback', @(src, event) apply_resize(-1));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Rotate CCW', ...
              'Units', 'normalized', 'Position', [0.65, 0.15, 0.2, 0.1], ...
              'Callback', @(src, event) apply_rotate(0.01));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Rotate CW', ...
              'Units', 'normalized', 'Position', [0.65, 0.05, 0.2, 0.1], ...
              'Callback', @(src, event) apply_rotate(-0.01));
    uicontrol('Parent', hFig, 'Style', 'pushbutton', 'String', 'Terminate', ...
              'Units', 'normalized', 'Position', [0.4, 0.05, 0.2, 0.1], ...
              'Callback', @(src, event) close(hFig));

    function apply_resize(scale)
        modifiedImg2 = imresize(modifiedImg2, size(modifiedImg2Color)+scale);
        update_display();
    end

    function apply_rotate(angle)
        modifiedImg2 = imrotate(modifiedImg2, angle,'bicubic','loose');
        update_display();
    end

    function update_display()
        modifiedImg2Color = modifiedImg2;
        combinedImg = imfuse(img1Color, modifiedImg2Color, 'falsecolor');
        set(hImg, 'CData', combinedImg);
    end
end
