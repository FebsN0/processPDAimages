function varargout = percentileClipSlider(idxMon,data,titleOrig,titleTemplateClean,labelBar,AxisLength,varargin)
% percentileClipSlider
% Interactive percentile clipping (values > prctile(data,p) set to NaN)
% with live slider update.
%
% Inputs:
%   idxMon               monitor index for objInSecondMonitor (optional)
%   SeeMe                true/false
%   data                 matrix (can contain NaN)
%   titleOrig            title for original plot (string/char)
%   titleTemplateClean   sprintf template, e.g. 'Height - clipped above %.2fth pct'
%   labelBar             colorbar label (e.g. "Height (nm)")
%   AxisLength           [] or [Y_length_m, X_length_m]
%
% Name-value (optional):
%   'pInit'              initial percentile (default 99)
%   'pMin'               slider min (default 90)
%   'pMax'               slider max (default 100)
%
% Outputs:
%   pChosen              chosen percentile (NaN if cancelled)

% --- parse options
    p = inputParser;
    addParameter(p, 'pInit', 99, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'pMin',  95, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'pMax', 100, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'pLowInit',  1, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'pLowMin',   0, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'pLowMax',   5, @(x) isnumeric(x) && isscalar(x));
    parse(p,varargin{:});
    pHighInit = p.Results.pInit;    pHighMin = p.Results.pMin;      pHighMax = p.Results.pMax;
    pLowInit = p.Results.pLowInit;  pLowMin = p.Results.pLowMin;    pLowMax = p.Results.pLowMax;
    % --- UI Figure
    fig = uifigure('Name','Percentile clip (interactive)');
    objInSecondMonitor(fig, idxMon);
    
    % Layout grid (plots + control row)
    gl = uigridlayout(fig,[2 2]);
    gl.RowHeight = {'1x', 100};
    gl.ColumnWidth = {'1x','1x'};    
    ax1 = uiaxes(gl); ax1.Layout.Row = 1; ax1.Layout.Column = 1;
    ax2 = uiaxes(gl); ax2.Layout.Row = 1; ax2.Layout.Column = 2;
    
    % -------------------------------------------------------------------------
    % Controls: 2 rows × 3 cols
    % Row 1: low-label  | low-slider  | Accept
    % Row 2: high-label | high-slider | Take original
    % -------------------------------------------------------------------------
    ctrl = uigridlayout(gl,[2 3]);
    ctrl.Layout.Row = 2;
    ctrl.Layout.Column = [1 2];
    ctrl.RowHeight   = {'1x', '1x'};      % top = Accept, bottom = slider row
    ctrl.ColumnWidth = {140,'1x',220};  % label | slider | buttons
    ctrl.RowSpacing  = 6;
    % --- Row 1: label + slider Low Percentile ---
    lblLow = uilabel(ctrl,'Text',sprintf('Low clip p = %.2f', pLowInit));
    lblLow.Layout.Row = 1; lblLow.Layout.Column = 1;    
    sldLow = uislider(ctrl,'Limits',[pLowMin pLowMax],'Value',pLowInit);
    sldLow.Layout.Row = 1; sldLow.Layout.Column = 2;
    sldLow.MajorTicks = [];
    sldLow.MinorTicks = [];

    % --- Row 2: label + slider High Percentile ---
    % High percentile (Row 2)
    lblHigh = uilabel(ctrl,'Text',sprintf('High clip p = %.2f', pHighInit));
    lblHigh.Layout.Row = 2; lblHigh.Layout.Column = 1;
    sldHigh = uislider(ctrl,'Limits',[pHighMin pHighMax],'Value',pHighInit);
    sldHigh.Layout.Row = 2; sldHigh.Layout.Column = 2;
    sldHigh.MajorTicks = [];
    sldHigh.MinorTicks = [];

    % --- Row 1: Accept button (above slider) ---
    btnOK = uibutton(ctrl,'Text','Accept');
    btnOK.Layout.Row = 1;
    btnOK.Layout.Column = 3;
    % --- Row 2: Cancel / Take original (same line as slider) ---
    btnCA = uibutton(ctrl,'Text','Take original');
    btnCA.Layout.Row = 2;
    btnCA.Layout.Column = 3;
    btnCA.Tooltip = "Keep original (no percentile clipping)";

    % --- initial render
    localShowUI(ax1, data, titleOrig, labelBar, AxisLength);
    [pLowNow, pHighNow, dataNow] = localClip2Sided(data, pLowInit, pHighInit);
    h2 = localShowUI(ax2, dataNow, sprintf(titleTemplateClean,pLowNow, pHighNow), labelBar, AxisLength);
    
    % --- shared state
    pChosen = [NaN NaN]; dataClean = [];
    % --- continuous update while dragging
    sldLow.ValueChangingFcn  = @(src,evt) onAnySlide(evt.Value, sldHigh.Value);
    sldHigh.ValueChangingFcn = @(src,evt) onAnySlide(sldLow.Value, evt.Value);
    % also update on release (redundant but fine)
    sldLow.ValueChangedFcn   = @(src,evt) onAnySlide(src.Value, sldHigh.Value);
    sldHigh.ValueChangedFcn  = @(src,evt) onAnySlide(sldLow.Value, src.Value);
    
    % --- buttons
    btnOK.ButtonPushedFcn = @(~,~) doAccept();
    btnCA.ButtonPushedFcn = @(~,~) doCancel();
    
    % Block until accept/cancel
    uiwait(fig);
    close(fig)

% ---------------- nested callbacks ----------------
    function onAnySlide(pLowVal, pHighVal)
        [pL, pH, dataClean] = localClip2Sided(data, pLowVal, pHighVal);
        lblLow.Text  = sprintf('Low clip p = %.2f',  pL);
        lblHigh.Text = sprintf('High clip p = %.2f', pH);
        h2.CData = dataClean;
        h2.AlphaData = ~isnan(dataClean);
        % Expect titleTemplateClean to accept TWO values, e.g.:
        % 'Clipped (low %.2f%%, high %.2f%%)'
        ax2.Title.String = sprintf(titleTemplateClean, pL, pH);
        drawnow limitrate
    end

    function doAccept()
        pChosen = [sldLow.Value sldHigh.Value];
        [~, ~, dataClean] = localClip2Sided(data, pChosen(1), pChosen(2));
        varargout{1}=pChosen;        
        varargout{2}=dataClean;
        uiresume(fig);
    end

    function doCancel()
        varargout{1}=NaN;        
        varargout{2}=[];
        uiresume(fig);
    end
end

% ---------- helpers ----------
function h = localShowUI(ax, data, ttl, labelBar, AxisLength)
    [x,y] = localAxisVectors(data, AxisLength);
    h = imagesc(ax,x,y,data);
    h.AlphaData = ~isnan(data);
    ax.Color = 'black';
    colormap(ax, parula(256));
    cb = colorbar(ax);
    cb.Label.String = string(labelBar);
    ax.Title.String = ttl;
    axis(ax,'equal'); xlim(ax,'tight'); ylim(ax,'tight');   
end

function [pLowUse, pHighUse, dataClipped] = localClip2Sided(data, pLowUse, pHighUse)
    % Enforce ordering (avoid invalid states)
    if pLowUse > pHighUse
        tmp = pLowUse; pLowUse = pHighUse; pHighUse = tmp;
    end
    v = data(:); v = v(~isnan(v));
    if isempty(v)
        dataClipped = data;
        return;
    end
    thLow  = prctile(v, pLowUse);
    thHigh = prctile(v, pHighUse);
    dataClipped = data;
    dataClipped(dataClipped < thLow)  = NaN;
    dataClipped(dataClipped > thHigh) = NaN;
end

function [x,y] = localAxisVectors(data, AxisLength)
    if isempty(AxisLength)
        x = 1:size(data,2); y = 1:size(data,1);
    else
        x = linspace(0,AxisLength(2),size(data,2));
        y = linspace(0,AxisLength(1),size(data,1));
        % convert to nm/um for display
        if AxisLength(2) < 1e-6, x = x*1e9; else, x = x*1e6; end
        if AxisLength(1) < 1e-6, y = y*1e9; else, y = y*1e6; end
    end
end
