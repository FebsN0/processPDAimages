function resFrictionAllExp=A1_frictionGlassCalc_method1(dataBK,metaDataBK,secondMonitorMain,newFolder,nameScan_AllScan,varargin)

% This function opens an .JPK image file in which the tip scanned the glass in order to retrieve the glass
% friction coefficient at different setpoints
%
% Author: Altieri F.
% University of Tokyo
% 
% Last update 26.June.2024

%%%%%%%%%%%%------------- IMPORTANT NOTE -------------%%%%%%%%%%%%
%%%%%% for the next function, the glass only friction coefficient is required!
%%%%%% When measurement for a PDA sample is done, also run measurements on only glass using the same conditions
%%%%%% Example: if you run 20 experiments with 2 different speeds and 10 different setpoints, then run the
%%%%%% same 20 experiments but only on glass.
%%%%%% For each experiment (with Hover Mode OFF, thus TRACE-RETRACE), you will get lateral and vertical signals
%%%%%%      - verSignals (V) ==> verForce (N)
%%%%%%      - latSignals (V) ==> latForce (N) (using alpha calibration factor)
%%%%%% after that, obtain the slope (y=lateral, x=vertical) which correspond to the glass friction
%%%%%% average any glass friction coefficient from the different experiments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    p=inputParser(); 
    argName = 'Silent';     defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    parse(p,varargin{:});
    clearvars argName defaultVal
    if(strcmp(p.Results.Silent,'Yes'));  SeeMe=0; else, SeeMe=1; end
    
    numFiles=length(dataBK);
    if SeeMe
        f1=figure('Visible','on');
    else
        f1=figure('Visible','off');
    end
    hold on
    limitsXYdata=zeros(2,2,numFiles);
    % init the var where store the different coefficient frictions of any scan image
    resFrictionAllExp=struct('nameScan',[],'slope',[],'offset',[]);
    for j=1:numFiles
        nameScan=nameScan_AllScan{j};
        resFrictionAllExp(j).nameScan = nameScan;
        % extract the needed data
        dataSingle=dataBK{j};
        metadataSingle=metaDataBK{j};
        % verDefl expressed in Newton
        vertical_Trace = dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image;
        vertical_ReTrace = dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image;
        % latDefl expressed in Volt
        latDefl_trace   = dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image;
        latDefl_retrace = dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image;
        % average trace and retrace scan lines (lateral deflection) to cancel out errors.
        % Calc Delta (loop offset)
        Delta =  (latDefl_trace + latDefl_retrace)/2;
        % Calc W (half-width loop)
        W = latDefl_trace - Delta;                          
        % convert W into force (in Newton units) using alpha calibration factor
        force=W*metadataSingle.Alpha;
        % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
        force=rot90(flipud(force));
        vertical_Trace=rot90(flipud(vertical_Trace));
        vertical_ReTrace=rot90(flipud(vertical_ReTrace));
        % convert N into nN
        force=force*1e9;
        vertical_Trace=vertical_Trace*1e9;
        vertical_ReTrace=vertical_ReTrace*1e9;
       
        % Remove extreme outliers using a defined threshold of 4nN ==> not reliable data ==> trace and retrace in vertical
        % should be almost the same.
        % This threshold is used as max acceptable difference between trace and retrace of vertical data        
        Th = 4;
        % average of each single fast line
        vertTrace_avg = mean(vertical_Trace,2);
        vertReTrace_avg = mean(vertical_ReTrace,2);
        % find the idx (slow direction) for which the difference 
        % of average vertical force between trace and retrace is acceptable
        Idx = abs(vertTrace_avg - vertReTrace_avg) < Th;
        % using this idx, remove strong outliers in entire lines in the lateral force too
        force_fixed = force(Idx,:);
        % prepare the x data for the fitting
        vertForce_avg_fixed = (vertTrace_avg(Idx,:) + vertReTrace_avg(Idx)) / 2;
        % average the fast lines of force
        [force_fixed_avg,vertForce_avg_fixed2]=feature_avgLatForce(force_fixed,vertForce_avg_fixed);
        % plot the experimental data
        limitsXYdata(:,:,j)=feature_plotErrorBar(vertForce_avg_fixed2,force_fixed_avg,j,nameScan);
        % fit the data and plot the fitted curve
        resFit=feature_fittingForceSetpoint(vertForce_avg_fixed2,force_fixed_avg,j);   
        % store the slope and offset
        resFrictionAllExp(j).slope=resFit(1);
        resFrictionAllExp(j).offset=resFit(2);         
    end

     % find the absolute minimum and maximum in all the data to better show the final results
    absMinX=min(limitsXYdata(1,1,:)); absMaxX=max(limitsXYdata(1,2,:));
    absMinY=min(limitsXYdata(2,1,:)); absMaxY=max(limitsXYdata(2,2,:));
    % prepare the plot for the definitive results
    xlim([absMinX*0.7 absMaxX*1.1]), ylim([absMinY*0.7 absMaxY*1.1])
    xlabel('Setpoint (nN)','Fontsize',15); ylabel('Delta Offset (nN)','Fontsize',15); grid on, grid minor
    legend('Location','northwest','FontSize',15,'Interpreter','none')
    title('Delta Offset vs Vertical Force - Method 1','FontSize',20);
    if ~isempty(secondMonitorMain); objInSecondMonitor(secondMonitorMain,f1); end
    saveas(f1,sprintf('%s/resultMethod_1_DeltaOffsetVSsetpoint.tif',newFolder))
    if SeeMe
        uiwait(msgbox('Click to conclude'));
    end
    close(f1)    
end



