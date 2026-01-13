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
%       BF_IO of BF image
%       cropped Tritic Before (if 'TRITIC_before' has been specified)
%       cropped Tritic After (if 'TRITIC_after' has been specified)
%       FurtherDetails : details about binarisation
%       
function varargout=A4_Mic_to_Binary(imageBF_aligned,idxMon,newFolder,varargin)

    p=inputParser();
    %Add default mandatory parameters.
    addRequired(p, 'imageBF_aligned');    
    argName = 'TRITIC_before';      defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'TRITIC_after';       defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'postHeat';           defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    parse(p,imageBF_aligned,varargin{:});
    clearvars argName defaultVal

    reduced_imageBF=imageBF_aligned;
    if ~isempty(p.Results.TRITIC_before)
        reduced_Tritic_before=p.Results.TRITIC_before;
    end
    if ~isempty(p.Results.TRITIC_after)
        reduced_Tritic_after=p.Results.TRITIC_after;
    end
    textCrop="";
    % decide if crop the image. If not, leave as original size
    if ~p.Results.postHeat && getValidAnswer('The image is not cropped yet, would Like to crop the Image?', '', {'Yes','No'})
        textCrop = " and cropped";
        if ~isempty(reduced_Tritic_after)
            ftritic=figure;
            imshow(imadjust(reduced_Tritic_after))
            objInSecondMonitor(ftritic,idxMon);
            title('TRITIC AFTER','FontSize',20)
        end
        ftmp=figure;
        figure_image=imshow(imadjust(imageBF_aligned));
        title('BrightField - CROP THE IMAGE','FontSize',20)
        objInSecondMonitor(ftmp,idxMon);
        [~,specs]=imcrop(figure_image);
        close(ftmp)
        if ~isempty(reduced_Tritic_after)
            close(ftritic)
        end
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
    image=imadjust(reduced_imageBF);
    
    waitfor(warndlg(sprintf("Brightfield Image typically contains lot of noise, remove through Morphological Operations small white pixels by inverting many time the binary image.\n" + ...
        "NOTE: after binarization completation, there is manual removal tool to remove easily pixel in the background if they still persist.")))
    [BF_IO, method]=binarizeImageMain(image,idxMon,'Brightfield');
    
    titleData1={sprintf("Original (adjusted%s) Brightfield Image",textCrop);"NOTE: white light (BK) toward 1, while dark regions (FR) toward 0"};
    titleData2={"Definitive Binarized Image";sprintf("%s",method)};
    [~,~,BF_IO_corr] = featureRemovePortions(imadjust(image),titleData1,idxMon, ...
                'additionalImagesToShow',BF_IO,'additionalImagesTitleToShow',titleData2);    
    % show final mask    
    if ~isequal(BF_IO_corr,BF_IO)
        tmpText=titleData2{2};
        tmpText=sprintf("%s - manualCorrections",tmpText);
        titleData2={titleData2{1};tmpText};
    end                
    % switch 0 to 1 in case of wrong category (white BF = BK but originally toward 1)    
    ftmp=showData(idxMon,true,imadjust(image),titleData1,'','','extraData',BF_IO_corr,'extraBinary',true,'extraTitles',{titleData2},'saveFig',false);
    if ~getValidAnswer("Is the binarized image correct? If not, invert 0 → 1, 1 → 0",'',{'Y','N'})
        BF_IO_corr=~BF_IO_corr;
        close(ftmp)
        ftmp=showData(idxMon,false,imadjust(image),titleData1,'','','extraData',BF_IO_corr,'extraBinary',true,'extraTitles',{titleData2},'saveFig',false);
    end
    saveFigures_FigAndTiff(ftmp,newFolder,'resultA4_1_OriginalBrightField_BackgroundForeground')
    varargout{1}=BF_IO_corr;
end
