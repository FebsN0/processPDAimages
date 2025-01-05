% The feature removes portion of the AFM data which are manually considered unstable (for example, when the
% tip is not scanning anymore or it is not properly scanning). Such regions can negatively affects both
% regular scans used for fluorescence-force experiments and scans from which extrapolate the definitive
% background friction coefficient.
% 
% IMPORTANT: in any case (friction or regular scans), DO NOT USE MODE=2 (area removal) BEFORE A5 
% (fitting lateral/height data) to avoid fitting errors, BUT ONLY MODE=1 (entire fast scan lines removal)
% Use MODE=2 only after finishing all the fittings!
%
% NOTE: technically, the removed region will considered background because the values within the removed regions
% will be substituted with the minimum value of the entire image (not with NaN or 0 to avoid unreadable image
% by imshow/imagesc). In case of regular scans, this is not an issue at all and it not requires any further check;
% however, in case of friction coefficient calculation, it is technically wrong because the values of removed areas
% will be considered in the fitting.
% i.e. in correspondence of the PDA regions, the mask "says" they are background, therefore, the
% lateral deflection values are actually corresponding with the PDA and not with the background          
% For this reason, the code for friction coefficient calculations have additional snippets to manage this
% situation by using the variable idxPortionsRemoved in order to totally exclude such values.
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
%   dataToShow :                        data image (matrix) to show to understand where clean
%   dataToClear :                       struct (in case of more channel) or matrix (in case of single channel) of 
%                                       the image containing the AFM data 
%   idxPortionsRemoved :                 indexes of the previously removed portions. If not declared, the
%                                       function assume it is called for the first time.
%   mode :                              1 : Remove lines
%                                       2 : Remove area (AWARE: operation recommended only after finishing all
%                                           the fitting operations. I.e. after A5)
%   secondMonitorMain :                 show better
% OUTPUT:
%   dataCleaned :                   the data with removed portions
%   idxPortionsRemoved :     updated matrix where store the indexes of the removed portions (each row contains 4 elements)
%                               1) the first two indicate the x-axis/slow scan direction
%                               2) the last two indicate the y-axis/fast scan direction
%                               NOTE:   In case of the first option "Remove lines", the two last elements are NaN,
%                                           indicating to eliminate the entire fast scan lines portion. 
%                                       In case of the second option "Remove area", the 4 elements indicates 
%                                           the rectangule area to be removed
%
function [dataCleaned,dataIOCleaned,idxPortionsRemoved] = A3_featureRemovePortion(dataToClear,dataIO,secondMonitorMain,varargin)
    %init instance of inputParser
    p=inputParser();
    argname='dataToClear';                                      addRequired(p,argname, @(x) (isstruct(x) || ismatrix(x)));
    argname='dataIO';                                           addRequired(p,argname, @(x) ismatrix(x));
    argName = 'imageToShow';            defaultVal = [];        addParameter(p,argName,defaultVal, @(x) (ismatrix(x) || isempty(x)));
    argName = 'idxPortionsRemoved';     defaultVal = [];        addParameter(p,argName,defaultVal, @(x) (ismatrix(x) || isempty(x)));
    argName = 'Normalization';          defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));    
    % validate and parse the inputs
    parse(p,dataToClear,dataIO,varargin{:});
    
    % extract the data to show in the figure where select the areas to remove
    if isempty(p.Results.imageToShow)
        % take the height channel by default
        if isstruct(dataToClear)
            dataToShow=dataToClear(strcmp([dataToClear.Channel_name],'Height (measured)')).AFM_image;
            % num of data to process
        else
            dataToShow=dataToClear;
        end
    else
        dataToShow=p.Results.imageToShow;
    end
    % normalization
    norm=p.Results.Normalization;
    % manage the previous removed portions
    idxPortionsRemoved=p.Results.idxPortionsRemoved;
    dataCleaned=dataToClear;
    dataIOCleaned=dataIO;
    f1=figure;     
    text='Not Corrected'; flagFirst=true;        
    while true
        subplot(121)
        if norm
            imshow(imadjust(dataToShow/max(dataToShow(:))))
        else
            imagesc(dataToShow)
        end
        axis on, axis equal
        xlim([0 size(dataToShow,2)]), ylim([0 size(dataToShow,1)])
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        colormap parula, c = colorbar; c.Label.String = 'Height [nm]'; c.Label.FontSize=15;
        title('Raw Height (measured) channel','FontSize',17)
        subplot(122)
        imagesc(dataIOCleaned)
        axis on, axis equal
        xlim([0 size(dataToShow,2)]), ylim([0 size(dataToShow,1)])
        title('Background (blue) - Foreground (yellow)','FontSize',17)
        ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
        if flagFirst, objInSecondMonitor(secondMonitorMain,f1); flagFirst=false; end
        sgtitle(sprintf('%s images',text),'Fontsize',20,'interpreter','none')
        answer = questdlg('Remove lines by selecting area?','','Yes','No','No');
        if ~strcmp(answer,'Yes')
            break
        else
            hold on            
            sgtitle('Select the figures to remove portions','FontSize',17)
            question='Choose the removal type';
            options={'All fast scan lines - 1st figure';
                     'Rectangular area - 1st figure';
                     'All fast scan lines - 2nd figure';
                     'Rectangular area - 2nd figure'};
            answer=getValidAnswer(question,'',options);
            if answer == 1 || answer == 2
                subplot(121)
            else
                subplot(122)
            end
            if answer == 1 || answer == 3
                modeRemoval=1;
            else
                modeRemoval=2;
            end
            roi=drawrectangle('Label','Removed');
            % in case of interruption
            if isempty(roi.Position)
                break
            end
            uiwait(msgbox('Click to continue'))
            hold off
            % take the coordinates along slow scan direction.
            xstart = round(roi.Position(1));     xend = xstart+round(roi.Position(3));
            % take the coordinates along fast scan direction.
            ystart = round(roi.Position(2));       yend = ystart+round(roi.Position(4));
            % if idx are out the figure
            if xstart<1, xstart=1; end;     if xend<1, xend=1; end
            if ystart<1, ystart=1; end;     if yend<1, yend=1; end
            % depending on the removal type, store the coordinates in idxPortionsRemoved var and
            % modify the image to show in the figure           
            if modeRemoval == 1  % entire lines will be deleted
                idxPortionsRemoved=[idxPortionsRemoved; xstart xend NaN NaN]; %#ok<AGROW>
                dataToShow(:,xstart:xend)=min(min(dataToShow(:,[1:xstart-1 xend+1:end])));
                yRemove1=':'; yRemove2=':';
            else                 % selected portion will be deleted
                idxPortionsRemoved=[idxPortionsRemoved; xstart xend ystart yend]; %#ok<AGROW>                
                yRemove1='ystart:yend';
                yRemove2='[1:ystart-1 yend+1:end]';
            end
            % clean the image to show
            eval(sprintf('%s(%s,xstart:xend)=min(min(%s(%s,[1:xstart-1 xend+1:end])));','dataToShow',yRemove1,'dataToShow',yRemove2))
            eval(sprintf('%s(%s,xstart:xend)=min(min(%s(%s,[1:xstart-1 xend+1:end])));','dataIOCleaned',yRemove1,'dataIOCleaned',yRemove2))
            text='Portion Removed -';
            % clean the AFM data
            if isstruct(dataCleaned)
                for i=1:length(dataCleaned)
                    tmp=dataCleaned(i).AFM_image;
                    if modeRemoval==2
                        tmp(ystart:yend,xstart:xend)=0;
                        %min(min(tmp([1:ystart-1 yend+1:end],[1:xstart-1 xend+1:end])));
                        dataCleaned(i).AFM_image=tmp;
                    else
                        tmp(:,xstart:xend)=0;
                        dataCleaned(i).AFM_image=tmp;
                    end
                end
            else
                eval(sprintf('%s(%s,xstart:xend)=min(min(%s(%s,[1:xstart-1 xend+1:end])));','dataCleaned',yRemove1,'dataCleaned',yRemove2))
            end            
        end       
    end
    close(f1)
end

