function [moving_tr]=A8_limited_registration(moved,fixed,newFolder,secondMonitorMain,varargin)
% Function to align optical images to each other (TRITC after and BF to TRITC before)
% if BF is given, it must be the first input

    fprintf('\n\t\tSTEP 8 processing ...\n')
    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'moved');
    addRequired(p,'fixed')
    %Add default parameters.
    argName = 'Silent';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal,@(x) ismember(x,{'Yes','No'})); 
    argName = 'Brightfield';
    defaultVal = 'No';
    addOptional(p, argName, defaultVal,@(x) ismember(x,{'Yes','No'}));
    argName = 'Moving';
    defaultVal = 'No';
    addOptional(p, argName, defaultVal,@(x) ismember(x,{'No','Yes'}));
    
    % validate and parse the inputs
    parse(p,moved,fixed,varargin{:});
    clearvars argName defaultVal

    %if(strcmp(p.Results.Silent,'Yes')), SeeMe='off'; else, SeeMe='on'; end

    fprintf(['Results of optional input:\n\tSilent:\t\t\t\t\t\t%s\n\t' ...
        'Brightfield:\t\t\t\t%s\n\t' ...
        'Moving:\t\t\t\t\t\t%s\n\n'], ...
        p.Results.Silent,p.Results.Brightfield,p.Results.Moving)
    % title and name figures based on what input and more are given
    if strcmpi(p.Results.Brightfield,'Yes')
        textFirstLastFig='BrightField and TRITIC Before Images Overlapped';
        textCropped = 'Fitted';
    else
        textFirstLastFig='TRITIC Before and After Images Overlapped';
        textCropped = '';
    end
    % show the overlapped original images
    if((~islogical(moved))&&(~islogical(fixed)))
        % mix two images
        fused_image=imfuse(imadjust(moved),imadjust(fixed),'falsecolor','Scaling','independent');
    else
        fused_image=imfuse(moved,fixed,'falsecolor','Scaling','independent');
    end
    f1=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    imshow(fused_image)
    title(sprintf('%s Not Aligned',textFirstLastFig),'FontSize',14) 
    saveas(f1,sprintf('%s/resultA8_1_Entire_%s_NotAligned.tif',newFolder,textFirstLastFig))

    % run the polynomial fitting on the Brightfield image since it is likely to be "tilted"
    flag_brightfield=0;
    if strcmpi(p.Results.Brightfield,'Yes')
        wb=waitbar(0/1,sprintf('Removing Polynomial Baseline . . .'),'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wb,'canceling',0);       
        flag_brightfield=1;
        if strcmpi(p.Results.Moving,'Yes')
            image_of_interest=moved;
        else
            image_of_interest=fixed;
        end
        x_Bk=1:size(image_of_interest,2);
        y_Bk=1:size(image_of_interest,1);
        % Prepare data inputs for surface fitting, similar to prepareCurveData but 3D. Transform the 2D image
        % into 3 arrays:
        % xData = 1 1 .. 1 2 .. etc = each block is long #row length of image
        % yData = 1 2 .. length(image) 1 2 .. etc
        [xData, yData, zData] = prepareSurfaceData( x_Bk, y_Bk, image_of_interest );
        ft = fittype( 'poly11' );
        [fitresult, ~] = fit( [xData, yData], zData, ft );
        fit_surf=zeros(size(y_Bk,2),size(x_Bk,2));
        y_Bk_surf=repmat(y_Bk',1,size(x_Bk,2))*fitresult.p01;
        x_Bk_surf=repmat(x_Bk,size(y_Bk,2),1)*fitresult.p10;
        fit_surf=plus(min(min(image_of_interest)),fit_surf);
        fit_surf=plus(y_Bk_surf,fit_surf);
        fit_surf=plus(x_Bk_surf,fit_surf);
        el_image=minus(image_of_interest,fit_surf);
        waitbar(1,wb,sprintf('Completed the calculation of Polynomial Baseline . . . '));
        if(exist('wb','var'))
            delete (wb)
        end
        % show the comparison between original and fitted BrightField
        f2_1=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2_1); end
        subplot(1,2,1)
        imshow(imadjust(image_of_interest)),title('Original Brightfield','FontSize',14)
        subplot(1,2,2)
        imshow(imadjust(el_image)),title('Brightfield with Bk Removed','FontSize',14)
        saveas(f2_1,sprintf('%s/resultA8_2_1_comparisonOriginalAndBackgroundSubstracted.tif',newFolder))   
                
        awnser=getValidAnswer(sprintf('Use the Backgrownd Subtracted Image?\nIf not, it will be used the original BF data'),'',{'Yes','No'});
        if awnser == 1
            if strcmpi(p.Results.Moving,'Yes')
                moved=el_image;
            else
                fixed=el_image;
            end
            close gcf
            f2_2=figure;
            if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2_2); end
            imshowpair(imadjust(moved), imadjust(fixed), 'falsecolor','Scaling','independent')
            title(sprintf('Fitted %s',textFirstLastFig),'FontSize',14)
            saveas(f2_2,sprintf('%s/resultA8_2_2_Fitted_BrightField.tif',newFolder))
            uiwait(msgbox('Click to continue',''));
        end
    end
   
    uiwait(msgbox('Crop the area of interest containing the stimulated part',''));
    % Size and position of the crop rectangle [xmin ymin width height]. Crop the last open figure.
    [~,specs]=imcrop();
    % find the indexes of the cropped area
    YBegin=round(specs(1,1));
    XBegin=round(specs(1,2));
    YEnd=round(specs(1,1))+round(specs(1,3));
    XEnd=round(specs(1,2))+round(specs(1,end)); 
    % in case the cropped area is bigger than image itself
    if(XEnd>size(moved,1)); XEnd=size(moved,1); end
    if(YEnd>size(moved,2)); YEnd=size(moved,2); end
    % extract the cropped image data
    reduced_fixed=fixed(XBegin:XEnd,YBegin:YEnd);
    reduced_moved=moved(XBegin:XEnd,YBegin:YEnd);
    close all
    
    %%%%%%%%%%%%%%%%%%% skip to this following section in case no argument
    if(islogical(reduced_moved))||(islogical(reduced_fixed))
        f3=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
        imshow(imfuse((reduced_moved),(reduced_fixed)))
        saveas(f3,sprintf('%s/resultA8_3_Cropped_%s_NotAligned.tif',newFolder,textFirstLastFig))   
        evo_reduced_fixed=reduced_fixed;
        evo_reduced_moved=reduced_moved;
        close gcf
    else
        sigma=1;
        reduced_fixed_blurred=imgaussfilt(reduced_fixed,sigma);
        reduced_moved_blurred=imgaussfilt(reduced_moved,sigma);
        f3=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
        imshowpair(imadjust(reduced_moved_blurred), imadjust(reduced_fixed_blurred), 'falsecolor','Scaling','independent')
        title(sprintf('Cropped %s-%s - Not Aligned',textCropped,textFirstLastFig))
        saveas(f3,sprintf('%s/resultA8_3_Cropped_%s-%s-NotAligned.tif',newFolder,textCropped,textFirstLastFig))   
        
        % choose if run the automatic binarization or not
        question='Do you want to perform manual (for too dimmered images) or automatic selection?';
        answer=getValidAnswer(question,'',{'manual','automatic'});
        close gcf
        %%%%%%%%%%%%%%%%%%%%%%%% MANUAL SELECTION %%%%%%%%%%%%%%%%%%%%%%%%
        if answer == 1
            % find the point to transform separately the images fixed and moved into 0/1, similarly to step 3
            % (A3) but twice
            text={'Cropped Fixed Image','Cropped Moved Image'};
            data={reduced_fixed,reduced_moved};

            for i=1:2
                % init the not completion of manual selection
                closest_indices=[];
                satisfied=1;
                eval(sprintf('f4_%d=figure;',i));
                if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,eval(sprintf('f4_%d',i))); end
                subplot(121), imshow(imadjust(data{i}))
                title(sprintf('Original %s',text{i}), 'FontSize',16)
                while satisfied==1
                    % reset every time
                    originalData=data{i};
                    no_sub_div=2000;
                    [Y,E] = histcounts(data{i},no_sub_div);
                    figure,hold on,plot(Y)
                    if any(closest_indices)
                        scatter(closest_indices,Y(closest_indices),40,'r*')
                    end
                    title(text{i},'FontSize',14);
                    pan on; zoom on;
                    % show dialog box before continue
                    uiwait(msgbox('Before click to continue the binarization, zoom or pan on the image for a better view',''));
                    zoom off; pan off;
                    closest_indices=selectRangeGInput(1,1,1:no_sub_div,Y);
                    % close the histogram
                    close gcf

                    %close(gcf)
                    % if the value is lower than selected point, then 0, otherwise 1
                    originalData(originalData<E(closest_indices))=0;
                    originalData(originalData>=E(closest_indices))=1;
                    if exist('subpl2','var')  && ishandle(subpl2)
                        delete(subpl2)
                    end
                    subpl2=subplot(122);
                    imshow(originalData)
                    title(sprintf('Result Binarization of %s',text{i}), 'FontSize',16)
                    satisfied=getValidAnswer('Keep selection or turn again to manual selection?','',{'Continue the manual selection.','Keep current.'});       
                end
                %save the result of binarization
                saveas(eval(sprintf('f4_%d',i)),sprintf('%s/resultA8_4_%s_BinarizationResult.tif',newFolder,text{i}))
                close gcf
                data{i}=originalData;
            end
            close all
            evo_reduced_fixed=data{1};
            evo_reduced_moved=data{2};

        %%%%%%%%%%%%%%%%%%%%%%%% AUTOMATIC SELECTION %%%%%%%%%%%%%%%%%%%%%%%%
        else
            [counts, ~] = imhist(reduced_fixed_blurred,1000000);
            Th_r_fixed = otsuthresh(counts);
            evo_reduced_fixed=reduced_fixed;
            evo_reduced_fixed(evo_reduced_fixed<Th_r_fixed)=0;
            [counts,~] = imhist(reduced_moved_blurred,1000000);
            Th_r_moving = otsuthresh(counts);
            evo_reduced_moved=reduced_moved;
            if(flag_brightfield==1)
                evo_reduced_moved(evo_reduced_moved>Th_r_moving)=0;
            else
                evo_reduced_moved(evo_reduced_moved<Th_r_moving)=0;
            end
        end
    end
    % xcorr2_fft Two-dimensional cross-correlation evaluated with FFT algorithm.
    cross_correlation=xcorr2_fft(evo_reduced_fixed,evo_reduced_moved);
    [~, imax] = max(abs(cross_correlation(:)));
    [ypeak, xpeak] = ind2sub(size(cross_correlation),imax(1));
    corr_offset = [(xpeak-size(evo_reduced_moved,2)) (ypeak-size(evo_reduced_moved,1))];
    rect_offset = [(evo_reduced_fixed(1)-evo_reduced_moved(1)) (evo_reduced_fixed(2)-evo_reduced_moved(2))];
    % calc the offset which is required to traslate the original image
    offset = corr_offset + rect_offset;
    xoffset = offset(1);
    yoffset = offset(2);
    moving_tr=imtranslate(moved,[xoffset,yoffset]);
    
    f5=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f5); end
    if((~islogical(moved))&&(~islogical(fixed)))
        imshow(imfuse(imadjust(moving_tr),imadjust(fixed)))
    else
        imshow(imfuse(moving_tr,fixed))
    end
    title(sprintf('Cropped %s-%s - Aligned',textCropped,textFirstLastFig),'FontSize',15)
    saveas(f5,sprintf('%s/resultA8_5_Cropped_%s-%s-Aligned.tif',newFolder,textCropped,textFirstLastFig))
end