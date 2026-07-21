function [imgsClip,lims,loHi] = imadjustMultiple(imgs, varargin)
    % Clips multiple images to a SHARED intensity window so they are
    % directly comparable, preserving original numerical values
    % (no normalization, just saturation at the shared low/high bounds).
    %
    % imgs     : cell array of matrices, e.g. {A, B, C, D}
    % 'Limits' : percentile range used to define the shared window (default [1 99])
    %
    % Output: cell array of clipped matrices, same size/order/units as input

    p = inputParser();
    addRequired(p, 'imgs', @(x) iscell(x) && ~isempty(x));
    addParameter(p, 'Limits', [.5 99.5], ...
        @(x) isnumeric(x) && isvector(x) && numel(x)==2 && all(x>=0 & x<=100));
    parse(p, imgs, varargin{:});

    lims = p.Results.Limits;
    loHi = commonIntensityRange(imgs,lims);
    lo = loHi(1); hi = loHi(2);

    imgsClip = cellfun(@(x) min(max(double(x), lo), hi), ...
        imgs, 'UniformOutput', false);
end


%%%% FUNCTIONS
function loHi = commonIntensityRange(imgs, lims)
    % Computes a shared [low high] intensity range across multiple images    
    allData = cellfun(@(x) x(:), imgs, 'UniformOutput', false);
    allData = vertcat(allData{:});
    loHi = prctile(allData, lims);
end
