function avg_fc2=A5_frictionGlassCalc_method2(alpha,Cropped_Images,AFM_height_IO,secondMonitorMain)

% This function opens the AFM cropped data previously created to calculate the glass friction
% coefficient. This method is more accurated than the method 1.
%
% Author: Bratati Das, Zheng Jianlu
% University of Tokyo
% 
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 26/6/2024


% Convert Selected_AFM_data -> AFM_cropped_channels
% AFM_cropped_channels data is different as follows:
%  - Cropped from Selected_AFM_data
%  - Data origin is right-bottom (Selected_AFM_data is top-left).


    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace_img_masked    = (Cropped_Images(strcmpi({Cropped_Images.Channel_name},'Lateral Deflection') & strcmpi({Cropped_Images.Trace_type},'Trace')).Cropped_AFM_image).*(~AFM_height_IO);
    Lateral_ReTrace_img_masked  = (Cropped_Images(strcmpi({Cropped_Images.Channel_name},'Lateral Deflection') & strcmpi({Cropped_Images.Trace_type},'ReTrace')).Cropped_AFM_image).*(~AFM_height_IO);
    vertical_Trace_img_masked   = (Cropped_Images(strcmpi({Cropped_Images.Channel_name},'Vertical Deflection') & strcmpi({Cropped_Images.Trace_type},'Trace')).Cropped_AFM_image).* (~AFM_height_IO);
    vertical_ReTrace_img_masked = (Cropped_Images(strcmpi({Cropped_Images.Channel_name},'Vertical Deflection') & strcmpi({Cropped_Images.Trace_type},'ReTrace')).Cropped_AFM_image).* (~AFM_height_IO);

    % Calc Delta (offset loop) 
    Delta = (Lateral_Trace_img_masked - Lateral_ReTrace_img_masked) / 2;
    W = Lateral_Trace_img_masked - Delta;      
        
    % convert W into force (in Newton units) using alpha calibration factor and show results.
    force=W*alpha;
    % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
    force=rot90(flipud(force));
    vertical_Trace_img_masked=rot90(flipud(vertical_Trace_img_masked));
    vertical_ReTrace_img_masked=rot90(flipud(vertical_ReTrace_img_masked));

    if ~isempty(secondMonitorMain), f1=figure; objInSecondMonitor(f1,secondMonitorMain,'maximized'); else, figure; end
    subplot(121)
    contourf(force,'LineStyle','none')
    c= colorbar; c.Label.String = 'Force [N]'; c.FontSize = 15;
    title('Force in glass regions','FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
    subplot(122)
    contourf(vertical_Trace_img_masked,'LineStyle','none','ShowText','on')
    
    title('Vertical Deflection','FontSize',20)
    xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
   
    % average force along fast scan line
    force_avg = mean(force,2);

    % Detect over the threshold 
    Th = 0.4e-8;
    Ave_VD_Trace = mean(vertical_Trace_img_masked,2);
    Ave_VD_ReTrace = mean(vertical_ReTrace_img_masked,2);
    Diff_VD = abs(Ave_VD_Trace - Ave_VD_ReTrace);
    Idx = Diff_VD < Th;

%% making figure offset vs vd

New_Ave_Offset = force_avg(Idx);
New_Ave_VD = (Ave_VD_Trace + Ave_VD_ReTrace) / 2;
New_Ave_VD = New_Ave_VD(Idx);
figure;
plot(New_Ave_VD, New_Ave_Offset, 'x');
xlabel('Set Point (N)');
ylabel('Delta Offset (N)');
xlim([0,max(New_Ave_VD) * 1.1]);


%% Linear fitting
x = New_Ave_VD;
y = New_Ave_Offset;
p = polyfit(x, y, 1);
yfit = polyval(p, x);

hold on;
plot(x, yfit, 'r-.');

%eqn = string("Linear: y = " + p(1)) + "x + " + string(p(2));
%text(min(x), max(y), eqn, "HorizontalAlignment", "Left", "VerticalAlignment","top");
eqn = sprintf('Linear: y = %f x %+g', p(1), p(2));

title({'Delta Offset vs Set Point'; eqn});