function closest_indices = selectRangeGInput(n_points,dimension,x,y)
% n_points  : how many points will be selected
% dimension : find the closest real indexes by 1-dimensional (x or y) or
%               2-dimensional (x and y) Euclidean distances
%               if 2, also normalize x and y since they are of different
%               orders of magnitude!
% x         : example height 
% y         : example force 

    % save x and y coordinates for each point
    pointSelected_all=zeros(n_points,2);
    point_selected=zeros(1,2);   
    closest_indices = zeros(size(pointSelected_all(:,1)));
    for j=1:numel(closest_indices)
        [x_selected, y_selected] = ginput(1);
        pointSelected_all(j,1)=x_selected;
        pointSelected_all(j,2)=y_selected;
        point_selected(j)=scatter(pointSelected_all(j,1), pointSelected_all(j,2), 'filled', 'MarkerFaceColor', 'red');  
        if strcmpi(string(dimension),'1')
            distances= abs(x-pointSelected_all(j,1));
        else
        % 2D euclidean distance
        % before calculate 2D euclidean distance, normalize x, y and
        % the manually selected point
            x_norm= (x - mean(x)) / std(x);
            y_norm= (y - mean(y)) / std(y);
            px_norm = (pointSelected_all(j,1) - mean(x)) / std(x);
            py_norm = (pointSelected_all(j,2) - mean(y)) / std(y);
            distances=sqrt( (x_norm - px_norm).^2 + ...
                            (y_norm - py_norm).^2);
        end
        [ ~, ix ] = min(distances);
        closest_indices(j) = ix;
   end
   pause(0.5)
   delete(point_selected)        
end