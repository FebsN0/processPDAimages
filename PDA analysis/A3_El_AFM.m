function [AFM_Images,IO_Image,accuracy,idxPortionRemoved]=A3_El_AFM(filtData,secondMonitorMain,filepath,varargin)

% The function extracts Images from the experiments.
% It removes baseline and extracts foreground from the AFM image.
%
% INPUT:    1) input = output of A2_CleanUpData2_AFM function which contains Height (measured), Lateral
%                      Deflection and Vertical Deflection, all in TRACE
%           2) optional input:
%               A) Accuracy: Low (default)  | Medium | High
%               B) AutoElab: No (default)   | other                 ==> keep the first result. Not recommended
%                                                                       when low accuracy is used
%
% The function uses a series a total of three parts to remove the baseline from the Height Image.
%   1) first order linear polinomial curve fitting for correct the height imahe by this baseline 
%   2) buttorworth filter backgrownd algorithm
%   3) Poly11: linear polynomial surface is fitted to results of Poly1 fitting, the fitted surface is subtracted from
%      the results of Poly1 fitting (poly_filt_data), yielding filt_data_no_Bk_visible_data
%   4) iterative backgrownd removal, in which R^2 and RMS residuals are used to calculate the final backgrownd
% The output is binary image of the height (background + foreground)
%
% Author: Dr. R.D.Ortuso, Levente Juhasz
% University of Geneva, Switzerland.
%
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 27/08/2024
%
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types
    % and properties of inputs. This helps to make functions more robust and user-friendly.
    p=inputParser();    %init instance of inputParser
    % Add required parameter and also check if it is a struct by a inner function end if the Trace_type are
    % all Trace
    addRequired(p, 'filtData', @(x) isstruct(x));
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'fitOrder';   defaultVal = '';        addParameter(p,argName,defaultVal, @(x) ismember(x,{'','Low','Medium','High'}));
    argName = 'AutoElab';   defaultVal = 'No';      addParameter(p, argName, defaultVal,@(x) ismember(x,{'No','Yes'}));
    argName = 'Silent';     defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'SaveFig';    defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,filtData,varargin{:});
    clearvars argName defaultVal
    
    % if this is seconf time that the A3 is called, like for the second AFM section, keep the accuracy of
    % first section
    if p.Results.fitOrder ~= ""
        flagAccuracy = true;
        accuracy=p.Results.fitOrder;
    else
        flagAccuracy = false;
    end

    if(strcmp(p.Results.Silent,'Yes'));  SeeMe=0; else, SeeMe=1; end
    if(strcmp(p.Results.SaveFig,'Yes')); SavFg=1; else, SavFg=0; end
    
    % Extract the height channel
    raw_data_Height=filtData(strcmp([filtData.Channel_name],'Height (measured)')).AFM_image;
    % Orient the image by counterclockwise 180° and flip to coencide with the Microscopy image through rotations
    raw_data_Height=flip(rot90(raw_data_Height),2);
    rawH=raw_data_Height;
    
    f1=figure; 
    objInSecondMonitor(secondMonitorMain,f1);
    text='Original';
    
    % in this snippet, remove outliers and data corresponding to those when the tip is not scanning anymore or
    % applying the plane fitting selecting background areas. Remove ENTIRE LINE.
    % Removing single selected portion leads to high error fitting. So it would be better just remove entire
    % line
    flagRemoval=false;
    idxPortionRemoved=[];
    while true
        figure(f1)
        imagesc(rawH*1e9)
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        colormap parula, c = colorbar; c.Label.String = 'Height [nm] (Note that it is not corrected yet)'; c.Label.FontSize=15;
        title(sprintf('%s Raw Height (measured) channel',text),'FontSize',17)
        answer = questdlg('Remove lines by selecting area?','','Yes','No','No');
        if strcmp(answer,'No')
            break
        else
            hold on  
            title('Select area to remove all the fast scan lines corresponding to the selected area.','FontSize',17)
            roi=drawrectangle('Label','Removed');
            uiwait(msgbox('Click to continue'))
            hold off
            % take the coordinates along slow scan direction. Not useful extracting y coordinates because
            % entire lines will be deleted
            xstart = round(roi.Position(1));     xend = xstart+round(roi.Position(3));
            if xstart<1, xstart=1; end;     if xend<1, xend=1; end
            % substitute the value of selected lines with the minimum value.
            % note: the min value is the one outside the selected area. Sometimes is very very low making it
            % unclear

            rawH(:,xstart:xend)=min(min(rawH(:,[1:xstart-1 xend+1:end])));
            % save the information of which region are removed. Useful for friction calculation to avoid
            % entire area. Sometime the cantilever goes crazy. In case of normal experiment no problem because
            % the removed region is considered background, so lateral and vertical deflection data are simply
            % ignored. But in case of friction data, it may be a problem
            idxPortionRemoved=[idxPortionRemoved; xstart xend];
            text='Portion Removed - ';
            flagRemoval=true;
        end
    end

    if flagRemoval
        axis equal, xlim([0 size(rawH,2)]), ylim([0 size(rawH,1)])
        saveas(f1,sprintf('%s\\resultA3_1_DefinitiveRawHeight_portionRemoved.tif',filepath))
    end
    close(f1)
    for i=1:size(filtData,2)
        if i==1             % put the fixed raw height data channel
            AFM_Images(i)=struct(...
                'Channel_name', filtData(i).Channel_name,...
                'Trace_type', filtData(i).Trace_type, ...
                'AFM_image', rawH);
        else
            temp_img=flip(rot90(filtData(i).AFM_image),2);
            AFM_Images(i)=struct(...
                    'Channel_name', filtData(i).Channel_name,...
                    'Trace_type', filtData(i).Trace_type, ...
                    'AFM_image', temp_img);
        end
    end

    height_image=AFM_Images(1).AFM_image;
    wb=waitbar(0/size(height_image,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(height_image,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(height_image,2);    
    % Polynomial baseline fitting (line by line)
    poly_filt_data=zeros(size(height_image,1),size(height_image,2));
    for i=1:size(height_image,2)
        if(exist('wb','var'))
            %if cancel is clicked, stop
            if getappdata(wb,'canceling'), error('Process cancelled'), end
        end
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        % prepareCurveData function clean the data like Removing NaN or Inf, converting nondouble to double, converting complex to 
        % real and returning data as columns regardless of the input shapes.
        % extract the i-th column of the image ==> fitting on single column
        [xData,yData] = prepareCurveData((1:size(height_image,1))',height_image(:,i));
        % in case of insufficient number of values for a given line (like entire line removed previously), skip the fitting
        if length(xData) <= 2 || length(yData) <= 2
            poly_filt_data(:,i)=height_image(:,i);
            continue
        end
        % Linear polynomial curve
        ft = fittype( 'poly1' );
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
        fitresult=fit(xData,yData, ft );
        % like the plan fitting, create new vector of same length as well as line of the height image
        xData = 1:size(height_image,1); xData=xData';
        % dont use the offset p2, rather the first value of the i-th column
        baseline_y=(fitresult.p1*xData+height_image(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        flag_poly_filt_data=height_image(:,i)-baseline_y;
        poly_filt_data(:,i)=flag_poly_filt_data-min(min(flag_poly_filt_data));
    end
    waitbar(0/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter...'));
    % distribute the fitted data among bins using N bins. OUTUPUT: Y=bin counts; E= bin edges
    % many will be zero (background), whereas other will be low to high height
    [Y,E] = histcounts(poly_filt_data,10000);
    % set the parameters for Butterworth filter ==> little recap: it is a low-pass filter with a frequency
    % response that is as flat as possible in the passband
    fc = 5; % Cut off frequency
    fs = size(height_image,2); % Sampling rate
    % Butterworth filter of order 6 with normalized cutoff frequency Wn
    % Return transfer function coefficients to be used in the filter function
    [b,a] = butter(6,fc/(fs/2)); 
    Y_filtered = filter(b,a,Y); % filtered signal using the Butterworth coefficients
    Y_filered_diff=diff(diff(Y_filtered));      % substract twice the right next element in array
    
    bk_limit=1;
    N_Cycluse_waitbar=size(Y_filered_diff,2);
    % Identifying Backgrownd value
    for i=2:size(Y_filered_diff,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter ... Identifying Backgrownd %2.1f %%',i/N_Cycluse_waitbar*100));
        if(Y_filered_diff(1,i-1)<=0)&&(Y_filered_diff(1,i)>0)
            bk_limit=i;
            waitbar(1,wb,sprintf('Backgrownd Identified!'));
            break
        end
    end
    

    %%% MAYBE NOT NECESSARY ANYMORE
    % Fitting of linear polynomial surface to the result of Poly1 fit
    backgrownd_th=E(1,bk_limit);
    Bk_poly_filt_data=poly_filt_data;
    Bk_poly_filt_data(Bk_poly_filt_data>backgrownd_th)=NaN;
    
    x_Bk=1:size(Bk_poly_filt_data,2);
    y_Bk=1:size(Bk_poly_filt_data,1);
    [xData, yData, zData] = prepareSurfaceData( x_Bk, y_Bk, Bk_poly_filt_data );
    ft = fittype( 'poly11' );
    [fitresult, ~] = fit( [xData, yData], zData, ft );
    
    fit_surf=zeros(size(y_Bk,2),size(x_Bk,2));
    a=max(max(Bk_poly_filt_data));
    y_Bk_surf=repmat(y_Bk',1,size(x_Bk,2))*fitresult.p01;
    x_Bk_surf=repmat(x_Bk,size(y_Bk,2),1)*fitresult.p10;
    fit_surf=plus(a,fit_surf);
    fit_surf=plus(y_Bk_surf,fit_surf);
    fit_surf=plus(x_Bk_surf,fit_surf);
    
    % Subtraction of fitted polynomial background
    filt_data_no_Bk=minus(poly_filt_data,fit_surf);
    filt_data_no_Bk=filt_data_no_Bk-min(min(filt_data_no_Bk));
   
    warning ('off','all');
    % For each different fitting depending on the accuracy (poly1 to poly9), extract 3 information:
    %   - Sum of squares due to error / Degree-of-freedom adjusted coefficient of determination
    %   - Sum of squares due to error
    %   - Degree-of-freedom adjusted coefficient of determination
    
    while true
        if ~flagAccuracy
            question='Fitting AFM Height channel data: which fitting order range use?';
            options={'Low (1-3)','Medium (1-6)','High (1-9)'};
            answer=getValidAnswer(question,'',options);
            switch answer
                case 1
                    accuracy= 'Low';
                case 2
                    accuracy= 'Medium';
                case 3
                    accuracy= 'High';
            end      
        end
        
        if strcmp(accuracy,'Low')
            limit=3;
        elseif strcmp(accuracy,'Medium')
            limit=6;
        else
            limit=9;
        end

        %init vars
        % the fit_decision_final will contain the best fit_decision and the polynomial parameters (if grade = 3
        % ==> # parameters = 4)
        fit_decision_final=nan(size(filt_data_no_Bk,2),3+limit+1);
        Bk_iterative=zeros(size(filt_data_no_Bk,1),size(filt_data_no_Bk,2));
        N_Cycluse_waitbar=size(filt_data_no_Bk,2);
        % build array abscissas for the fitting
        x=1:size(filt_data_no_Bk,1); %#ok<NASGU>
        clear Ind fitresult
        
        % Polynomial baseline fitting (line by line) - Linear least squares fitting to the results
        for i=1:size(filt_data_no_Bk,2)
            if(exist('wb','var'))
                if getappdata(wb,'canceling')
                   error('Process cancelled')
                end
            end
            flag_signal_y=filt_data_no_Bk(:,i);
            flag_signal_x=(1:size(flag_signal_y,1))';
            flag_signal_y(flag_signal_y>=median(filt_data_no_Bk(:,i)))=nan;
            flag_signal_x(flag_signal_y>=median(filt_data_no_Bk(:,i)))=nan;
            [pos_outliner]=isoutlier(flag_signal_y);
            
            while(any(pos_outliner))
                flag_signal_y(pos_outliner==1)=nan;
                flag_signal_x(pos_outliner==1)=nan;
                [pos_outliner]=isoutlier(flag_signal_y,'gesd');
            end
            [xData, yData] = prepareCurveData(flag_signal_x,flag_signal_y);
            if length(xData) <= 2 || length(yData) <= 2
                error('something is wrong. Too NaN values in the %d-th line\n',i)
            else
                opts = fitoptions( 'Method', 'LinearLeastSquares' );
                opts.Robust = 'LAR';
                fit_decision=NaN(3,limit);
                
                for z=1:limit
                    % based on the choosen accuracy, run the fitting using different curves to find the best fit
                    % before returning the definitive fitted single fast scan line
                    ft = fittype(sprintf('poly%d',z));
                    % returns goodness-of-fit statistics in the structure gof. Exclude data corresponding to PDA,
                    % which is previously converted to 5 
                    [~, gof] = fit( xData, yData, ft,opts);
                    if(gof.adjrsquare<0)
                        gof.adjrsquare=0.001;
                    end
                    fit_decision(1,z)=abs(gof.sse)/gof.adjrsquare;
                    fit_decision(2,z)=gof.sse;
                    fit_decision(3,z)=gof.adjrsquare;
                end
    
                
                [~,Ind]=min(fit_decision(2,:));
                
                ft = fittype(sprintf('poly%d',Ind));
                waitbar(i/N_Cycluse_waitbar,wb,sprintf('Processing %d° Ord Pol fit ... Line %.0f Completeted  %2.1f %%',Ind,i,i/N_Cycluse_waitbar*100));
              
                % save the fitting decisions
                fit_decision_final(i,1)=Ind;
                fit_decision_final(i,2)=fit_decision(2,Ind);
                fit_decision_final(i,3)=fit_decision(3,Ind);
                % start the fitting.
                % Although the fitresult seems to be unused, it is actually evaluated with eval function.
                fitresult= fit( xData, yData, ft, opts ); %#ok<NASGU> % % gof was suppressed
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
       
        AFM_noBk=minus(filt_data_no_Bk,Bk_iterative);
        AFM_noBk=AFM_noBk-min(min(AFM_noBk));
        AFM_noBk_visible_data=AFM_noBk/max(max(AFM_noBk));
        AFM_noBk_visible_data=imadjust(AFM_noBk_visible_data);
        
        f2=figure;
        imshow(AFM_noBk_visible_data),colormap parula, title('Fitted Height (measured) channel', 'FontSize',16)
        objInSecondMonitor(secondMonitorMain,f2);
        c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        

        if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
            close(f2)
            break
        else
            flagAccuracy=false;
        end
    end
    

    f3=figure;
    subplot(121), imshow(AFM_noBk_visible_data),colormap parula, title('Fitted Height (measured) channel', 'FontSize',16)
    objInSecondMonitor(secondMonitorMain,f3);
    c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
    ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)

    satisfied='Manual Selection';
    first_In=1;
    closest_indices=[];
    no_sub_div=1000;
    % Binarisation of the bg-subtracted image
    while(strcmp(satisfied,'Manual Selection'))
        kernel=strel('square',3); % can be modified
        if(first_In==1)
            T = adaptthresh(mat2gray(AFM_noBk));
            seg_AFM = imbinarize(mat2gray(AFM_noBk),T);
        else
            clearvars seg_AFM th_segmentation seg_dial
            
            imhistfig=figure('visible','on');hold on,plot(Y)
            if any(closest_indices)
                scatter(closest_indices,Y(closest_indices),40,'r*')
            end
            pan on; zoom on;
            % show dialog box before continue. Select the thresholding
            uiwait(msgbox('Before click to continue the binarization, zoom or pan on the image for a better view',''));
            zoom off; pan off;
            closest_indices=selectRangeGInput(1,1,1:no_sub_div,Y);
            th_segmentation=E(closest_indices);
            close(imhistfig)
            seg_AFM=AFM_noBk;
            seg_AFM(seg_AFM<th_segmentation)=0;
            seg_AFM(seg_AFM>=th_segmentation)=1;
        end       
        seg_dial=imerode(seg_AFM,kernel);
        seg_dial=imdilate(seg_dial,kernel);
        if exist('h1', 'var') && ishandle(h1)
            delete(h1);
        end
        h1=subplot(122);
        imshow(seg_dial); title('Baseline and foreground processed', 'FontSize',16), colormap parula
        colorbar('Ticks',[0 1],...
         'TickLabels',{'Background','Foreground'},'FontSize',13)

        if(strcmp(p.Results.AutoElab,'No'))
            satisfied=questdlg('Keep automatic threshold selection or turn to Manual?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
            if(first_In==1)
                if(strcmp(satisfied,'Manual Selection'))
                    [Y,E] = histcounts(AFM_noBk,no_sub_div);
                    first_In=0;
                end
            end
        end
    end
    close(f3)
    
    if SeeMe
        f4=figure('Visible','on');
    else
        f4=figure('Visible','off');
    end

    imshow(seg_dial); title('Baseline and foreground processed', 'FontSize',16), colormap parula
    colorbar('Ticks',[0 1],'TickLabels',{'Background','Foreground'},'FontSize',13)
    objInSecondMonitor(secondMonitorMain,f4);
    
    if SavFg
        saveas(f4,sprintf('%s\\resultA3_2_BaselineForeground.tif',filepath))
    end
    close(f4)
    % converts any nonzero element of the yellow/blue image into a logical image.
    IO_Image=logical(seg_dial);
    if(exist('wb','var'))
        delete (wb)
    end
end


