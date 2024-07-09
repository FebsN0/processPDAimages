% Function to binarise optical images (BF, and embedded in the limited
% registration: TRITC)
% Use the PCDA and DCDA versions for those PDA films (line 62-72 is cut for
% more contrast)


function [binary_image,Tritic_before,Tritic_after_reg,FurtherDetails]=A8_feature_Mic_to_Binary(image,Tritic_before,Tritic_after_reg,varargin)

    p=inputParser();
    argName = 'Silent';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal);
    
    parse(p,varargin{:});
    if(strcmp(p.Results.Silent,'Yes')), SeeMe='off'; else, SeeMe='on'; end
    
    clearvars argName defaultVal
    Crop_image = getValidAnswer('Would Like to Crop the Image?', '', {'Yes','No'});

    if Crop_image == 1
        Was_I_Cropped='Yes';
        figure_image=imshow(imadjust(image));
        title('')
        [~,specs]=imcrop(figure_image);
        close all
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        if(XEnd>size(image,1))
            XEnd=size(image,1);
        end
        if(YEnd>size(image,2))
            YEnd=size(image,2);
        end
        Im_Or=image;
        image=image(XBegin:XEnd,YBegin:YEnd,:);
        Tritic_before=Tritic_before(XBegin:XEnd,YBegin:YEnd,:);  %added on 19112019
        Tritic_after_reg=Tritic_after_reg(XBegin:XEnd,YBegin:YEnd,:);  %added on 19112019
    else
        Was_I_Cropped='No';
        YBegin=nan;
        XBegin=nan;
        YEnd=nan;
        XEnd=nan;
    end


    question='\nThe fluorescence is from PCDA? [Y,N]';
    answer=getValidAnswer(question,{'y','n'});
    if strcmpi(answer,'n')
        Im_Neg(size(image,1),size(image,2))=0;
        [a,~]=max(max(image));
        Im_Neg=plus(Im_Neg,a);
        Im_Neg=minus(Im_Neg,image);
        background=imopen(imadjust(Im_Neg),strel('square',50)); %modified to 100 from 50 on 22112019
        I2=imadjust(Im_Neg)-background;
        [a,~]=max(max(I2));
        Im_Pos(size(image,1),size(image,2))=0;
        Im_Pos=plus(Im_Pos,a);
        image2=imadjust(minus(Im_Pos,I2)); %modified to image2 on 22112019
        clearvars Im_Neg a background I2 Im_Pos
    else
        image2=image; %%%%%%%%%%% nella parte proveniente da Mic_to_Binary_PCDA.m, previous condition is omitted %%%%%%%%%%%
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
    
    FurtherDetails=struct(...
        'Threshold',...
        threshold,...
        'Cropped',...
        Was_I_Cropped,...
        'Crop_XBegin',...
        XBegin,...
        'Crop_YBegin',...
        YBegin,...
        'Crop_XEnd',...
        XEnd,...
        'Crop_YEnd',...
        YEnd);

end