% Function to binarise optical images (BF, and embedded in the limited
% registration: TRITC)
% Use the PCDA and DCDA versions for those PDA films (line 62-72 is cut for
% more contrast)


function [binary_image,reduced_Tritic_before,reduced_Tritic_after_aligned,FurtherDetails]=A9_Mic_to_Binary(imageBF_aligned,Tritic_before,Tritic_after_aligned,secondMonitorMain,newFolder)

    p=inputParser();
    %Add default mandatory parameters.
    addRequired(p, 'imageBF_aligned');
    addRequired(p,'Tritic_before')
    addRequired(p,'Tritic_after_aligned')
   
    parse(p,imageBF_aligned,Tritic_before,Tritic_after_aligned);
    clearvars argName defaultVal
     
    % decide if crop the image
    Crop_image = getValidAnswer('The image is not cropped yet, would Like to Crop the Image?', '', {'Yes','No'});
    if Crop_image == 1
        ftmp=figure;
        figure_image=imshow(imadjust(imageBF_aligned));
        title('BrightField image post alignment')
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,ftmp); end
        [~,specs]=imcrop(figure_image);
        close all
        % take the coordinate of the cropped area
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        if(XEnd>size(imageBF_aligned,1)), XEnd=size(imageBF_aligned,1); end
        if(YEnd>size(imageBF_aligned,2)), YEnd=size(imageBF_aligned,2); end
        % extract the cropped area
        reduced_imageBF=imageBF_aligned(XBegin:XEnd,YBegin:YEnd);
        reduced_Tritic_before=Tritic_before(XBegin:XEnd,YBegin:YEnd);
        reduced_Tritic_after_aligned=Tritic_after_aligned(XBegin:XEnd,YBegin:YEnd);
    else
        reduced_imageBF                 =imageBF_aligned;
        reduced_Tritic_before           =Tritic_before;
        reduced_Tritic_after_aligned    =Tritic_after_aligned;
    end

    question=sprintf('Performs morphological opening operation?\n(In original code it is always yes, whereas commented in case of the PDCA code');
    answer=getValidAnswer(question,'',{'Yes','No'});
    if answer == 1
        % init a matrix with same imageBF's size
        Im_Neg = zeros(size(reduced_imageBF));
        % find the highest value in the imageBF's matrix 
        a=max(max(reduced_imageBF));
        % add the highest value to any element of the matrix
        Im_Neg= Im_Neg + a;
        % now substract with the imageBF matrix. Obtain the "mould" image of brightfield
        Im_Neg= Im_Neg - reduced_imageBF;
        % define the Structuring Element. In this case it is a 50x50 matrix (each element = 1), which will be
        % used to erode and dilate the BF image
        SE=strel('square',50);
        % performs morphological opening operation on the grayscale/binary image ==> it is an erosion followed by a dilation,
        % using the same SE for both operations. Required to remove small objects from an image while preserving the s
        % hape and size of larger objects in the image. Imadjust transform the image into grayscale.
        background=imopen(imadjust(Im_Neg),SE);
        % remove the morphological opening matrix from the "mould"
        I2=imadjust(Im_Neg)-background;
        a=max(max(I2));
        Im_Pos=zeros(size(reduced_imageBF));
        Im_Pos= Im_Pos + a;
        image2=imadjust(Im_Pos - I2);
        clearvars Im_Neg a background I2 Im_Pos
    else
        image2=reduced_imageBF; %%%%%%% in the original version Mic_to_Binary_PCDA.m, previous section was omitted %%%%%%%%%%%
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    close all
    closest_indices=[];
    satisfied='Manual Selection';
    first_In=true;
    no_sub_div=2000;
    [Y,E] = histcounts(image2,no_sub_div); 
    
    f1=figure;
    if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f1); end
    subplot(121), imshow(imadjust(image2)), title('Cropped Brightfield Image', 'FontSize',16)
    
    while(strcmp(satisfied,'Manual Selection'))
        % in the first iteration, 
        if(first_In==true)
            first_In=false;
            diff_Y=diff(Y);         % calculates differences between adjacent elements (from right to left)
            [~,b]=max(diff_Y);      % find idx of the max
            for i=2:size(diff_Y,2)
                if(i>b)
                    if (diff_Y(1,i-1)<0) && (diff_Y(1,i)>=0)    
                        flag=i;     % identify the index by which the PDA is distinguished from the background in the BF image
                        break
                    end
                end
            end
            % if the index is found, use as threshold
            if(exist('flag','var'))
                threshold=E(1,flag);
                binary_image=image2;
                binary_image(binary_image<threshold)=0;
                binary_image(binary_image>=threshold)=1;
                binary_image=~binary_image;
            else        % otherwise use in-built MATLAB function
                threshold = adaptthresh(image2);
                binary_image=~imbinarize(image2,threshold);
                % binary_image=~imbinarize(image2,'adaptive');       % identical operation. In this way it is
                % possible to know the threshold
            end
        else
            % take the original data
            binary_image=image2;
            % identify the threshold by histogram               
            imhistfig=figure('visible','on');hold on,plot(Y)
            if any(closest_indices)
                scatter(closest_indices,Y(closest_indices),40,'r*')
            end
            pan on; zoom on;
            % show dialog box before continue
            uiwait(msgbox('Before click to continue the binarization, zoom or pan on the image for a better view',''));
            zoom off; pan off;
            closest_indices=selectRangeGInput(1,1,1:no_sub_div,Y);         
            close(imhistfig)
            % find the threshold
            threshold=E(closest_indices);          
            
            binary_image(binary_image<threshold)=0;
            binary_image(binary_image>=threshold)=1;
            binary_image=~binary_image;
        end
        if exist('h1', 'var') && ishandle(h1)
            delete(h1);
        end
        h1=subplot(122);
        imshow(binary_image); title('Binarized BrightField image', 'FontSize',16)
        satisfied=questdlg('Keep selection or turn to Manual', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
    end
    saveas(f1,sprintf('%s/resultA9_1_OriginalBrightField_BaselineForeground.tif',newFolder))
    close(f1)
    % create a Structuring Element to remove objects smaller than 2 pixels
    kernel=strel('square',2);
    binary_image=imerode(binary_image,kernel);
    binary_image=imdilate(binary_image,kernel);
    f2=figure;
    imshow(binary_image)
    text=sprintf('Definitive Binarized BrightField (Morphological Opening - kernel: square 2 pixels)');
    title(text,'FontSize',14)
    if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f2); end
    saveas(f2,sprintf('%s/resultA9_2_DefinitiveBinarizedBrightField.tif',newFolder))

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
    uiwait(msgbox('Click to continue',''));
    close all
end
