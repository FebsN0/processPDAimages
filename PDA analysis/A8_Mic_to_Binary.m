% Function to binarise optical images (BF and TRITIC)
% INPUT
% (mandatory):
%       BF image to be binarised
%       secondMonitorMain
%       folderResultsImg : folder where store the images
% (optional):
%       argument to specify: 'TRITIC_before' ==> upload Tritic Before
%       argument to specify: 'TRITIC_after' ==> upload Tritic After,
% OUTPUT:
%       binary_image of BF image
%       cropped Tritic Before (if 'TRITIC_before' has been specified)
%       cropped Tritic After (if 'TRITIC_after' has been specified)
%       FurtherDetails : details about binarisation
%       
function varargout=A8_Mic_to_Binary(imageBF_aligned,idxMon,newFolder,varargin)

    p=inputParser();
    %Add default mandatory parameters.
    addRequired(p, 'imageBF_aligned');
    
    argName = 'TRITIC_before';      defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'TRITIC_after';       defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'saveFig';            defaultVal = 'Yes';     addParameter(p, argName, defaultVal, @(x) ismember(x,{'No','Yes'}));

    parse(p,imageBF_aligned,varargin{:});
    clearvars argName defaultVal
    if(strcmp(p.Results.saveFig,'Yes')), saveFig=1; else, saveFig=0; end

    reduced_imageBF=imageBF_aligned;
    if ~isempty(p.Results.TRITIC_before)
        reduced_Tritic_before=p.Results.TRITIC_before;
    end
    if ~isempty(p.Results.TRITIC_after)
        reduced_Tritic_after=p.Results.TRITIC_after;
    end
    flagCrop=false;
    % decide if crop the image. If not, leave as original size
    if getValidAnswer('The image is not cropped yet, would Like to Crop the Image? Dont in case of post heated scans', '', {'Yes','No'})
        flagCrop=true;
        ftmp=figure;
        figure_image=imshow(imadjust(imageBF_aligned));
        title('BrightField image post alignment - CROP THE IMAGE')
        objInSecondMonitor(ftmp,idxMon);
        [~,specs]=imcrop(figure_image);
        close gcf
        % take the coordinate of the cropped area
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        if(XEnd>size(imageBF_aligned,1)), XEnd=size(imageBF_aligned,1); end
        if(YEnd>size(imageBF_aligned,2)), YEnd=size(imageBF_aligned,2); end
        % extract the cropped area of BF as well TRITIC if uploaded
        reduced_imageBF=imageBF_aligned(XBegin:XEnd,YBegin:YEnd);
        if exist('reduced_Tritic_before','var')
            reduced_Tritic_before=reduced_Tritic_before(XBegin:XEnd,YBegin:YEnd);            
        end
        if exist('reduced_Tritic_after','var')
            reduced_Tritic_after=reduced_Tritic_after(XBegin:XEnd,YBegin:YEnd);
        end
    end
    if exist('reduced_Tritic_before','var')
        varargout{2}=reduced_Tritic_before;
    end
    if exist('reduced_Tritic_after','var')
        varargout{3}=reduced_Tritic_after;
    end
    
    % the following part has been observed to make worse the binarization.
    % Not fully understood why it was implemented in the original versions...
    %{
    question=sprintf('Performs morphological opening operation? (Recommended for heated sample)');
    if getValidAnswer(question,'',{'Yes','No'},2)
        % find the highest value in the imageBF's matrix 
        maxPixel=max(reduced_imageBF(:));
        % create a matrix with same imageBF's size and add the maxPixel value
        Im_baseShift= zeros(size(reduced_imageBF)) + maxPixel;
        % substract the new matrix with the imageBF matrix to obtain the "mould" image of brightfield
        Im_mold= Im_baseShift - reduced_imageBF;
        % define the Structuring Element. In this case it is a 50x50 matrix (each element = 1), which will be
        % used to erode and dilate the BF image
        SE=strel('square',25);
        % performs morphological opening operation on the grayscale/binary image ==> it is an erosion followed by a dilation,
        % using the same SE for both operations. Required to remove small objects from an image while preserving the s
        % hape and size of larger objects in the image. Imadjust transform the image into grayscale.
        background=imopen(imadjust(Im_mold),SE);
        % remove the morphological opening matrix from the "mould"
        I2=imadjust(Im_mold)-background;
        maxPixel=max(max(I2));
        Im_baseShift= zeros(size(reduced_imageBF)) + maxPixel;
        image2=imadjust(Im_baseShift - I2);
        clearvars Im_Neg a background I2 Im_Pos
    else
        image2=reduced_imageBF; %%%%%%% in the original version Mic_to_Binary_PCDA.m, previous section was omitted %%%%%%%%%%%
    end
    %}
    image2=reduced_imageBF; %%%%%%% in the original version Mic_to_Binary_PCDA.m, previous section was omitted %%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    closest_indices=[];
    satisfied='Manual Selection';
    first_In=true;
    no_sub_div=2000;
    [Y,E] = histcounts(image2,no_sub_div); 
    
    f1=figure;
    objInSecondMonitor(f1,idxMon);
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
            figure(imhistfig)
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
    if saveFig
        saveas(f1,sprintf('%s/tiffImages/resultA8_1_OriginalBrightField_BaselineForeground',newFolder),'tif')
        saveas(f1,sprintf('%s/figImages/resultA8_1_OriginalBrightField_BaselineForeground',newFolder))
    end
    close(f1)
    % create a Structuring Element to remove objects smaller than 2 pixels
    kernel=strel('square',2);
    binary_image=imerode(binary_image,kernel);
    binary_image=imdilate(binary_image,kernel);
    
    f2=figure('Visible','off');
    imshow(binary_image)
    text=sprintf('Definitive Binarized BrightField (Morphological Opening - kernel: square 2 pixels)');
    title(text,'FontSize',14)
    objInSecondMonitor(f2,idxMon);
    if saveFig
        saveas(f2,sprintf('%s/tiffImages/resultA8_2_DefinitiveBinarizedBrightField',newFolder),'tif')
        saveas(f2,sprintf('%s/figImages/resultA8_2_DefinitiveBinarizedBrightField',newFolder))
    else
    % for the heated sample case in which no figImages exist, so store
    % only the tiff to easy how good was the binarization
        saveas(f2,sprintf('%s/binarizedBF',newFolder),'tif')      
    end
    close(f2)  

    if flagCrop == 1
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
    
    varargout{1}=binary_image;
    varargout{4}=FurtherDetails;

end
