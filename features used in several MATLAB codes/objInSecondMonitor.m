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
        for i=1:numScreens
            % Create an invisible temporary figure to detect usable area
            tmp = uifigure('Visible','off','Units','pixels',...
                         'Position',[screens(i,1)+10 screens(i,2)+10 300 200]);
            drawnow;
            % Maximize it
            set(tmp,'WindowState','maximized');
            drawnow;
            usable(i,:) = get(tmp,'Position');  % usable area inside that monitor
            delete(tmp);
        
            % Extract screen position and size
            left   = usable(i,1);      bottom = usable(i,2);
            width  = screens(i,3);   height = screens(i,4);
            % Define proportional window size (20% of screen size) to identify them
            winWidth  = round(0.4 * width);
            winHeight = round(0.2 * height);    
             % Locate the window on the screen at 10% of the left-bottom corner
            relativeXpositionXCenterScreen= left+width*0.5-winWidth/2 ;
            relativeYpositionXCenterScreen= bottom+height*0.5-winHeight/2;
            % Create the small windows and put at the center showing which
            % monitor they correspond
            f=uifigure('Name', ['Monitor ' num2str(i)], 'NumberTitle', 'off',...
                'Position', [relativeXpositionXCenterScreen, relativeYpositionXCenterScreen, winWidth, winHeight],'Visible','on');
            gl = uigridlayout(f, [1 1]);
            uilabel(gl,'Text',  ['This is Monitor ' num2str(i)], ...
                'FontSize', 25, ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'center', ...
                'WordWrap', 'off'); % no text wrapping    
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
