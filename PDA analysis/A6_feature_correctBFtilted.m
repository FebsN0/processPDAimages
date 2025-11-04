function [image_of_interest] = A6_feature_correctBFtilted(image_of_interest,idxMon,pathFile)
% run the polynomial fitting on the Brightfield image since it is likely to be "tilted"
    wb=waitbar(0/1,sprintf('Correction of Tilted effects: removing Polynomial Baseline . . .'),'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);       

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
    f1=figure;
    subplot(1,2,1)
    imshow(imadjust(image_of_interest)),title('Original BF image','FontSize',14)
    subplot(1,2,2)
    imshow(imadjust(el_image)),title('Corrected BF Image','FontSize',14)
    objInSecondMonitor(f1,idxMon);
    question=sprintf('Use the Background Subtracted Image?\nIf not, it will be used the original BF data'); 
    if getValidAnswer(question,'',{'Yes','No'})        
        saveas(f1,pathFile,'tif')        
        %saveas(f1,pathFile)   
        image_of_interest=el_image;
    end
    close(f1)
end