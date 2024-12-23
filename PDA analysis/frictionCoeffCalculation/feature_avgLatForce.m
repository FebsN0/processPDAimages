function [force_fixed_avg,vert_fixed_avg,numSetpFit]=feature_avgLatForce(force,vert_avg)    
    force_fixed_avg = zeros(1, size(force,1));
    % adjust again vertical force
    % average fast line of lateral force ignoring zero values
    for i=1:size(force,1)
        tmp = force(i,:);
        force_fixed_avg(i) = mean(tmp(tmp~=0));
    end  
    % remove nan data and lines from vertical force using lateral force
    force_fixed_avg = force_fixed_avg(~isnan(force_fixed_avg));
    vert_fixed_avg = vert_avg(~isnan(force_fixed_avg));
    numSetpFit=length(unique(round(vert_fixed_avg)));
end