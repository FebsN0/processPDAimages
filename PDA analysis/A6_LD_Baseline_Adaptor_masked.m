% Function to process and subtract the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function [Corrected_LD_Trace,AFM_Elab,Bk_iterative]=A6_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,alpha,avg_fc,varargin)

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Accuracy';
    defaultVal = 'Low';
    addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    % validate and parse the inputs
    parse(p,varargin);
    clearvars argName defaultVal

    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace   = (AFM_cropped_Images(strcmpi({AFM_cropped_Images.Channel_name},'Lateral Deflection') & strcmpi({AFM_cropped_Images.Trace_type},'Trace')).Cropped_AFM_image);
    Lateral_ReTrace = (AFM_cropped_Images(strcmpi({AFM_cropped_Images.Channel_name},'Lateral Deflection') & strcmpi({AFM_cropped_Images.Trace_type},'ReTrace')).Cropped_AFM_image);
    vertical_Trace  = (AFM_cropped_Images(strcmpi({AFM_cropped_Images.Channel_name},'Vertical Deflection') & strcmpi({AFM_cropped_Images.Trace_type},'Trace')).Cropped_AFM_image);


    % convert W into force (in Newton units) using alpha calibration factor and show results.
    % force=W*alpha;
    % % flip and rotate to have the start of scan line to left and the low setpoint to bottom)
    % force=rot90(flipud(force));
    % vertical_Trace=rot90(flipud(vertical_Trace));
    % vertical_ReTrace=rot90(flipud(vertical_ReTrace));
    
    % Calc Delta (offset loop) 
    Delta = (Lateral_Trace + Lateral_ReTrace) / 2;
    % Calc W (half-width loop)
    W = Lateral_Trace - Delta;

    %Subtract the minimum of the image
    W=minus(W,min(min(W)));
    %Fix orientation
    W=rot90(flipud(W));
    vertical_Trace=rot90(flipud(vertical_Trace));
    %vertical_ReTrace=rot90(flipud(vertical_ReTrace));
    % plot 
    if ~isempty(secondMonitorMain), f1=figure; objInSecondMonitor(secondMonitorMain,f1); else, figure; end
    subplot(131)
    imshow(flip(imadjust(Lateral_Trace/max(max(Lateral_Trace))))), colormap parula, title('Lateral Trace [V]','FontSize',15)
    subplot(132)
    imshow(flip(imadjust(Lateral_ReTrace/max(max(Lateral_ReTrace))))), colormap parula, title('Lateral Retrace [V]','FontSize',15)
    subplot(133)
    imshow(flip(imadjust(W/max(max(W))))), colormap parula, title('Shifted half-width loop [W]','FontSize',15)
    %show dialog box
    wb=waitbar(0/size(W,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(W,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    
    % Polynomial baseline fitting (line by line)
    warning ('off','all');
    fit_decision_final=nan(size(W,1),13);
    % init var with same size as well as W 
    Bk_iterative=zeros(size(W,1),size(W,2));
    N_Cycluse_waitbar=size(W,1);
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    
    switch p.Results.Accuracy
        case 'Low'
            limit=3;
        case 'Medium'
            limit=6;
        case 'High'
            limit=9;
    end
    fit_decision=zeros(3,limit);

    % perform the fitting fast scan line by fast scan line 
    for i=1:size(W,1)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling')
               % break
            end
        end           
        % Mask W to cut the PDA from the baseline fitting. Where there is PDA in corrispondece of the mask, then mask the
        % lateral deflection data. Basically, the goal is fitting using the glass which is know to be flat. 
        W(AFM_height_IO==1)=5;
        % extract the single fast scan line
        flag_signal_y=W(i,:);
        flag_signal_x=(1:size(flag_signal_y,2));
        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double, converting complex to 
        % real and returning data as columns regardless of the input shapes.
        [xData, yData] = prepareCurveData(flag_signal_x,flag_signal_y);
    
        if(size(xData,1)>2)
            opts = fitoptions( 'Method', 'LinearLeastSquares' );
            opts.Robust = 'LAR';
           
            for z=1:limit
                % based on the choosen accuracy, run the fitting using different curves to find the best fit
                % before returning the definitive fitted single fast scan line
                ft = fittype(sprintf('poly%d',z));
                % returns goodness-of-fit statistics in the structure gof. Exclude data corresponding to PDA,
                % which is previously converted to 5 
                [~, gof] = fit( xData, yData, ft,'Exclude', yData > 1 );
                if(gof.adjrsquare<0)
                    gof.adjrsquare=0.001;
                end
                fit_decision(1,z)=abs(gof.sse)/gof.adjrsquare;
                fit_decision(2,z)=gof.sse;
                fit_decision(3,z)=gof.adjrsquare;
            end
            
            %prepare type fitting. Choose the one with the best statistics
            clearvars Ind
            [~,Ind]=min(fit_decision(1,:));
            ft = fittype(sprintf('poly%d',Ind));
            waitbar(i/N_Cycluse_waitbar,wb,sprintf('Processing %d° Ord Pol fit ... Line %.0f Completeted  %2.1f %%',Ind,i,i/N_Cycluse_waitbar*100));
            % save the fitting decisions
            fit_decision_final(i,1)=Ind;
            fit_decision_final(i,2)=fit_decision(2,Ind);
            fit_decision_final(i,3)=fit_decision(3,Ind);
            % start the fitting. Ignore the data in corrispondence of PDA.
            % Although the fitresult seems to be unused, it is actually evaluated with eval function.
            [fitresult, ~] = fit( xData, yData, ft, 'Exclude', yData > 1 );
        else
            error('The extracted fast scan line is too short. Something is wrong');
        end
        % build the y value using the polynomial coefficients and x value (1 ==> 512)
        % save polynomial coefficients (p1, p2, p3, ...) into fit_decision_final
        commPart =[];
        x=1:size(W,1);
        j=1;
        for n=Ind:-1:0
            commPart = sprintf('%s + %s', commPart,sprintf('fitresult.p%d*(x).^%d',j,n));
            eval(sprintf('fit_decision_final(i,%d)= fitresult.p%d;',j+3,j))
            j=j+1;
        end
        Bk_iterative(i,:)= eval(commPart);
    end
    % processed every fast scan line
    delete(wb)

    % find idx having adjrsquare < 0.95. Averaging using taking adjacent lines.
    to_avg=find(fit_decision_final(:,3)<0.95);
    if(exist('to_avg','var'))
        for i=1:size(to_avg,1)
            if(to_avg(i,1)==1)                                                   % if idx = 1  ==> copy second row and paste in first row
                Bk_iterative(to_avg(i,1),:)=Bk_iterative(to_avg(i,1)+1,:);  
            elseif(to_avg(i,1)==size(Bk_iterative,1))                            % if idx =512 ==> copy second-last row and paste in last row
                Bk_iterative(to_avg(i,1),:)=Bk_iterative(to_avg(i,1)-1,:);
            else                                                                 % of idx between 2 and 511 ==> 
               Bk_iterative(to_avg(i,1),:)=( ...                                 % take the previous and the next row and average them.
                   Bk_iterative(to_avg(i,1)-1,:) + Bk_iterative(to_avg(i,1)+1,:) )/2;
            end
        end
    end
    
    % Plot the fitted backround:
    if ~isempty(secondMonitorMain), f1=figure; objInSecondMonitor(secondMonitorMain,f1); else, figure; end
    subplot(131)
    imshow(flip(imadjust(Bk_iterative/max(max(Bk_iterative))))), colormap parula, title('FITTED BACKGROUND (no PDA data)','FontSize',15)
        
    % remove the minimum of the image and then the background (friction on glass should be zero afterwards):
    Lateral_Trace_Shifted_noBK= Lateral_Trace - min(min(Lateral_Trace)) - Bk_iterative;
    subplot(132)
    imshow(flip(imadjust(Lateral_Trace_Shifted_noBK/max(max(Lateral_Trace_Shifted_noBK))))), colormap parula, title('FITTED BACKGROUND (no PDA data)','FontSize',15)
    % Friction force = friction coefficient * Normal Force
    Baseline_Friction_Force= vertical_Trace*avg_fc;
    % Friction force = calibration coefficient * Lateral Trace (V)
    Lateral_Trace_Force= Lateral_Trace_Shifted_noBK*alpha;
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    subplot(133),
    imshow(flip(imadjust(Corrected_LD_Trace/max(max(Corrected_LD_Trace))))), colormap parula, title('Lateral Force [N] - FITTED','FontSize',15)
    
    AFM_Elab=AFM_cropped_Images;
    % save the corrected lateral force into cropped AFM image
    AFM_Elab(strcmpi({AFM_cropped_Images.Channel_name},'Lateral Deflection') & strcmpi({AFM_cropped_Images.Trace_type},'Trace')).Cropped_AFM_image=Corrected_LD_Trace;
end
