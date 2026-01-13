function saveFigures_FigAndTiff(fig,nameDir,nameFig,varargin)
    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addParameter(p,'closeImmediately',true,@islogical);
    parse(p,varargin{:});
    fullnameTif=fullfile(nameDir,"tiffImages",nameFig+".tif");
    fullnameFig=fullfile(nameDir,"figImages",nameFig+".fig");
    % --- Save only the content of the axes ---
    if isMatlabDarkMode()
        forceLightTheme(fig);
    end
    exportgraphics(fig,fullnameTif,'Resolution',300,'ContentType','image','Padding', 100);

    saveas(fig,fullnameFig)
    if p.Results.closeImmediately
        close(fig)
    end
end

function isDark = isMatlabDarkMode()
    bg = get(groot, 'DefaultFigureColor');
    % Dark mode uses a very dark (near black) background
    isDark = mean(bg) < 0.5;
end

function forceLightTheme(fig)
    % 1) Force figure background
    set(fig, 'Color', 'white');
    % 2) Force axes appearance (background + ticks)
    ax = findall(fig, 'Type', 'axes');
    for k = 1:numel(ax)
        ax(k).Color  = 'white';    % Axes background
        ax(k).XColor = 'black';    % Tick + axis line
        ax(k).YColor = 'black';
        ax(k).ZColor = 'black';
        % Title
        ax(k).Title.Color = 'black';
        ax(k).Subtitle.Color = 'black';
        % Labels
        ax(k).XLabel.Color = 'black';
        ax(k).YLabel.Color = 'black';
        ax(k).ZLabel.Color = 'black';
    end    
    % 3) Force **legend** text to black
    lgd = findall(fig, 'Type', 'legend');
    for k = 1:numel(lgd)
        lgd(k).TextColor = 'black';
        lgd(k).Color     = 'white';   % Legend box background
    end
    % 4) Force **colorbar** labels to black 
    cb = findall(fig, 'Type', 'colorbar');
    for k = 1:numel(cb)
        cb(k).Color = 'black';
    end
end
