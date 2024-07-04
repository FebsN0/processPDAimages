function res=objInSecondMonitor(varargin)
    %%% INPUT:
    % - object to handle
    % - secondMonitor is main? Y or N
    % varargin (optional) = 'maximized'
    % Get the position and resolution of all monitors
    screens = get(0, 'MonitorPositions');
    % first request. Ask if show figures in another monitor
    if isempty(varargin)
        % Check if there is more than one monitor
        if size(screens, 1) > 1
            question= sprintf('More monitor detected!\nDo you want to show the figures into a maximized window in a second monitor?');
            options={'Yes','No'};
            if getValidAnswer(question,'',options)==1
                question= sprintf('Is the second monitor a main monitor?'); 
                res = getValidAnswer(question,'',options);
            end
        else
            res = [];
        end
    else 
        % if the second monitor is a main monitor, then put the obj in the first monitor (second row
        % screen var). varargin{1} is "res" var
        if varargin{1}==1, z=1; else, z=2; end
        % Get the position of the second monitor (not main)
        secondMonitor = screens(z, :);
        % Move the figure to the new position
        set(varargin{2}, 'Position', secondMonitor,'WindowState','maximized');
    end
