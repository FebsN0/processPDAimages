function [moving_adj,fixed_adj,offset]=A3_feature_BF_TRITIC_imageAlignment(moved,fixed,idxMon,varargin)
% Function to align optical images to each other (TRITC after and BF to TRITC before)
% if BF is given, it must be the first input

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'moved');
    addRequired(p,'fixed')
    %Add default parameters.
    argName = 'Brightfield';    defaultVal = 'No';      addParameter(p, argName, defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,moved,fixed,varargin{:});
    clearvars argName defaultVal

    % title and name figures based on what input and more are given
    switch p.Results.Brightfield
        case 'Yes'
            textFirstLastFig='BF preAFM and BF postAFM - PostAlignement';
            sigma=0.4; % for Gaussian low-pass filter (smoothing). See later            
        case 'No'       
            textFirstLastFig='TRITIC preAFM and TRITIC postAFM- PostAlignement';
            sigma=0.8;
    end

    % show the overlapped original images
    if((~islogical(moved))&&(~islogical(fixed)))
        % mix two images
        fused_image=imfuse(imadjust(moved),imadjust(fixed),'falsecolor','Scaling','independent');
    else
        fused_image=imfuse(moved,fixed,'falsecolor','Scaling','independent');
    end
    % dont close this figure. If BK is not fixed, then use this image to crop
    f1 = figure;
    axOriginal = axes('Parent', f1);    
    imagesc(axOriginal, fused_image);
    axis(axOriginal, 'image');       % keep aspect ratio    
    title(axOriginal,sprintf('%s - Not Aligned',textFirstLastFig),'FontSize',14)
    objInSecondMonitor(f1,idxMon);
    while true        
        uiwait(warndlg(sprintf('Crop the area to register the two images.\nNOTE: for better alignment, crop possibly outside the AFM scan area.\nObjects, especially small ones, can be drifted away from original position.'),''));        
        % close the previous figure and keep the new one to the crop part    
        % Size and position of the crop rectangle [xmin ymin width height]. Crop the last open figure.
        [~,specs]=imcrop(axOriginal);
        % find the indexes of the cropped area
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,4)); 
        % in case the cropped area is bigger than image itself
        if(XEnd>size(moved,1)); XEnd=size(moved,1); end
        if(YEnd>size(moved,2)); YEnd=size(moved,2); end
        % extract the cropped image data
        reduced_fixed=fixed(XBegin:XEnd,YBegin:YEnd);
        reduced_moved=moved(XBegin:XEnd,YBegin:YEnd);
        % choose if run the automatic binarization or not
        question='What type of traslation to perform?';        
        options={'Manual (histogram)','Manual (buttons)'};
        answer=getValidAnswer(question,'',options);
        
        % Apply a Gaussian low-pass filter (smoothing) to both images before any registration step. It reduces noise 
        % and high-frequency texture. It keeps only the large-scale structures (edges, shapes, intensity blobs).
        % It applies only for method 1 and 2 because Phase correlation in  method 3  already ignores intensity scaling
        % and relies heavily on the frequency content (edges, gradients).
        %| Image type                         | Suggested sigma | Reason              |
        %| ---------------------------------- | --------------- | ------------------- |
        %| Fluorescence (low SNR)             | 0.8–1.0         | reduce noise spikes |
        %| Brightfield / TRITC overlay        | 0.3–0.7         | keep edges crisp    |
        %| AFM or high-resolution grayscale   | 0.0–0.3         | best edge retention |
        %| Already smoothed / filtered images | 0.0             | unnecessary blur    |
        reduced_fixed_blurred=imgaussfilt(reduced_fixed,sigma);
        reduced_moved_blurred=imgaussfilt(reduced_moved,sigma);
      
        %%%%%%%%%%%%%%%%%%%%%%%% SEMI- MANUAL SELECTION BY BINARIZATION OF MOVING AND FIXED AND THEN XCORR %%%%%%%%%%%%%%%%%%%%%%%%
        if answer == 1
            % Since there are two images (fixed, moving), repeat the operation twice.
            % The goal here is to binarize the images and easily align them. 
            text={'Cropped Fixed Image','Cropped Moved Image'};
            data={reduced_fixed,reduced_moved};
            for i=1:2
                % init the not completion of manual selection
                closest_indices=[];
                satisfied=1;
                ftmp=figure;
                objInSecondMonitor(ftmp,idxMon);
                tiledlayout(ftmp,2,2,'TileSpacing','compact');
                % --- Subplot 1: Original AFM image (always visible) ---
                axData_original=nexttile(1,[2 1]); cla(axData_original);
                imshow(imadjust(data{i}),'Parent',axData_original)
                title(axData_original,sprintf('Original %s',text{i}), 'FontSize',16)                
                originalData=data{i};
                no_sub_div=2000;
                [Y,E] = histcounts(data{i},no_sub_div);
                axHist=nexttile(2,[1 1]);
                hold(axHist,"on"), plot(axHist,Y)
                if any(closest_indices)
                    scatter(axHist,closest_indices,Y(closest_indices),40,'r*')
                end
                title(axHist,'Distribution values image','FontSize',12);
                axData_Bin=nexttile([1 1]);                
                tmpImg = imshow(zeros(size(originalData)),'Parent',axData_Bin);   % placeholder matrix
                title(axData_Bin,sprintf('Result Binarization of %s',text{i}), 'FontSize',12)
                while satisfied==1
                    closest_indices=selectRangeGInput(1,1,axHist);
                    % if the value is lower than selected point, then 0, otherwise 1
                    tmpData=originalData;
                    tmpData(tmpData<E(closest_indices))=0;
                    tmpData(tmpData>=E(closest_indices))=1; 
                    % Update ONLY the image, keep everything else
                    tmpImg.CData = tmpData;
                    question='Keep selection or turn again to manual selection?';
                    satisfied=getValidAnswer(question,'',{'Continue the manual selection.','Keep current.'},2);       
                end
                close(ftmp)
                data{i}=tmpData;
            end
            evo_reduced_fixed=data{1};
            evo_reduced_moved=data{2};
             % xcorr2_fft Two-dimensional cross-correlation evaluated with FFT algorithm.
            cross_correlation=xcorr2_fft(evo_reduced_fixed,evo_reduced_moved);
            [~, imax] = max(abs(cross_correlation(:)));
            [ypeak, xpeak] = ind2sub(size(cross_correlation),imax(1));
            corr_offset = [(xpeak-size(evo_reduced_moved,2)) (ypeak-size(evo_reduced_moved,1))];
            rect_offset = [(evo_reduced_fixed(1)-evo_reduced_moved(1)) (evo_reduced_fixed(2)-evo_reduced_moved(2))];
            % calc the offset which is required to traslate the original image
            offset = round(corr_offset + rect_offset);
            xoffset = offset(1);
            yoffset = offset(2);
        %%%%%%%%%%%%%%%%%%%%%%%% MANUAL SELECTION BY BUTTONS %%%%%%%%%%%%%%%%%%%%%%%%
        else      
            reduced_fixed_blurred_exp = padarray(reduced_fixed_blurred, [100, 100], min(reduced_fixed_blurred(:)), 'both');
            reduced_moved_blurred_exp = padarray(reduced_moved_blurred, [100, 100], min(reduced_moved_blurred(:)), 'both');
            [xoffset, yoffset]=A3_feature_manualAlignment(reduced_fixed_blurred_exp,reduced_moved_blurred_exp);
            offset=[xoffset, yoffset];
        end
    
        moving_tr=imtranslate(moved,[xoffset,yoffset]);
        fprintf('\nTotal Offset_X: %d - Total Offset_Y: %d\n\n',xoffset,yoffset)
        % adjust the borders. If not done, the fusing image will be not clear
        [rows, cols] = size(fixed);
        x_start = max(1, 1 + xoffset);
        y_start = max(1, 1 + yoffset);
        x_end = min(cols, cols + xoffset);
        y_end = min(rows, rows + yoffset);
        % cut out the not common area
        fixed_adj = fixed(y_start:y_end, x_start:x_end);
        moving_adj = moving_tr(y_start:y_end, x_start:x_end);
    
        f2=figure;
        if((~islogical(moved))&&(~islogical(fixed)))
            imshow(imfuse(imadjust(moving_adj),imadjust(fixed_adj)))
        else
            imshow(imfuse(moving_adj,fixed_adj))
        end
        title(sprintf('%s - Aligned',textFirstLastFig),'FontSize',15)
        objInSecondMonitor(f2,idxMon);        
        answer=getValidAnswer('Satisfied of the alignment? If not, restart from cropping.','',{'y','n'});
        close(f2)
        if answer
            break            
        end
    end
    close(f1)
end


