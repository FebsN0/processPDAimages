% to align AFM height IO image to BF IO image, the main alignment
function [padded_AFM,microscope_cut,AFM_Elab,pos_allignment,details_it_reg]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,BFcropped,AFM_height_IO,metaData_AFM,AFM_Elab,newFolder,secondMonitorMain,varargin)
    fprintf('\n\t\tSTEP 10 processing ...\n')
    dbstop if error
    warning('off', 'Images:initSize:adjustingMag');
    
    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'BF_Mic_Image_IO');
    addRequired(p,'metaData_BF')
    addRequired(p,'BFcropped') 
    addRequired(p, 'AFM_height_IO');
    addRequired(p,'metaData_AFM')
    addRequired(p,'AFM_Elab') 
    
    argName = 'Silent';
    defaultVal = 'No';
    addParameter(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));
    argName = 'CropStill';
    defaultVal = 'Yes';
    addParameter(p,argName,defaultVal,@(x) ismember(x,{'No','Yes'}));    
    argName = 'Margin';
    defaultVal = 25;
    addParameter(p,argName,defaultVal,@(x) isnumeric(x) && (x >= 0));
    
    parse(p,BF_Mic_Image_IO,metaData_BF,BFcropped,AFM_height_IO,metaData_AFM,AFM_Elab,varargin{:});

    if(strcmp(p.Results.Silent,'Yes')), SeeMe=false; else, SeeMe=true; end
    fprintf(['Results of optional input:\n' ...
        '\tSilent:\t\t\t\t%s\n'      ...
        '\tCropStill:\t\t\t%s\n' ...
        '\tMargin:\t\t\t\t%d\n'
        ],p.Results.Silent,p.Results.CropStill,p.Results.Margin)
    
    % Add a new column-Field to the AFM data struct with zero elements matrix and same BF image size
    [AFM_Elab(:).Padded]=deal(zeros(size(BF_Mic_Image_IO)));
    % x and y lengths of AFM image are in meters ==> convert to um 
    metaData_AFM.x_scan_length=metaData_AFM.x_scan_length*1e6;
    metaData_AFM.y_scan_length=metaData_AFM.y_scan_length*1e6;
    % Optical microscopy and AFM image resolution can be entered here
    
    if SeeMe
        [settings, ~] = settingsdlg(...
            'Description'                        , 'Setting the parameters that will be used in the elaboration', ...
            'title'                              , 'Image Alighnment options', ...
            'separator'                          , 'Microscopy Parameters', ...
            {'Image Width (um):';'MW'}               , metaData_BF.ImageWidthPixels*metaData_BF.ImageWidthMeter, ...
            {'Image Height (um):';'MH'}              , metaData_BF.ImageHeightPixels*metaData_BF.ImageHeightMeter, ... %modified to 237.18 from 237.10 on 12022020
            {'Or Img Size Px Width (Px):';'MicPxW'}  , metaData_BF.ImageWidthPixels, ...
            {'Or Img Size Px Height (Px):';'MicPxH'} , metaData_BF.ImageHeightPixels, ...
            'separator'                           , 'AFM Parameters', ...
            {'Image Width (um):';'AFMW'}          , metaData_AFM.x_scan_length, ...
            {'Image Height (um):';'AFMH'}         , metaData_AFM.y_scan_length, ...
            {'Image Pixel Width (Px):';'AFMPxW'}  , metaData_AFM.x_scan_pixels, ...
            {'Image Pixel Height (Px):';'AFMPxH'} , metaData_AFM.y_scan_pixels);
    else
        settings.MW= metaData_BF.ImageWidthPixels*metaData_BF.ImageWidthMeter;
        settings.MH= metaData_BF.ImageHeightPixels*metaData_BF.ImageHeightMeter;
        settings.MicPxW= metaData_BF.ImageWidthPixels;
        settings.MicPxH= metaData_BF.ImageHeightPixels;
        settings.AFMW=metaData_AFM.x_scan_length;
        settings.AFMPxW=metaData_AFM.x_scan_pixels;
        settings.AFMH=metaData_AFM.y_scan_length;
        settings.AFMPxH=metaData_AFM.y_scan_pixels;
    end
    
    BFRatioHorizontal=settings.MW/settings.MicPxW;              % size in um of single pixel based on entire image (horizontal - BF  image)
    BFRatioVertical=settings.MH/settings.MicPxH;                % size in um of single pixel based on entire image (vertical - BF  image)
    AFMRatioHorizontal=settings.AFMW/settings.AFMPxW;           % size in um of single pixel based on entire image (horizontal - AFM image
    AFMRatioVertical=settings.AFMH/settings.AFMPxH;             % size in um of single pixel based on entire image (vertical   - AFM image)

    % The AFM and BF may be in different meter scale (i.e. the size in meter of single pixel may be different)
    % Therefore a scaling is required so that the size of the single pixel is the same as the BF image. If the
    % ratio is > 1 ==> than the AFM image's size will increase, otherwise it will decrease
    scaleAFM2BF_H=  AFMRatioHorizontal/BFRatioHorizontal;
    scaleAFM2BF_V=  AFMRatioVertical/BFRatioVertical;
    
    text=sprintf('Scaling the AFM channels based on BF pixel size (%d of %d channels)',0,size(AFM_Elab,2));
    wb=waitbar(0/size(AFM_Elab,2),text,'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);      

    if(AFMRatioVertical==AFMRatioHorizontal)
        % if the x and y pixel sizes are the same
        scale = scaleAFM2BF_H;              % scalar value
    else
         % if the x and y pixel sizes are not the same
        scale = [round(scaleAFM2BF_H*size(AFM_height_IO,1)) round(scaleAFM2BF_V*size(AFM_height_IO,2))];    % number of rows and columns
    end
        
    moving=imresize(AFM_height_IO,scale);
    for flag_AFM=1:size(AFM_Elab,2)
        if getappdata(wb,'canceling')
           break
        end
        text=sprintf('Scaling the AFM channels based on BF pixel size (%d of %d channels)',flag_AFM,size(AFM_Elab,2));
        waitbar(flag_AFM/size(AFM_Elab,2),wb,text);
        % scale the AFM channels. It doesnt mean that the matrix size of AFM and BF images will be the same
        AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,scale);
    end
    
    % crop BF IO image
    if strcmp(BFcropped,'No')
        question='Crop the BrightField image? The smaller the crop, the easier the alignment will be.';
        answer=getValidAnswer(question,'',{'Yes','No'});
        if answer==1
            f1=figure;
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
            imshow(BF_Mic_Image_IO); title('BrightField 0/1 image','FontSize',14)
            uiwait(msgbox('Crop the area of interest containing the stimulated part',''));
            [~,specs]=imcrop();
            close(f1)
            YBegin=round(specs(1));
            XBegin=round(specs(2));
            YEnd=round(specs(1))+round(specs(3));
            XEnd=round(specs(2))+round(specs(end));  
            if(XEnd>size(BF_Mic_Image_IO,1)), XEnd=size(BF_Mic_Image_IO,1); end
            if(YEnd>size(BF_Mic_Image_IO,2)), YEnd=size(BF_Mic_Image_IO,2); end
            BF_Mic_Image_IO=BF_Mic_Image_IO(XBegin:XEnd,YBegin:YEnd);
        end
    end

    waitbar(0/1,wb,'First Cross Correlation');
    % calc the time required to run a cross-correlation
    before1=datetime('now');
    cross_correlation=xcorr2_fft(BF_Mic_Image_IO,moving);
    final_time=minus(datetime('now'),before1);
    waitbar(1/1,wb,'Completed First Cross Correlation');

    % find the max value in the 2D matrix. Such value represent the point in which the two images are mostly
    % correlated (i.e. almost aligned).
    [max_c_it_OI, imax] = max(abs(cross_correlation(:)));                 % cross_correlation(:) becomes a single array with any element, therefore find the idx x max value in 1D array
    [ypeak, xpeak] = ind2sub(size(cross_correlation),imax);     % convert the idx of 1D array into idx 2D matrix
    % The idx's point of view is from BF_Mic_Image_IO ==> therefore the AFM image has to moved
    corr_offset = [(xpeak-size(moving,2)) (ypeak-size(moving,1))];

    xoffset = corr_offset(1);                    % idx from the left of BF matric
    yoffset = corr_offset(2);                    % idx from the top of BF matrix
    % In the worst case scenario, the top and left edges of the AFM image coincide with those of the BF image.
    % It is very unlikely that the AFM image goes outside the BF image because of experimental design.
    if(xoffset>0), xbegin = round(xoffset); else, xbegin = 1; end
    xend   = xbegin+size(moving,2)-1;
    if(yoffset>0), ybegin = round(yoffset); else, ybegin = 1; end
    yend   = ybegin+size(moving,1)-1;
    % create a zero-element matrix with the same cropped BF sizes and place the AFM image based at those idxs (i.e.
    % offset) which represent the most aligned position
    padded_AFM=(zeros(size(BF_Mic_Image_IO)));
    padded_AFM(ybegin:yend,xbegin:xend) = moving;
    % show the first cross correlation
    f2=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
    imshowpair(BF_Mic_Image_IO(:,:),padded_AFM,'falsecolor')
    title('Cropped Brightfield and resized AFM images - First cross-correlation','FontSize',14)
    saveas(f2,sprintf('%s/resultA10_1_BF_AFM_firstCrossCorrelation.tif',newFolder))

    question=sprintf('Maximize the cross-correlation between the BF and AFM images?\n(I.e. Run a cycle of series of operations: Iterative, auto-expansion and compression).');
    answer=getValidAnswer(question,'',{'Yes','No'});
    rotation_deg=0;

    if answer==1
        waitbar(0,wb,'Initializing Iterative Cross Correlation');
        % check whether the BF image, in case it was already cropped before this function, is still OK
        if(strcmp(BFcropped,'Yes'))
            if(ybegin-p.Results.Margin>=1) && (xbegin-p.Results.Margin>=1) && ...
                (yend+p.Results.Margin<size(BF_Mic_Image_IO,2)) && ...
                (xend+p.Results.Margin<size(BF_Mic_Image_IO,2))
                reduced_BF_IO=BF_Mic_Image_IO(ybegin-p.Results.Margin:yend+p.Results.Margin,xbegin-p.Results.Margin:xend+p.Results.Margin,:);
                % run a second cross-correlation between the already cropped BF image and AFM image
                cross_correlation=xcorr2_fft(reduced_BF_IO,moving);
                [max_c_it_OI,~] = max(abs(cross_correlation(:)));
            else
                reduced_BF_IO=BF_Mic_Image_IO;
            end
        else
            reduced_BF_IO=BF_Mic_Image_IO;
        end
        
        
        %%%%%%%%%%%%%%%%%%%%%%
%%% FIX THE REQUIRED AMOUNT OF TIME %% not sure how much is. Before was 100/20
        %%%%%%%%%%%%%%%%%%%%%%
        
        options= { ...
            sprintf('TRCDA - Maximum time required: %3.2f min\n(Limit_Cycles: 1000; StepSize: 0.005 Tot_par: 2).',seconds(final_time)*1000/60),...
            sprintf('DCDA - Maximum time required: %3.2f min\n(Limit_Cycles: 500; StepSize: 0.0001 Tot_par: 50)',seconds(final_time)*500/60),...
            sprintf('PCDA - Maximum time required: %3.2f min\n(Limit_Cycles: 1000; StepSize: 0.00001 Tot_par: 500)',seconds(final_time)*1000/60),...
            'Enter manually the values'};
        question='Select the Polydiacetylene used in the experiment to prepare the alignment cycle parameters or choose to set them manually.';
        answer=getValidAnswer(question,'',options);
        switch answer
            case 1
                Limit_Cycles=1000;          % the number of iteration of alignment
                StepSize=0.005;             % the increase in resize
                Rot_par=2;                  % the extra rotational parameter
            case 2
                Limit_Cycles=500;
                StepSize=0.0001;
                Rot_par=50; 
            case 3
                Limit_Cycles=1000;
                StepSize=0.00001;
                Rot_par=500;
            case 4
                cycleParameters=zeros(3,1);
                question ={'Enter the number of iterations:' ...
                    'Enter the step size (increase/decrease in resize and rotation):'...
                    'Enter the rotational parameter'};
                valueDefault = {'1000','0.005','2'};
                while true
                    cycleParameters = str2double(inputdlg(question,'Setting parameters for the alignment',[1 90],valueDefault));
                    if any(isnan(cycleParameters)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                    else, break
                    end
                end
                Limit_Cycles=cycleParameters(1);
                StepSize=cycleParameters(2);
                Rot_par=cycleParameters(3);
        end
        while true
            maxAttempts = str2double(inputdlg('How many attempts should be made when a local maximum is found for which the StepSize halves?','',[1 50],{'3'}));
            if any(isnan(maxAttempts)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
            else, break
            end
        end
        
        % init vars. Everytime the cross-correlation is better than the previous, increase z
        N_cycles_opt=1; z=0;
        % Init the var where keep information of any transformationù
        % 1° col: resize operation (0 = no, 1 = yes)
        % 2° col: save the new matrix size (row) OR the rotation angle
        % 3° col: save the new matrix size (col) OR NaN
        details_it_reg = zeros(Limit_Cycles,3);
        before2=datetime('now');
        moving_OPT=moving;
        while(N_cycles_opt<=Limit_Cycles)
            if(exist('wb','var'))
                %if cancel is clicked, stop
                if getappdata(wb,'canceling')
                   break
                end
            end
            waitbar(N_cycles_opt/Limit_Cycles,wb,sprintf('Processing the EXP/RED/ROT optimization. Cycle %d / %d',N_cycles_opt,Limit_Cycles));
    
            % increase
            moving_iterative_Oversize=imresize(moving_OPT,1+StepSize*N_cycles_opt);
            cross_correlation_Oversize=xcorr2_fft(reduced_BF_IO,moving_iterative_Oversize);
            [max_c_iterative(1),imax(1)] = max(abs(cross_correlation_Oversize(:)));
            % decrease
            moving_iterative_Undersize=imresize(moving_OPT,1-StepSize*N_cycles_opt);
            cross_correlation_Undersize=xcorr2_fft(reduced_BF_IO,moving_iterative_Undersize);
            [max_c_iterative(2),imax(2)] = max(abs(cross_correlation_Undersize(:)));
            % rotation clockwise
            moving_iterative_PosRot=imrotate(moving_OPT,StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_PosRot=xcorr2_fft(reduced_BF_IO,moving_iterative_PosRot);
            [max_c_iterative(3),imax(3)] = max(abs(cross_correlation_PosRot(:)));          
            % rotation counter-clockwise
            moving_iterative_NegRot=imrotate(moving_OPT,-StepSize*N_cycles_opt*Rot_par,'nearest','loose');
            cross_correlation_NegRot=xcorr2_fft(reduced_BF_IO,moving_iterative_NegRot);
            [max_c_iterative(4),imax(4)] = max(abs(cross_correlation_NegRot(:)));

            % if the max value of the new cross-correlation is better than the previous saved one, then
            % update. Save also the index for a new shift
            if(max(max_c_iterative)>max_c_it_OI)
                % reset the stepChanges
                StepChanges=0;
                z=z+1;
                [a,b]=max(max_c_iterative);
                max_c_it_OI=a;
                imax_OI=imax(b);   % required to shift the image
                switch b
                    case 1
                        moving_OPT=moving_iterative_Oversize;
                        size_OI=size(cross_correlation_Oversize);
                        details_it_reg(z,1)=1;
                        details_it_reg(z,2)=size(moving_OPT,1);
                        details_it_reg(z,3)=size(moving_OPT,2);
                        fprintf('\n Expansion Scaling Optimization Found. The new dimension is %dx%d \n',details_it_reg(z,2), details_it_reg(z,3))
                        for flag_AFM=1:size(AFM_Elab,2)
                            AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,1+StepSize*N_cycles_opt);
                        end
                    case 2
                        moving_OPT=moving_iterative_Undersize;
                        size_OI=size(cross_correlation_Undersize);
                        details_it_reg(z,1)=1;
                        details_it_reg(z,2)=size(moving_OPT,1);
                        details_it_reg(z,3)=size(moving_OPT,2);
                        fprintf('\n Contraction Scaling Optimization Found. The new dimension is %dx%d \n',details_it_reg(z,2), details_it_reg(z,3))
                        for flag_AFM=1:size(AFM_Elab,2)
                            AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,1-StepSize*N_cycles_opt);
                        end
                    case 3
                        moving_OPT=moving_iterative_PosRot;
                        rotation_deg = rotation_deg + StepSize*N_cycles_opt*Rot_par;
                        size_OI=size(cross_correlation_PosRot);
                        details_it_reg(z,1)=0;
                        details_it_reg(z,2)=StepSize*N_cycles_opt*Rot_par;
                        details_it_reg(z,3)=nan;
                        fprintf('\n Clock Wise Rotation Scaling Optimization Found. The rotation is %f \n',details_it_reg(z,2))
                        for flag_AFM=1:size(AFM_Elab,2)
                            AFM_Elab(flag_AFM).Cropped_AFM_image=imrotate(AFM_Elab(flag_AFM).Cropped_AFM_image,StepSize*N_cycles_opt*Rot_par,'bilinear','loose');
                        end
                    case 4
                        moving_OPT=moving_iterative_NegRot;
                        rotation_deg = rotation_deg - StepSize*N_cycles_opt*Rot_par;
                        size_OI=size(cross_correlation_NegRot);
                        details_it_reg(z,1)=0;
                        details_it_reg(z,2)=-StepSize*N_cycles_opt*Rot_par;
                        details_it_reg(z,3)=nan;
                        fprintf('\n Counter Clock Wise Rotation Scaling Optimization Found. The rotation is %f \n',details_it_reg(z,2))
                        for flag_AFM=1:size(AFM_Elab,2)
                           AFM_Elab(flag_AFM).Cropped_AFM_image=imrotate(AFM_Elab(flag_AFM).Cropped_AFM_image,-StepSize*N_cycles_opt*Rot_par,'bilinear','loose');
                        end
                end
                if(exist('h_it','var'))
                    close(h_it)
                end

                % if the new AFM image sizes are still smaller than those of BF image, shift the new image
                if(size(moving_OPT)<size(reduced_BF_IO))
                    [ypeak, xpeak] = ind2sub(size_OI,imax_OI(1));
                    corr_offset = [(xpeak-size(moving_OPT,2)) (ypeak-size(moving_OPT,1))];
                    xoffset = corr_offset(1);
                    yoffset = corr_offset(2);

                    if(xoffset>0), xbegin = round(xoffset); else, xbegin = 1; end
                    xend   = xbegin+size(moving_OPT,2)-1;
                    if(yoffset>0), ybegin = round(yoffset); else, ybegin = 1; end
                    yend   = ybegin+size(moving_OPT,1)-1;
                % save the new image
                    padded_AFM=(zeros(size(reduced_BF_IO)));
                    padded_AFM(ybegin:yend,xbegin:xend) = moving_OPT;
                end
                h_it=figure('visible',SeeMe);
                imshowpair(reduced_BF_IO,padded_AFM,'falsecolor');

                N_cycles_opt=N_cycles_opt+1;
            else
                % if there are no updates, change StepSize. If there are no updates
                % three consecutive times when changing the StepSize, then the entire process stops
                StepSize=StepSize/2;
                N_cycles_opt=N_cycles_opt+1;
                StepChanges=StepChanges+1;
                fprintf('\n\n A local maximum may have been found. Halved step size. Attempt %d of %d\n',StepChanges,maxAttempts)
                if(StepChanges==maxAttempts)
                    break
                end
            end
        end

        % remove the all zero elements
        tmp=details_it_reg(1:z,:);
        details_it_reg = tmp;
        moving_final=moving_OPT;
        % calc the calculates the time taken for the entire process
        final_time2=minus(datetime('now'),before2);
        waitbar(1/1,wb,sprintf('Completed the EXP/RED/ROT optimization. Performed %d Cycles in %3.2f min',N_cycles_opt,seconds(final_time2)));
        uiwait(msgbox('Process Completed. Click to continue',''));

    % in case the user believe that the first cross correlation is ok
    else
        details_it_reg(1)=1;
        details_it_reg(2)=size(moving,1);
        details_it_reg(3)=size(moving,2);
        moving_final=moving;
    end

    for flag_size=1:size(AFM_Elab,2)
        if getappdata(wb,'canceling')
           break
        end
        text=sprintf('Apply the final modification to any AFM channel (%d of %d channels)',flag_AFM,size(AFM_Elab,2));
        waitbar(flag_AFM/size(AFM_Elab,2),wb,text);
        AFM_Elab(flag_size).Padded(ybegin:size(AFM_Elab(flag_size).Cropped_AFM_image,1)+ybegin-1,xbegin:size(AFM_Elab(flag_size).Cropped_AFM_image,2)+xbegin-1)=AFM_Elab(flag_size).Cropped_AFM_image;
    end

    % save all the information
    pos_allignment=struct(...
        'YBegin',...
        ybegin,...
        'YEnd',...
        yend,...
        'XBegin',...
        xbegin,...
        'XEnd',...
        xend,...
        'FinalAdjPixelCol',...
        size(moving_final,1),...
        'FinalAdjPixelRow',...
        size(moving_final,2),...
        'Rotation',...
        rotation_deg,...
        'MarginOfBFReduced',...
        p.Results.Margin);


    
    if(strcmp(p.Results.CropStill,'Yes'))
        warning_Flag=0;
        a=ybegin-p.Results.Margin;
        c=xbegin-p.Results.Margin;
        b=yend+p.Results.Margin;
        d=xend+p.Results.Margin;
        if ~(ybegin-p.Results.Margin>=1)
            a=1;
            warning_Flag=1;
        end
        if ~(xbegin-p.Results.Margin>=1)
            c=1;
            warning_Flag=1;
        end
        if ~(yend+p.Results.Margin<size(BF_Mic_Image_IO,1))
            b=size(BF_Mic_Image_IO,1);
            warning_Flag=1;
        end
        if ~(xend+p.Results.Margin<size(BF_Mic_Image_IO,2))
            d=size(BF_Mic_Image_IO,2);
            warning_Flag=1;
        end
        microscope_cut=BF_Mic_Image_IO(a:b,c:d);
        if(warning_Flag==1)
            warndlg('Was not able to assign Cut Microscope image ... ')
        end
    end


    if(exist('wb','var'))
        delete (wb)
    end

end
