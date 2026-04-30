% Function to binarise optical BF image
% INPUT
%       BF image to be binarised
%       secondMonitorMain
%       folderResultsImg : folder where store the images
% (optional):
%       argument to specify: 'TRITIC_after' ==> upload Tritic After ==> better cropping guide
% OUTPUT:
%       BF_IO of BF image
%       cropInfo : coordinates of the cropped area (empty in case of postHeated scan)
%       
function varargout=A3_3_binarizeBF(imageBF,idxMon,folderResultsImg,varargin)
    p=inputParser();
    %Add default mandatory parameters.
    addRequired(p, 'imageBF_aligned');    
    % TRITIC after useful to understand where to crop the image before binarize. Crop is recommended to save computational time
    argName = 'TRITIC_after';       defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'postHeat';           defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    parse(p,imageBF,varargin{:});
    clearvars argName defaultVal
    postHeat=p.Results.postHeat;
    if ~isempty(p.Results.TRITIC_after)
        Tritic_after=p.Results.TRITIC_after;
    end

    % in case there are two BF images (PRE and POST), choose which one to use for binarization and all the next steps. Use AFM mask for better help
    if numel(fieldnames(imageBF))>1          
        showData(idxMon,true,imadjust(imageBF.pre),"BF-pre","","",'grayscale',true,'saveFig',false,'noLabels',true);
        showData(idxMon,true,imadjust(imageBF.post),"BF-post","","",'grayscale',true,'saveFig',false,'noLabels',true);
        % if any, find the image of AFM scan to understand how to choose
        file1="resultA2_1_PostProcessed_HeightChannel_Assembled.fig";
        file2="resultA2_1_PostProcessed_HeightChannel_Entire.fig";
        if exist(fullfile(folderResultsImg,"figImages",file1),"file")
            figtmp2=openfig(fullfile(folderResultsImg,"figImages",file1),'visible');                
            objInSecondMonitor(figtmp2,idxMon)
        elseif exist(fullfile(folderResultsImg,"figImages",file2),"file")
            figtmp2=openfig(fullfile(folderResultsImg,"figImages",file2),'visible');                
            objInSecondMonitor(figtmp2,idxMon)
        end
        if getValidAnswer("Since there are BF pre and post AFM, which Brightfield Image to take?","",{"BEFORE","AFTER"})==1
            tmp=imageBF.pre;
        else
            tmp=imageBF.post;
        end
        close all
    else
        tmp=Image_BF_PRE_aligned;
    end  
    imageBF=tmp;
    clear tmp p varargin file1 file2 figtmp2 ans
    % in case of normal scans, crop the area
    textCrop="";
    % decide if crop the image. If not, leave as original size
    if ~postHeat && getValidAnswer('The image is not cropped yet, would Like to crop the Image?', '', {'Yes','No'})
        textCrop = " and cropped";
        if ~isempty(Tritic_after)
            ftritic=figure;
            imshow(imadjust(Tritic_after))
            objInSecondMonitor(ftritic,idxMon);
            title('TRITIC AFTER','FontSize',20)
        end
        ftmp=figure;
        figure_image=imshow(imadjust(imageBF));
        title('BrightField - CROP THE IMAGE','FontSize',20)
        subtitle('Post AFM figure has been opened too, use it for a better crop','FontSize',16)
        objInSecondMonitor(ftmp,idxMon);
        [~,specs]=imcrop(figure_image);
        close(ftmp)
        if ~isempty(Tritic_after)
            close(ftritic)
        end
        % take the coordinate of the cropped area
        YBegin=round(specs(1,1));
        XBegin=round(specs(1,2));
        YEnd=round(specs(1,1))+round(specs(1,3));
        XEnd=round(specs(1,2))+round(specs(1,end));
        if(XEnd>size(imageBF,1)), XEnd=size(imageBF,1); end
        if(YEnd>size(imageBF,2)), YEnd=size(imageBF,2); end
        % extract the cropped area of BF as well TRITIC if uploaded
        reduced_imageBF=imageBF(XBegin:XEnd,YBegin:YEnd);
        cropInfo=[XBegin XEnd YBegin YEnd];
    else
        cropInfo=[];
        reduced_imageBF=imageBF;
    end 
    varargout{2}=cropInfo;
    % increase contrast to make easier binarization
    image2bin=imadjust(reduced_imageBF);
    clear XBegin XEnd YBegin YEnd ftmp ftritic figure_image specs reduced_imageBF
    % START THE BINARIZATION
    waitfor(warndlg(sprintf("Brightfield Image typically contains lot of noise, remove through Morphological Operations small white pixels by inverting many time the binary image.\n" + ...
        "NOTE: after binarization completation, there is manual removal tool to remove easily pixel in the background if they still persist.")))
    [BF_IO, method]=binarizeImageMain(image2bin,idxMon,'Brightfield');
    % plot binarized BF
    titleData1={sprintf("Original (adjusted%s) Brightfield Image",textCrop);"NOTE: black light (BK) toward 1, while white regions (FR) toward 0"};
    titleData2={"Definitive Binarized Image";sprintf("%s",method)};
    [~,~,BF_IO_corr] = featureRemovePortions(imadjust(image2bin),titleData1,idxMon, ...
                'additionalImagesToShow',BF_IO,'additionalImagesTitleToShow',titleData2);    
    % show final mask    
    if ~isequal(BF_IO_corr,BF_IO)
        tmpText=titleData2{2};
        tmpText=sprintf("%s - manualCorrections",tmpText);
        titleData2={titleData2{1};tmpText};
    end                
    % switch 0 to 1 in case of wrong category (white BF = BK but originally toward 1)    
    ftmp=showData(idxMon,true,imadjust(image2bin),titleData1,'','','extraData',BF_IO_corr,'extraBinary',true,'extraTitles',{titleData2},'saveFig',false,'grayScale',true);
    if ~getValidAnswer("Is the binarized image correct? If not, invert 0 → 1, 1 → 0",'',{'Y','N'})
        BF_IO_corr=~BF_IO_corr;
        close(ftmp)
        ftmp=showData(idxMon,false,imadjust(image2bin),titleData1,'','','extraData',BF_IO_corr,'extraBinary',true,'extraTitles',{titleData2},'saveFig',false,'grayScale',true);
    end
    saveFigures_FigAndTiff(ftmp,folderResultsImg,'resultA3_4_OriginalBrightField_BackgroundForeground')
    varargout{1}=BF_IO_corr;
end
