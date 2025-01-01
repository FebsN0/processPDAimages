% The feature removes portion of the AFM data which are manually considered unstable (for example, when the
% tip is not scanning anymore or it is not properly scanning. Note: to avoid fitting problems, the function
% remove ENTIRE fast scan lines in correspondence of the manually selected portion.
% INPUT:
%   rawH :                           the data from which remove the regions;
%   secondMonitorMain and filepath : useful to save the resulting figure;
%   idxPortionRemoved :              the function can be called anytime and keep track the previous usage of
%                                    this function, so this variable can be updated, otherwise will be reset.
%
% OUTPUT:
%   raw :               the data with removed portions
%   idxPortionRemoved : matrix where keep track the idx of removed regions
function [rawH,idxPortionRemoved] = A3_featureRemovePortion(rawH,secondMonitorMain,filepath,mode,idImg,idxPortionRemoved)
    f1=figure; 
    objInSecondMonitor(secondMonitorMain,f1);
    text='Not Corrected -';
    
    flagRemoval=false;
    if ~exist('idxPortionRemoved',"var")
        idxPortionRemoved=[];
    end
    while true
        figure(f1)
        imagesc(rawH*1e9)
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        colormap parula, c = colorbar; c.Label.String = 'Height [nm]'; c.Label.FontSize=15;
        title(sprintf('%s Raw Height (measured) channel',text),'FontSize',17)
        answer = questdlg('Remove lines by selecting area?','','Yes','No','No');
        if strcmp(answer,'No')
            break
        else
            hold on  
            pan on; zoom on;
            % show dialog box before continue. Select the thresholding
            uiwait(msgbox('Before click to continue the binarization, zoom or pan on the image for a better view',''));
            zoom off; pan off;
          
            title('Select area to remove every fast scan line corresponding to the selected area.','FontSize',17)
            roi=drawrectangle('Label','Removed');
            uiwait(msgbox('Click to continue'))
            hold off
            % take the coordinates along slow scan direction. Not useful extracting y coordinates because
            % entire lines will be deleted
            xstart = round(roi.Position(1));     xend = xstart+round(roi.Position(3));
            if xstart<1, xstart=1; end;     if xend<1, xend=1; end
            % save the information of which region are removed. Useful for friction calculation to avoid
            % entire area. Sometime the cantilever goes crazy. In case of normal experiment no problem because
            % the removed region is considered background, so lateral and vertical deflection data are simply
            % ignored. But in case of friction data, it may be a problem and provide false results
            % i.e. in correspondence of the PDA regions, the mask "says" they are background, therefore, the
            % lateral deflection values are actually corresponding with the PDA and not with the background            
            idxPortionRemoved=[idxPortionRemoved; xstart xend];

            % sol 1: the removed values became NaN
            % problem: during the next fitting, preparecurve function remove all NaN values so the
            % corresponding line will be empty ==> FAILURE FITTING (the error is like not possible to perform
            % fitting because there are no enough values..
            % sol to this problem: check the line before the fitting and entirely skip leaving NaN
            % new problem: when plotted, there is no right proportion so it seems that the removed region is
            % more close to BK while the true BK is higher rather than being close to zero
            %rawH(:,xstart:xend)=nan; 

            % sol 2: the removed values became the minimum value in the matrix outside the removed regions
            % problem: the values in correspondence of crystal are considered background in the background/foreground
            % separation to create the mask, so in the optimization process (A4_El_AFM_masked), the values in PDA 
            % regions will be considered because the mask "says" it is background...
            % sol to this problem: better managment in friction codes
            rawH(:,xstart:xend)=min(min(rawH(:,[1:xstart-1 xend+1:end])));

            % sol 3: remove entirely the selected regions and merge the others. Save the idx so they will be
            % used to remove also vertical and lateral deflection data
            % problem: regions will be disconnected.. but at least totally cleared data
            % true problem: in case of normal scans, the alignment of IOimage with fluorescence images will
            % fail...            
            %rawH=[rawH(:,1:xstart-1) rawH(:,xend+1:end)];

            text='Portion Removed -';
            flagRemoval=true;
        end
    end
    
    % if regions have been removed, then show and save the figure of the new data
    if flagRemoval
        axis equal, xlim([0 size(rawH,2)]), ylim([0 size(rawH,1)])
        saveas(f1,sprintf('%s\\resultA%d_%d_DefinitiveRawHeight_portionRemoved.tif',filepath,mode,idImg))
    end
    close(f1)
end