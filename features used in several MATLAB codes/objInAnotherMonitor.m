function idMon=objInAnotherMonitor(varargin)
%%% INPUT (not first call function. The first call is empty)
% - object to handle (window)
% - idMon = which ID monitor to put figures. Generated after first empty call function
%%% OUTPUT first call function.
% - idMon = Get the choosen ID of the monitor where to show figs from the first call
    
    % Get all screen devices (monitors)
    ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    gs = ge.getScreenDevices();
    numMon = length(gs);
    monitorBounds = cell(numMon,1);
    for k = 1:numMon
        % Each monitor has a configuration that contains its bounds
        cfg = gs(k).getDefaultConfiguration();
        b = cfg.getBounds();        
        monitorBounds{k} = struct( ...
            'X',b.getX(),...
            'Y', b.getY(), ...
            'Width',  b.getWidth(), ...
            'Height', b.getHeight());
    end

    % The root origin (bottom-left of the primary monitor)
    primaryOrigin = monitorBounds{end};   % MATLAB puts the *primary* monitor last

    % first function call, empty input. Identify monitors and choose which
    % one use for showing figures
    if isempty(varargin)
        if nargout ~= 1
            error("Output must be declared when this function is called without input!")
        end
        numScreens = length(monitorBounds);
        for i = 1:numScreens    
        % Extract screen position and size
            left   = monitorBounds{i}.X;       bottom = monitorBounds{i}.Y;
            width  = monitorBounds{i}.Width;   height = monitorBounds{i}.Height;
            
            % Define proportional window size (20% of screen size) to identify them
            winWidth  = round(0.2 * width);
            winHeight = round(0.2 * height);    
         % Center the window on the screen

            relativeXpositionXCenterScreen= left+width/2 - winWidth/2 ;
            relativeYpositionXCenterScreen= bottom+height/2 - winHeight/2;
            
           

            tmp_wind=figure('Name', ['Monitor ' num2str(i)], 'NumberTitle', 'off',...
                'Position', [ relativeXpositionXCenterScreen, relativeYpositionXCenterScreen, winWidth, winHeight]);          
    
            winBottom = bottom - primaryOrigin(2) + round((height - winHeight) / 2);
        
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
        fig=varargin{1};
        % full screen size, included taskbar
        selectedMon=monitorBounds{idMon};       
        left   = selectedMon.X;
        bottom = selectedMon.Y;
        width  = selectedMon.Width;
        height = selectedMon.Height;
        % extract size of task bar
        usable = ge.getMaximumWindowBounds();
        taskbarHeight = height - usable.getHeight();
        taskbarWidth  = width  - usable.getWidth();
        % Move to the target monitor manually
        set(fig, 'Position', [left+taskbarWidth bottom+taskbarHeight width-taskbarWidth height-taskbarHeight]);
        clear idMon % Prevent output from being returned
    end
end
