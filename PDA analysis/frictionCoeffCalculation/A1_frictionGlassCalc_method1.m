function avg_fc=A1_frictionGlassCalc_method1(dataBK,metaDataBK,secondMonitorMain,filePath,varargin)

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
    
    % create a new directory where store the BK results of every processes scan
    newFolder=fullfile(filePath,'Results All Only-Background');
    if exist(newFolder, 'dir')
        question= sprintf('Directory already exists and it may already contain previous results.\nDo you want to overwrite it or create new directory?');
        options= {'Overwrite the existing dir','Create a new dir'};
        if getValidAnswer(question,'',options) == 1
            rmdir(newFolder, 's');
            mkdir(newFolder);
        else
            % create new directory with different name
            nameFolder = inputdlg('Enter the name new folder','',[1 80]);
            newFolder = fullfile(filePathData,nameFolder{1});
            mkdir(newFolder);
            clear nameFolder
        end
    else
        mkdir(newFolder);
    end

    numFiles=length(dataBK);
    fc=zeros(1,numFiles);
    if SeeMe
        f1=figure('Visible','on');
    else
        f1=figure('Visible','off');
    end
    xlabel('Vertical Deflection [nN]','FontSize',15), ylabel('Lateral Deflection [nN]','FontSize',15), grid on
    title(sprintf('Results of %d curves of AFM only background',numFiles),'FontSize',15);
    pfs=[];
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k'};
    for j=1:numFiles
        % extract the needed data
        dataSingle=dataBK{j};
        metadataSingle=metaDataBK{j};
        % latDefl expressed in Volt
        latDefl_trace   = dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image;
        latDefl_retrace = dataSingle(strcmpi([dataSingle.Channel_name],'Lateral Deflection') & strcmpi([dataSingle.Trace_type],'ReTrace')).AFM_image;
        % verDefl expressed in Newton
        verForce        = dataSingle(strcmpi([dataSingle.Channel_name],'Vertical Deflection') & strcmpi([dataSingle.Trace_type],'Trace')).AFM_image;
        
        % obtain the setpoint value. Note: because of little instabilities, round the vertical values to the fixed setpoint 
        % (i.e. 3.091 nN --> 3.000 nN)
        verForce = round(verForce,9);
     
        % average trace and retrace scan lines (lateral deflection) to cancel out errors.
        % Calc Delta (loop offset)
        Delta =  (latDefl_trace + latDefl_retrace)/2;
        % Calc W (half-width loop)
        W = latDefl_trace - Delta;                          
        % convert W into force (in Newton units) using alpha calibration factor
        force=W*metadataSingle.Alpha;
        % convert into nN
        force=force*1e9;
        verForce=verForce*1e9;
        % find unique groups of vertical force and its index
        [vertForceAVG, start_indices] = unique(round(mean(verForce,1),1));
        % flip, so the coefficient will be positive
        if start_indices(1)>start_indices(end)
            verForce=flip(verForce,2);
            force=flip(force,2);
            start_indices=flip(start_indices);
        end

        % Using the previous indexes, group the lateral deflection scan lines in correspondence with the same applied setpoint
        force_avg_singleSetpoint=zeros(length(start_indices),1);
        force_std_singleSetpoint=zeros(length(start_indices),1);
        for i=1:length(start_indices)
            if i==length(start_indices)
                last=size(force,2);
            else
                last=start_indices(i+1)-1;
            end
            %average the scan line and then the group in which the setpoint is same
            force_avg_singleSetpoint(i)=mean(mean(force(:,start_indices(i):last)));
            force_std_singleSetpoint(i)=std(mean(force(:,start_indices(i):last)));
        end

        [x,y]=prepareCurveData(vertForceAVG,force_avg_singleSetpoint);

        %FITTING VERTICAl and LATERAL DEFLECTION (both expressed in Newton)
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2

        [fitresult,~]=fit(x,y, 'poly1' );
        %plot the fitting curve and the experimental data
        x=linspace(verForce(1),verForce(end),100);
        y=(fitresult.p1*x+fitresult.p2);
        figure(f1)
        hold on
        eqn = sprintf('y = %0.3gx + %0.3g', fitresult.p1, fitresult.p2);
        pf(j)=plot(x,y,'DisplayName',sprintf('Fitted curve: %s',eqn),'Color',colors{j});
        ps=plot(vertForceAVG,force_avg_singleSetpoint,'k*','DisplayName','lateralForce_avg');
        pe=errorbar(vertForceAVG,force_avg_singleSetpoint,force_std_singleSetpoint, 'k', 'LineStyle', 'none', 'Marker','none','LineWidth', 1.5,'DisplayName','lateralForce_std');
        xlim([0,max(vertForceAVG) * 1.1]);
        hold off        
        
        fc(j)=fitresult.p1;
        pfs=[pfs pf(j)];
    end
    legend([ps,pe,pfs],'Location','northwest','FontSize',15,'Interpreter','none')

    %legend([ps,pe,pf(1),pf(2),pf(3)],'Location','northwest','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f1);
    saveas(f1,sprintf('%s/resultA5method1_2_DeltaOffsetVSsetpoint.tif',newFolder))
    avg_fc=mean(fc);
    
end



