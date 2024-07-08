function [moving_tr]=A8_limited_registration(moved,fixed,newFolder,secondMonitorMain,varargin)
% Function to align optical images to each other (TRITC after and BF to TRITC before)
   
    fprintf('\n\t\tSTEP 8 processing ...\n')
    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'moved');
    addRequired(p,'fixed')
    addRequired(p,'newFolder')
    addRequired(p,'secondMonitorMain')
    %Add default parameters.
    argName = 'Silent';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal,@(x) ismember(x,{'Yes','No'}));
    
    argName = 'Brightfield';
    defaultVal = 'No';
    addOptional(p, argName, defaultVal,@(x) ismember(x,{'Yes','No'}));

    argName = 'AFM';
    defaultVal = 'No';
    addOptional(p, argName, defaultVal,@(x) ismember(x,{'Yes','No'}));

    argName = 'Moving';
    defaultVal = 'No';
    addOptional(p, argName, defaultVal,@(x) ismember(x,{'No','Yes'}));

    % validate and parse the inputs
    parse(p,moved,fixed,newFolder,secondMonitorMain,varargin{:});

    clearvars argName defaultVal
    fprintf('Results of optional input:\n\tSilent:\t\t\t%s\n\tBrightfield:\t%s\n\tMoving:\t\t\t%s\n',p.Results.Silent,p.Results.Brightfield,p.Results.Moving)
  
    if((~islogical(moved))&&(~islogical(fixed)))
        fused_image=imfuse(imadjust(moved),imadjust(fixed),'falsecolor','Scaling','independent');
    else
        fused_image=imfuse(moved,fixed,'falsecolor','Scaling','independent');
    end
    
    uiwait(msgbox('Crop the area of interest containing the stimulated part',''));
    f1=figure;
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    imshow(fused_image)
    saveas(f1,sprintf('%s/image_8step_1_Entire_TRITIC_BeforeAfter_Overlapped_NOTfixed.tif',newFolder))   
  
    % Size and position of the crop rectangle [xmin ymin width height].
    [~,specs]=imcrop(fused_image);
    close all
    % find the indexes of the cropped area
    YBegin=round(specs(1,1));
    XBegin=round(specs(1,2));
    YEnd=round(specs(1,1))+round(specs(1,3));
    XEnd=round(specs(1,2))+round(specs(1,end));
    
    % in case the cropped area is bigger than image itself
    if(XEnd>size(moved,1)); XEnd=size(moved,1); end
    if(YEnd>size(moved,2)); YEnd=size(moved,2); end
    
    % extract the cropped image data
    reduced_fixed=fixed(XBegin:XEnd,YBegin:YEnd,:);
    reduced_moving=moved(XBegin:XEnd,YBegin:YEnd,:);
    
    flag_brightfield=0;
    % if no optional argument is given then skip the entire following part
    if strcmpi(p.Results.Brightfield,'Yes')
        flag_brightfield=1;
        if strcmpi(p.Results.Moving,'Yes')
            image_of_interest=reduced_moving;
        else
            image_of_interest=reduced_fixed;
        end
        x_Bk=1:size(image_of_interest,2);
        y_Bk=1:size(image_of_interest,1);
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
        
        f2=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
        subplot(1,2,1)
        imshow(imadjust(image_of_interest)),title('Original')
        subplot(1,2,2)
        imshow(imadjust(el_image)),title('Bk Removed')
        saveas(f2,sprintf('%s/image_8step_2_BrightField_TRITIC_Overlapped_NOTfixed.tif',newFolder))   
        awnser=getValidAnswer('Use Backgrownd Subtracted Image?','',{'Yes','No'});
        if awnser == 1
            if strcmpi(p.Results.Moving,'Yes')
                reduced_moving=el_image;
            else
                reduced_fixed=el_image;
            end
        end
        close all
        awnser_BA=getValidAnswer('Procede with border Analysis?','Border Analysis',{'Yes','No'});
        if awnser_BA == 1
            [IO_OI_moving,~]=A8_feature_Mic_to_Binary(reduced_moving);
            IO_edge_moving=edge(IO_OI_moving,'Canny');
            IO_edge_fixed=edge(reduced_fixed,'Canny');
            reduced_moving=IO_edge_moving;
            reduced_fixed=IO_edge_fixed;
        end
    elseif strcmpi(p.Results.AFM,'Yes')
        [reduced_moving,~]=Mic_to_Binary(reduced_moving);
        [reduced_fixed,~]=Mic_to_Binary(reduced_fixed);
    end

    %%%%%%%%%%%%%%%%%%% section in case no argument is given
    if(islogical(reduced_moving))||(islogical(reduced_fixed))
        f3=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
        imshow(imfuse((reduced_moving),(reduced_fixed)))
        saveas(f3,sprintf('%s/image_8step_2_Cropped_TRITIC_BeforeAfter_Overlapped_NOTfixed.tif',newFolder))   
        evo_reduced_fixed=reduced_fixed;
        evo_reduced_moving=reduced_moving;
    else
        sigma=1;
        reduced_fixed_blurred=imgaussfilt(reduced_fixed,sigma);
        reduced_moving_blurred=imgaussfilt(reduced_moving,sigma);
        imshowpair(imadjust(reduced_moving_blurred), imadjust(reduced_fixed_blurred), 'falsecolor','Scaling','independent')
        title('Cropped and Overlapped images Not Fixed')
        f3=figure;
        if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
        saveas(f3,sprintf('%s/image_8step_3_Cropped_TRITIC_BeforeAfter_Overlapped_NOTfixed.tif',newFolder))   

        % choose if run the automatic binarization or not
        question='Do you want to perform manual (for too dimmered images) or automatic selection?';
        answer=getValidAnswer(question,'',{'manual','automatic'});
        %%%%%%%%%%%%%%%%%%%%%%%% MANUAL SELECTION %%%%%%%%%%%%%%%%%%%%%%%%
        if answer == 1
            % find the point to transform separately the images fixed and moved into 0/1, similarly to step 3
            % (A3) but twice
            text={'Cropped Fixed Image','Cropped Moved Image'};
            data={reduced_fixed,reduced_moving};

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
                    if exist('subpl2','var')
                        delete(subpl2)
                    end
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
                    closest_indices=selectRangeGInput(1,1,1:1000,Y);
                    close(gcf)
                    % if the value is lower than selected point, then 0, otherwise 1
                    originalData(originalData<E(closest_indices))=0;
                    originalData(originalData>=E(closest_indices))=1;
                    subpl2=subplot(122);
                    imshow(originalData)
                    title(sprintf('Result Binarization of %s',text{i}), 'FontSize',16)
                    satisfied=getValidAnswer('Keep selection or turn again to manual selection?','',{'Continue the manual selection.','Keep current.'});       
                end
                %save the result of binarization
                saveas(eval(sprintf('f4_%d',i)),sprintf('%s/image_8step_4_%s_BinarizationResult.tif',newFolder,text{i}))
                data{i}=originalData;
            end
            close all
            evo_reduced_fixed=data{1};
            evo_reduced_moving=data{2};

        %%%%%%%%%%%%%%%%%%%%%%%% AUTOMATIC SELECTION %%%%%%%%%%%%%%%%%%%%%%%%
        else
            [counts, ~] = imhist(reduced_fixed_blurred,1000000);
            Th_r_fixed = otsuthresh(counts);
            evo_reduced_fixed=reduced_fixed;
            evo_reduced_fixed(evo_reduced_fixed<Th_r_fixed)=0;
            [counts,~] = imhist(reduced_moving_blurred,1000000);
            Th_r_moving = otsuthresh(counts);
            evo_reduced_moving=reduced_moving;
            if(flag_brightfield==1)
                evo_reduced_moving(evo_reduced_moving>Th_r_moving)=0;
            else
                evo_reduced_moving(evo_reduced_moving<Th_r_moving)=0;
            end
        end
        % show the final result of manual\auto selection
        imshowpair(imadjust(evo_reduced_moving), imadjust(evo_reduced_fixed), 'falsecolor','Scaling','independent')
    end

    cross_correlation=xcorr2_fft(evo_reduced_fixed,evo_reduced_moving);
    [~, imax] = max(abs(cross_correlation(:)));
    [ypeak, xpeak] = ind2sub(size(cross_correlation),imax(1));
    corr_offset = [(xpeak-size(evo_reduced_moving,2)) (ypeak-size(evo_reduced_moving,1))];
    rect_offset = [(evo_reduced_fixed(1)-evo_reduced_moving(1)) (evo_reduced_fixed(2)-evo_reduced_moving(2))];
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
    saveas(f5,sprintf('%s/image_8step_4_TRITIC_BeforeAfter_Overlapped_FIXED.tif',newFolder))
end