% Function to binarise optical images (BF, and embedded in the limited
% registration: TRITC)
% Use the PCDA and DCDA versions for those PDA films (line 62-72 is cut for
% more contrast)


function [binary_image,reduced_Tritic_before,reduced_Tritic_after_aligned,FurtherDetails]=A9_Mic_to_Binary(imageBF_aligned,Tritic_before,Tritic_after_aligned,varargin)

    p=inputParser();
    %Add default mandatory parameters.
    addRequired(p, 'imageBF_aligned');
    addRequired(p,'Tritic_before')
    addRequired(p,'Tritic_after_aligned')
    %Add default parameters.
    argName = 'Silent';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal,@(x) ismember(x,{'Yes','No'}));

    parse(p,imageBF_aligned,Tritic_before,Tritic_after_aligned,varargin{:});
    clearvars argName defaultVal
    fprintf('Results of optional input:\n\tSilent:\t\t\t\t\t\t%s\n\n',p.Results.Silent)
 
    if(strcmp(p.Results.Silent,'Yes')), SeeMe='off'; else, SeeMe='on'; end
    
    Crop_image = getValidAnswer('The image is not cropped yet, would Like to Crop the Image?', '', {'Yes','No'});
    if Crop_image == 1
        figure_image=imshow(imadjust(imageBF_aligned));
        title('')
        [~,specs]=imcrop(figure_image);
        close all
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        if(XEnd>size(imageBF_aligned,1)), XEnd=size(imageBF_aligned,1); end
        if(YEnd>size(imageBF_aligned,2)), YEnd=size(imageBF_aligned,2); end
        reduced_imageBF=imageBF_aligned(XBegin:XEnd,YBegin:YEnd);
        reduced_Tritic_before=Tritic_before(XBegin:XEnd,YBegin:YEnd);
        reduced_Tritic_after_aligned=Tritic_after_aligned(XBegin:XEnd,YBegin:YEnd);
    else
        reduced_imageBF                 =imageBF_aligned;
        reduced_Tritic_before           =Tritic_before;
        reduced_Tritic_after_aligned    =Tritic_after_aligned;


    question='The fluorescence is from PCDA?';
    answer=getValidAnswer(question,'',{'Yes','No'});
    if answer == 2
        Im_Neg(size(reduced_imageBF,1),size(reduced_imageBF,2))=0;
        [a,~]=max(max(reduced_imageBF));
        Im_Neg=plus(Im_Neg,a);
        Im_Neg=minus(Im_Neg,reduced_imageBF);
        background=imopen(imadjust(Im_Neg),strel('square',50)); %modified to 100 from 50 on 22112019
        I2=imadjust(Im_Neg)-background;
        [a,~]=max(max(I2));
        Im_Pos(size(reduced_imageBF,1),size(reduced_imageBF,2))=0;
        Im_Pos=plus(Im_Pos,a);
        image2=imadjust(minus(Im_Pos,I2)); %modified to image2 on 22112019
        clearvars Im_Neg a background I2 Im_Pos
    else
        image2=reduced_imageBF; %%%%%%%%%%% nella parte proveniente da Mic_to_Binary_PCDA.m, previous condition is omitted %%%%%%%%%%%
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    if(~exist('given_flag','var'))
        
        satisfied='Manual Selection';
        alredy_done=0;
        no_sub_div=2000;
        [Y,E] = histcounts(image2,no_sub_div); %modified to image2 on 22112019
        
        while(strcmp(satisfied,'Manual Selection'))
            if(alredy_done==0)
                alredy_done=1;
                diff_Y=diff(Y);
                [~,b]=max(diff_Y);
                
                for i=2:size(diff_Y,2)
                    if(i>b)
                        if (diff_Y(1,i-1)<0)&&(diff_Y(1,i)>=0)
                            flag=i;
                            break
                        end
                    end
                end
                
                if(exist('flag','var'))
                    binary_image=image2; %modified to image2 on 22112019
                    binary_image(binary_image<E(1,flag))=0;
                    binary_image(binary_image>=E(1,flag))=1;
                    binary_image=~binary_image;
                else
                    binary_image=~imbinarize(image2,'adaptive'); %modified to image2 on 22112019
                end
                
                figure,imshow(binary_image)
                satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
            else
                close all
                clearvars binary_image diff_Y flag
                figure,hold on,plot(Y)
                if(exist('x_sel','var'))
                    plot([x_sel x_sel],ylim)
                    xlim([x_sel-x_sel/2 x_sel+x_sel/2])
                end
                
                [x_sel,~]=ginput(1);
                close all
                
                binary_image=image2; %modified to image2 on 22112019
                binary_image(binary_image<E(1,round(x_sel)))=0;
                binary_image(binary_image>=E(1,round(x_sel)))=1;
                binary_image=~binary_image;
                
                figure,imshow(binary_image)
                satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
                
            end
        end
        
        if(~strcmp(satisfied,'Keep Current'))
            if(exist('flag','var'))
                threshold=E(1,flag);
            else
                threshold=E(1,round(x_sel));
            end
        end
        
    else
        binary_image=image2; %modified to image2 on 22112019
        binary_image(binary_image<given_flag)=0;
        binary_image(binary_image>=given_flag)=1;
        binary_image=~binary_image;
    end
    
    kernel=strel('square',2);
    binary_image=imerode(binary_image,kernel);
    binary_image=imdilate(binary_image,kernel);
    
    if(~exist('threshold','var'))
        threshold=nan;
    end
    
    if Crop_image == 1
        FurtherDetails=struct(...
            'Threshold',    threshold,...
            'Cropped',      'Yes',...
            'Crop_XBegin',  XBegin,...
            'Crop_YBegin',  YBegin,...
            'Crop_XEnd',    XEnd,...
            'Crop_YEnd',    YEnd);
    else
        FurtherDetails=struct(...
            'Threshold',    threshold,...
            'Cropped',      'No');
    end

end
