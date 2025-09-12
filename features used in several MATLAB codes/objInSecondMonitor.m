function idMon=objInSecondMonitor(varargin)
    %%% INPUT (not first call function. The first call is empty)
    % - object to handle (window)
    % - idMon = which ID monitor to put figures. Generated after first empty call function
    %%% OUTPUT first call function.
    % - Get the choosen ID of the monitor where to show figs
    
    % identify all the monitors
    screens = get(0, 'MonitorPositions'); % get the position of the monitors and their size  

    % first function call, empty input. Identify monitors and choose which
    % one use for showing figures
    if isempty(varargin)
        if nargout ~= 1
            error("Output must be declared when this function is called without input!")
        end
        numScreens = size(screens, 1);
        for i = 1:numScreens    
        % Extract screen position and size
            left   = screens(i, 1);       bottom = screens(i, 2);
            width  = screens(i, 3);       height = screens(i, 4);
        % Define proportional window size (20% of screen size) to identify them
            winWidth  = round(0.2 * width);
            winHeight = round(0.2 * height);    
         % Center the window on the screen
            winLeft   = left + round((width - winWidth) / 2);
            winBottom = bottom + round((height - winHeight) / 2);
        % Create the small windows and put at the center showing which
        % monitor they correspond
            figure('Name', ['Monitor ' num2str(i)], 'NumberTitle', 'off',...
                'Position', [winLeft, winBottom, winWidth, winHeight]);
            uicontrol('Style', 'text', 'String', ['This is Monitor ' num2str(i)], ...
                       'FontSize', 14, 'Units', 'normalized', ...
                       'Position', [0.2 0.4 0.6 0.2]);
        end
        % choose where to show figures if there are more monitors
        if numScreens > 1
            question= sprintf('More monitor detected!\nIn which monitor do you want to show the maximized windows with the figures/plots?');
            options= arrayfun(@(x) {"Monitor " + string(x)}, 1:numScreens);
            idMon=getValidAnswer(question,'',options);
        else
            idMon=1;
        end
        close all
    else
        idMon = varargin{2};
        monitorXfig = screens(idMon, :);
        % Move the figure to the new position and maximized
        set(varargin{1},'WindowState','maximized','Position', monitorXfig);
        clear idMon % Prevent output from being returned
    end
end
