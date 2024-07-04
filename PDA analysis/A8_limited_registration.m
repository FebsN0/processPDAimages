function [moving_tr]=A8_limited_registration(moving,fixed,varargin)
% Function to align optical images to each other (TRITC after and BF to TRITC before)

    if((~islogical(moving))&&(~islogical(fixed)))
        fused_image=imfuse(imadjust(moving),imadjust(fixed),'falsecolor','Scaling','independent');
    else
        fused_image=imfuse(moving,fixed,'falsecolor','Scaling','independent');
    end
    
    answ=[];
    while isempty(answ)
        answ= questdlg(' Crop the area of interest containing the stimulated part','Crop!','OK','OK');
    end
    % Size and position of the crop rectangle [xmin ymin width height].
    [~,specs]=imcrop(fused_image);
    close all
    
    YBegin=round(specs(1,1));
    XBegin=round(specs(1,2));
    YEnd=round(specs(1,1))+round(specs(1,3));
    XEnd=round(specs(1,2))+round(specs(1,end));
    
    % in case the cropped area is bigger than image itself
    if(XEnd>size(moving,1)); XEnd=size(moving,1); end
    if(YEnd>size(moving,2)); YEnd=size(moving,2); end
    
    % extract the cropped image data
    reduced_fixed=fixed(XBegin:XEnd,YBegin:YEnd,:);
    reduced_moving=moving(XBegin:XEnd,YBegin:YEnd,:);
    
    flag_brightfield=0;
    % if no optional argument is given then skip the entire following part
    % but if any, the argument must be more than two.
    if(size(varargin,2)~=0)
        if(size(varargin,2)>2)
            error('Unknown Inputs!')
        else
            if(strcmp(varargin{1,1},'brightfield'))
                flag_brightfield=1;
                if(strcmp(varargin{1,2},'moving'))
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
                figure,
                subplot(1,2,1)
                imshow(imadjust(image_of_interest)),title('Original')
                subplot(1,2,2)
                imshow(imadjust(el_image)),title('Bk Removed')
                awnser=questdlg(sprintf('Use Backgrownd Subtracted Image?'),'Correct Image','Yes','No','No');
                if(strcmp(awnser,'Yes'))
                    if(strcmp(varargin{1,2},'moving'))
                        reduced_moving=el_image;
                    else
                        reduced_fixed=el_image;
                    end
                end
                close all
                awnser_BA=questdlg(sprintf('Procede with border Analysis?'),'Border Analysis','Yes','No','No');
                if(strcmp(awnser_BA,'Yes'))
                    [IO_OI_moving,~]=Mic_to_Binary(reduced_moving);
                    IO_edge_moving=edge(IO_OI_moving,'Canny');
                    IO_edge_fixed=edge(reduced_fixed,'Canny');
                    reduced_moving=IO_edge_moving;
                    reduced_fixed=IO_edge_fixed;
                end
            elseif(strcmp(varargin{1,1},'AFM'))
                    [reduced_moving,~]=Mic_to_Binary(reduced_moving);
                    [reduced_fixed,~]=Mic_to_Binary(reduced_fixed);
            else
                error('Unknown Inputs!')
            end
        end
    end

    if(islogical(reduced_moving))||(islogical(reduced_fixed))
        figure,imshow(imfuse((reduced_moving),(reduced_fixed)))
    else
        figure,imshow(imfuse(imadjust(reduced_moving),imadjust(reduced_fixed)))
        sigma=1;
        reduced_fixed_blurred=imgaussfilt(reduced_fixed,sigma);
        reduced_moving_blurred=imgaussfilt(reduced_moving,sigma);
        imshowpair(imadjust(reduced_moving_blurred), imadjust(reduced_fixed_blurred), 'falsecolor','Scaling','independent')
        
        %%%%%%%%%%%%%%%%%%%%% added part: choose if run the automatic binarization or not
        question='Do you want to perform manual (for too dimmered images) or automatic selection?';
        answer=getValidAnswer(question,{'manual','automatic'});
   

        if strcmpi(answer,'manual')
            alredy_done=0;
            satisfied='Manual Selection';
        
            while(strcmp(satisfied,'Manual Selection'))
                if(alredy_done==0)
                    alredy_done=1;
                     no_sub_div=2000;
                    [Y,E] = histcounts(reduced_fixed,no_sub_div);
                    figure,hold on,plot(Y)
                    [x_sel,~]=ginput(1);
                    close all
                    
                   reduced_fixed(reduced_fixed<E(1,round(x_sel)))=0;
                   reduced_fixed(reduced_fixed>=E(1,round(x_sel)))=1;
                   figure,imshow(reduced_fixed)
            
                   satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                   else
                    close all
                    figure,hold on,plot(Y)
                    if(exist('x_sel','var'))
                        plot([x_sel x_sel],ylim)
                        xlim([x_sel-x_sel/2 x_sel+x_sel/2])
                    end
                    
                    [x_sel,~]=ginput(1);
                    close all
                    
                   reduced_fixed(reduced_fixed<E(1,round(x_sel)))=0;
                   reduced_fixed(reduced_fixed>=E(1,round(x_sel)))=1;
                   figure,imshow(reduced_fixed)
                   satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                    
                end
           end
           
            alredy_done=0;
            satisfied='Manual Selection';
            
            while(strcmp(satisfied,'Manual Selection'))
                if(alredy_done==0)
                    alredy_done=1;
                     no_sub_div=2000;
                    [Y,E] = histcounts(reduced_moving,no_sub_div);
                    figure,hold on,plot(Y)
                    [x_sel,~]=ginput(1);
                    close all
                    
                   reduced_moving(reduced_moving<E(1,round(x_sel)))=0;
                   reduced_moving(reduced_moving>=E(1,round(x_sel)))=1;
                   figure,imshow(reduced_moving)
            
                   satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                   else
                    close all
                    figure,hold on,plot(Y)
                    if(exist('x_sel','var'))
                        plot([x_sel x_sel],ylim)
                        xlim([x_sel-x_sel/2 x_sel+x_sel/2])
                    end
                    
                    [x_sel,~]=ginput(1);
                    close all
                    
                   reduced_moving(reduced_moving<E(1,round(x_sel)))=0;
                   reduced_moving(reduced_moving>=E(1,round(x_sel)))=1;
                   figure,imshow(reduced_moving)
                   satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                    
                end
            end
        evo_reduced_fixed=reduced_fixed;
        evo_reduced_moving=reduced_moving;
       %%%%%%%%%%%%%%%%%%%%%%%% end added part
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
    
    moving_tr=imtranslate(moving,[xoffset,yoffset]);
    
    if((~islogical(moving))&&(~islogical(fixed)))
        figure,imshow(imfuse(imadjust(moving_tr),imadjust(fixed)))
    else
        figure,imshow(imfuse(moving_tr,fixed))
    end
end