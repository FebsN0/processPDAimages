function user_choice = getValidAnswer(question, titleStr, options, default_choice)
% getValidAnswer
% Adaptive option dialog using UIFIGURE + UIGRIDLAYOUT.
% - Question supports '\n' and real newlines -> multi-line display
% - Options now ALSO support '\n' and real newlines
% - Reduced bottom whitespace by tighter padding/spacing and better size estimate

    % ------------------------ Input checks ------------------------
    if nargin < 2 || isempty(titleStr), titleStr = ''; end
    if nargin < 3 || isempty(options), error('Options must be non-empty.'); end
    if nargin < 4 || isempty(default_choice), default_choice = 1; end

    options = cellstr(string(options));
    nOpt = numel(options);

    if ~isnumeric(default_choice) || default_choice < 1 || default_choice > nOpt
        error('Invalid default choice index.');
    end

    % ------------------------ Normalize options ------------------------
    optionStrs = lower(string(options(:)));

    % Yes/No detection
    yesStrings = ["yes","y","1","true"];
    noStrings  = ["no","n","0","false"];
    flagYesNo = false;

    if nOpt == 2
        isYes1 = any(optionStrs(1) == yesStrings);
        isNo2  = any(optionStrs(2) == noStrings);
        isYes2 = any(optionStrs(2) == yesStrings);
        isNo1  = any(optionStrs(1) == noStrings);
        if (isYes1 && isNo2) || (isYes2 && isNo1)
            flagYesNo = true;
        end
    end

    

    % ------------------------ UI sizing heuristics ------------------------
    FontQuestion = 18;
    FontOptions = 15;
    % Compute option metrics that account for '\n' and real newlines
    m = measureDialogContentPixels_legacy(question, options, FontQuestion, FontOptions ,flagYesNo);      

    % ------------------------ Screen clamp (current monitor) ------------------------
    mon = get(0,'MonitorPositions');
    p = get(0,'PointerLocation');
    monIdx = 1;
    for k = 1:size(mon,1)
        if p(1) >= mon(k,1) && p(1) <= mon(k,1)+mon(k,3) && ...
           p(2) >= mon(k,2) && p(2) <= mon(k,2)+mon(k,4)
            monIdx = k; break;
        end
    end
    scr = mon(monIdx,:);
    scrW = scr(3); scrH = scr(4);

    figW = m.targetW_px;
    figH = m.targetH_px;
    figX = scr(1) + (scrW - figW)/2;
    figY = scr(2) + (scrH - figH)/2;
    
    % ------------------------ State ------------------------
    user_choice = 0;
    numericInput = "";
    done = false;

    % ------------------------ UIFIGURE + layout ------------------------
    f = uifigure( ...
        'Name', titleStr, ...
        'Position', [figX figY figW figH], ...
        'Resize', 'on', ...
        'CloseRequestFcn', @onClose);

    f.KeyPressFcn = @onKey;

    % Main grid: question + options
    gl = uigridlayout(f, [2 1]);
    gl.RowHeight = {'fit','fit'};        % avoid forced expansion bottom gap in default size
    gl.ColumnWidth = {'1x'};
    gl.Padding = [12 10 12 2];           % smaller bottom padding
    gl.RowSpacing = 10;
    gl.BackgroundColor='black';
    % Question label
    questionLines = splitToLines_legacy(question);
    qText = strjoin(questionLines, newline);
    qLabel = uilabel(gl, ...
        'Text', qText, ...
        'FontSize', FontQuestion, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'center', ...
        'WordWrap', 'off'); % no text wrapping
    qLabel.Layout.Row = 1;

    % Options area (directly on main grid)
    if flagYesNo
        optGrid = uigridlayout(gl, [1 2]);
        optGrid.Layout.Row = 2;
        optGrid.ColumnWidth = {'1x','1x'};
        optGrid.RowHeight = {'fit'};
        optGrid.ColumnSpacing = 10;
        optGrid.Padding = [0 0 0 0];

        % Determine yes/no meaning for default mapping
        idxYes = find(optionStrs == "yes" | optionStrs == "y" | optionStrs == "1" | optionStrs == "true", 1);
        idxNo  = find(optionStrs == "no"  | optionStrs == "n" | optionStrs == "0" | optionStrs == "false", 1);
        if isempty(idxYes), idxYes = 1; end
        if isempty(idxNo),  idxNo  = 2; end

        bYes = uibutton(optGrid, 'push', ...
            'Text', 'Yes', 'FontSize', FontOptions, ...
            'ButtonPushedFcn', @(~,~)chooseYesNo(true));
        bNo  = uibutton(optGrid, 'push', ...
            'Text', 'No',  'FontSize', FontOptions, ...
            'ButtonPushedFcn', @(~,~)chooseYesNo(false));

        if default_choice == idxYes
            highlightButton(bYes);
        elseif default_choice == idxNo
            highlightButton(bNo);
        end

    else
        optGrid = uigridlayout(gl, [nOpt 2]);
        optGrid.Layout.Row = 2;
        optGrid.ColumnWidth = {52, '1x'};
        optGrid.RowHeight = repmat({'fit'}, 1, nOpt); % key: rows expand for multiline options
        optGrid.RowSpacing = 10;                       
        optGrid.ColumnSpacing = 10;
        optGrid.Padding = [0 0 0 0];
        btns = gobjects(nOpt,1);

        for i = 1:nOpt
            [icon, textOnly] = parseOptionIconAndText(options{i}, i);
            % Convert any literal '\n' sequences to real newlines for display
            textOnly = normalizeNewlines(textOnly);

            btns(i) = uibutton(optGrid, 'push', ...
                'Text', string(icon), ...
                'FontSize', FontOptions, ...
                'ButtonPushedFcn', @(~,~)chooseIndex(i));
            btns(i).Layout.Row = i;
            btns(i).Layout.Column = 1;

            lab = uilabel(optGrid, ...
                'Text', textOnly, ...
                'FontSize', FontOptions, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'off'); % no wrapping
            lab.Layout.Row = i;
            lab.Layout.Column = 2;
            lab.BackgroundColor = "red";
            if i == default_choice
                highlightButton(btns(i));
            end
        end
    end

  
    drawnow;
    uiwait(f);

    if isnan(user_choice)
        error('Closed window. Stopped the process.');
    end

    % ------------------------ Callbacks ------------------------
    function chooseIndex(idx)
        user_choice = idx;
        done = true;
        finish();
    end

    function chooseYesNo(tf)
        user_choice = logical(tf);
        done = true;
        finish();
    end

    function finish()
        if isvalid(f)
            uiresume(f);
            delete(f);
        end
    end

    function onClose(~,~)
        if ~done
            user_choice = NaN;
        end
        finish();
    end

    function onKey(~, event)
        k = lower(string(event.Key));

        if k == "escape"
            onClose();
            return;
        end

        if k == "return" || k == "enter"
            if strlength(numericInput) > 0
                val = str2double(numericInput);
                numericInput = "";
                if ~isnan(val) && val >= 1 && val <= nOpt
                    if flagYesNo
                        if val == 1, chooseYesNo(true); end
                        if val == 2, chooseYesNo(false); end
                    else
                        chooseIndex(val);
                    end
                else
                    numericInput = "";
                end
            else
                if flagYesNo
                    if any(optionStrs(default_choice) == yesStrings)
                        chooseYesNo(true);
                    elseif any(optionStrs(default_choice) == noStrings)
                        chooseYesNo(false);
                    else
                        chooseYesNo(default_choice == 1);
                    end
                else
                    chooseIndex(default_choice);
                end
            end
            return;
        end

        if k == "backspace"
            if strlength(numericInput) > 0
                numericInput = extractBefore(numericInput, strlength(numericInput));
            end
            return;
        end

        if strlength(k) == 1 && k >= "0" && k <= "9"
            numericInput = numericInput + k;
            val = str2double(numericInput);
            if ~isnan(val) && val > nOpt
                numericInput = k;
            end
            return;
        end

        if flagYesNo && (k == "y" || k == "n")
            if k == "y", chooseYesNo(true); else, chooseYesNo(false); end
            return;
        end

        numericInput = "";
    end

    function highlightButton(b)
        b.FontWeight = 'bold';
        try
            b.FontColor = [0.85 0 0];
        catch
        end
    end
end


function metrics = measureDialogContentPixels_legacy(question, options, FontQ, FontOpt, flagYesNo, ui)
% measureDialogContentPixels_legacy
% Estimates dialog content dimensions using classic uicontrol text Extent.
%
% INPUTS:
%   question, options: strings/cells (supports '\n' and real newlines)
%   FontQ, FontOpt   : font sizes for question/options
%   ui               : struct with layout constants (pixels), e.g.:
%       ui.buttonColW   = 52;
%       ui.buttonH      = 44;
%       ui.colSpacing   = 10;
%       ui.rowSpacing   = 6;
%       ui.glPad        = [12 10 12 2];   % [L T R B]
%       ui.mainRowGap   = 8;             % gap between question and options (gl.RowSpacing)
%       ui.safetyW      = 40;
%       ui.safetyH      = 18;
%       ui.lineGapQ     = 2;             % extra gap between question lines
%       ui.lineGapOpt   = 2;             % extra gap between option lines within a row
% OUTPUT (metrics struct):
%   metrics.targetW_px          : recommended figure width (including UI chrome)
%   metrics.targetH_px          : recommended figure height (including padding/gaps)

    % Defaults for ui constants if missing
    if nargin < 6 || isempty(ui), ui = struct(); end
    ui = fillDefaults(ui);
    % Split lines
    questionLines = splitToLines_legacy(question);
    optionsLines = cell(numel(options),1);
    for i = 1:numel(options)
        optionsLines{i} = splitToLines_legacy(options{i});
    end
    % Hidden classic figure & text control for measurement
    fh = figure('Visible','off','Units','pixels','Position',[100 100 400 300]); %#ok<NASGU>
    c = onCleanup(@() close(gcf));
    ht = uicontrol('Style','text','Units','pixels','Position',[1 1 10 10], ...
                   'HorizontalAlignment','left');
        % ---------- Measure question block ----------
    set(ht,'FontSize',FontQ);
    qMaxW = 0;
    qLineHeights = zeros(numel(questionLines),1);
    for k = 1:numel(questionLines)
        set(ht,'String',char(questionLines(k)));
        e = get(ht,'Extent');           % [x y w h]
        qMaxW = max(qMaxW, e(3));
        qLineHeights(k) = e(4);
    end
    if isempty(qLineHeights)
        qH = 0;
    elseif isscalar(questionLines)
        qH = sum(qLineHeights)+10;
    else
        qH = sum(qLineHeights)*(0.95^numel(questionLines));
    end

    % ---------- Measure options block ----------
    set(ht,'FontSize',FontOpt);
    

    if flagYesNo
        optH=30;
        maxLineW = qMaxW;
    else
        optMaxW = 0;
        rowHeights = zeros(numel(options),1);
        for i = 1:numel(options)
            lines = optionsLines{i};
            lineHeights = zeros(numel(lines),1);
    
            for k = 1:numel(lines)
                set(ht,'String',char(lines(k)));
                e = get(ht,'Extent');
                optMaxW = max(optMaxW, e(3));
                lineHeights(k) = e(4);
            end
    
            textH = 0;
            if ~isempty(lineHeights)
                textH = sum(lineHeights) + ui.lineGapOpt * (numel(lineHeights)-1);
            end
    
            % Option row height is at least the button height
            rowHeights(i) = max(ui.buttonH, textH);
        end
        if isempty(rowHeights)
            optH = 0;
        else
            optH = sum(rowHeights)*(0.95^numel(rowHeights));
        end
        % ---------- Combine to recommended figure size ----------
        maxLineW = max(qMaxW, optMaxW);
    end

    % Width: longest text line + button column + spacing + padding + safety
    %targetW = maxLineW + ui.buttonColW + ui.colSpacing + ui.glPad(1) + ui.glPad(3) + ui.safetyW;
    targetW = maxLineW*0.95;
    % Height: padding top/bottom + question + gap + options + safety
    targetH = qH + optH;

    metrics = struct();
    metrics.targetW_px      = targetW;
    metrics.targetH_px      = targetH;
end

function ui = fillDefaults(ui)
    def.buttonColW = 52;
    def.buttonH    = 44;
    def.colSpacing = 10;
    def.rowSpacing = 6;
    def.glPad      = [12 10 12 2]; % [L T R B]
    def.mainRowGap = 8;
    def.safetyW    = 40;
    def.safetyH    = 18;
    def.lineGapQ   = 2;
    def.lineGapOpt = 2;

    fns = fieldnames(def);
    for k = 1:numel(fns)
        if ~isfield(ui, fns{k}) || isempty(ui.(fns{k}))
            ui.(fns{k}) = def.(fns{k});
        end
    end
end

function parts = splitToLines_legacy(s)    
    if iscell(s)
        lines = string.empty(0,1);
        for i = 1:numel(s)
            sarr = string(s{i});
            for k = 1:numel(sarr)
                parts = regexp(char(sarr(k)), '\\n|\r\n|\n', 'split');
                lines = [lines; string(parts(:))]; %#ok<AGROW>
            end
        end
        parts=lines;
    else
        parts = regexp(char(string(s)), '\\n|\r\n|\n', 'split');
        parts = string(parts(:));
    end
    if isempty(parts), parts = ""; end
end

% ---------- Helper: convert literal '\n' to real newline for UI display ----------
function out = normalizeNewlines(in)
    out = string(in);
    out = regexprep(out, '\\n', newline);
end

% ---------- Helper: parse "(n) text" / "n) text" patterns ----------
function [icon, textOnly] = parseOptionIconAndText(optStr, fallbackIdx)
    s = char(string(optStr));

    patterns = { ...
        '^\(\d+\)\s*', ...
        '^\d+\)\s*', ...
        '^\s*\(\d+\)\s*', ...
        '^\s*\d+\)\s*'};

    icon = fallbackIdx;
    textOnly = string(optStr);

    for p = 1:numel(patterns)
        [startIdx, endIdx] = regexp(s, patterns{p}, 'once');
        if ~isempty(startIdx)
            prefix = s(startIdx:endIdx);
            d = regexp(prefix, '\d+', 'match', 'once');
            if ~isempty(d)
                icon = str2double(d);
                if ~isnan(icon)
                    textOnly = string(strtrim(s(endIdx+1:end)));
                end
            end
            return;
        end
    end
end



