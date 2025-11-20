function closest_indices = selectRangeGInput(n_points,dimension,axFig)
% OUTPUT:
%   closest_indices : if dimension = 1, the output will be the index for each point on the
%                       corrisponding x axis (1 value for each point)
%                     if dimension = 2, the output will be the index for each point on the
%                       corrisponding x and y axis (2 values for each point)
% INPUTS
%   n_points        : how many points will be selected
%   dimension       : find the closest real indexes by 1-dimensional (x direction) or
%                       2-dimensional (x and y) Euclidean distances
%                       if 2, also normalize x and y since they are of different
%                       orders of magnitude!
%   axFig           : target axis where the user must click
    
    if dimension == 2 && ~exist('y','var')
        error('The selected dimension is two, but the second input data is missing!')
    end
    %--------------------------------------------------------------
    % Force the axis to be current and get the first child object
    %--------------------------------------------------------------
    axes(axFig);
    hold(axFig, 'on');
    obj = axFig.Children(1);
    %--------------------------------------------------------------
    % Determine the type of object and then extract data depending on it
    %--------------------------------------------------------------
    switch obj.Type
        case {'line','scatter'}
            % XData/YData are arrays xMin:xMax
            x = obj.XData(:);
            y = obj.YData(:);
        case 'image'
            % For images generated through imagesc and image, XData/YData usually are limits [xMin xMax]
            sz = size(obj.CData);
            x = 1:sz(2);
            y = 1:sz(1);
        case 'surface'
            % meshgrid style
            x = obj.XData(:);
            y = obj.YData(:);
        otherwise
            error('Unsupported object type: %s', obj.Type);
    end
   
    %--------------------------------------------------------------
    % Preallocate
    %--------------------------------------------------------------
    closest_indices = zeros(n_points, dimension);
    point_selected  = gobjects(1, n_points);
    point_closest   = gobjects(1, n_points);
    
    %--------------------------------------------------------------
    % Loop over user clicks
    %--------------------------------------------------------------
    for j=1:n_points
        % Force focus on the axis again (in case the user interacts elsewhere)
        axes(axFig); %#ok<LAXES>
        [x_selected, y_selected] = ginput(1);
        pointSelected_all(1)=x_selected;
        pointSelected_all(2)=y_selected;
        % mark click
        point_selected(j)=scatter(axFig,x_selected, y_selected,60, 'filled', 'MarkerFaceColor', 'red','DisplayName','Selected Point');         
        if strcmpi(string(dimension),'1')
            % Find closest x-value
            if x_selected<min(x)
                ix=1;
            elseif x_selected>max(x)
                ix=length(x);
            else
                % min distance between any point of x and x_selected
                [ ~, ix ] = min(abs(x-x_selected));
            end
            closest_indices(j)=ix;
            point_closest(j)=xline(axFig,x(ix),'--','LineWidth',2,'Color','green','DisplayName','Closest x line');
        else
            % find the closest x
            if x_selected<min(x), ix=1;
            elseif x_selected>max(x), ix=length(x);
            else, [~, ix] = min(abs(x - x_selected));
            end
            % find the closest y
            if y_selected<min(y), iy=1;
            elseif y_selected>max(y), iy=length(y);
            else, [~, iy] = min(abs(y - y_selected)); 
            end
            closest_indices(j,1)=ix;
            closest_indices(j,2)=iy;
            point_closest(j)=scatter(axFig,x(ix),y(iy),20,'filled','MarkerFaceColor', 'green','DisplayName','Closest Point');  
        end       
   end
   pause(2)
   delete(point_selected)  
   delete(point_closest)     
end