function A6_feature_plotFluoHeighCorrCurve_medianPatch(axCorr,FluoHeigh,idxColor,nameScanText)    
    x=[FluoHeigh.BinCenter]*1e9; % 'Feature height (nm)'
    y=[FluoHeigh.BinMedian];
    sUp=[FluoHeigh.Bin75prctile];
    sDown=[FluoHeigh.Bin25prctile];
    % ensure column vectors
    x = x(:); y = y(:); sUp = sUp(:); sDown = sDown(:);
    % remove NaNs if needed
    valid = ~(isnan(x) | isnan(y) | isnan(sUp) | isnan(sDown));
    x = x(valid); y = y(valid); sUp = sUp(valid); sDown = sDown(valid);
    % sort by x in case data are not monotonic
    [x, idx] = sort(x); y = y(idx); sUp = sUp(idx); sDown = sDown(idx);
    % build shaded region
    xpatch = [x; flipud(x)];
    ypatch = [sDown; flipud(sUp)];
    patch(axCorr, xpatch, ypatch, globalColor(idxColor), 'FaceAlpha', 0.30,'EdgeColor', 'none','HandleVisibility', 'off');
    hold(axCorr,'on')              
    % plot the correlation
    plot(axCorr, x, y,'Color', globalColor(idxColor),'LineWidth', 2,"DisplayName",nameScanText);  
end