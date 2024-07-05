function avg_fc=A5_frictionGlassCalc_method2(alpha,AFM_cropped_ImagesHVOFF_fitted,AFM_H_NoBkHVOFF,secondMonitorMain,newFolder)
%
% This function opens the AFM cropped data previously created to calculate the glass friction
% coefficient. This method is more accurated than the method 1. HOVER MODE OFF DATA
%
% Author: Bratati Das, Zheng Jianlu
% University of Tokyo
% 
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 05/07/2024

    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace_masked    = (AFM_cropped_ImagesHVOFF_fitted(strcmpi({AFM_cropped_ImagesHVOFF_fitted.Channel_name},'Lateral Deflection') & strcmpi({AFM_cropped_ImagesHVOFF_fitted.Trace_type},'Trace')).Cropped_AFM_image).*(~AFM_H_NoBkHVOFF);
    Lateral_ReTrace_masked  = (AFM_cropped_ImagesHVOFF_fitted(strcmpi({AFM_cropped_ImagesHVOFF_fitted.Channel_name},'Lateral Deflection') & strcmpi({AFM_cropped_ImagesHVOFF_fitted.Trace_type},'ReTrace')).Cropped_AFM_image).*(~AFM_H_NoBkHVOFF);
    vertical_Trace   = (AFM_cropped_ImagesHVOFF_fitted(strcmpi({AFM_cropped_ImagesHVOFF_fitted.Channel_name},'Vertical Deflection') & strcmpi({AFM_cropped_ImagesHVOFF_fitted.Trace_type},'Trace')).Cropped_AFM_image);
    vertical_ReTrace = (AFM_cropped_ImagesHVOFF_fitted(strcmpi({AFM_cropped_ImagesHVOFF_fitted.Channel_name},'Vertical Deflection') & strcmpi({AFM_cropped_ImagesHVOFF_fitted.Trace_type},'ReTrace')).Cropped_AFM_image);

    % Calc Delta (offset loop) 
    Delta = (Lateral_Trace_masked + Lateral_ReTrace_masked) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace_masked - Delta;      
        
    % convert W into force (in Newton units) using alpha calibration factor and show results.
    force=W*alpha;
    % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
    force=rot90(flipud(force));
    vertical_Trace=rot90(flipud(vertical_Trace));
    vertical_ReTrace=rot90(flipud(vertical_ReTrace));
    % plot lateral (masked force, N) and vertical data (force, N)
    f1=figure;
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain, f1); end
    subplot(121)
    imagesc(flip(force))
    c= colorbar; c.Label.String = 'Force [N]'; c.FontSize = 15;
    title({'Force in glass regions';'(PDA masked out)'},'FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
    axis equal
    xlim([0 512]), ylim([0 512])
    subplot(122)
    imagesc(flip(vertical_Trace))
    title('Vertical Deflection (masked)','FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
    axis equal
    xlim([0 512]), ylim([0 512])
    saveas(f1,sprintf('%s/resultA5method2_1_ForceInGlassRegionsAndVerticalDeflectionN.tif',newFolder))
    
    % calc average along fast scan line, ignore zero values
    force_avg = zeros(1, size(force,1));
    for i=1:size(force,1)
        tmp = force(i,:);
        force_avg(i) = mean(tmp(tmp~=0));
    end

    % Detect over the threshold. Remove those with vertical force values too outside from theoritical value
    Th = 0.4e-8;
    vertTrace_avg = mean(vertical_Trace,2);
    vertReTrace_avg = mean(vertical_ReTrace,2);
    Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
    % based on the idx, remove the outliers
    force_avg_fix = force_avg(Idx);
    vertTrace_avg_fix = (vertTrace_avg + vertReTrace_avg) / 2;
    vertTrace_avg_fix = vertTrace_avg_fix(Idx);
    
    f3=figure;
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain, f3); end
    plot(vertTrace_avg_fix, force_avg_fix, 'x');
    xlabel('Set Point (N)'); ylabel('Delta Offset (N)');
    xlim([0,max(vertTrace_avg_fix) * 1.1]);   
    % Linear fitting
    p = polyfit(vertTrace_avg_fix, force_avg_fix, 1);
    yfit = polyval(p, vertTrace_avg_fix);
    % plot
    hold on;
    plot(vertTrace_avg_fix, yfit, 'r-.'); grid on
    legend('fitted curve','experimental data','Location','northwest','FontSize',15)
    eqn = sprintf('Linear: y = %0.3g x %0.3g', p(1), p(2));
    title({'Delta Offset vs Set Point'; eqn},'FontSize',15);
    hold off
    saveas(f3,sprintf('%s/resultA5method2_3_DeltaOffsetVSsetpoint.tif',newFolder))
    avg_fc=p(1);
end