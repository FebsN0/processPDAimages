function resStatistics=afmDistribution_skewness_analysis(trace,retrace,saveFigPath,nameFig,type,textTitlePart)
% AFM_SKEWNESS_ANALYSIS  Skewness-based symmetry analysis of AFM force data.
%
%   afm_skewness_analysis(trace, retrace)
%
%   Inputs:
%     trace   - vector of force values (trace direction)
%     retrace - vector of force values (retrace direction)
%
%   Outputs (in figure):
%     - Overlaid KDE distributions with skewness annotated
%     - Skewness comparison bar chart
%     - Quantile–quantile plot of trace vs mirrored retrace
%     - Console output: skewness values, symmetry test p-values
%
%   Symmetry test used: modified sign test on (x - median) for each
%   distribution, plus a Mira (2009) nonparametric skewness test.
%   Both are distribution-free and appropriate for AFM force data. 
    % ── Input validation ──────────────────────────────────────────────────────
    if nargin < 2
        error('Provide both trace and retrace vectors.');
    end
    trace   = trace(:);
    retrace = retrace(:);
    if strcmp(type,"Force")
        textXLabel="Force [nN]";
        textXTitle=sprintf('AFM Force Distribution (%s) — Symmetry Analysis',textTitlePart);
    elseif strcmp(type,"Voltage")
        textXLabel="Deflection [V]";
        textXTitle=sprintf('AFM Deflection Distribution (%s) — Symmetry Analysis',textTitlePart);
    else
        textXLabel="";
        textXTitle=sprintf('Data Distribution (%s) — Symmetry Analysis',textTitlePart);
    end    
    % ── Remove NaNs ───────────────────────────────────────────────────────────
    trace   = trace(~isnan(trace));
    retrace = retrace(~isnan(retrace));
    allDataHistog=[trace;retrace];
    pLow = prctile(allDataHistog, .5);
    pHigh = prctile(allDataHistog, 99.5);

    % ── Core statistics ───────────────────────────────────────────────────────
    sk_tr  = skewness(trace);
    sk_rt  = skewness(retrace);     
    med_tr  = median(trace);
    med_rt  = median(retrace);
    mean_tr = mean(trace);
    mean_rt = mean(retrace);
    std_tr  = std(trace);
    std_rt  = std(retrace);
     
    % Pearson's second skewness coefficient (robust, median-based):
    % = 3*(mean - median) / std
    pearson_tr = 3 * (mean_tr - med_tr) / std_tr;
    pearson_rt = 3 * (mean_rt - med_rt) / std_rt;
            
    % Also test if retrace ≈ mirror of trace using a 2-sample KS test
    % on trace vs -retrace:
    medianAxis=(med_tr+med_rt)/2;
    retrace_mirror = 2 * medianAxis - retrace;   % instead of -retrace + 2*med_rt
    % save the output
    resStatistics.medianTrace=med_tr;
    resStatistics.medianReTrace=med_rt;
    resStatistics.medianAxis=medianAxis;
    resStatistics.retrace_mirror=retrace_mirror;

    [h_mirror, p_mirror, ks_stat] = kstest2(trace, retrace_mirror);     
    if h_mirror
        textXsubtitle='Result: Trace and Retrace differ → NOT mirror images (reject H0 at α=0.05).';
    else
        textXsubtitle='Result: no significant difference Trace and Retrace → consistent with mirror symmetry (fail to reject H0).';
    end
    % ── Std ratio verdict string (reused in panel 4) ─────────────────────
    % Std ratio — a spread mismatch means mirror symmetry breaks even with a
    % perfect axis.  ratio = 1 ideally; >1.1 or <0.9 warrants attention.
    std_ratio = std_tr / std_rt;
    if abs(std_ratio - 1) < 0.1
        ratio_verdict = '✓ spreads matched';
        ratio_col_flag = 'g';   % green
    elseif abs(std_ratio - 1) < 0.2
        ratio_verdict = '⚠ moderate spread mismatch';
        ratio_col_flag = 'a';   % amber
    else
        ratio_verdict = '✗ large spread mismatch';
        ratio_col_flag = 'r';   % red
    end

    % ── Main Big Figure ────────────────────────────────────────────────────────────────
    fStatistics=figure('Name', 'AFM Force Skewness Analysis', ...
           'Color', [0.12 0.12 0.14], ...
           'Units', 'normalized', ...
           'Position', [0.05 0.1 0.88 0.78]);     
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, textXTitle, ...
        'Color', [0.9 0.9 0.9], 'FontSize', 16, 'FontWeight', 'bold');
    subtitle(tl,textXsubtitle,...
        'Color', [0.9 0.9 0.9], 'FontSize', 13, 'FontWeight', 'bold');     
    col_tr = [0.36 0.72 0.92];   % blue-ish for trace
    col_rt = [0.96 0.62 0.35];   % amber for retrace
    ax_bg  = [0.16 0.16 0.19];
    txt_c  = [0.88 0.88 0.88];
     
    % ── Panel 1: KDE overlay ─────────────────────────────────────────────────
    ax1 = nexttile;
    hold(ax1, 'on');     
    [f_tr, xi_tr] = ksdensity(trace); % data-#points
    [f_rt, xi_rt] = ksdensity(retrace);     
    % Also show reflected retrace for visual mirror check
    [f_mirror, xi_mirror] = ksdensity(retrace_mirror);     
    fill_between(ax1, xi_tr, f_tr, col_tr, 0.25);    
    fill_between(ax1, xi_rt, f_rt, col_rt, 0.25);     
    plot(ax1, xi_tr,     f_tr,    '-', 'Color', col_tr, 'LineWidth', 2.0, 'DisplayName', 'Trace');
    plot(ax1, xi_rt,     f_rt,    '-', 'Color', col_rt, 'LineWidth', 2.0, 'DisplayName', 'Retrace');
    plot(ax1, xi_mirror, f_mirror,'--','Color', col_rt, 'LineWidth', 1.2, 'DisplayName', 'Retrace (reflected)');     
    % Mean/median lines    
    plot(ax1, [med_tr  med_tr],  [0 max(f_tr)],  ':', 'Color', col_tr, 'LineWidth', 1.2,'DisplayName',sprintf('Median: %.3g',med_tr));
    plot(ax1, [med_rt  med_rt],  [0 max(f_rt)],  ':', 'Color', col_rt, 'LineWidth', 1.2,'DisplayName',sprintf('Median: %.3g',med_rt));
    plot(ax1, [mean_tr mean_tr], [0 max(f_tr)],  '--','Color', col_tr, 'LineWidth', 0.8,'DisplayName',sprintf('μ±σ: %.3g ± %.2g',mean_tr,std_tr));
    plot(ax1, [mean_rt mean_rt], [0 max(f_rt)],  '--','Color', col_rt, 'LineWidth', 0.8,'DisplayName',sprintf('μ±σ: %.3g ± %.2g',mean_rt,std_rt));     
    plot(ax1, [medianAxis medianAxis], [0 max(f_rt)],  '-','Color', 'red', 'LineWidth', 1.2,'DisplayName',sprintf('MirrorAxis: %.3g',medianAxis));     
    legend(ax1, 'AutoUpdate','off','TextColor', txt_c, 'Color', ax_bg, ...
           'EdgeColor',[0.3 0.3 0.3], 'Location','northwest','FontSize',12);
    % adjust xlim
    xlim(ax1, [pLow, pHigh]);
    % Annotate skewness
    annotation_str = sprintf('g_1^{trace} = %.3f\ng_1^{retrace} = %.3f', sk_tr, sk_rt);
    text(ax1, 0.97, 0.95, annotation_str, 'Units','normalized', ...
        'HorizontalAlignment','right', 'VerticalAlignment','top', ...
        'Color', txt_c, 'FontSize', 11, 'BackgroundColor', [0.2 0.2 0.22], ...
        'EdgeColor', [0.35 0.35 0.38], 'Margin', 4);
     
    style_axis(ax1, ax_bg, txt_c);
    xlabel(ax1, textXLabel, 'Color', txt_c);
    ylabel(ax1, 'Density', 'Color', txt_c);
    title(ax1, 'KDE distributions + reflected retrace', 'Color', txt_c, 'FontSize', 13);
    subtitle(ax1, 'Shown 0.5%tile-99.5%tile of entire dataset', 'Color', txt_c, 'FontSize', 10);
    hold(ax1, 'off');
     
    % ── Panel 2: Skewness comparison bar chart ────────────────────────────────
    ax2 = nexttile;
    hold(ax2, 'on');     
    skew_types  = {'Fisher g1', 'Pearson 2nd'};
    vals_tr     = [sk_tr,     pearson_tr];
    vals_rt     = [sk_rt,     pearson_rt];     
    x = 1:2;
    bw = 0.3;
    b1 = bar(ax2, x - bw/2, vals_tr, bw, 'FaceColor', col_tr, 'EdgeColor','none', 'FaceAlpha', 0.85);
    b2 = bar(ax2, x + bw/2, vals_rt, bw, 'FaceColor', col_rt, 'EdgeColor','none', 'FaceAlpha', 0.85);     
    % Zero line
    yline(ax2, 0, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.8);     
    % Symmetric threshold bands
    yline(ax2,  0.5, '--', 'Color', [0.55 0.85 0.55], 'Alpha', 0.5, 'LineWidth', 0.8);
    yline(ax2, -0.5, '--', 'Color', [0.55 0.85 0.55], 'Alpha', 0.5, 'LineWidth', 0.8);
    yline(ax2,  1.0, '--', 'Color', [0.95 0.65 0.35], 'Alpha', 0.5, 'LineWidth', 0.8);
    yline(ax2, -1.0, '--', 'Color', [0.95 0.65 0.35], 'Alpha', 0.5, 'LineWidth', 0.8);
     
    % Value labels on bars
    for i = 1:2
        v = vals_tr(i);
        text(ax2, i - bw/2, v + 0.03*sign(v), sprintf('%.3f', v), ...
            'HorizontalAlignment','center', 'Color', 'black', 'FontSize', 13,'VerticalAlignment','middle');
        v = vals_rt(i);
        text(ax2, i + bw/2, v + 0.03*sign(v), sprintf('%.3f', v), ...
            'HorizontalAlignment','center', 'Color', 'black', 'FontSize', 13,'VerticalAlignment','middle');
    end

    textXlegend = {'Trace', 'Retrace'};
    legend(ax2, [b1, b2],textXlegend, 'TextColor', txt_c, ...
        'Color', ax_bg, 'EdgeColor',[0.3 0.3 0.3],'FontSize',10,'Location','northwest');
    set(ax2, 'XTick', x, 'XTickLabel', skew_types);
    style_axis(ax2, ax_bg, txt_c);
    grid(ax2, 'off');
    ylabel(ax2, 'Skewness coefficient', 'Color', txt_c);
    title(ax2, 'Skewness metrics', 'Color', txt_c, 'FontSize', 13);     
    % Add region labels on right
    text(ax2, 3, 0.25,   'Symmetrical (|g1| < 0.5)', 'Color',[0.55 0.85 0.55],'FontSize',11,'HorizontalAlignment','right','FontWeight','bold');
    text(ax2, 3, 0.75,   'Mod. skewed (0.5 ≤ |g1| < 1.0)', 'Color',[0.95 0.65 0.35],'FontSize',11,'HorizontalAlignment','right','FontWeight','bold');
    text(ax2, 3, 1.25,   'Highly skewed (|g1| ≥ 1.0)', 'Color','blue','FontSize',11,'HorizontalAlignment','right','FontWeight','bold');
    hold(ax2, 'off');
     
    % ── Panel 3: Q-Q plot trace vs mirror-retrace ─────────────────────────────
    ax3 = nexttile;
    hold(ax3, 'on');
     
    % Quantile–quantile between trace and reflected retrace
    n_q    = 200;
    probs  = linspace(0.01, 0.99, n_q);
    q_tr   = quantile(trace,          probs);
    q_mir  = quantile(retrace_mirror, probs);
     
    scatter(ax3, q_mir, q_tr, 18, probs, 'filled', 'MarkerFaceAlpha', 0.7);
    colormap(ax3, cool(256));
    cb = colorbar(ax3);
    cb.Label.String = 'Quantile';
    cb.Color = txt_c;
     
    % Reference line y = x (perfect mirror symmetry)
    all_q  = [q_tr, q_mir];
    qlims  = [min(all_q), max(all_q)];
    plot(ax3, qlims, qlims, '-', 'Color','black', 'LineWidth', 1.5);
     
    style_axis(ax3, ax_bg, txt_c);
    xlabel(ax3, 'Retrace quantiles (reflected)', 'Color', txt_c);
    ylabel(ax3, 'Trace quantiles', 'Color', txt_c);
    title(ax3, 'Q-Q: trace vs reflected retrace', 'Color', txt_c, 'FontSize', 13);
     
    % Annotate KS test result
    ks_str = sprintf('KS stat = %.3f\nKS p-value = %.4f\n%s', ks_stat, p_mirror, ...
        ternary(h_mirror, 'NOT mirror-symmetric', 'Consistent with mirror symmetry'));
    text(ax3, 0.03, 0.97, ks_str, 'Units','normalized', ...
        'VerticalAlignment','top', 'Color', txt_c, 'FontSize', 11, ...
        'BackgroundColor', [0.2 0.2 0.22], 'EdgeColor',[0.35 0.35 0.38], 'Margin',4);
    hold(ax3, 'off');
     
    % ── Panel 4: Box + swarm plots ────────────────────────────────────────────
    ax4 = nexttile;
    hold(ax4, 'on');
     
    % Subsample for jitter plot (max 800 points each for readability)
    n_jit = 800;
    jit_tr = subsample_jitter(trace,   n_jit);
    jit_rt = subsample_jitter(retrace, n_jit);     
    jx_tr = 1 + 0.18*(rand(numel(jit_tr),1)-0.5);
    jx_rt = 2 + 0.18*(rand(numel(jit_rt),1)-0.5);     
    scatter(ax4, jx_tr, jit_tr, 4, col_tr, 'filled', 'MarkerFaceAlpha', 0.25);
    scatter(ax4, jx_rt, jit_rt, 4, col_rt, 'filled', 'MarkerFaceAlpha', 0.25);    
    ylimRange=[min(min(jit_tr),min(jit_rt))*0.9,max(max(jit_tr),max(jit_rt))*1.3];
    % Box plots
    w_hi_all = zeros(1,2);
    for k = 1:2
        if k == 1; d = trace; c = col_tr; else; d = retrace; c = col_rt; end
        q25   = quantile(d, 0.25);
        q75   = quantile(d, 0.75);
        iqr_d = q75 - q25;
        w_lo  = max(min(d), q25 - 1.5*iqr_d);
        w_hi  = min(max(d), q75 + 1.5*iqr_d);
        w_hi_all(k) = w_hi;
        px  = k;
        bw2 = 0.22;
 
        rectangle(ax4, 'Position', [px-bw2, q25, 2*bw2, q75-q25], ...
            'EdgeColor', c, 'LineWidth', 1.5, 'FaceColor', 'none');
        plot(ax4, [px-bw2, px+bw2], [median(d) median(d)], '-', 'Color', c, 'LineWidth', 2.5);
        plot(ax4, px, mean(d), 'x', 'Color', c, 'LineWidth', 1.5, 'MarkerSize', 8);
        plot(ax4, [px px], [w_lo q25], '-', 'Color', c, 'LineWidth', 1);
        plot(ax4, [px px], [q75 w_hi], '-', 'Color', c, 'LineWidth', 1);
 
        sk_label = sprintf('g_1 = %.3f', skewness(d));
        text(ax4, px, w_hi, sk_label, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'Color', 'black', 'FontSize', 13);
    end

    % ── Std ratio annotation between the two boxes ────────────────────────
    % Bracket spanning both whisker tops, ratio value + verdict centered
    bracket_y = max(w_hi_all) * 1.2;   % sit above the taller whisker top
    line_y    = bracket_y * 0.99;
 
    % Horizontal bracket line
    plot(ax4, [1 2], [bracket_y bracket_y], '-', 'Color', 'black', 'LineWidth', 0.8);
    % Tick marks at each end
    plot(ax4, [1 1], [line_y bracket_y], '-', 'Color', 'black', 'LineWidth', 0.8);
    plot(ax4, [2 2], [line_y bracket_y], '-', 'Color', 'black', 'LineWidth', 0.8);
 
    % Choose annotation color based on verdict
    switch ratio_col_flag
        case 'g'; ann_c = [0.55 0.85 0.55];
        case 'a'; ann_c = [0.95 0.65 0.35];
        case 'r'; ann_c = [0.90 0.35 0.35];
    end
 
    ratio_str = sprintf('std ratio = %.3f\n%s', std_ratio, ratio_verdict);
    text(ax4, 1.5, bracket_y*0.98, ratio_str, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'Color', ann_c, 'FontSize', 10, ...
        'BackgroundColor', [0.2 0.2 0.22], 'EdgeColor', ann_c, 'Margin', 3);
    ylim(ax4,ylimRange)
    set(ax4, 'XTick', [1 2], 'XTickLabel', {'Trace', 'Retrace'});
    style_axis(ax4, ax_bg, txt_c);
    ylabel(ax4, textXLabel, 'Color', txt_c);
    title(ax4, 'Distribution + box  (median  |  mean ×)', 'Color', txt_c, 'FontSize', 13);
    hold(ax4, 'off'); 
    % end figure
    fStatistics.WindowState="maximized";
    saveFigures_FigAndTiff(fStatistics,saveFigPath,nameFig)
end
 
% ── Helper functions ──────────────────────────────────────────────────────
 
function fill_between(ax, x, y, col, alpha)
% Fill area under a curve.
    p=patch(ax, [x, fliplr(x)], [y, zeros(1,numel(y))], ...
        col, 'FaceAlpha', alpha, 'EdgeColor','none');
    p.Annotation.LegendInformation.IconDisplayStyle="off";
end
 
function style_axis(ax, bg, txt_c)
    set(ax, 'Color', bg, 'XColor', txt_c, 'YColor', txt_c, ...
        'GridColor', [0.35 0.35 0.38], 'GridAlpha', 0.4, ...
        'Box', 'off', 'TickDir', 'out', 'FontSize', 9);
    grid(ax, 'on');
end
 
function out = subsample_jitter(x, n)
    if numel(x) > n
        idx = randperm(numel(x), n);
        out = x(idx);
    else
        out = x;
    end
end
 
function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end