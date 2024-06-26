function avg_fc=A5_frictionGlassCalc_method1(alphaGlass,dataGlass,secondMonitorMain)

% This function opens an .JPK image file in which the tip scanned the glass in order to retrieve the glass
% friction coefficient at different setpoints
%
% Author: Altieri F.
% University of Tokyo
% 
% Last update 26.June.2024
    
    % extract the needed data
    % latDefl expressed in Volt
    latDefl_trace   = dataGlass(strcmpi({dataGlass.Channel_name},'Lateral Deflection') & strcmpi({dataGlass.Trace_type},'Trace')).AFM_image;
    latDefl_retrace = dataGlass(strcmpi({dataGlass.Channel_name},'Lateral Deflection') & strcmpi({dataGlass.Trace_type},'ReTrace')).AFM_image;
    % verDefl expressed in Newton
    verForce         = dataGlass(strcmpi({dataGlass.Channel_name},'Vertical Deflection') & strcmpi({dataGlass.Trace_type},'Trace')).AFM_image;
    % obtain the setpoint value. Note: because of little instabilities, round the vertical values to the fixed setpoint 
    % (i.e. 3.091 nN --> 3.000 nN)
    verForce = round(verForce,8);
 
    % average trace and retrace scan lines (lateral deflection) to cancel out errors.
    % Delta = loop offset
    % W = half-width loop
    Delta =  (latDefl_trace + latDefl_retrace)/2;
    W = latDefl_trace -  Delta;                     
    
    if ~isempty(secondMonitorMain), f1=figure; objInSecondMonitor(f1,secondMonitorMain,'maximized'); else, figure; end
    surf(W,'LineStyle','none'), title('W half-width loop')
    xlabel(' fast direction - scan line'), zlabel('W [V]'), ylabel('slow direction')

    % convert W into force (in Newton units) using alpha calibration factor
    force=W*alphaGlass;
       
    % find unique groups of setpoints and its index.
    [~, ~, group_ids] = unique(verForce, 'rows', 'stable');
    start_indices = [];
    for i = 1:max(group_ids)
        group_indices = find(group_ids == i,1);
        start_indices = [start_indices; group_indices];
    end
    % Using the previous indexes, group the lateral deflection scan lines in correspondence with the same applied setpoint
    force_avg_singleSetpoint=zeros(length(start_indices),1);
    force_std_singleSetpoint=zeros(length(start_indices),1);
    setpoints=zeros(length(start_indices),1);
    for i=1:length(start_indices)
        if i==length(start_indices)
            last=length(force);
        else
            last=start_indices(i+1)-1;
        end
        %average the scan line and then the group in which the setpoint is same
        force_avg_singleSetpoint(i)=mean(mean(force(start_indices(i):last,:),2));
        force_std_singleSetpoint(i)=std(mean(force(start_indices(i):last,:),2));
        setpoints(i)=mean(mean(verForce(start_indices(i):last,:),2));
    end
    
    %FITTING VERTICAl and LATERAL DEFLECTION (both expressed in Newton)
    % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
    [fitresult,~]=fit(setpoints,force_avg_singleSetpoint, 'poly1' );
    %plot the fitting curve and the experimental data
    x=linspace(verForce(1),verForce(end),100);
    y=(fitresult.p1*x+fitresult.p2);
    if ~isempty(secondMonitorMain), f2=figure; objInSecondMonitor(f2,secondMonitorMain,'maximized'); else, figure; end
    hold on
    plot(x,y), plot(setpoints,force_avg_singleSetpoint,'k*')
    hold off, xlabel('Vertical Deflection [N]'), ylabel('Lateral Deflection [N]'), grid on
    legend('fitted curve','experimental data','Location','northwest')
    avg_fc=fitresult.p1;
end



