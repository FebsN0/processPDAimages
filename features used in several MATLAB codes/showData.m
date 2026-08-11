% show the data with proper title and etc etc
% INPUT:    idxMon      = monitor print out index
%           SeeMe       = show the figure
%           data1       = matrix which contains the data to show
%           titleData1  = title to show in the first plot
%           nameDir     = path where to save the figure
%           nameFig     = namefile
%           varargin    :
%               - saveFig       = true/false, choose if save the figure
%               - normalized    = true/false, choose if normalize the data
%               - binary        = true/false, the image is binary
%               - lenghtAxis    = two value vector representing the true (meter) size of entire image, in case of conversion from pixel index to
%               meter. Example: [metadata.TRITIC.ImageWidth_umeterXpixel*size(TRITIC_After) metadata.TRITIC.ImageHeight_umeterXpixel*size(TRITIC_After)]
%                   lenghtAxis(1) ==> AXIS Y
%                   lenghtAxis(2) ==> AXIS X
%               - labelBar      = text to printed out as lateral bar
%               - prevFig       = in case the figure should be plotted in an existing fig
%               - noLabels      = when true, no texts over axis and no label to indicate other info
%               - grayscale     = when true, show image in grascale values (white to black, for Brightfield images)
%               - Broadcast     = it requires two values which represent the min/max pixel value ==> "scale" the image. Useful to compare multiple
%                                 different images. For example, compare TRITIC exp1-scan4 with TRITIC exp4-scan2
%               - addScaleBar   = addScaleBar Draws a horizontal scale bar on the figure like a scientific paper. Provide one of the two options
%                                 -> 'true' to add standard scalebar (white, LineWidth=4)
%                                 -> {'colorID',valueLineWidth} to specify them. 
% for extra data (more figures in the main figure)
%               extraData       
%               extraNorm         
%               extraBinary
%               extraLengthAxis
%               extraTitles       
%               extraLabel  

function fig=showData(idxMon,SeeMe,data1,titleData1,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'saveFig';            defaultVal = true;  addOptional(p,argName,defaultVal, @(x) islogical(x))  
    argName = 'normalized';         defaultVal=false;   addOptional(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))))
    argName = 'binary';             defaultVal=false;   addOptional(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))))
    argName = 'lenghtAxis';         defaultVal=[];      addOptional(p,argName,defaultVal, @(x) isnumeric(x))   
    argName = 'labelBar';           defaultVal='';      addOptional(p,argName,defaultVal, @(x) (isstring(x) || ischar(x)))
    argName = 'noLabels';           defaultVal=false;   addOptional(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))))
    argName = 'grayscale';          defaultVal=false;   addOptional(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))))
    argName = 'Broadcast';          defaultVal=[];      addOptional(p,argName,defaultVal, @(x) (isnumeric(x) && isvector(x)))  
    argName = 'bigTitle';           defaultVal=[];      addOptional(p,argName,defaultVal, @(x) isstring(x))  
    % for extra data
    argName = 'extraData';          defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || ismatrix(x))
    argName = 'extraNorm';          defaultVal={};      addOptional(p,argName,defaultVal, @(x) (iscell(x) || isnumeric(x) || islogical(x)))
    argName = 'extraBinary';        defaultVal={};      addOptional(p,argName,defaultVal, @(x) (iscell(x) || isnumeric(x) || islogical(x)))    
    argName = 'extraLengthAxis';    defaultVal={};      addOptional(p,argName,defaultVal, @(x) (iscell(x) || isnumeric(x) || islogical(x)))
    argName = 'extraTitles';        defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || isstring(x))
    argName = 'extraLabel';         defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || isstring(x)) 
    % in case the fig already exist and the user just want to update the internal figures
    argName = 'prevFig';            defaultVal=[];      addOptional(p,argName,defaultVal)
    argName = 'addScaleBar';        defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || islogical(x))       
    parse(p,varargin{:});
    
    % prepare the optional inputs
    if isempty(p.Results.prevFig)
        if SeeMe, fig = figure('Visible', 'on'); else, fig = figure('Visible', 'off'); end
        flagPrevFig=false;
    else
        fig=p.Results.prevFig; flagPrevFig=true;
        if SeeMe, fig.Visible = 'on'; else, fig.Visible = 'off'; end
    end
    if p.Results.saveFig,    saveFig=true; else, saveFig=false; end
    if p.Results.normalized, norm1=true; else, norm1=false; end
    if p.Results.noLabels,   noLabs=true; else, noLabs=false; end
    if p.Results.grayscale,  grayScale=true; else, grayScale=false; end
    if p.Results.binary,     bin1=true; else, bin1=false; end
    if isempty(p.Results.addScaleBar)
        scaleBar=false;
    else
        if islogical(p.Results.addScaleBar)
            scaleBar=[];
        else
            scaleBar=p.Results.addScaleBar;
        end
    end
    % -------------------------------
    % Count number of datasets
    % -------------------------------
    if iscell(p.Results.extraData)        
        nExtra = numel(p.Results.extraData);
    elseif ~isempty(p.Results.extraData)
        nExtra = 1;        
    else
        nExtra=0;
    end       
    tl = tiledlayout(1,nExtra+1, 'TileSpacing', 'compact', 'Padding', 'loose');
    tl.OuterPosition(2) = 0;          % anchor to bottom
    tl.OuterPosition(4) = 0.99;       % leave ~2% at top for the supertitle
    if ~isempty(p.Results.bigTitle)
        annotation('textbox', [0, 0.91, 1, 0.14], ...
        'String', p.Results.bigTitle, ...
        'Color','black',...
        'FontSize', 18, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'EdgeColor', 'none');
    end
    broadcastRange=p.Results.Broadcast;
    lenghtAxis=p.Results.lenghtAxis;
    labelBar1=string(p.Results.labelBar);         
    % ---- SUBPLOT 1: main data ----
    ax = nexttile;
    showSingleData(ax,data1,norm1,titleData1,labelBar1,bin1,lenghtAxis,noLabs,grayScale,broadcastRange,scaleBar)
    % ---- SUBPLOTS for EXTRA DATA ----
    for k = 1:nExtra
        axk = nexttile;
        dataK       = getOrDefault(p.Results.extraData,k,[]);
        normK       = getOrDefault(p.Results.extraNorm,k,false); 
        binK        = getOrDefault(p.Results.extraBinary,k,false);
        sizeAxisK   = getOrDefault(p.Results.extraLengthAxis,k,[]);
        titleK      = getOrDefault(p.Results.extraTitles, k, '');
        labelK      = getOrDefault(p.Results.extraLabel,  k, '');                             
        showSingleData(axk,dataK,normK,titleK,labelK,binK,sizeAxisK,noLabs,grayScale,broadcastRange,scaleBar)
    end   
    % in case the fig is already opened, dont re-update the position. The user may have changed location for a more comfortable area
    if ~flagPrevFig
        objInSecondMonitor(fig,idxMon);
    end
    pause(1)
    % save both fig (eventually for post modification) and tiff
    if saveFig
        if ~exist(sprintf('%s/tiffImages',nameDir),"dir") 
            mkdir(sprintf('%s/tiffImages',nameDir))
            mkdir(sprintf('%s/figImages',nameDir))
        end
        if ~SeeMe
            closeImmediate=true;
        else
            closeImmediate=false;
        end
        saveFigures_FigAndTiff(fig,nameDir,nameFig,'closeImmediately',closeImmediate);        
    end
    if ~SeeMe & saveFig      
        clear fig
    end
end

function showSingleData(ax,data, norm, titleData,labelBar,bin,AxisLength,noLabels,grayScale,broadcastRange,scaleBar)   
    %axes(ax) % Make sure plotting happens in this axes
    % Create axis vectors. In case there is no pixel size, then use meter axis
    if isempty(AxisLength)
        x = 1:size(data,2);
        y = 1:size(data,1);
    else
        x=0:AxisLength(2):AxisLength(2)*size(data,2);
        y=0:AxisLength(1):AxisLength(1)*size(data,1);
        % check axis size
        [unitsX,x]=checkAxisSize(x);
        [unitsY,y]=checkAxisSize(y);        
    end
    if norm
        % save the nan location. mat2gray convert nan into 1
        nanPos=isnan(data);
        data=mat2gray(data);
        data(nanPos)=nan;
    end
    h=imagesc(ax,x,y,data);
    h.AlphaData = ~isnan(data);   % NaN → transparent
    set(ax, 'Color', 'black');    % Background color visible    
    c=colorbar; c.Label.FontSize=16;
    
    if bin       
        % Apply a custom two-color colormap (e.g., blue for 0, yellow for 1)
        colormap(ax,[0 0 1; 1 1 0]);
        % colormap is binary and not gradient
        clim(ax,[0 1]);
        %c.Ticks = [0 1];
        set(c,'YTickLabel',[]);
        cLabel = ylabel(c,'Background                                     Foreground');
        cLabel.FontSize=14;        
    else
        if grayScale
            colormap(ax, flipud(gray(256)));   % white=high, black=low (brightfield)
        else
            colormap(ax, parula(256));
        end
        if ~isempty(broadcastRange)
            clim([broadcastRange(1) broadcastRange(2)])
        end
        if norm
            c.Label.String = 'Normalized';
        else
            c.Label.String = labelBar;
        end
    end
    % --- hide colorbar and axis decorations if noLabels ---
    if noLabels
        colorbar(ax,'off');
        set(ax,'XTick',[],'YTick',[],'XTickLabel',[],'YTickLabel',[]);
        xlabel(ax,''); ylabel(ax,'');
    end

    if ~iscell(titleData)
        % in case there escape char \n, then split in more parts
        parts = strsplit(sprintf(titleData), '\n');  
    else
        parts=titleData;
    end
    if length(parts) > 1
        title(ax,parts{1}, 'FontSize', 14, 'Units', 'normalized', 'Position', [0.5, 1.045, 0],'Interpreter','none'); % move upward
        subtitleText = strjoin(parts(2:end), '\n');
        subtitle(ax,subtitleText,'FontSize',11,'Units', 'normalized', 'Position', [0.5, 1.01, 0],'Interpreter','none')
    else
        title(ax,parts{1}, 'FontSize', 17,'Units', 'normalized', 'Position', [0.5, 1.02, 0],'Interpreter','none');
    end

    if size(data,2)<size(data,1)/3
        nXtickElements=4;
    else
        nXtickElements=7;
    end
    if size(data,1)<size(data,2)/3
        nYtickElements=4;
    else
        nYtickElements=7;
    end    

    % change the axis from pixel to micrometer unit (if noLabs is true, just ignore the following block)
    if ~noLabels
        if ~isempty(AxisLength)
            xlabel(ax,sprintf('slow direction (%s)',unitsX),'FontSize',14);
            ylabel(ax,sprintf('fast direction (%s)',unitsY),'FontSize',14);       
            % create evenly spaced ticks, force last to be exact max, remove duplicates            
            adjustAxisTicks(ax,x,nXtickElements,'x');
            adjustAxisTicks(ax,y,nYtickElements,'y');
        else
            xlabel(ax,'slow direction','FontSize',14), ylabel(ax,'fast direction','FontSize',14)    
            xticks(round(linspace(min(x),max(x),nXtickElements)));
            xtickangle(0)
            yticks(round(linspace(min(x),max(y),7)));
        end
    end
    if ~isempty(AxisLength) && ~islogical(scaleBar)
        addScaleBar(ax,unitsX,scaleBar);
    end
    axis on, axis equal
    xlim tight, ylim tight
end

% Utility: safe cell/array indexing
function val = getOrDefault(array,k,defaultVal)
    if isempty(array)
        val = defaultVal;
    elseif iscell(array)
        if numel(array) >= k, val = array{k}; else, val = defaultVal; end
    elseif ismatrix(array)
    % just one matrix, like just one additional image    
        val=array;
    else
        % numeric/logical arrays
        if numel(array) >= k, val = array(k); else, val = defaultVal; end
    end
end

function [units,v]=checkAxisSize(v)
    if v(end)>=1e-6 && v(end)<1e-3
        units='\mum';          
    elseif v(end)>=1e-9 && v(end)<1e-6
        units='nm';
    else
        units='mm';
    end
    % convert x and y into proper size
    if strcmp(units,'nm')
        v=v*1e9;
    elseif strcmp(units,'\mum')
        v=v*1e6; 
    else 
        v=v*1e3; 
    end
end

function adjustAxisTicks(ax,t,nT,tax) %#ok<INUSD>
    T = linspace(0,max(t),nT);
    T(end) = max(t);        % ensure last is exact
    T = round(T,1); 
    % remove duplicates that rounding may create
    T = unique(T);                                      %#ok<NASGU> 
    eval(sprintf("%cticks(ax,T);",tax))
    eval(sprintf("%clim(ax,[min(T) max(T)]);",tax))     % ensure axis includes the final tick
    eval(sprintf("%ctickangle(ax,0)",tax))
end

function h = addScaleBar(ax,unit,parameters)
    % addScaleBar Draws a horizontal scale bar on the figure like a scientific paper
    barLength = round(diff(ax.XLim))/5;             % length barLength (in x-data units) near the lower-right corner of axes ax.
    label = sprintf('%g %s', barLength,unit);       % string shown below the bar.
    if isempty(parameters)
        opts=struct('Color','white','LineWidth',4);
    else
        opts.Color=parameters{1};
        opts.LineWidth=parameters{2};
    end
    padX = 0.05*diff(ax.XLim); padY = 0.05*diff(ax.YLim);
    xRight = ax.XLim(2) - padX;
    xLeft  = xRight - barLength;
    yPos   = ax.YLim(1) + padY;
    % place the line
    hline = line(ax, [xLeft xRight], [yPos yPos], 'Color', opts.Color, 'LineWidth', opts.LineWidth, 'Clipping','on');
    htxt  = text(ax, (xLeft+xRight)/2, yPos - 0.02*diff(ax.YLim), label, ...
                 'Color', opts.Color, 'HorizontalAlignment','center', 'VerticalAlignment','middle','FontSize',15);    
    h = [hline; htxt];       
end