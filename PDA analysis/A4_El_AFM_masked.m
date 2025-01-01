function [AFM_Images_Bk,idxRemovedPortion]=A4_El_AFM_masked(AFM_Images,AFM_height_IO,idxRemovedPortion,secondMonitorMain,filepath,varargin)
%%
% The function extracts the original Height Images from the experiments.
% It removes baseline and extracts foreground from the AFM image.
% This function is different to EL_AFM in a way that it uses the AFM IO
% image obtained by that to use as a mask for the background fitting, thus
% a more accurate AFM height image is gonna be yielded.
% 
% It is like to restart the previous operations used in A3_El_AFM, but applying the height mask before
%
% The function uses a series a total of three parts. One simple polinomial backgrownd
% removal (to remove the tilted effect), the second a buttorworth filter backgrownd 
% algorithm and a final iterative backgrownd removal, in which R^2 and RMS residuals
% are used to calculate the final backgrownd contained in the image.
% It can also output a binary image if further binary elaboration is required.
%
% Author: Dr. R.D.Ortuso
% University of Geneva, Switzerland.
%
%
% Author modifications: Altieri F.
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types
    % and properties of inputs. This helps to make functions more robust and user-friendly.
    p=inputParser();    %init instance of inputParser
    % Add required parameter and also check if it is a struct by a inner function end if the Trace_type are all Trace
    addRequired(p, 'Cropped_Images', @(x) isstruct(x));
    argName = 'Silent';     defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    
    % validate and parse the inputs
    parse(p,AFM_Images,varargin{:});
    clearvars argName defaultVal

    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end

    % using the 0/1 height image, new fitting by excluding those information
    % which correspond to the PDA crystals. Put value 5 to exclude in corrispondence
    % of crystal
    image_height=AFM_Images(1).AFM_image;
    % if portions of the height have been previously removed, then use the same idxs to remove the 
    % data from height the second time.
    if ~isempty(idxRemovedPortion)
        for i=1:length(idxRemovedPortion)
            image_height(:,idxRemovedPortion(i,1):idxRemovedPortion(i,2))=min(image_height(:));
        end
    end
    % original raw image
    image_height_glass=image_height;
    f1=figure('Visible','off'); 
    imshow(imadjust(image_height_glass/max(image_height_glass(:))));
    title('Height (measured) channel - Raw', 'FontSize',16), colormap parula
    objInSecondMonitor(secondMonitorMain,f1);
    saveas(f1,sprintf('%s\\resultA4_1_heightOriginal.tif',filepath))
    close(f1)
    
    % no create figure of the masked height because it is very close to the mask, since the max value is 5
    % wherease the background has a magnitude of nanometer
    image_height_glass(AFM_height_IO==1)=5;
   
    wb=waitbar(0/size(image_height,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(image_height,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(image_height,2);
    
    % Polynomial baseline fitting (line by line) to remove tilted effect
    poly_filt_data=zeros(size(image_height,1),size(image_height,2));
    for i=1:size(image_height,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        [xData,yData] = prepareCurveData((1:size(image_height,1))',image_height_glass(:,i));
        ft = fittype( 'poly1' );
        [fitresult,~]=fit(xData,yData, ft,'Exclude', yData > 1 ); % exclude PDA crystals
         % dont use the offset p2, rather the first value of the i-th column to normalize
        xData_mod=xData-1;
        baseline_y=(fitresult.p1*xData_mod+image_height_glass(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        flag_poly_filt_data=image_height(:,i)-baseline_y;
        poly_filt_data(:,i)=flag_poly_filt_data-min(min(flag_poly_filt_data));
    end
  
    AFM_noBk=poly_filt_data;
    AFM_noBk=AFM_noBk-min(min(AFM_noBk));

    if SeeMe
        f3=figure('Visible','on');
    else
        f3=figure('Visible','off');
    end
    imshow(imadjust(AFM_noBk/max(AFM_noBk(:)))),colormap parula,
    title('Height (measured) channel - Masked and Fitted', 'FontSize',16)        
    objInSecondMonitor(secondMonitorMain,f3);
    c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
    ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)      
    saveas(f3,sprintf('%s/resultA4_2_OptFittedHeightChannel.tif',filepath))
    if SeeMe
        uiwait(msgbox('Click to continue'))
    end
    close(f3)
    [AFM_noBk,idxRemovedPortion]=A3_featureRemovePortion(AFM_noBk,secondMonitorMain,filepath,4,4,idxRemovedPortion);

    if(exist('wb','var'))
        delete(wb)
    end

    % show the definitive height distribution
    if SeeMe
        f4=figure('Visible','on');
    else
        f4=figure('Visible','off');
    end
    histogram(AFM_noBk*1e9,100,'DisplayName','Distribution height');
    xlabel(sprintf('Feature height (nm)'),'FontSize',15)
    title('Distribution Height','FontSize',20)
    objInSecondMonitor(secondMonitorMain,f4);
    saveas(f4,sprintf('%s/resultA4_3_OptHeightDistribution.tif',filepath))
    close(f4)
    % substitutes to the raw cropped date the Height with no BK
    AFM_Images_Bk=AFM_Images;
    AFM_Images_Bk(strcmp([AFM_Images_Bk.Channel_name],'Height (measured)')).AFM_image=AFM_noBk;
end
    

