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
%               - lenghtAxis    = two value vector representing the true (meter) size of entire image, in case of conversion from pixel index to meter
%                   lenghtAxis(1) ==> AXIS Y
%                   lenghtAxis(2) ==> AXIS X
%               - labelBar      = text to printed out as lateral bar
%               - prevFig       = in case the figure should be plotted in an existing fig
% for extra data
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
    argName = 'lenghtAxis';         defaultVal=[];       addOptional(p,argName,defaultVal, @(x) isnumeric(x))   
    argName = 'labelBar';           defaultVal='';      addOptional(p,argName,defaultVal, @(x) (isstring(x) || ischar(x)))
    % for extra data
    argName = 'extraData';          defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || ismatrix(x))
    argName = 'extraNorm';          defaultVal={};      addOptional(p,argName,defaultVal, @(x) (iscell(x) || isnumeric(x) || islogical(x)))
    argName = 'extraBinary';        defaultVal={};      addOptional(p,argName,defaultVal, @(x) (iscell(x) || isnumeric(x) || islogical(x)))    
    argName = 'extraLengthAxis';    defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x))
    argName = 'extraTitles';        defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || isstring(x))
    argName = 'extraLabel';         defaultVal={};      addOptional(p,argName,defaultVal, @(x) iscell(x) || isstring(x)) 
    % in case the fig already exist and the user just want to update the internal figures
    argName = 'prevFig';            defaultVal=[];      addOptional(p,argName,defaultVal)

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
    if p.Results.binary,     bin1=true; else, bin1=false; end
    lenghtAxis=p.Results.lenghtAxis;
    labelBar1=string(p.Results.labelBar);     

    % -------------------------------
    % Count number of datasets
    % -------------------------------
    if iscell(p.Results.extraData)
        nExtra = numel(p.Results.extraData);
    else
        nExtra=1;
    end
    nTotal = 1 + nExtra;   % main image + extras
    % ---- SUBPLOT 1: main data ----
    ax = subplot(1,nTotal,1,'Parent',fig);
    showSingleData(ax,data1,norm1,titleData1,labelBar1,bin1,lenghtAxis)
    % ---- SUBPLOTS for EXTRA DATA ----
    for k = 1:nExtra
        axk = subplot(1,nTotal,k+1,'Parent',fig);
        dataK       = getOrDefault(p.Results.extraData,k,[]);
        normK       = getOrDefault(p.Results.extraNorm,k,false); 
        binK        = getOrDefault(p.Results.extraBinary,k,false);
        sizeAxisK   = getOrDefault(p.Results.extraLengthAxis,k,[]);
        titleK      = getOrDefault(p.Results.extraTitles, k, '');
        labelK      = getOrDefault(p.Results.extraLabel,  k, '');                             
        showSingleData(axk,dataK,normK,titleK,labelK,binK,sizeAxisK)
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
        fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
        saveas(fig,fullnameFig,'tiff')
        fullnameFig=fullfile(nameDir,"figImages",nameFig);
        saveas(fig,fullnameFig)
    end
    if ~SeeMe && saveFig
        close(fig)
        clear fig
    end
end

function showSingleData(ax,data, norm, titleData,labelBar,bin,AxisLength)   
    %axes(ax) % Make sure plotting happens in this axes
    % Create axis vectors. In case there is no pixel size, then use meter axis
    if isempty(AxisLength)
        x = 1:size(data,2);
        y = 1:size(data,1);
    else
        x=linspace(0,AxisLength(2),size(data,2));
        y=linspace(0,AxisLength(1),size(data,1));

        % check axis size
        if all(AxisLength>=1e-6) && all(AxisLength<1e-3)
            unitsX='\mum'; unitsY='\mum';            
        elseif all(AxisLength>=1e-9) && all(AxisLength<1e-6)
            unitsX='nm'; unitsY='nm';
        else
            if AxisLength(1)>=1e-9 && AxisLength(1)<1e-6, unitsY='nm'; else, unitsY='\\mum'; end
            if AxisLength(2)>=1e-9 && AxisLength(2)<1e-6, unitsX='nm'; else, unitsX='\\mum'; end
        end
        % convert x and y into proper size
        if strcmp(unitsX,'nm'), x=x*1e9; else, x=x*1e6; end
        if strcmp(unitsY,'nm'), y=y*1e9; else, y=y*1e6; end
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
        colormap(ax, parula(256));
        if norm
            c.Label.String = 'Normalized';
        else
            c.Label.String=labelBar;
        end
    end
    
    if ~iscell(titleData)
        % in case there escape char \n, then split in more parts
        parts = strsplit(sprintf(titleData), '\n');  
    else
        parts=titleData;
    end
    if length(parts) > 1
        title(parts{1}, 'FontSize', 15, 'Units', 'normalized', 'Position', [0.5, 1.04, 0]); % move upward
        subtitle(parts{2},'FontSize',12,'Units', 'normalized', 'Position', [0.5, 1.01, 0])
    else
        title(parts{1}, 'FontSize', 17,'Units', 'normalized', 'Position', [0.5, 1.02, 0]);
    end
    % change the axis from pixel to micrometer unit
    if ~isempty(AxisLength)
        xlabel(sprintf('slow direction (%s)',unitsX),'FontSize',14);
        ylabel(sprintf('fast direction (%s)',unitsY),'FontSize',14);
        xticks(round(linspace(0,max(x),11)));
        yticks(round(linspace(0,max(y),11)));
    else
        xlabel('slow direction','FontSize',14), ylabel('fast direction','FontSize',14)    
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