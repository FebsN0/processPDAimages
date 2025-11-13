% show the data with proper title and etc etc
% INPUT:    secondMonitorMain = 0 / 1
%           SeeMe = true / false
%           data1 = matrix which contains the data to show
%           norm = true / false ==> normalize the data
%           titleData1 = title to show in the plot
%           labelBar = text to show in the label (in case norm = true, the text will be just 'normalized'
%           nameFig = name of the generating file
%           varargin =      Data2 and titleData2 for a figure with two subplots
%                           Binarized = true / false
%                           closeImmediately = true / false
function fig=showData(idxMon,SeeMe,data1,norm,titleData1,labelBar,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Binarized';          defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'data2';              defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'titleData2';         defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'background';         defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'meterUnit';          defaultVal = [];      addOptional(p,argName,defaultVal);
    argName = 'scale';              defaultVal = [];      addOptional(p,argName,defaultVal);
    argName = 'saveFig';            defaultVal = true;    addOptional(p,argName,defaultVal, @(x) islogical(x));
    
    parse(p,varargin{:});
    if p.Results.Binarized,  bin=true; else, bin=false; end
    if p.Results.background, bk=true; else, bk=false; end
    if p.Results.saveFig,    saveFig=true; else, saveFig=false; end
    
    if SeeMe
        fig = figure('Visible', 'on'); 
    else
        fig = figure('Visible', 'off');
    end    
    if ~isempty(p.Results.meterUnit)
        pixmeter=p.Results.meterUnit;
    else
        pixmeter=1;
    end
    rangeScale=p.Results.scale;

    if ~isempty(p.Results.data2)
        ax1 = subplot(1,2,1,'Parent',fig);
        showSingleData(ax1,data1, norm, titleData1, labelBar,bin,bk,pixmeter,rangeScale)
        ax2 = subplot(1,2,2,'Parent',fig);
        showSingleData(ax2,p.Results.data2, norm, p.Results.titleData2,labelBar,bin,bk,pixmeter,rangeScale)
    else
        ax = axes('Parent',fig);
        showSingleData(ax,data1, norm, titleData1, labelBar,bin,bk,pixmeter,rangeScale)
    end    
    objInSecondMonitor(fig,idxMon);
    pause(2)
    if ~exist(sprintf('%s/tiffImages',nameDir),"dir") 
        mkdir(sprintf('%s/tiffImages',nameDir))
        mkdir(sprintf('%s/figImages',nameDir))
    end
    % save both fig (eventually for post modification) and tiff
    if saveFig
        fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
        saveas(fig,fullnameFig,'tiff')
        fullnameFig=fullfile(nameDir,"figImages",nameFig);
        saveas(fig,fullnameFig)
    end
    if ~SeeMe
        close(fig)
        clear fig
    end
end

function showSingleData(ax,data, norm, titleData, labelBar,bin,bk,pixelSize,rangeScale)   
    %axes(ax) % Make sure plotting happens in this axes
    % Create axis vectors. In case there is no pixel size, then use meter axis
    x = (0:size(data,2)-1)*pixelSize; 
    y = (0:size(data,1)-1)*pixelSize;
    if norm
        data=data/max(max(data));
    end
    h=imagesc(ax,x,y,data);
    if ~isempty(rangeScale)
        clim(rangeScale)
    end
    c=colorbar; c.Label.FontSize=16;
    if bk
        % make white the nan data for better visual
        set(h, 'AlphaData', ~isnan(h.CData))
    end
    if bin       
        % Apply a custom two-color colormap (e.g., blue for 0, yellow for 1)
        colormap([0 0 1; 1 1 0]);
        % colormap is binary and not gradient
        clim([0 1]);
        %c.Ticks = [0 1];
        set(c,'YTickLabel',[]);
        cLabel = ylabel(c,'Background                                     Foreground');
        cLabel.FontSize=14;        
    elseif norm
        c.Label.String = 'Normalized';
    else
        c.Label.String=labelBar;
    end
    
    colormap parula,  
    if iscell(titleData)
        title(titleData{1}, 'FontSize', 18, 'Units', 'normalized', 'Position', [0.5, 1.04, 0]); % move upward
        subtitle(titleData{2},'FontSize',13,'Units', 'normalized', 'Position', [0.5, 1.01, 0])
    else
        t = title(titleData, 'FontSize', 18);
        % Slightly move it up in data units (safe range)
        t.Units = 'normalized';
        pos = t.Position;
        pos(2) = min(pos(2) + 0.03, 1);  % Move up by 3% but stay inside [0,1]
        t.Position = pos;
    end

    if pixelSize ~= 1
        xlabel('slow direction (\mum)','FontSize',14); ylabel('fast direction (\mum)','FontSize',14);
        xticks(0:10:max(x)); yticks(0:10:max(y));
    else
        xlabel('slow direction','FontSize',14), ylabel('fast direction','FontSize',14)    
    end
    axis on, axis equal
    xlim tight, ylim tight
end
