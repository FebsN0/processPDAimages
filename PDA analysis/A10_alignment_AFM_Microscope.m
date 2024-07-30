% to align AFM height IO image to BF IO image, the main alignment
function [AFM_IO_padded,BF_IO_reduced,AFM_Elab,pos_allignment,details_it_reg]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,BFcropped,AFM_height_IO,metaData_AFM,AFM_Elab,newFolder,secondMonitorMain,varargin)
    % OUTPUT DETAILS
    %   - AFM_IO_padded :   AFM height 0/1 data ALIGNED with BF 0/1 data BUT the image is slighly bigger (in
    %                       case of margin or only crop) which values, outside AFM height is only 0. Briefly,
    %                       it is the moving data
    %   - BF_IO_reduced :   same size as the previous output data, it is the fixed data used for alignment
    %   - AFM_Elab      :   the AFM data with any channels. Post elaboration of the original AFM_Elab used as input.
    %                       the updates consist in:
    %                               1) Cropped_AFM_image field  (update): the original data is aligned (rotation and resize)
    %                               2) AFM_Padded field         (new): it is the same of before, but in the space of BF original image (BF_Mic_Image_IO input variable)
    %   - pos_allignment
    %   - details_it_reg:   contains all the iterative (both manual or automatic) steps performed to process the AFM image. Two possibilities for each row
    %                       1) 1 : resize | scale (positive or negative)
    %                       2) 0 : rotation | degree rotation
    %
    % INPUT DETAILS

    fprintf('\n\t\tSTEP 10 processing ...\n')
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

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
    argName = 'Margin';
    defaultVal = 25;
    addParameter(p,argName,defaultVal,@(x) isnumeric(x) && (x >= 0));
    
    parse(p,BF_Mic_Image_IO,metaData_BF,BFcropped,AFM_height_IO,metaData_AFM,AFM_Elab,varargin{:});

    if(strcmp(p.Results.Silent,'Yes')), SeeMe=false; else, SeeMe=true; end
    fprintf(['Results of optional input:\n' ...
        '\tSilent:\t\t\t\t%s\n'      ...
        '\tMargin:\t\t\t\t%d\n'
        ],p.Results.Silent,p.Results.Margin)
    
    % Add a new column-Field to the AFM data struct with zero elements matrix and same BF image size
    [AFM_Elab(:).AFM_Padded]=deal(zeros(size(BF_Mic_Image_IO)));
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
    
    if(AFMRatioVertical==AFMRatioHorizontal)
        % if the x and y pixel sizes are the same
        scale = scaleAFM2BF_H;              % scalar value
    else
         % if the x and y pixel sizes are not the same
        scale = [round(scaleAFM2BF_H*size(AFM_height_IO,1)) round(scaleAFM2BF_V*size(AFM_height_IO,2))];    % number of rows and columns
    end
        
    AFM_IO_resized=imresize(AFM_height_IO,scale);
    for flag_AFM=1:size(AFM_Elab,2)
        % scale the AFM channels. It doesnt mean that the matrix size of AFM and BF images will be the same.
        % Indipendent from BF processing
        AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,scale);
    end
    clear BFRatioHorizontal BFRatioVertical AFMRatioHorizontal AFMRatioVertical scaleAFM2BF_H scaleAFM2BF_V scale
    
    % if not already cropped, ask if crop the BF IO image
    if strcmp(BFcropped,'No')
        question='Original BrightField image not cropped yet. Crop? The smaller the crop, the easier the alignment will be.';
        answerCrop=getValidAnswer(question,'',{'Yes','No'});
    else
        answerCrop=2;
    end

    while true
        if answerCrop == 1
            % crop the right area containing the AFM image, if not, restart
            f1=figure;
            imshow(BF_Mic_Image_IO); title('BrightField 0/1 image','FontSize',14)
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
            uiwait(msgbox('Crop the area of interest containing the stimulated part',''));
            [~,specs]=imcrop();
            close(f1)
            % extract the cropped area
            YBegin=round(specs(1));
            XBegin=round(specs(2));
            YEnd=round(specs(1))+round(specs(3));
            XEnd=round(specs(2))+round(specs(end));  
            if(XEnd>size(BF_Mic_Image_IO,1)), XEnd=size(BF_Mic_Image_IO,1); end
            if(YEnd>size(BF_Mic_Image_IO,2)), YEnd=size(BF_Mic_Image_IO,2); end
            BF_IO_cropped=BF_Mic_Image_IO(XBegin:XEnd,YBegin:YEnd);
            clear YBegin XBegin YEnd XEnd
        else
            % in case already cropped
            BF_IO_cropped=BF_Mic_Image_IO;
        end

        % run cross correlation and alignment between BF and resized AFM
        [max_c_it_OI,~,~,final_time,rect,AFM_IO_padded] = A10_feature_crossCorrelationAlignmentAFM(BF_IO_cropped,AFM_IO_resized);
        f2=figure;
        imshowpair(BF_IO_cropped,AFM_IO_padded,'falsecolor')
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
        title('Brightfield and resized AFM images - Post First cross-correlation','FontSize',14)
        question='Is the AFM image correctly aligned with the BF? If not, you might selected wrong cropping area or should crop if not cropped.\nClick "No" to run a new crop.';
        answer = getValidAnswer(sprintf(question),'',{'Yes','No'});
        if answer == 1
            saveas(f2,sprintf('%s/resultA10_1_BFcropped_AFMresize_firstCrossCorrelation.tif',newFolder))
            break
        else
            answerCrop=1;
        end
        close(f2)
    end
    % save the coordinates of AFM resized in the 2D space of BF (cropped)
    xbegin = rect(1); xend = rect(2);
    ybegin = rect(3); yend = rect(4);
    % fix the size of BF image based on the Margin
    question=sprintf('Do you want to obtain a BF image slightly larger than the AFM image by a defined margin (%d pixels)?',p.Results.Margin);
    answerReducedBF=getValidAnswer(question,'',{'Yes','No'});
    close all
    % if the AFM image is properly inside the BF image. Adjust the borders
    % the new coordinates represent the new space of BF reduced
    if answerReducedBF == 1
        % FIX LEFT BORDER: if the BF border is very close and less than margin, then "modify" the margin to the extreme BF border
        if (xbegin-p.Results.Margin>=1), tmp_xbegin=xbegin-p.Results.Margin; else, tmp_xbegin=1; end
        % FIX RIGHT BORDER
        if (xend-p.Results.Margin>=1), tmp_xend=xend+p.Results.Margin; else, tmp_xend=size(tmpIO,2); end
        % FIX BOTTOM BORDER
        if (ybegin-p.Results.Margin>=1), tmp_ybegin=ybegin-p.Results.Margin; else, tmp_ybegin=1; end
        % FIX TOP BORDER
        if (yend-p.Results.Margin>=1), tmp_yend=yend+p.Results.Margin; else, tmp_yend=size(tmpIO,1); end
        
        % extract the BF with reduced border depending on the margin
        BF_IO_reduced=BF_IO_cropped(tmp_ybegin:tmp_yend,tmp_xbegin:tmp_xend);
        AFM_IO_padded=(zeros(size(BF_IO_reduced)));
        AFM_IO_padded( ...
            p.Results.Margin+1:yend-ybegin+p.Results.Margin+1, ...
            p.Results.Margin+1:xend-xbegin+p.Results.Margin+1) = AFM_IO_resized;
        % note: rect is not valid anymore, since there is a new BF image
        f3=figure;
        imshowpair(BF_IO_reduced,AFM_IO_padded,'falsecolor')
        clear tmpIO
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
        title('Reduced (by margin) Brightfield and resized AFM images - First cross-correlation','FontSize',14)
        saveas(f3,sprintf('%s/resultA10_2_BFreduced_AFMresize_firstCrossCorrelation.tif',newFolder))
    else
        BF_IO_reduced=BF_IO_cropped;
    end
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% OPTIMIZATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%% NOTE: although the AFM and BF images have same sizes, the true content of AFM is smaller and coincides
    %%% with the AFM_IO_resized
    
    question='Maximizing the cross-correlation between the BF and AFM images.'; ...
    options={ ...
        sprintf('(1) Automatic method\n Iterative process of expansion, reduction and rotation.'); ...
        sprintf('(2) Manual method\n Choose which operation (expansion, reduction and rotation) run.'); ...
        '(3) Stop here the process. The fist cross-correlatin is okay.'};
    answerMethod=getValidAnswer(question,'',options);
    close gcf
    % in case the user believe that the first cross correlation is ok
    if answerMethod == 3
        details_it_reg=nan;
        moving_final=AFM_IO_resized;
    elseif answerMethod==2
    % manual approach
        [moving_final,details_it_reg,rect,rotation_deg_tot]=A10_feature_manualAlignmentGUI(BF_IO_reduced,AFM_IO_padded,max_c_it_OI,secondMonitorMain,newFolder); % forse va AFM_IO_resized e non AFM_IO_padded
        xbegin=rect(1); xend=rect(2); ybegin=rect(3); yend=rect(4);
        f4=figure('visible','off');
        imshowpair(BF_IO_reduced,moving_final,'falsecolor');
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f4); end
        title('Reduced (by margin) Brightfield and resized AFM images - End Manual Approach','FontSize',14)
        saveas(f4,sprintf('%s/resultA10_4_BFreduced_AFMopt_EndManualApproach.tif',newFolder))
        % process the AFM channel data using the details_it_reg
        for i=1:size(details_it_reg,1)
            % process rotation
            if details_it_reg(i,1)==0
                for flag_AFM=1:size(AFM_Elab,2)
                    AFM_Elab(flag_AFM).Cropped_AFM_image=imrotate(AFM_Elab(flag_AFM).Cropped_AFM_image,details_it_reg(i,2),'bilinear','loose');
                end
                fprintf('rotation. new size: %dx%d\n',size(AFM_Elab(1).Cropped_AFM_image))
            else
            % process resize
                for flag_AFM=1:size(AFM_Elab,2)
                    AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,size(AFM_Elab(flag_AFM).Cropped_AFM_image)+details_it_reg(i,2));
                end
                fprintf('resize. new size: %dx%d\n',size(AFM_Elab(1).Cropped_AFM_image))
            end
        end
    else
    % automatic approach
        rotation_deg_tot=0;    
        wb=waitbar(0,'Initializing Iterative Cross Correlation','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wb,'canceling',0);    
        % setting the parameters
        cycleParameters=zeros(3,1);
        question ={sprintf('Enter the number of iterations (100 times is estimated to last %3.2f s):',seconds(final_time)*100) ...
            'Enter the step in pixel to increase/decrease during the resize:'...
            'Enter the step in degree° to rotate clock-wise/counter clock-wise:'};
        valueDefault = {'100','1','1'};
        while true
            cycleParameters = str2double(inputdlg(question,'Setting parameters for the alignment',[1 80],valueDefault));
            if any(isnan(cycleParameters)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
            else, break
            end
        end
        Limit_Cycles=cycleParameters(1);
        StepSizeMatrix=cycleParameters(2);
        Rot_par=cycleParameters(3);
        while true
            maxAttempts = str2double(inputdlg('How many attempts should be made when a local maximum is found for which the step halves (both resize and rotation)?','',[1 50],{'3'}));
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
        details_it_reg = zeros(Limit_Cycles,2);
        before2=datetime('now');
        moving_OPT=AFM_IO_resized;
        % init plot where show overlapping of AFM-BF and trend of max correlation value
        close all
        h_it=figure('visible',SeeMe);
        f2max=figure; grid on
        max_c_it_OI_prev=max_c_it_OI;
        maxC_original = max_c_it_OI;
        h = animatedline('Marker','o');
        addpoints(h,0,1)
        ylabel('Cross-correlation scor','FontSize',12), xlabel('# cycles','FontSize',12)        

        while(N_cycles_opt<=Limit_Cycles)
            if(exist('wb','var'))
                %if cancel is clicked, stop
                if getappdata(wb,'canceling')
                   break
                end
            end
            waitbar(N_cycles_opt/Limit_Cycles,wb,sprintf('Processing the EXP/RED/ROT optimization. Cycle %d / %d',N_cycles_opt,Limit_Cycles));
            % init
            moving_iterative=cell(1,4); max_c_iterative=zeros(1,4); imax_iterative=zeros(1,4); sz_iterative=zeros(4,2);
            textFprintf={'Expansion','Reduction','Counter ClockWise Rotation','ClockWise Rotation'};
            % 1: Oversize - 2 : Undersize - 3 : PosRot - 4 : NegRot
            moving_iterative{1} = imresize(moving_OPT,size(moving_OPT)+StepSizeMatrix);
            moving_iterative{2} = imresize(moving_OPT,size(moving_OPT)-StepSizeMatrix);
            moving_iterative{3} = imrotate(moving_OPT,Rot_par,'nearest','loose');
            moving_iterative{4} = imrotate(moving_OPT,-Rot_par,'nearest','loose');
            for i=1:4
                [max_c_it_OI,imax,sz] = A10_feature_crossCorrelationAlignmentAFM(BF_IO_reduced,moving_iterative{i},'runAlignAFM',false);
                max_c_iterative(i)=max_c_it_OI;
                imax_iterative(i)=imax;
                sz_iterative(i,:) = sz;
            end
            % if the max value of the new cross-correlation is better than the previous saved one, then
            % update. Save also the index for a new shift
            if(max(max_c_iterative)>max_c_it_OI_prev)
                % reset the attemptChanges
                attemptChanges=0;
                z=z+1;
                [a,b]=max(max_c_iterative);
                max_c_it_OI_prev=a;
                imax_OI=imax_iterative(b);   % required to shift the image
                size_OI = sz_iterative(b,:);
                % save the best moving AFM image
                moving_OPT= moving_iterative{b};
                % adjust any AFM data channels into FIELD Cropped_AFM_image (Lateral deflection, etc etc) every step based
                % on the OPT process. NOTE: Indipendent from BF processing
                switch b
                    case {1,2} 
                        if b == 1, StepSizeMatrix=abs(StepSizeMatrix); else, StepSizeMatrix=-abs(StepSizeMatrix); end
                        for flag_AFM=1:size(AFM_Elab,2)
                            AFM_Elab(flag_AFM).Cropped_AFM_image=imresize(AFM_Elab(flag_AFM).Cropped_AFM_image,size(AFM_Elab(flag_AFM).Cropped_AFM_image)+StepSizeMatrix);
                        end
                        % keep track
                        details_it_reg(z,1)=1;
                        details_it_reg(z,2)=StepSizeMatrix;
                    case {3,4}
                        if b == 3, Rot_par=abs(Rot_par); else, Rot_par=-abs(Rot_par); end
                        for flag_AFM=1:size(AFM_Elab,2)
                            AFM_Elab(flag_AFM).Cropped_AFM_image=imrotate(AFM_Elab(flag_AFM).Cropped_AFM_image,Rot_par,'bilinear','loose');
                        end
                        % keep track
                        details_it_reg(z,1)=0;
                        details_it_reg(z,2)=Rot_par;
                        rotation_deg_tot=rotation_deg_tot+Rot_par;
                end
                fprintf('\n %s Scaling Optimization Found.\n\tMatrix Size: %dx%d\n\tTotal rotation:%0.2f°\n\n', textFprintf{b}, size(moving_OPT),rotation_deg_tot)

                % update the score
                figure(f2max)
                score = max_c_it_OI_prev/maxC_original;
                addpoints(h,N_cycles_opt, score)
                drawnow
                
                % adjust the AFM height 0/1 image, dont run FFT, just alignment section
                [~,~,~,~,rect,AFM_IO_padded] = A10_feature_crossCorrelationAlignmentAFM(BF_IO_reduced,moving_OPT,'runFFT',false,'idxCCMax',imax_OI,'sizeCCMax',size_OI);
                xbegin = rect(1); xend = rect(2);
                ybegin = rect(3); yend = rect(4);   
                disp(rect)
                figure(h_it);
                if exist('pairAFM_BF','var')
                    delete(pairAFM_BF)
                end
                pairAFM_BF=imshowpair(BF_IO_reduced,AFM_IO_padded,'falsecolor');
                % update the cycle
                N_cycles_opt=N_cycles_opt+1;
            else
                % if there are no updates, a maximum local is likely to be found, therefore reduce StepSizeMatrix and rotaion degree.
                % If there are no updates three consecutive times when changing the StepSize, then the entire process stops
                StepSizeMatrix=ceil((StepSizeMatrix/2));
                Rot_par=Rot_par/2;
                N_cycles_opt=N_cycles_opt+1;
                attemptChanges=attemptChanges+1;
                fprintf('\n\n A local maximum may have been found. Halved parameters. Attempt %d of %d\n',attemptChanges,maxAttempts)
                if(attemptChanges==maxAttempts)
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
        waitbar(1/1,wb,'Completed the EXP/RED/ROT optimization');
        uiwait(msgbox('Process Completed. Click to continue',''));
        figure(h_it)
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,h_it); end
        title('Reduced (by margin) Brightfield and resized AFM images - End Iterative Process','FontSize',14)
        saveas(h_it,sprintf('%s/resultA10_3_reducedBF_AFM_EndIterativeProcess.tif',newFolder))
        figure(f2max)
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2max); end
        title('Trend Cross-correlation score (max value among the four different image editing)','FontSize',14)
        saveas(f2max,sprintf('%s/resultA10_4_TrendCross-correlationScore_EndIterativeProcess.tif',newFolder))
        
        uiwait(msgbox(sprintf('Performed %d Cycles in %3.2f min',N_cycles_opt,minutes(final_time2))))
        close all     
    end
    % if the method is manual or automatic, place the the AFM data in the same space of BF image (no data modification)
    if answerMethod == 1 || answerMethod == 2
        for flag_size=1:size(AFM_Elab,2)
            AFM_Elab(flag_size).AFM_Padded(ybegin:size(AFM_Elab(flag_size).Cropped_AFM_image,1)+ybegin-1,xbegin:size(AFM_Elab(flag_size).Cropped_AFM_image,2)+xbegin-1)=AFM_Elab(flag_size).Cropped_AFM_image;
        end
    end
   

    if answerReducedBF == 1, answer= 'True'; else, answer = 'False'; end
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
        'TotalRotation',...
        rotation_deg_tot,...
        'MarginOfBFReduced',...
        answer, ...
        'AmountMargin',...
        p.Results.Margin);

    if(exist('wb','var'))
        delete (wb)
    end

end

