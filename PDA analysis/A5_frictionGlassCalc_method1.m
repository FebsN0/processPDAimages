function avg_fc=A5_frictionGlassCalc_method1(secondMonitorMain,newFolder,varargin)

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

    [fileNameFriction, filePathDataFriction] = uigetfile({'*.jpk'},'Select the .jpk AFM image to extract glass friction coefficient',newFolder,'MultiSelect','on');
    if isequal(fileNameFriction,0)
        error('No File Selected');
    else
        if iscell(fileNameFriction)
            numFiles = length(fileNameFriction);
        else
            numFiles = 1; % if only one file, filename is a string
        end
    end
    newFolder = fullfile(filePathDataFriction, 'Results Processing AFM-background only');
    % check if dir already exists
    if exist(newFolder, 'dir')
        question= sprintf('Directory already exists and it may already contain results.\nDo you want to overwrite it or create new directory?');
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
    
    fc=zeros(1,numFiles);
    if SeeMe
        f2=figure('Visible','on');
    else
        f2=figure('Visible','off');
    end
    xlabel('Vertical Deflection [N]','FontSize',15), ylabel('Lateral Deflection [N]','FontSize',15), grid on
    title(sprintf('Results of %d curves of AFM only background',numFiles),'FontSize',15);
    pfs=[];
    colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k'};
    for j=1:numFiles
        if numFiles==1
            [~,nameFile]=fileparts(fileNameFriction);
            [dataGlass,metaDataGlass]=A1_open_JPK(fullfile(filePathDataFriction,fileNameFriction));
        else
            [~,nameFile]=fileparts(fileNameFriction{j});
            [dataGlass,metaDataGlass]=A1_open_JPK(fullfile(filePathDataFriction,fileNameFriction{j}));
        end
            % extract the needed data
        % latDefl expressed in Volt
        latDefl_trace   = dataGlass(strcmpi({dataGlass.Channel_name},'Lateral Deflection') & strcmpi({dataGlass.Trace_type},'Trace')).AFM_image;
        latDefl_retrace = dataGlass(strcmpi({dataGlass.Channel_name},'Lateral Deflection') & strcmpi({dataGlass.Trace_type},'ReTrace')).AFM_image;
        % verDefl expressed in Newton
        verForce        = dataGlass(strcmpi({dataGlass.Channel_name},'Vertical Deflection') & strcmpi({dataGlass.Trace_type},'Trace')).AFM_image;
        % obtain the setpoint value. Note: because of little instabilities, round the vertical values to the fixed setpoint 
        % (i.e. 3.091 nN --> 3.000 nN)
        verForce = round(verForce,8);
     
        % average trace and retrace scan lines (lateral deflection) to cancel out errors.
        % Calc Delta (loop offset)
        Delta =  (latDefl_trace + latDefl_retrace)/2;
        % Calc W (half-width loop)
        W = latDefl_trace - Delta;                     
        
        if SeeMe
            f1=figure('Visible','on');
        else
            f1=figure('Visible','off');
        end
        objInSecondMonitor(secondMonitorMain,f1);
        imagesc(W), title('Half-loop width (W) of only substrate','FontSize',20)
        xlabel(' fast direction - scan line','FontSize',15), ylabel('slow direction','FontSize',15)
        c=colorbar; c.Label.String = 'W half-width loop [V]'; c.Label.FontSize=15;
        saveas(f1,sprintf('%s/resultA5method1_1_HalfLoopWidth_%s.tif',newFolder,nameFile))
        

        % convert W into force (in Newton units) using alpha calibration factor
        force=W*metaDataGlass.Alpha;
           
        % find unique groups of setpoints and its index.
        [setpoints, start_indices] = unique(round(mean(verForce,2),8));
        [start_indices,idx] = sort(start_indices);
        setpoints=setpoints(idx);
        % Using the previous indexes, group the lateral deflection scan lines in correspondence with the same applied setpoint
        force_avg_singleSetpoint=zeros(length(start_indices),1);
        force_std_singleSetpoint=zeros(length(start_indices),1);
        for i=1:length(start_indices)
            if i==length(start_indices)
                last=length(force);
            else
                last=start_indices(i+1)-1;
            end
            %average the scan line and then the group in which the setpoint is same
            force_avg_singleSetpoint(i)=mean(mean(force(start_indices(i):last,:),2));
            force_std_singleSetpoint(i)=std(mean(force(start_indices(i):last,:),2));
        end  
        if force_avg_singleSetpoint(1)>force_avg_singleSetpoint(end)
            warning('first value of force is higher than last value, maybe inverted! In any case, the values are flipped')
            force_avg_singleSetpoint=flip(force_avg_singleSetpoint);
        end

        %FITTING VERTICAl and LATERAL DEFLECTION (both expressed in Newton)
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
        [fitresult,~]=fit(setpoints,force_avg_singleSetpoint, 'poly1' );
        %plot the fitting curve and the experimental data
        x=linspace(verForce(1),verForce(end),100);
        y=(fitresult.p1*x+fitresult.p2);
        figure(f2)
        hold on
        eqn = sprintf('y = %0.3gx + %0.3g', fitresult.p1, fitresult.p2);
        pf(j)=plot(x,y,'DisplayName',sprintf('Fitted curve: %s',eqn),'Color',colors{j});
        ps=plot(setpoints,force_avg_singleSetpoint,'k*','DisplayName','Experimental data');
        pe=errorbar(setpoints,force_avg_singleSetpoint,force_std_singleSetpoint, 'k', 'LineStyle', 'none', 'Marker','none','LineWidth', 1.5,'DisplayName','StandardDeviation');
        xlim([0,max(setpoints) * 1.1]);
        hold off        
        
        fc(j)=fitresult.p1;
        pfs=[pfs pf(j)];
    end
    legend([ps,pe,pfs],'Location','northwest','FontSize',15)

    %legend([ps,pe,pf(1),pf(2),pf(3)],'Location','northwest','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f2);
    saveas(f2,sprintf('%s/resultA5method1_2_DeltaOffsetVSsetpoint.tif',newFolder))
    avg_fc=mean(fc);
    
end



