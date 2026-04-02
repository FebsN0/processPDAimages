function idMon=objInSecondMonitor(varargin)
%%% INPUT (not first call function. The first call is empty)
% - object to handle (window)
% - idMon = which ID monitor to put figures. Generated after first empty call function
%%% OUTPUT first call function.
% - idMon = Get the choosen ID of the monitor where to show figs from the first call
    % identify all the monitors and its position
    screens = get(0, 'MonitorPositions'); % get the position of the monitors and their size  

    % first function call, empty input. Identify monitors and choose which
    % one use for showing figures
    if isempty(varargin)
        if nargout ~= 1
            error("Output must be declared when this function is called without input!")
        end
        
        % since TASKBAR "eats" pixels, consider the effective space
        numScreens = size(screens, 1);
        usable=zeros(numScreens,4);
        for i = 1:numScreens
            % Compute the CENTER of each monitor from MonitorPositions
            % MonitorPositions: [left, bottom, width, height]  ← in pixel units
            % For rotated monitors, 'left' can be negative
            monLeft   = screens(i,1);
            monBottom = screens(i,2);
            monW      = screens(i,3);
            monH      = screens(i,4);
            
            % Place the temp figure near the CENTER of the monitor (safer than corner)
            centerX = monLeft + floor(monW / 2) - 150;   % 300/2 offset
            centerY = monBottom + floor(monH / 2) - 100;  % 200/2 offset
            
            tmp = uifigure('Visible','on', 'Units','pixels', ...
                           'Position', [centerX, centerY, 300, 200]);
            set(tmp, 'WindowState', 'maximized');
            pause(2);   % give Windows time to finish maximizing            
            usable(i,:) = get(tmp, 'Position');
            delete(tmp);
            drawnow; pause(0.1);
            
            % Use USABLE area (post-maximize) for placement
            left   = usable(i,1);
            bottom = usable(i,2);
            width  = usable(i,3);   % <-- usable width, not raw screen width
            height = usable(i,4);   % <-- usable height
            
            winWidth  = round(0.4 * width);
            winHeight = round(0.2 * height);
            
            posX = left + (width  - winWidth)  / 2;
            posY = bottom + (height - winHeight) / 2;
            
            f = uifigure('Name', ['Monitor ' num2str(i)], ...
                         'Position', [posX, posY, winWidth, winHeight], ...
                         'Visible', 'on');
            gl = uigridlayout(f, [1 1]);
            uilabel(gl, 'Text', ['This is Monitor ' num2str(i)], ...
                'FontSize', 25, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'off');
        end


            % choose where to show figures if there are more monitors
        if numScreens > 1
            question= sprintf('More monitor detected!\nIn which monitor do you want to show the maximized windows with the figures/plots?');
            options= arrayfun(@(x) {"Monitor " + string(x)}, 1:numScreens);
            idMon=getValidAnswer(question,'',options);
        else
            idMon=1;
        end
        close all force
    else
        idMon = varargin{2};
        fig=varargin{1};
        % Move the figure to the new position and maximized.
        % NOTE: In invisible state, MATLAB does not create a real window, so: it has no position, it cannot be moved to a monitor, it cannot be maximized
        monitorXfig = screens(idMon, :);
        % Move to the target monitor manually
        left   = monitorXfig(1);
        bottom = monitorXfig(2)+50; % because of bottom windows bar
        width  = monitorXfig(3);
        height = monitorXfig(4)-80; % to see the top windows (where there is close, max, min)       
        set(fig, 'Position', [left bottom width height*0.95]);
        clear idMon % Prevent output from being returned
    end
end
