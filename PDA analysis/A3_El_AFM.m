function [AFM_noBk,Cropped_Images,IO_Image,Rect]=A3_El_AFM(input,secondMonitorMain,varargin)

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
% The function uses a series a total of three parts. One simple polinomial
% background removal, the second a buttorworth filter backgrownd algorithm
% and a final iterative backgrownd removal, in which R^2 and RMS residuals
% are used to calculate the final backgrownd contained in the image. It can
% also output a binary image if further binary elaboration is required.
%
% Author: Dr. R.D.Ortuso, Levente Juhasz
% University of Geneva, Switzerland.
%
% Author modifications: Altieri F.
% University of Tokyo
%
% Last update 18/06/2024
%
    if(~isempty(varargin))&&(size(varargin,2)==1)
        if(iscell(varargin{1,1}))
            varargin=vertcat(varargin{:});
        end
    end
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types
    % and properties of inputs. This helps to make functions more robust and user-friendly.
    p=inputParser();    %init instance of inputParser
    % Add required parameter and also check if it is a struct by a inner function end if the Trace_type are
    % all Trace
    addRequired(p, 'input', @(x) isstruct(x));
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Accuracy';
    defaultVal = 'Low';
    addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}) );
    argName = 'AutoElab';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}) );
    % validate and parse the inputs
    parse(p,input,varargin{:});
    clearvars argName defaultVal

  

    % Extract the height channel
    raw_data_Or=input(strcmp({input.Channel_name},'Height (measured)')).AFM_image;
    % Orient the image by counterclockwise 180° and flip to coencide with the Microscopy image through rotations
    raw_data=flip(rot90(raw_data_Or),2);
    % Normalize using the 2D max value
    visible_data_rot=raw_data/max(max(raw_data));
    %maps the intensity values in grayscale image I to new values in J
    visible_data_rot=imadjust(visible_data_rot);
    f_start=figure;
    imshow(visible_data_rot)
    colormap parula
    title('Whole Image. Select to crop')
    fprintf('Crop manually the area of interest...\n')
    % Crop AFM image
    % Rect = Size and position of the crop rectangle [xmin ymin width height].
    [~,~,cropped_image,Rect]=imcrop();
    close(f_start)
    clc
    % Extract the data relative to the cropped area for each channel
    for i=1:size(input,2)
        %rotate and flip because the the crop area reference is already rotated and flipped
        temp_img=flip(rot90(input(i).AFM_image),2);
        size_Max_r=size(temp_img,1);
        size_Max_c=size(temp_img,2);
        end_y=round(Rect(1,1))+round(Rect(1,3));
        if(end_y>size_Max_c)
            end_y=size_Max_c;
        end
        start_y=round(Rect(1,1));
        end_x=round(Rect(1,2))+round(Rect(1,4));
        if(end_x>size_Max_r)
            end_x=size_Max_r;
        end  
        start_x=round(Rect(1,2));
        Cropped_Images(i)=struct(...
            'Channel_name', input(i).Channel_name,...
            'Trace_type', input(i).Trace_type, ...
            'Cropped_AFM_image', temp_img(start_x:end_x,start_y:end_y));
    end
    
    
    
    wb=waitbar(0/size(cropped_image,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(cropped_image,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(cropped_image,2);

    % Polynomial baseline fitting (line by line)
    poly_filt_data=zeros(size(cropped_image,1),size(cropped_image,2));
    for i=1:size(cropped_image,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        % extract the i-th column of the cropped image ==> fitting on single column
        [xData,yData] = prepareCurveData((1:size(cropped_image,1))',cropped_image(:,i));
        % Linear polynomial curve
        ft = fittype( 'poly1' );
        % group of coefficients: p1 and p2 ==> val(x) = p1*x + p2
        [fitresult,~]=fit(xData,yData, ft );
        % start the value from the origin 0
        xData_mod=xData-1;
        % dont use the offset p2, rather the first value of the i-th column
        baseline_y=(fitresult.p1*xData_mod+cropped_image(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        flag_poly_filt_data=cropped_image(:,i)-baseline_y;
        poly_filt_data(:,i)=flag_poly_filt_data-min(min(flag_poly_filt_data));
    end
    waitbar(0/N_Cycluse_waitbar,wb,sprintf('Optimizing Butterworth Filter...'));
    % distribute the fitted data among bins using N bins. OUTUPUT: Y=bin counts; E= bin edges
    % many will be zero (background), whereas other will be low to high height
    [Y,E] = histcounts(poly_filt_data,10000);
    % set the parameters for Butterworth filter ==> little recap: it is a low-pass filter with a frequency
    % response that is as flat as possible in the passband
    fc = 5; % Cut off frequency
    fs = size(cropped_image,2); % Sampling rate
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
    fit_decision_final=nan(size(filt_data_no_Bk,2),13);
    Bk_iterative=zeros(size(filt_data_no_Bk,1),size(filt_data_no_Bk,2));
    N_Cycluse_waitbar=size(filt_data_no_Bk,2);
    
    % Linear least squares fitting to the results
    for i=1:size(filt_data_no_Bk,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Preparing for best fit ... Line %.0f Completeted  %2.1f %%',i,i/N_Cycluse_waitbar*100));
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
        
        if(size(xData,1)>2)
            opts = fitoptions( 'Method', 'LinearLeastSquares' );
            opts.Robust = 'LAR';
            limit=9;
            if(exist('fit_decision','var'))
                clearvars fit_decision
                fit_decision=NaN(3,limit);
            else
                fit_decision=NaN(3,limit);
            end
 
            for z=1:limit    
                if     (z==1)&&((strcmp(p.Results.Accuracy,'Low'))||(strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly1' );
                elseif (z==2)&&((strcmp(p.Results.Accuracy,'Low'))||(strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly2' );
                elseif (z==3)&&((strcmp(p.Results.Accuracy,'Low'))||(strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly3' );
                elseif (z==4)&&((strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly4' );
                elseif (z==5)&&((strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly5' );
                elseif (z==6)&&((strcmp(p.Results.Accuracy,'Medium'))||(strcmp(p.Results.Accuracy,'High')))
                    ft = fittype( 'poly6' );
                elseif (z==7)&&(strcmp(p.Results.Accuracy,'High'))
                    ft = fittype( 'poly7' );
                elseif (z==8)&&(strcmp(p.Results.Accuracy,'High'))
                    ft = fittype( 'poly8' );
                elseif (z==9)&&(strcmp(p.Results.Accuracy,'High'))
                    ft = fittype( 'poly9' );
                end
                waitbar(i/N_Cycluse_waitbar,wb,sprintf('Observing %dst Ord Pol fit ... Line %.0f Completeted  %2.1f %%',z,i,i/N_Cycluse_waitbar*100));
                [~, gof] = fit( xData, yData, ft, opts );
                
                if(gof.adjrsquare<0)
                    gof.adjrsquare=0.001;
                end
                fit_decision(1,z)=abs(gof.sse)/gof.adjrsquare;
                fit_decision(2,z)=gof.sse;
                fit_decision(3,z)=gof.adjrsquare;    
            end
            clearvars Ind
            [~,Ind]=min(fit_decision(2,:));
            
            if (Ind==1)
                ft = fittype( 'poly1' );
            elseif (Ind==2)
                ft = fittype( 'poly2' );
            elseif (Ind==3)
                ft = fittype( 'poly3' );
            elseif (Ind==4)
                ft = fittype( 'poly4' );
            elseif (Ind==5)
                ft = fittype( 'poly5' );
            elseif (Ind==6)
                ft = fittype( 'poly6' );
            elseif (Ind==7)
                ft = fittype( 'poly7' );
            elseif (Ind==8)
                ft = fittype( 'poly8' );
            elseif (Ind==9)
                ft = fittype( 'poly9' );
            end
            waitbar(i/N_Cycluse_waitbar,wb,sprintf('Applying %d° Ord Pol fit ... Line %.0f Completeted  %2.1f %%',Ind,i,i/N_Cycluse_waitbar*100));

            fit_decision_final(i,1)=Ind;
            fit_decision_final(i,2)=fit_decision(2,Ind);
            fit_decision_final(i,3)=fit_decision(3,Ind);
            [fitresult, ~] = fit( xData, yData, ft, opts ); % gof was suppressed
            x=1:size(filt_data_no_Bk,1);
        else
            Ind=0;
        end
        
        if(Ind==1)
            Bk_iterative(:,i)=fitresult.p1*x+fitresult.p2;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
        elseif(Ind==2)
            Bk_iterative(:,i)=fitresult.p1*(x).^2+fitresult.p2*x+fitresult.p3;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
        elseif(Ind==3)
            Bk_iterative(:,i)=fitresult.p1*(x).^3+fitresult.p2*(x).^2+fitresult.p3*x+fitresult.p4;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
        elseif(Ind==4)
            Bk_iterative(:,i)=fitresult.p1*(x).^4+fitresult.p2*(x).^3+fitresult.p3*(x).^2+fitresult.p4*x+fitresult.p5;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
        elseif(Ind==5)
            Bk_iterative(:,i)=fitresult.p1*(x).^5+fitresult.p2*(x).^4+fitresult.p3*(x).^3+fitresult.p4*(x).^2+fitresult.p5*x+fitresult.p6;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
            fit_decision_final(i,9)=fitresult.p6;
        elseif(Ind==6)
            Bk_iterative(:,i)=fitresult.p1*(x).^6+fitresult.p2*(x).^5+fitresult.p3*(x).^4+fitresult.p4*(x).^3+fitresult.p5*(x).^2+fitresult.p6*x+fitresult.p7;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
            fit_decision_final(i,9)=fitresult.p6;
            fit_decision_final(i,10)=fitresult.p7;
        elseif(Ind==7)
            Bk_iterative(:,i)=fitresult.p1*(x).^7+fitresult.p2*(x).^6+fitresult.p3*(x).^5+fitresult.p4*(x).^4+fitresult.p5*(x).^3+fitresult.p6*(x).^2+fitresult.p7*x+fitresult.p8;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
            fit_decision_final(i,9)=fitresult.p6;
            fit_decision_final(i,10)=fitresult.p7;
            fit_decision_final(i,11)=fitresult.p8;
        elseif(Ind==8)
            Bk_iterative(:,i)=fitresult.p1*(x).^8+fitresult.p2*(x).^7+fitresult.p3*(x).^6+fitresult.p4*(x).^5+fitresult.p5*(x).^4+fitresult.p6*(x).^3+fitresult.p7*(x).^2+fitresult.p8*x+fitresult.p9;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
            fit_decision_final(i,9)=fitresult.p6;
            fit_decision_final(i,10)=fitresult.p7;
            fit_decision_final(i,11)=fitresult.p8;
            fit_decision_final(i,12)=fitresult.p9;
        elseif(Ind==9)
            Bk_iterative(:,i)=fitresult.p1*(x).^9+fitresult.p2*(x).^8+fitresult.p3*(x).^7+fitresult.p4*(x).^6+fitresult.p5*(x).^5+fitresult.p6*(x).^4+fitresult.p7*(x).^3+fitresult.p8*(x).^2+fitresult.p9*x+fitresult.p10;
            fit_decision_final(i,4)=fitresult.p1;
            fit_decision_final(i,5)=fitresult.p2;
            fit_decision_final(i,6)=fitresult.p3;
            fit_decision_final(i,7)=fitresult.p4;
            fit_decision_final(i,8)=fitresult.p5;
            fit_decision_final(i,9)=fitresult.p6;
            fit_decision_final(i,10)=fitresult.p7;
            fit_decision_final(i,11)=fitresult.p8;
            fit_decision_final(i,12)=fitresult.p9;
            fit_decision_final(i,13)=fitresult.p10;
        end 
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
    
    if ~isempty(secondMonitorMain), f2=figure; objInSecondMonitor(secondMonitorMain,f2); else, figure; end
    subplot(121), imshow(AFM_noBk_visible_data),colormap parula, title('Usable Partial of Image')
    satisfied='Manual Selection';
    first_In=1;
    
    % Binarisation of the bg-subtracted image
    while(strcmp(satisfied,'Manual Selection'))
        kernel=strel('square',3); % can be modified
        if(first_In==1)
            T = adaptthresh(mat2gray(AFM_noBk));
            seg_AFM = imbinarize(mat2gray(AFM_noBk),T);
        else
            clearvars seg_AFM th_segmentation seg_dial
            
            imhistfig=figure('visible','on');hold on,plot(Y)
                if(exist('x_sel','var'))
                    plot([x_sel x_sel],ylim)
                    xlim([x_sel-x_sel/2 x_sel+x_sel/2])
                end
                [x_sel,~]=ginput(1);
                th_segmentation=E(1,round(x_sel));
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
        imshow(seg_dial); title('Baseline and foreground processed'), colormap parula
        
        if(strcmp(p.Results.AutoElab,'No'))
            if(first_In==1)
                satisfied=questdlg('Keep automatic threshold selection or turn to Manual?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                if(strcmp(satisfied,'Manual Selection'))
                    no_sub_div=1000;
                    [Y,E] = histcounts(AFM_noBk,no_sub_div);
                    first_In=0;
                end
            else
                satisfied=questdlg('Keep current or reselct threshold Manually?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
            end
        else
            satisfied='Keep Current';
        end
    end
    
    % converts any nonzero element of the yellow/blue image into a logical image.
    IO_Image=logical(seg_dial);
    if(exist('wb','var'))
        delete (wb)
    end
end


