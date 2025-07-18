function closest_indices = selectRangeGInput(n_points,dimension,x,y)
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
%   x               : x axis values 
%   y               : y axis values 
    if dimension == 2 && ~exist('y','var')
        error('The selected dimension is two, but the second input data is missing!')
    end
    % init
    closest_indices=zeros(n_points,dimension);
    % save x and y coordinates for each point
    point_selected=zeros(1,n_points);
    point_closest=zeros(1,n_points);
    for j=1:size(closest_indices,1)
        [x_selected, y_selected] = ginput(1);
        pointSelected_all(1)=x_selected;
        pointSelected_all(2)=y_selected;
        hold on
        point_selected(j)=scatter(pointSelected_all(j,1), pointSelected_all(j,2),60, 'filled', 'MarkerFaceColor', 'red','DisplayName','Selected Point');         
        if strcmpi(string(dimension),'1')
            [ ~, ix ] = min(abs(x-x_selected));
            closest_indices(j)=ix;
            point_closest(j)=xline(x(ix),'--','LineWidth',2,'Color','green','DisplayName','Closest x line');
        else
            [~, ix] = min(abs(x - x_selected));
            [~, iy] = min(abs(y - y_selected));
            closest_indices(j,1)=ix;
            closest_indices(j,2)=iy;
            point_closest(j)=scatter(x(ix),y(iy),20,'filled','MarkerFaceColor', 'green','DisplayName','Closest Point');  
        end       
   end
   pause(2)
   delete(point_selected)  
   delete(point_closest)     
end