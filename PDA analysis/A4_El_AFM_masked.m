function Cropped_Images_Bk=A4_El_AFM_masked(Cropped_Images,AFM_height_IO,secondMonitorMain,filepath,varargin)
%%
% The function extracts Images from the experiments.
% It removes baseline and extracts foreground from the AFM image.
% This function is different to EL_AFM_2 in a way that it uses the AFM IO
% image obtained by that to use as a mask for the background fitting, thus
% a more accurate AFM height image is gonna be yielded.
%
% [AFM_Image_with_no_Bk,Binary_AFM_Image]=El_AFM(Image_to_Elaborate)
%
%
% The function uses a series a total of three parts. One simple polinomial
% backgrownd removal, the second a buttorworth filter backgrownd algorithm
% and a final iterative backgrownd removal, in which R^2 and RMS residuals
% are used to calculate the final backgrownd contained in the image. It can
% also output a binary image if further binary elaboration is required.
%
% Author: Dr. R.D.Ortuso
% University of Geneva, Switzerland.
%
%
% Author modifications: Altieri F.
% Last update 15.July.2024
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)

    fprintf('\n\t\tSTEP 4 processing ...\n')
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types
    % and properties of inputs. This helps to make functions more robust and user-friendly.
    p=inputParser();    %init instance of inputParser
    % Add required parameter and also check if it is a struct by a inner function end if the Trace_type are all Trace
    addRequired(p, 'Cropped_Images', @(x) isstruct(x));
    argName = 'Silent';
    defaultVal = 'No';
    addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,Cropped_Images,varargin{:});
    
    clearvars argName defaultVal
    fprintf('Results of optional input:\n\tSilent:\t\t%s\n',p.Results.Silent)

    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end

    % added on 20012020: using the 0/1 height image, new fitting by excluding those information
    % which correspond to the PDA crystals. Put value 5 to exclude
    cropped_image=Cropped_Images(1).Cropped_AFM_image; 
    cropped_image_glass=cropped_image;
    cropped_image_glass(AFM_height_IO==1)=5;
    
    wb=waitbar(0/size(cropped_image,1),sprintf('Removing Polynomial Baseline %.0f of %.0f',0,size(cropped_image,1)),...
        'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);
    N_Cycluse_waitbar=size(cropped_image,2);
    
    % Polynomial baseline fitting (line by line)
    poly_filt_data=zeros(size(cropped_image,1),size(cropped_image,2));
    for i=1:size(cropped_image,2)
        waitbar(i/N_Cycluse_waitbar,wb,sprintf('Removing Polynomial Baseline ... Completed %2.1f %%',i/N_Cycluse_waitbar*100));
        
        [xData,yData] = prepareCurveData((1:size(cropped_image,1))',cropped_image_glass(:,i));
        ft = fittype( 'poly1' );
        [fitresult,~]=fit(xData,yData, ft,'Exclude', yData > 1 ); % exclude PDA crystals
         % dont use the offset p2, rather the first value of the i-th column to normalize
        xData_mod=xData-1;
        baseline_y=(fitresult.p1*xData_mod+cropped_image_glass(1,i));
        % substract the baseline_y and then substract by the minimum ==> get the 0 value in height 
        flag_poly_filt_data=cropped_image(:,i)-baseline_y;
        poly_filt_data(:,i)=flag_poly_filt_data-min(min(flag_poly_filt_data));
    end
  
    AFM_noBk=poly_filt_data;
    AFM_noBk=AFM_noBk-min(min(AFM_noBk));
    if SeeMe
        f1=figure('Visible','on');
    else
        f1=figure('Visible','off');
    end
    imshow(imadjust(AFM_noBk/max(max(AFM_noBk)))),colormap parula, title('(Optimized) Fitted Height (measured) channel', 'FontSize',16)        
    if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f1); end
    c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
    ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
    saveas(f1,sprintf('%s/resultA4_1_OptFittedHeightChannel.tif',filepath))
    
    if(exist('wb','var'))
        delete(wb)
    end

    % substitutes to the raw cropped date the Height with no BK
    Cropped_Images_Bk=Cropped_Images;
    Cropped_Images_Bk(strcmp({Cropped_Images_Bk.Channel_name},'Height (measured)')).Cropped_AFM_image=AFM_noBk;
end
    

