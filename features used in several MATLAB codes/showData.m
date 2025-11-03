% show the data with proper title and etc etc
% INPUT:    secondMonitorMain = 0 / 1
%           SeeMe = true / false
%           i = number of the plot for the correct image file enumeration (if there are many plots in the same function which call this function)
%           data1 = matrix which contains the data to show
%           norm = true / false ==> normalize the data
%           titleData1 = title to show in the plot
%           labelBar = text to show in the label (in case norm = true, the text will be just 'normalized'
%           nameFig = name of the generating file
%           varargin =      Data2 and titleData2 for a figure with two subplots
%                           Binarized = true / false
%                           closeImmediately = true / false
function showData(idxMon,SeeMe,i,data1,norm,titleData1,labelBar,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'Binarized';          defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'data2';              defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'titleData2';         defaultVal = [];      addOptional(p,argName,defaultVal)
    argName = 'background';         defaultVal = false;   addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'meterUnit';          defaultVal = [];      addOptional(p,argName,defaultVal);
    argName = 'scale';              defaultVal = [];      addOptional(p,argName,defaultVal);

    parse(p,varargin{:});
    if p.Results.Binarized, bin=true; else, bin=false; end
    if p.Results.background, bk=true; else, bk=false; end
    
    if SeeMe
        eval(sprintf('f%d=figure(''Visible'',''on'');',i)) 
    else
        eval(sprintf('f%d=figure(''Visible'',''off'');',i)) 
    end   
    if ~isempty(p.Results.meterUnit)
        pixmeter=p.Results.meterUnit;
    else
        pixmeter=1;
    end
    rangeScale=p.Results.scale;

    if ~isempty(p.Results.data2)
        subplot(121)
        showSingleData(data1, norm, titleData1, labelBar,bin,bk,pixmeter,rangeScale)       
        subplot(122)
        showSingleData(p.Results.data2, norm, p.Results.titleData2, labelBar,bin,bk,pixmeter,rangeScale)
    else
        showSingleData(data1, norm, titleData1, labelBar,bin,bk,pixmeter,rangeScale)
    end    
    objInSecondMonitor(eval(sprintf('f%d',i)),idxMon);
    
    if ~exist(sprintf('%s/tiffImages',nameDir),"dir") 
        mkdir(sprintf('%s/tiffImages',nameDir))
        mkdir(sprintf('%s/figImages',nameDir))
    end
    % save both fig (eventually for post modification) and tiff
    fullnameFig=fullfile(nameDir,"tiffImages",nameFig);
    saveas(eval(sprintf('f%d',i)),fullnameFig,'tiff')
    fullnameFig=fullfile(nameDir,"figImages",nameFig);
    saveas(eval(sprintf('f%d',i)),fullnameFig)
    if ~SeeMe
        eval(sprintf('close(f%d)',i))
    end
end

function showSingleData(data, norm, titleData, labelBar,bin,bk,pixelSize,rangeScale)   
    % Create axis vectors. In case there is no pixel size, then use meter axis
    x = (0:size(data,2)-1)*pixelSize; 
    y = (0:size(data,1)-1)*pixelSize;
    if norm
        data=data/max(max(data));
    end
    h=imagesc(x,y,data);
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
    title(titleData,'FontSize',16),
    if pixelSize ~= 1
        xlabel('slow direction (\mum)','FontSize',14); ylabel('fast direction (\mum)','FontSize',14);
        xticks(0:10:max(x)); yticks(0:10:max(y));
    else
        xlabel('slow direction','FontSize',14), ylabel('fast direction','FontSize',14)    
    end
    axis on, axis equal
    xlim tight, ylim tight
end
