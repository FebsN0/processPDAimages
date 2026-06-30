function fill_between(ax, x, y, col, alpha)
% Fill area under a curve.
    p=patch(ax, [x, fliplr(x)], [y, zeros(1,numel(y))], ...
        col, 'FaceAlpha', alpha, 'EdgeColor','none');
    p.Annotation.LegendInformation.IconDisplayStyle="off";
end