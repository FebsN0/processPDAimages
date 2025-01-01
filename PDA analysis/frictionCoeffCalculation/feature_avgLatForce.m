% the function remove zeros values for the given fast scan line and then average
% INPUT: the data as entire matric with both fast and slow scan lines
function [x_avg_clear,y_avg_clear]=feature_avgLatForce(x,y)    
    % init
    x_avg = zeros(1, size(x,2));
    y_avg = zeros(1, size(y,2));
    % average fast line of lateral force ignoring zero values
    for i=1:size(x,2)
        tmp1 = x(:,i);
        tmp2 = y(:,i);
        x_avg(i) = mean(tmp1(tmp1~=0));
        y_avg(i) = mean(tmp2(tmp2~=0));        
    end
    % in case entire fast scan line is 0, the resulting averaged element will be NaN. Therefore, remove them
    y_avg_clear=y_avg(~isnan(y_avg));
    x_avg_clear=x_avg(~isnan(y_avg));
end