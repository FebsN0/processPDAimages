% The feature removes portion of the AFM data which are manually considered unstable (for example, when the
% tip is not scanning anymore or it is not properly scanning). Such regions can negatively affects both
% regular scans used for fluorescence-force experiments and scans from which extrapolate the definitive
% background friction coefficient.
% 
% IMPORTANT: in any case (friction or regular scans), DO NOT REMOVE PORTIONS BY POLYGONS OR RECT BEFORE A5 
% (fitting lateral/height data) to avoid fitting errors, BUT ONLY PORTIONS BY LINE (entire fast scan lines removal)
%
% NOTE: technically, the removed region will considered background because the values within the removed regions
% will be substituted with the minimum value of the entire image (not with NaN or 0 to avoid unreadable image
% by imshow/imagesc). In case of regular scans, this is not an issue at all and it not requires any further check;
% however, in case of friction coefficient calculation, it is technically wrong because the values of removed areas
% will be considered in the fitting.
% i.e. in correspondence of the PDA regions, the mask "says" they are background, therefore, the
% lateral deflection values are actually corresponding with the PDA and not with the background          
% For this reason, the code for friction coefficient calculations have additional snippets to manage this
% situation by using the variable maskRemoval in order to totally exclude such values.
%
% several approaches to remove data has been explore and each showed a problem
% sol 1: the removed values became NaN
% problem: during the next fitting, preparecurve function remove all NaN values so the
% corresponding line will be empty ==> FAILURE FITTING (the error is like not possible to perform
% fitting because there are no enough values..
% sol to this problem: check the line before the fitting and entirely skip leaving NaN
% new problem: when plotted, there is no right proportion so it seems that the removed region is
% more close to BK while the true BK is higher rather than being close to zero
% data(:,xstart:xend)=nan; 

% sol 2 (USED): the removed values became the minimum value in the matrix outside the removed regions
% problem: the values in correspondence of crystal are considered background in the background/foreground
% separation to create the mask, so in the optimization process (A4_El_AFM_masked), the values in PDA 
% regions will be considered because the mask "says" it is background...
% sol to this problem: better managment in friction codes. Not an issue in case of regular scans
% data(:,xstart:xend)=min(min(data(:,[1:xstart-1 xend+1:end])))
%
% sol 3: remove entirely the selected regions and merge the others. Save the idx so they will be
% used to remove also vertical and lateral deflection data
% problem: regions will be disconnected.. but at least totally cleared data
% true problem: in case of normal scans, the alignment of IOimage with fluorescence images will
% fail...            
% data=[data(:,1:xstart-1) data(:,xend+1:end)];
%
%
% INPUT:
%   dataToShow :            data image (matrix) to show to understand where clean
%   dataToClear :           struct (in case of more channel) or matrix (in case of single channel) of the image containing the AFM data
%   dataIO  :               previous binarized AFM height image
%   maskPrev :              mask containing the already removed portions. If the function is called for the first time, it will be empty matrix
%   secondMonitorMain :     show better

% OUTPUT:
%   dataCleaned :           updated struct (in case of more channel) or matrix (in case of single channel)
%   dataIOCleaned :         updated binarized AFM height image
%   maskRemoval :              updated mask containing the removed portions
%                              
function [dataCleaned,dataIOCleaned,maskRemoval] = featureRemovePortions(dataToClear,dataIO,idxMon,varargin)
    %init instance of inputParser
    p=inputParser();
    % Required arguments
    addRequired(p, 'dataToClear', @(x) (isstruct(x) || ismatrix(x)));
    addRequired(p, 'dataIO', @(x) ismatrix(x));
    addRequired(p, 'secondMonitorMain', @(x) islogical(x) || isnumeric(x));
    % Optional parameters
    addParameter(p, 'imageToShow', [], @(x) (ismatrix(x) || isempty(x)));
    addParameter(p, 'maskRemoval', [], @(x) (ismatrix(x) || isempty(x)));
    addParameter(p, 'Normalization', false, @(x) islogical(x));   
    % validate and parse the inputs
    parse(p, dataToClear, dataIO, idxMon, varargin{:});                                                                     
    % extract the data to show in the figure where select the areas to remove
    if isempty(p.Results.imageToShow)
        % by default take the height channel in case of struct
        if isstruct(dataToClear)
            channel='Height (measured)';
            matchIdx = strcmp([dataToClear.Channel_name],channel) & strcmp([dataToClear.Trace_type],'Trace');
            dataToShow1=dataToClear(matchIdx).AFM_image; 
            flagSingleImageShow=false;            
        else
            dataToShow1=dataToClear;   
            flagSingleImageShow=true;
        end
    else
        dataToShow1=p.Results.imageToShow;
        flagSingleImageShow=true;
    end

    if flagSingleImageShow
        options={'Height (measured)','Lateral Deflection','Vertical Deflection'};
        question='What channel is the given ''imageToShow'' or the single matrix ''dataToClear''?';
        answer=getValidAnswer(question,'',options);
        channel=options{answer};
    end
    % check if the mask has the same size of the data. The mask represents the already removed regions
    maskRemoval=p.Results.maskRemoval;
    if ~isempty(maskRemoval) && size(maskRemoval)~=size(dataToShow1)
        error('The given existing mask has not the same size of the given data. Make sure it is the right mask!')
    end
    % normalization
    norm=p.Results.Normalization;
    dataCleaned=dataToClear;
    dataIOCleaned=dataIO;
    f1=figure;     
    text='Not Corrected'; flagFirst=true;        
    while true
        subplot(121)
        if strcmp(channel,'Height (measured)')
            textBar='Height [nm]';
            multiplier=1e9;
        else
            textBar='Voltage [V]';
            multiplier=1;
        end
        if norm
            imshow(imadjust(dataToShow1/max(dataToShow1(:))))
        else
            imagesc(dataToShow1*multiplier)
        end        
        axis on, axis equal
        xlim([0 size(dataToShow1,2)]), ylim([0 size(dataToShow1,1)])
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        colormap parula, c = colorbar; c.Label.String = textBar; c.Label.FontSize=15;
        title(sprintf('%s channel',channel),'FontSize',17)
        subplot(122)
        imagesc(dataIOCleaned)
        axis on, axis equal
        xlim([0 size(dataIOCleaned,2)]), ylim([0 size(dataIOCleaned,1)])
        title('Background (blue) - Foreground (yellow)','FontSize',17)
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        if flagFirst, objInSecondMonitor(f1,idxMon); flagFirst=false; end
        sgtitle(sprintf('%s images',text),'Fontsize',20,'interpreter','none')
        question = 'Remove lines or portions?';
        if ~flagSingleImageShow
            options = {'Yes','No','Change into height channel for the 1st figure','Change into lateral deflection channel for the 1st figure'};
        else
            options = {'Yes','No'};
        end
        answer=getValidAnswer(question,'',options,2);
        if answer==2 || answer == false
            break
        elseif answer==3
            channel='Height (measured)';
            matchIdx = strcmp([dataCleaned.Channel_name],channel) & strcmp([dataCleaned.Trace_type],'Trace');
            dataToShow1=dataCleaned(matchIdx).AFM_image; 
        elseif answer==4
            channel='Lateral Deflection';
            matchIdx = strcmp([dataCleaned.Channel_name],channel) & strcmp([dataCleaned.Trace_type],'Trace');
            dataToShow1=dataCleaned(matchIdx).AFM_image; 
        elseif answer == 1 || answer == true
            hold on            
            sgtitle('Select the figures to remove portions. Double click on the selection to terminate','FontSize',17)
            question='Choose the removal type';
            options={'All fast scan lines - 1st figure';
                     'Rectangle area - 1st figure';
                     'Polygon area - 1st figure';
                     'All fast scan lines - 2nd figure';
                     'Rectangle area - 2nd figure';
                     'Polygon area - 2st figure'};
            answer=getValidAnswer(question,'',options);
            if answer == 1 || answer == 2 || answer == 3
                subplot(121)
            else
                subplot(122)
            end
            if answer == 1 || answer == 4
                modeRemoval='line';
                roi=drawline('Color','red');
                pos = round(customWait(roi));
                removedElementLine=[pos(1,1) pos(2,1)];
            elseif answer == 2 || answer == 5
                modeRemoval='rect';
                roi=drawrectangle('Color','red');
                pos = round(customWait(roi));
                % take the coordinates along slow scan direction.
                xstart = pos(1);     xend = xstart+pos(3);
                % take the coordinates along fast scan direction.
                ystart = pos(2);     yend = ystart+pos(4);            
                removedElementLine=[xstart ystart xstart yend xend yend xend ystart];
            else
                modeRemoval='polygon';
                roi=drawpolygon('Color','red');
                pos = customWait(roi);
                removedElementLine=round(reshape(pos',[1 size(pos,1)*2]));
            end            
            % in case of interruption
            if isempty(roi.Position)
                break
            end
            hold off           
            % manage the coordinates to create the mask depending on the choosen removal method
            [rows, cols] = size(dataToShow1);
            if ~strcmp(modeRemoval,'line')
                xCoords = removedElementLine(1:2:end);
                yCoords = removedElementLine(2:2:end);            
            else
                removedElementLine=sort(removedElementLine);
                yCoords=[0 0 size(dataToShow1,1) size(dataToShow1,1) ];
                xCoords=[removedElementLine(1) removedElementLine(2) removedElementLine(2) removedElementLine(1)];
            end
            % create the mask polygon
            mask = poly2mask(xCoords, yCoords, rows, cols);
            % find the min value outside the polygon
            externalValues = dataToShow1(~mask);
            minValueOutside = min(externalValues(:));
            % clean the image to show
            dataToShow1(mask) = minValueOutside;
            dataIOCleaned(mask)=0;
            % update the mask containing the removed elements
            if ~isempty(maskRemoval)
                maskRemoval= maskRemoval | mask;
            else
                maskRemoval=mask;
            end            
            text='Portion Removed -';
            %clean the AFM data
            if isstruct(dataCleaned)
                for i=1:length(dataCleaned)
                    tmp=dataCleaned(i).AFM_image;
                    tmp(mask)=0;
                    dataCleaned(i).AFM_image=tmp;
                end
            else
                dataCleaned(mask)=0;
            end            
        end       
    end
    close(f1)
end

% Function to wait until completion by clicking twice. Return final pos array
function pos = customWait(hROI)
    % Listen for mouse clicks on the ROI
    l = addlistener(hROI,'ROIClicked',@clickCallback);    
    % Block program execution
    uiwait;    
    % Remove listener
    delete(l);    
    % Return the current position
    pos = hROI.Position;
end

function clickCallback(~,evt)
    if strcmp(evt.SelectionType,'double')
        uiresume;
    end
end