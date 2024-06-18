function objInSecondMonitor(h,secondMonitorMain,varargin)
    %%% INPUT:
    % - object to handle
    % - secondMonitor is main? Y or N
    % varargin (optional) = 'maximized'
    % Get the position and resolution of all monitors
    screens = get(0, 'MonitorPositions');
    % Check if there is more than one monitor
    if size(screens, 1) > 1
        if ~isempty(varargin)
            if strcmp(varargin{1},'maximized')
                set(h,'units','normalized','outerposition',[-2 0 1 1],'WindowState','maximized')
            end
        else
            % if the second monitor is a main monitor, then put the obj in the first monitor
            if strcmpi(secondMonitorMain,'y'), z=1; else, z=2; end
            % Get the position of the second monitor (not main)
            secondMonitor = screens(z, :);
            %left bottom width height
            windowObjPosition = get(h, 'Position');
            % Calculate the new position for the waitbar on the second monitor
            newPosition = [(secondMonitor(1)+3*windowObjPosition(3)), secondMonitor(2)+10, windowObjPosition(3), windowObjPosition(4)];
            % Move the waitbar to the new position
            set(h, 'Position', newPosition);
        end
    else
        disp('Only one monitor detected.');
    end
end

