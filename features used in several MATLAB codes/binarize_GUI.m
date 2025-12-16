function[IO_Image, detailOperations] = binarize_GUI(image,typeImage)
% Initialize outputs
    segImage = [];
    binarizationMethod_text = [];
    morphologicalOperations_text = [];
    % max 15 operations, very unlikely to reach this iteration, but just in case
    segImage_MorphOpsHistory=cell(20);
    counterHistory=1;
    if strcmp(typeImage,'Height')
        textHistXLabel="Height [nm]";
        textHistTitle="Height Distribution";
        textOriginalImageTitle="Original Height Image - PostFit";
        textOriginalImageSubtitle=[];
    else % Brightfield
        textHistXLabel="Intensity pixel (imadjusted)";
        textHistTitle="Intensity Distribution (imadjusted)";
        textOriginalImageTitle="Original Brightfield Image";
        textOriginalImageSubtitle="Original (imadjusted - saturated 1% bottom and 99% top)";
    end
    % Create main figure
    mainFig = uifigure('Name', 'Interactive Binarization Tool', ...
                     'NumberTitle', 'off', ...
                     'WindowState','maximized','CloseRequestFcn',@onUserClose);
    % Create main layout (5 columns)
    mainLayout = uigridlayout(mainFig, [2 6]);
    mainLayout.RowHeight = {'1x','1x'};                              % Top = 3/5 height
    mainLayout.ColumnWidth = {'1x','1x', '1x', '1x', '1x', '1x'};    % 6 columns    
   % ================================================================
    % (A) LEFT: IMAGES (Column 1-4, Row 1-2)
    % ================================================================
    imgPanel = uipanel(mainLayout);
    imgPanel.Layout.Row = [1 2];            % takign both 2 rows and not the first only that occupy 3/5 of the entire space
    imgPanel.Layout.Column = [1 4];        
    % Grid with two axes, no spacing
    imgGrid = uigridlayout(imgPanel, [1 2]);
    imgGrid.RowHeight = {'1x'};
    imgGrid.ColumnWidth = {'1x','1x'};
    imgGrid.Padding = [0 0 0 0];
    imgGrid.RowSpacing = 0;
    imgGrid.ColumnSpacing = 0;
    % Left axis
    axOriginal = uiaxes(imgGrid);
    axOriginal.Layout.Row = 1;
    axOriginal.Layout.Column = 1;
    if strcmp(typeImage,'Height')
        h=imagesc(axOriginal,image);
        h.AlphaData = ~isnan(image);   % NaN → transparent
        set(axOriginal, 'Color', 'black');    % Background color visible    
        c=colorbar(axOriginal); c.Label.FontSize=16;
        c.Label.String="Height [nm]";
    else
        imshow(image, 'Parent', axOriginal);
    end
    axis(axOriginal, 'image');
    axOriginal.Toolbar.Visible = 'on';
    title(axOriginal,textOriginalImageTitle,'FontSize',13);   
    if ~isempty(textOriginalImageSubtitle)
        subtitle(axOriginal,textOriginalImageSubtitle,'FontSize',10)
    end
    % Right axis
    axBin = uiaxes(imgGrid);
    axBin.Layout.Row = 1;
    axBin.Layout.Column = 2;
    tmpImg = imshow(zeros(size(image)), 'Parent', axBin);
    axis(axBin, 'image');
    axBin.Toolbar.Visible = 'on';
    title(axBin, 'Binarized Preview','FontSize',14);
    c=colorbar(axBin); c.Label.FontSize=16;   
    % Apply a custom two-color colormap (black-white)
    colormap(axBin,[0 0 0; 1 1 1]);
    % colormap is binary and not gradient
    clim(axBin,[0 1]);
    %c.Ticks = [0 1];
    set(c,'YTickLabel',[]);
    cLabel = ylabel(c,'Background                                                     Foreground');
    cLabel.FontSize=14;     

    % ================================================================
    % (B) RIGHT-TOP: HISTOGRAM (Column 5-6, Row 1 but upper half)
    % ================================================================
    histPanel = uipanel(mainLayout);
    histPanel.Layout.Row = 1;
    histPanel.Layout.Column = [5 6];
    % Make internal grid (top = histogram, bottom empty)
    histGrid = uigridlayout(histPanel, [1 1]);
    axHist = axes('Parent', histGrid);
    histGrid.Padding = [0 0 0 0];
    histGrid.RowSpacing = 0;
    histGrid.ColumnSpacing = 0;
    hold(axHist, 'on');
    % Compute histogram once
    no_sub_div = 1000;
    [Y,E] = histcounts(image,no_sub_div,'Normalization','pdf');
    binCenters = (E(1:end-1) + diff(E)/2);    
    % Plot it once
    hHistPlot=plot(axHist, binCenters, Y, 'LineWidth', 1.3); xlim(axHist,"tight")
    % Make histogram clickable only when manual mode is active
    hHistPlot.PickableParts = 'none'; 
    hHistPlot.HitTest = 'off';
    % Store threshold line handle (initially empty)
    prevXLine = [];
    xlabel(axHist, textHistXLabel, 'FontSize', 12);
    ylabel(axHist, 'PDF count', 'FontSize', 12);
    title(axHist,textHistTitle, 'FontSize', 13);
    axHist.ButtonDownFcn = [];  % disabled by default
    % ================================================================
    % (C) RIGHT-BOTTOM: BUTTONS (Column 5-6, Row 2 but lower half)
    % ================================================================
    ctrlPanel = uipanel(mainLayout);
    ctrlPanel.Layout.Row = 2;
    ctrlPanel.Layout.Column = [5 6];
    % inside the control panel, there are 7 rows and 1 column (nested grid)
    ctrlGrid = uigridlayout(ctrlPanel, [7 1]);
    ctrlGrid.RowHeight = {'0.94x','0.94x','0.94x','0.94x','0.94x','0.94x','1.36x'};

    % ---- Buttons ----
    % BINARIZATION CONTROL
    btnAuto = uibutton(ctrlGrid, 'Text','Run Binarization','FontSize',14,'ButtonPushedFcn',@runBinarization, ...
         'Tooltip',"Select method and eventually choose sensitivity below.");
    btnAuto.Layout.Row = 1;
    % nested grid
    row2cols_1 = uigridlayout(ctrlGrid, [1 2]);
    row2cols_1.ColumnWidth = {'1x','1x'};
    typeMethodPopup=uidropdown(row2cols_1,'Value','Adaptthresh (mean statistics)','FontSize',13, 'Tooltip',"Binarization method. In case of Adaptthresh, choose sensitivity.",'Items', ...
        {'Adaptthresh (mean statistics)','Adaptthresh (median statistics)','Adaptthresh (gaussian statistics)','Otsu''s method','Global manual (click on histogram)'});            
    numField = uieditfield(row2cols_1,'numeric',"Limits",[0 1], "LowerLimitInclusive","off","UpperLimitInclusive","off",'Tooltip','Default value: 0.5', ...
        "Placeholder","Sensitivity Adaptthresh","AllowEmpty",'on',"Value",[],'HorizontalAlignment','center','FontSize',13);
    row2cols_1.ColumnSpacing=10; row2cols_1.Padding=0; row2cols_1.Layout.Row = 2;

    % MORPHOLOGICAL CLEANING OPERATIONS TO REMOVE NOISE AND SMALL PIXELS (ACTUALLY ONLY MORPHOLOGICAL OPENING)
    btnMorphological = uibutton(ctrlGrid, 'Text','Run Morphological Opening','FontSize',13,'ButtonPushedFcn',@applyMorphologyCleaning,'Enable','off',...
    'tooltip',sprintf("Erosion → Dilation of white pixels (1) on binary image.\nNOTE 1: Morphological Closing if invert the binary image.\nNOTE 2: once clicked, first exe bwareaopen, then morphological opening and finally imfill."));
    btnMorphological.Layout.Row = 3;
    % nested grid
    row3cols_2 = uigridlayout(ctrlGrid, [1 3]);
    row3cols_2.ColumnWidth = {'1x','1x','1x'};
    row3cols_2.ColumnSpacing=10; row3cols_2.Padding=0; row3cols_2.Layout.Row = 4;
    kernelPopup = uidropdown(row3cols_2,'Items',{'disk','square','diamond','octagon'},'Value','square','FontSize',13,'Tooltip',"Kernel type");
    kernelValue=uieditfield(row3cols_2,'numeric',"Limits",[0 100], "LowerLimitInclusive","on","UpperLimitInclusive","on",'Tooltip',sprintf("Default value: 3\nIf 0, nothing change."),...
        "Placeholder","Kernel Radius","AllowEmpty",'on',"Value",[],'HorizontalAlignment','center','FontSize',13);
    btnUndo=uibutton(row3cols_2,'Text','Undo Morph.Op.','FontSize', 13,'ButtonPushedFcn',@undoMO,'Enable','off','Tooltip',"Return to the previous Morphological operation.");
    % operation before M.O.
    row2cols_3 = uigridlayout(ctrlGrid, [1 2]);
    row2cols_3.ColumnWidth = {'1x','1x'};
    row2cols_3.ColumnSpacing=10; row2cols_3.Padding=0; row2cols_3.Layout.Row = 5;    
    removeWithNoDistorsionValue = uieditfield(row2cols_3,'numeric',"Limits",[0 100], "LowerLimitInclusive","on","UpperLimitInclusive","on", ...
        "Placeholder","bwareaopen area","AllowEmpty",'on',"Value",[],'HorizontalAlignment','center','FontSize',13,...
        'Tooltip',sprintf("Default area size: 0\nRemove small connected objects (white pixels) smaller than a certain area WITHOUT distorting real objects.\nIf 0, nothing happens"));
    fillHolesCheck=uicheckbox(row2cols_3,"Value",false,"Text","Fill holes (regions of 0 - black)","FontSize",13, ...
        "Tooltip","A hole is a set of background pixels that cannot be reached by filling in the background from the edge of the image.");
    % final buttons
    btnInvertBinary = uibutton(ctrlGrid,'Text','Invert Binary Image: white (1) ↔ black (0)','FontSize', 14,'ButtonPushedFcn',@invertBinaryImage,'Enable','off',...
        'Tooltip',sprintf("IMPORTANT NOTE: Recommended to click before any MO if BK=white, so first Morph.Opening, then invert again to perform Morph.Closing.\n\n" + ...
                          "If foreground (1) = real objects ==> Morph.Opening (removes small objects and thin protrusions from objects)\n" + ...
                          "If foreground (1) = inverted background ==> Morph.Closing (removes small background islands and smooths the boundaries of BK regions."));
    btnInvertBinary.Layout.Row = 6;
    % END BUTTON
    btnConfirm = uibutton(ctrlGrid, 'Text','Confirm the Binarized Preview and close','FontSize',20,'ButtonPushedFcn', @terminate,'Enable','off');
    btnConfirm.Layout.Row = 7;
    %===== END PREPARATION GUI ======%
    % disable or activate buttons during execution of a binarization method

    function setControlsEnabled(state)
        % state = 'on' or 'off'    
        btnAuto.Enable = state;
        typeMethodPopup.Enable = state;
        numField.Enable = state;
        btnMorphological.Enable = state;        
        kernelPopup.Enable = state;
        kernelValue.Enable = state;
        removeWithNoDistorsionValue.Enable =state;
        fillHolesCheck.Enable = state;
        btnInvertBinary.Enable = state;
        btnConfirm.Enable = state;
        % update the show of buttons
        drawnow;
    end
    
    function updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)
        % Update binary preview image and label
        tmpImg.CData = segImage;
        if isempty(morphologicalOperations_text)
            textBin=binarizationMethod_text;
        else
            textBin={binarizationMethod_text;morphologicalOperations_text};
        end
        title(axBin,textBin, 'FontSize', 14);
    end

    %----------------------------------------------------------------- for manual threshold
    function manualThreshold(src,event)
         % src   = hHistPlot
         % event = graphics event with IntersectionPoint field
        % Protect GUI state even here
        try            
            cp = event.IntersectionPoint;
            clicked_x = cp(1); 
            % Disable click mode immediately
            hHistPlot.PickableParts = 'none';
            hHistPlot.HitTest = 'off';
            hHistPlot.ButtonDownFcn = [];
            % Find closest bin index
            [~, closest_idx] = min(abs(binCenters - clicked_x));    
            % Remove previous line
            if ~isempty(prevXLine) && isvalid(prevXLine)
                delete(prevXLine);
            end    
            % Draw new line
            prevXLine = xline(axHist, binCenters(closest_idx), 'r--', 'LineWidth', 2);
            % Compute threshold
            thSeg = E(closest_idx);
            segImage = image >= thSeg;        
            binarizationMethod_text = "Binarization: Manual Gloabl Threshold";
            updateBinImage(segImage,binarizationMethod_text,morphologicalOperations_text)
            % Restore title
            title(axHist, 'Intensity Distribution (imadjusted)', 'FontSize', 13);
        catch ME
            errordlg(ME.message, 'Manual threshold error');
        end

        % Disable further clicks on histogram
        src.PickableParts = 'none';
        src.HitTest       = 'off';
        src.ButtonDownFcn = [];
        setControlsEnabled('on');
        % reset history MO and disable button
        segImage_MorphOpsHistory=cell(20);
        btnUndo.Enable="off";
        % the first idx is the original before MO
        segImage_MorphOpsHistory{1}=segImage;
        counterHistory=2;
    end

    %----------------------------------------------------------------- for adaptive threshold
    function runBinarization(~,~)        
        % Disable all controls during manual click selection
        setControlsEnabled('off');
        try
            % check the modality of thresholding
            switch typeMethodPopup.Value
                case 'Otsu''s method'
                    segImage = manual_otsu(image);
                    binarizationMethod_text="Binarization: Otsu's method";
                case 'Global manual (click on histogram)'
                    % Enable clicking on the histogram; computation will be done in manualThreshold when the user clicks.
                    hHistPlot.PickableParts = 'all';
                    hHistPlot.HitTest       = 'on';
                    % since it is not possible to wait for the next line because the GUI still run and not totally freeze, do all inside the
                    % function, including computation and plotting/update. Inside freeze everything and the user can only click on the
                    % histogram
                    hHistPlot.ButtonDownFcn = @manualThreshold;
                    title(axHist, 'Click on histogram to choose threshold', 'FontSize', 13);
                    return
                
                otherwise
                    % Get sensitivity from user field
                    if isempty(numField.Value)
                        sens = 0.5;
                    else
                        sens = numField.Value;
                    end
                    if strcmp(typeMethodPopup.Value,'Adaptthresh (median statistics)')
                        % default size makes the computation damnly slow
                        nSize=2*floor(size(image)/256)+1;
                        T = adaptthresh(image,sens,"Statistic","median","NeighborhoodSize",nSize);
                        binarizationMethod_text="Binarization: Adaptive (median) Threshold";
                    else
                        if strcmp(typeMethodPopup.Value,'Adaptthresh (mean statistics)')
                            typeStatistics="mean";
                            binarizationMethod_text="Binarization: Adaptive (mean) Threshold";
                        else
                            typeStatistics="gaussian";
                            binarizationMethod_text="Binarization: Adaptive (gaussian) Threshold";
                        end
                        T = adaptthresh(image,sens,"Statistic",typeStatistics);
                    end
                    % Apply adaptive threshold to the image
                    segImage = imbinarize(image, T);
            end                     
            % Update preview
            updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)
            
        % If error happens, restore UI before throwing error    
        catch ME  
            setControlsEnabled('on');
            errordlg(ME.message, 'Binarization error');
        end
        % Normal end (automatic methods) → re-enable controls
        setControlsEnabled('on');
        % reset history MO and disable button
        segImage_MorphOpsHistory=cell(20);
        btnUndo.Enable="off";
        % the first idx is the original before MO
        segImage_MorphOpsHistory{1}=segImage;
        counterHistory=2;
    end
         
    %----------------------------------------------------------------- MORPHOLOGICAL CLEARING
    function applyMorphologyCleaning(~,~)
    % workflow routinely used in object segmentation, cleaning binary masks, removing noise, filling holes, and measuring structures.
    % 1) Remove very small objects (noise cleaning)
    % 2) Fill holes inside objects
    % 3) Morphological opening (erosion → dilation)
    %       GOAL: 
    %           Remove thin protrusions.
    %           Smooth small details.
    %           Disconnect narrow bridges.
    % 4) Morphological closing (dilation → erosion)
    %       GOAL:
    %           Fill small gaps and "close" cracks between segments.
    %           Smooth boundaries.
    % 5) Remove objects touching the border: useful when you want only full objects inside the frame.
    % 6) Label connected components
    % CONSIDERATION:
    % since invertImageBin has been introduced to give more control at the user,
    % !!!!! Morphological Opening of BW == Morphological Closing of ~BW !!!!!
    % therefore, step 4 is omitted
    % DELUCIDATION ABOUT bwareaopen and imopen
    % bwareaopen ==> delete all objects smaller than a certain area == robust cleaning WITHOUT distorting real objects.
    % imopen     ==> remove thin structures or refine shape == to smooth boundaries and to disconnect objects connected by thin bridges.
        kernelType = kernelPopup.Value;
        rad = kernelValue.Value;
        if isempty(rad)
            rad = 3;    % default
        end
        switch kernelType
            case 'disk'
                kernel = strel('disk', rad);
            case 'square'
                kernel = strel('square', rad);
            case 'diamond'
                kernel = strel('diamond', rad);
            case 'octagon'
                rad=round(rad/3)*3;
                kernel = strel('octagon', rad);
        end
        morphologicalOperations_text=sprintf("Kernel: %s - size: %d",kernelType,rad);
        bw = segImage;
        % step 1: remove tiny objects if value is not empty. Removes obvious noise.
        if ~isempty(removeWithNoDistorsionValue.Value)
            bw = bwareaopen(bw, removeWithNoDistorsionValue.Value);
        end

        % step 2: Perform actual morphology opening (previously as imerode then imdilate).
        % NOTE: imopen(bw, kernel) always performs erosion followed by dilation.
        %   Its effect depends on which pixels are treated as FOREGROUND (1):       
        %     • If foreground = original objects:
        %           - Removes small objects and thin protrusions from objects
        %           - Smooths object boundaries
        %           - Can break thin connections
        %
        %     • If foreground = inverted background (after binary inversion):
        %           - Removes small background islands
        %           - Smooths the boundaries of background regions
        %           - Visually appears as "filling small bright gaps" in the ORIGINAL image
        bw = imopen(bw, kernel);
        % step 3: fill whatever true "holes" remain inside the cleaned objects.
        if fillHolesCheck.Value
            bw = imfill(bw, 'holes');
        end

        % end MO process
        segImage=bw;
        % Update preview
        updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)

        % update history of applied Morph.operations
        segImage_MorphOpsHistory{counterHistory,1}=bw;
        segImage_MorphOpsHistory{counterHistory,2}=morphologicalOperations_text;
        counterHistory=counterHistory+1;
        % over storage not allowed, lose the oldest cell (first index)
        if counterHistory>size(segImage_MorphOpsHistory,2)
            segImage_MorphOpsHistory(1:end-1,:)=segImage_MorphOpsHistory(2:end,:);
            segImage_MorphOpsHistory(end,:)={[]}; % assign empty cell into *all columns*
            warndlg("Storage History reached. Deleting first Morphological Operation.")
        end
        btnUndo.Enable="on";
    end

    function invertBinaryImage(~,~)
        segImage=~segImage;
        updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)
    end
        
    function undoMO(~,~)
    % restore last Morphological operation
        segImage=segImage_MorphOpsHistory{counterHistory-2,1};
        morphologicalOperations_text=segImage_MorphOpsHistory{counterHistory-2,2};
        counterHistory=counterHistory-1;
        updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)
        % prevent over undo history
        if counterHistory<=2
            btnUndo.Enable="off";
        end
    end

    function terminate(~,~)
        % Here you prepare the outputs you want to send back to the caller:            
        mainFig.UserData = {segImage, binarizationMethod_text,morphologicalOperations_text};   
        % Resumes the execution of the caller function waiting at uiwait
        % it allows the GUI to return outputs preventing the parent function from staying frozen
        uiresume(mainFig);    
    end

    function onUserClose(~,~)
        % Close button or window close (X)
        mainFig.UserData = [];    
        uiresume(mainFig);        
    end
    
    % blocks the calling function, but NOT the GUI.
    uiwait(mainFig);
    % Retrieve results (safe, since GUI already finished)
    if isempty(mainFig.UserData)
        error('Interrupted by User or not generated anything')
    else
        IO_Image = mainFig.UserData{1};
        binarizationMethod_text = mainFig.UserData{2};
        morphologicalOperations_text=mainFig.UserData{3};
        if ~isempty(morphologicalOperations_text)
            detailOperations=sprintf("%s (Morph.Ops applied)",binarizationMethod_text);
        else
            detailOperations=binarizationMethod_text;
        end
    end
    % Safe to delete GUI AFTER retrieving data
    delete(mainFig);
end


function BW = manual_otsu(img)
    % MANUAL_OTSU - Universal Otsu thresholding
    % Works with uint8, uint16, double images
    % Accepts input in range [0,1] or [0,255]
    % Output: logical BW image (objects = img > threshold)

    arr = double(img); % Convert to double
    % Normalize to 0–255 if needed
    if max(arr(:)) <= 1
        arr = arr * 255;
    end
    % Clip just in case
    arr(arr < 0) = 0;
    arr(arr > 255) = 255;
    % Histogram
    hist_vals = imhist(uint8(arr), 256);
    total = numel(arr);
    sumB = 0;
    wB = 0;
    maximum = 0;
    % Precompute full histogram sum
    sum1 = sum((0:255)' .* hist_vals);
    % Otsu main loop
    for i = 0:255
        wB = wB + hist_vals(i+1);
        if wB == 0
            continue;
        end
        wF = total - wB;
        if wF == 0
            break;
        end
        sumB = sumB + i * hist_vals(i+1);
        mB = sumB / wB;
        mF = (sum1 - sumB) / wF;
        between = wB * wF * (mB - mF)^2;
        if between > maximum
            maximum = between;
            threshold = i;
        end
    end
    % Apply threshold (standard Otsu: objects = brighter pixels)
    BW = arr > threshold;
    % Return logical
    BW = logical(BW);
end


