% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function [AFM_Elab,Bk_iterative]=A5_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,alpha,secondMonitorMain,newFolder,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Accuracy';   defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    argName = 'Silent';     defaultVal = 'Yes';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'SaveFig';    defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));

    parse(p,varargin{:});
    clearvars argName defaultVal

    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end
    if(strcmp(p.Results.SaveFig,'Yes')); SavFg=1; else, SavFg=0; end

    % extract data (lateral deflection Trace and Retrace, vertical deflection) and then mask (glass-PDA) elementXelement
    % ONLY in correspondence with the glass!
    Lateral_Trace   = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);
    Lateral_ReTrace = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'ReTrace')).AFM_image);
    vertical_Trace  = (AFM_cropped_Images(strcmpi([AFM_cropped_Images.Channel_name],'Vertical Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image);

    
    % the code assumes the experiment was done in hover mode (no retrace data) ==> add automatically something
    % to check from metadata in hover mode was enabled
    % if getValidAnswer('Was the HOVER MODE ON?','',{'y','n'})==2
    % % substract lateral deflection trace from retrace if HOVER MODE UNACTIVATED,
    %     Lateral_Trace_clean =Lateral_Trace - Lateral_ReTrace;
    % else
    %     Lateral_Trace_clean =Lateral_Trace;
    % end

    Lateral_Trace_clean =Lateral_Trace;

    %Subtract the minimum of the image
    Lateral_Trace_clean_shift= Lateral_Trace_clean - min(min(Lateral_Trace_clean));
    % Mask W to cut the PDA from the baseline fitting. Where there is PDA in corrispondece of the mask, then mask the
    % lateral deflection data. Basically, the goal is fitting using the glass which is know to be flat. 
    if SeeMe
        f1=figure('Visible','on');
    else
        f1=figure('Visible','off');
    end
           
    subplot(121)
    imshow((imadjust(Lateral_Trace/max(max(Lateral_Trace))))), colormap parula; colorbar,
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize = 15;
    title('Raw Lateral Deflection [V] - Trace','FontSize',18)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    axis equal, xlim([0 size(Lateral_Trace,2)]), ylim([0 size(Lateral_Trace,1)])


    subplot(122)
    imshow((imadjust(Lateral_Trace_clean_shift/max(max(Lateral_Trace_clean_shift))))), colormap parula; colorbar,
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize = 15;
    title({'Lateral Deflection - Trace [V]'; '(shifted toward minimum)'},'FontSize',18)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    axis equal, xlim([0 size(Lateral_Trace,2)]), ylim([0 size(Lateral_Trace,1)])
    
    objInSecondMonitor(secondMonitorMain,f1);
    if SavFg
        saveas(f1,sprintf('%s/resultA5_1_RawAndShiftedLateralDeflection.tif',newFolder))
    end



    % apply the PDA mask
    Lateral_Trace_shift_masked= Lateral_Trace_clean_shift;
    Lateral_Trace_shift_masked(AFM_height_IO==1)=5;

    %show dialog box
    wb=waitbar(0/size(Lateral_Trace_shift_masked,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(Lateral_Trace_shift_masked,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    
    warning ('off','all');
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    if strcmp(p.Results.Accuracy,'Low')
        limit=3;
    elseif strcmp(p.Results.Accuracy,'Medium')
        limit=6;
    else
        limit=9;
    end
    % init var with same size as well as W 
    % the fit_decision_final will contain the best fit_decision and the polynomial parameters (if grade = 3
    % ==> # parameters = 4)
    fit_decision_final=nan(size(Lateral_Trace_shift_masked,2),3+limit+1);
    Bk_iterative=zeros(size(Lateral_Trace_shift_masked,1),size(Lateral_Trace_shift_masked,2));
    N_Cycluse_waitbar=size(Lateral_Trace_shift_masked,2);
    % build x array for the fitting
    x=1:size(Lateral_Trace_shift_masked,1); %#ok<NASGU> ignore error
    % perform the fitting fast scan line by fast scan line 
    for i=1:size(Lateral_Trace_shift_masked,2)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling')
               error('Process cancelled')
            end
        end           

        % extract the single fast scan line
        flag_signal_y=Lateral_Trace_shift_masked(:,i);
        flag_signal_x=(1:size(flag_signal_y,1));

        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double, converting complex to 
        % real and returning data as columns regardless of the input shapes.
        [xData, yData] = prepareCurveData(flag_signal_x,flag_signal_y);
        
        %PDA=excludedata(xData, yData,'range',[-1 1]);
        % if sum(PDA ~= 1) < 5
        %     continue
        % else

            if(size(xData,1)>2)
                opts = fitoptions( 'Method', 'LinearLeastSquares' );
                opts.Robust = 'LAR';
                fit_decision=zeros(3,limit);
                for z=1:limit
                    % based on the choosen accuracy, run the fitting using different curves to find the best fit
                    % before returning the definitive fitted single fast scan line
                    ft = fittype(sprintf('poly%d',z));
                    % returns goodness-of-fit statistics in the structure gof. Exclude data corresponding to PDA,
                    % which is previously converted to 5       
                        [~, gof] = fit(xData, yData, ft,'Exclude', yData >= 5 ); % MODIFICATO. prima era 1 e dava problemi
                        if(gof.adjrsquare<0)
                            gof.adjrsquare=0.001;
                        end
                        fit_decision(1,z)=abs(gof.sse)/gof.adjrsquare;
                        fit_decision(2,z)=gof.sse;
                        fit_decision(3,z)=gof.adjrsquare;
                end
                
                %prepare type fitting. Choose the one with the best statistics. Ind represent the polynomial grade
                clearvars Ind
                [~,Ind]=min(fit_decision(1,:));
    
                ft = fittype(sprintf('poly%d',Ind));
                waitbar(i/N_Cycluse_waitbar,wb,sprintf('Processing %d° Ord Pol fit ... Line %.0f Completeted  %2.1f %%',Ind,i,i/N_Cycluse_waitbar*100));
                % save the fitting decisions
                fit_decision_final(i,1)=Ind;
                fit_decision_final(i,2)=fit_decision(2,Ind);
                fit_decision_final(i,3)=fit_decision(3,Ind);
                % start the fitting. Ignore the data in corrispondence of PDA.
                [fitresult, ~] = fit( xData, yData, ft, 'Exclude', yData >= 5 ); %#ok<ASGLU> ignore warning
            else
                error('The extracted fast scan line is too short. Something is wrong');
            end
        
            % build the y value using the polynomial coefficients and x value (1 ==> 512)
            % save polynomial coefficients (p1, p2, p3, ...) into fit_decision_final
            commPart =[];
            j=1;
            for n=Ind:-1:0
                commPart = sprintf('%s + %s', commPart,sprintf('fitresult.p%d*(x).^%d',j,n));
                eval(sprintf('fit_decision_final(i,%d)= fitresult.p%d;',j+3,j))
                j=j+1;
            end
            Bk_iterative(:,i)= eval(commPart);
        end
    %end
    % processed every fast scan line
    delete(wb)

    % find idx having adjrsquare < 0.95. Averaging using taking adjacent lines.
    to_avg=find(fit_decision_final(:,3)<0.95);
    if(exist('to_avg','var'))
        for i=1:size(to_avg,1)-1
            if(to_avg(i,1)~=1)
                Bk_iterative(:,to_avg(i,1))=(Bk_iterative(:,to_avg(i,1)-1)+Bk_iterative(:,to_avg(i,1)+1))/2;
            elseif(to_avg(i,1)==1)
                Bk_iterative(:,to_avg(i,1))=Bk_iterative(:,to_avg(i,1)+1);
            elseif(to_avg(i,1)==size(Bk_iterative,2))
                Bk_iterative(:,to_avg(i,1))=Bk_iterative(:,to_avg(i,1)-1);
            end
        end
    end
    Lateral_Trace_shift_noBK= Lateral_Trace_clean_shift - Bk_iterative;

    % choose friction coefficients depending on the case (experimental results done in another moment),
    % or manually put the value
    question=sprintf('Which background friction coefficient use?');
    options={ ...
        sprintf('1) TRCDA (air) = 0.3405'), ...
        sprintf('2) PCDA  (air)  = 0.2626'), ... 
        sprintf('3) TRCDA-DMPC (air) = 0.2693'), ...
        sprintf('4) TRCDA-DOPC (air) = 0.3316 (only 3_3_1)'), ...
        sprintf('5) TRCDA-POPC (air) = 0.2090'), ...
        sprintf('6) Enter manually a value')};
    choice = getValidAnswer(question, '', options);
    
    switch choice
        case 1, avg_fc = 0.3405;
        case 2, avg_fc = 0.2626;
        case 3, avg_fc = 0.2693;
        case 4, avg_fc = 0.3316; % from 0.3070; updated using only 3_3_1 NOTE: issues wth the experiments in which only two setpoints have been used
        case 5, avg_fc = 0.2090;                     
        case 6
            while true
                avg_fc = str2double(inputdlg('Enter a value for the glass fricction coefficient','',[1 50]));
                if any(isnan(avg_fc)) || avg_fc <= 0 || avg_fc >= 1
                    questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                else
                    break
                end
            end
    end
    clear choice question options wb


    % Friction force = friction coefficient * Normal Force
    Baseline_Friction_Force= vertical_Trace*avg_fc;
    % Friction force = calibration coefficient * Lateral Trace (V)
    Lateral_Trace_Force= Lateral_Trace_shift_noBK*alpha;
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    
    % Plot the fitted backround:
    if SeeMe
        f2=figure('Visible','on');       
    else
        f2=figure('Visible','off');      
    end
   
    subplot(121)
    imshow((imadjust(Bk_iterative/max(max(Bk_iterative))))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    title('Fitted Background','FontSize',15)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    % remove the background from the image (friction on glass should be zero afterwards):
    subplot(122)
    imshow((imadjust(Lateral_Trace_shift_noBK/max(max(Lateral_Trace_shift_noBK))))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    title('Fitted Lateral Deflection channel [V] - Trace ','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f2);
    if SavFg
        saveas(f2,sprintf('%s/resultA5_2_ResultsFittingOnLateralDeflections.tif',newFolder))
    end

    f3=figure;
    imshow(imadjust(Corrected_LD_Trace/max(max(Corrected_LD_Trace)))), colormap parula
    c=colorbar; c.Label.String = 'normalized to max value'; c.FontSize =15;
    title('Fitted and corrected Lateral Force [N]','FontSize',17)
    xlabel(' slow direction','FontSize',15), ylabel('fast direction - scan line','FontSize',15)
    objInSecondMonitor(secondMonitorMain,f3);
    if SavFg
        saveas(f3,sprintf('%s/resultA5_3_ResultsDefinitiveLateralDeflectionsNewton.tif',newFolder))
    end

    AFM_Elab=AFM_cropped_Images;
    % save the corrected lateral force into cropped AFM image
    AFM_Elab(strcmpi([AFM_cropped_Images.Channel_name],'Lateral Deflection') & strcmpi([AFM_cropped_Images.Trace_type],'Trace')).AFM_image=Corrected_LD_Trace;

    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
end
