function[IO_Image, detailOperations] = binarize_GUI(image)
% Initialize outputs
    segImage = [];
    binarizationMethod_text = [];
    morphologicalOperations_text = [];
    % max 15 operations, very unlikely to reach this iteration, but just in case
    segImage_MorphOpsHistory=cell(20);
    counterHistory=1;
    % Create main figure
    mainFig = uifigure('Name', 'Interactive Binarization Tool', ...
                     'NumberTitle', 'off', ...
                     'WindowState','maximized','CloseRequestFcn', @onUserClose);
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
    imshow(image, 'Parent', axOriginal);
    axis(axOriginal, 'image');
    axOriginal.Toolbar.Visible = 'on';
    title(axOriginal, 'Original (imadjusted - saturated 1% bottom and 99% top)','FontSize',13);   
    % Right axis
    axBin = uiaxes(imgGrid);
    axBin.Layout.Row = 1;
    axBin.Layout.Column = 2;
    tmpImg = imshow(zeros(size(image)), 'Parent', axBin);
    axis(axBin, 'image');
    axBin.Toolbar.Visible = 'on';
    title(axBin, 'Binarized Preview','FontSize',14);

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
    xlabel(axHist, 'Intensity Pixel', 'FontSize', 12);
    ylabel(axHist, 'PDF count', 'FontSize', 12);
    title(axHist, 'Intensity Distribution (imadjusted)', 'FontSize', 13);
    axHist.ButtonDownFcn = [];  % disabled by default
    % ================================================================
    % (C) RIGHT-BOTTOM: BUTTONS (Column 5-6, Row 2 but lower half)
    % ================================================================
    ctrlPanel = uipanel(mainLayout);
    ctrlPanel.Layout.Row = 2;
    ctrlPanel.Layout.Column = [5 6];
    % inside the control panel, there are 6 rows and 1 column (nested grid)
    ctrlGrid = uigridlayout(ctrlPanel, [6 1]);
    ctrlGrid.RowHeight = {'0.90x','0.90x','0.90x','0.90x','0.90x','1.5x'};

    % ---- Buttons ----
    % BINARIZATION CONTROL
    btnAuto = uibutton(ctrlGrid, 'Text','Run Binarization (select method below)','FontSize',14,'ButtonPushedFcn',@runBinarization);
    btnAuto.Layout.Row = 1;
    % nested grid
    row2cols = uigridlayout(ctrlGrid, [1 2]);
    row2cols.ColumnWidth = {'1x','1x'};
    typeMethodPopup=uidropdown(row2cols,'Value','Adaptthresh (mean statistics)','FontSize',13,'Items', ...
        {'Adaptthresh (mean statistics)','Adaptthresh (median statistics)','Adaptthresh (gaussian statistics)','Otsu''s method','Global manual (click on histogram)'});            
    numField = uieditfield(row2cols,'numeric',"Limits",[0 1], "LowerLimitInclusive","off","UpperLimitInclusive","off", ...
        "Placeholder","Sensitivity Adaptthresh (def: 0.5)","AllowEmpty",'on',"Value",[],'HorizontalAlignment','center','FontSize',13);
    row2cols.ColumnSpacing=10; row2cols.Padding=0;

    % MORPHOLOGICAL CLEANING OPERATIONS TO REMOVE NOISE AND SMALL PIXELS
    btnMorphological = uibutton(ctrlGrid, 'Text','Run Morphological Operations (remove white pixels (1) on binary image)','FontSize',13, ...
        'ButtonPushedFcn',@applyMorphologyCleaning,'Enable','off');
    btnMorphological.Layout.Row = 3;
    % nested grid
    row3cols = uigridlayout(ctrlGrid, [1 3]);
    row3cols.ColumnWidth = {'1x','1x','1x'};
    row3cols.ColumnSpacing=10; row3cols.Padding=0; row3cols.Layout.Row = 4;
    kernelPopup = uidropdown(row3cols,'Items',{'disk','square','diamond','rectangle','octagon'},'Value','square','FontSize',13);
    kernelValue=uieditfield(row3cols,'numeric',"Limits",[0 100], "LowerLimitInclusive","on","UpperLimitInclusive","on", ...
        "Placeholder","Kernel Radius (def: 3)","AllowEmpty",'on',"Value",[],'HorizontalAlignment','center','FontSize',13);
    btnUndo=uibutton(row3cols,'Text','Undo last Morph.Op.','FontSize', 13,'ButtonPushedFcn',@undoMO,'Enable','off');
    
    btnInvertBinary = uibutton(ctrlGrid,'Text','Invert Binary Image: white (1) ↔ black (0)','FontSize', 14,'ButtonPushedFcn',@invertBinaryImage,'Enable','off');
    btnInvertBinary.Layout.Row = 5;
    % END BUTTON
    btnConfirm = uibutton(ctrlGrid, 'Text','Confirm the Binarized Preview and close','FontSize',20,'ButtonPushedFcn', @terminate,'Enable','off');
    btnConfirm.Layout.Row = 6;
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
            case 'rectangle'
                kernel = strel('rectangle', [rad rad]);
            case 'octagon'
                rad=round(rad/3)*3;
                kernel = strel('octagon', rad);
        end
        morphologicalOperations_text=sprintf("Kernel: %s - size: %d",kernelType,rad);
        segImage_cleared = imerode(segImage, kernel);
        segImage_cleared = imdilate(segImage_cleared, kernel);
        segImage=segImage_cleared;
        % Update preview
        updateBinImage(segImage, binarizationMethod_text,morphologicalOperations_text)

        % update history of applied Morph.operations
        segImage_MorphOpsHistory{counterHistory,1}=segImage_cleared;
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


