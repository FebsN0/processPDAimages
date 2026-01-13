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
    parse(p,varargin{:});
    pInit = p.Results.pInit; pMin = p.Results.pMin; pMax = p.Results.pMax;
    
    % --- UI Figure
    fig = uifigure('Name','Percentile clip (interactive)');
    objInSecondMonitor(fig, idxMon);
    
    % Layout grid
    gl = uigridlayout(fig,[2 2]);
    gl.RowHeight = {'1x', 100};
    gl.ColumnWidth = {'1x','1x'};    
    ax1 = uiaxes(gl); ax1.Layout.Row = 1; ax1.Layout.Column = 1;
    ax2 = uiaxes(gl); ax2.Layout.Row = 1; ax2.Layout.Column = 2;
    
    % ---- controls row (2 rows × 3 columns) ---- (1st row empty|empty|AcceptBtn - 2nd row number|slider|TakeOriginalBtn
    ctrl = uigridlayout(gl,[2 3]);
    ctrl.Layout.Row = 2;
    ctrl.Layout.Column = [1 2];
    ctrl.RowHeight   = {'1x', '1x'};      % top = Accept, bottom = slider row
    ctrl.ColumnWidth = {140,'1x',220};  % label | slider | buttons
    ctrl.RowSpacing  = 6;
    % --- Row 2: label + slider ---
    lbl = uilabel(ctrl,'Text',sprintf('p = %.2f',pInit));
    lbl.Layout.Row = 2;
    lbl.Layout.Column = 1;
    sld = uislider(ctrl,'Limits',[pMin pMax],'Value',pInit);
    sld.Layout.Row = 2;
    sld.Layout.Column = 2;
    sld.MajorTicks = [];
    sld.MinorTicks = [];
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
    [pNow, dataNow] = localClip(data, pInit);
    h2 = localShowUI(ax2, dataNow, sprintf(titleTemplateClean,pNow), labelBar, AxisLength);
    % --- shared state
    pChosen = NaN; dataClean = [];
    % --- continuous update while dragging
    sld.ValueChangingFcn = @(src,evt) onSlide(evt.Value);
    % --- also update on final release (optional redundancy)
    sld.ValueChangedFcn  = @(src,evt) onSlide(src.Value);
    % --- buttons
    btnOK.ButtonPushedFcn = @(~,~) doAccept();
    btnCA.ButtonPushedFcn = @(~,~) doCancel();
    
    % Block until accept/cancel
    uiwait(fig);
    close(fig)

% ---------------- nested callbacks ----------------
    function onSlide(pVal)
        [pUse, dataCl] = localClip(data, pVal);
        lbl.Text = sprintf('p = %.2f', pUse);

        % Update image data + alpha (NaN transparent)
        h2.CData = dataCl;
        h2.AlphaData = ~isnan(dataCl);

        ax2.Title.String = sprintf(titleTemplateClean, pUse);
        drawnow limitrate
    end

    function doAccept()
        pChosen = sld.Value;
        [pChosen, dataClean] = localClip(data, pChosen);
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
function [h, climRef] = localShowUI(ax, data, ttl, labelBar, AxisLength)
    [x,y] = localAxisVectors(data, AxisLength);
    h = imagesc(ax,x,y,data);
    h.AlphaData = ~isnan(data);
    ax.Color = 'black';
    colormap(ax, parula(256));
    cb = colorbar(ax);
    cb.Label.String = string(labelBar);
    ax.Title.String = ttl;
    axis(ax,'equal'); xlim(ax,'tight'); ylim(ax,'tight');

    v = data(:); v = v(~isnan(v));
    if isempty(v), climRef = [0 1];
    else
        climRef = [prctile(v,1) prctile(v,99)];
        if climRef(1) == climRef(2)
            climRef = [min(v) max(v)];
            if climRef(1)==climRef(2), climRef = climRef + [-1 1]; end
        end
    end
end

function [pUse, dataClipped] = localClip(data, pUse)
    v = data(:); v = v(~isnan(v));
    if isempty(v), dataClipped = data; return; end
    th = prctile(v, pUse);
    dataClipped = data;
    dataClipped(dataClipped > th) = NaN;
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
