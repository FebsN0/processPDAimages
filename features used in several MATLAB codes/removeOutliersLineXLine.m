function [data_outliersRemoved,countOutliers,outlierMap]=removeOutliersLineXLine(data)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%% REMOVE OUTLIERS (remove anomalies like high spikes) %%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % this solution is more adaptive and less aggressive than removing 99.5
    % percentile. Remove outliers line by line ==> more prone to remove spikes!
    % INPUT: data to clean
    % OUTPUT:   - data_outliersRemoved  : data removed outiers
    %           - countOutliers         : numbers of outliers
    %           - outlierMap            : same size of input data. position of outliers as True 
    num_lines = size(data, 2);
    countOutliers=0;
    data_outliersRemoved=zeros(size(data));
    % track the position of the outliers
    outlierMap = false(size(data));
    for i=1:num_lines
        yData = data(:, i);
        [pos_outlier] = isoutlier(yData, 'gesd');        
        while any(pos_outlier)
            countOutliers=countOutliers+nnz(pos_outlier);
            outlierMap(:, i) = outlierMap(:, i) | pos_outlier;
            yData(pos_outlier) = NaN;
            [pos_outlier] = isoutlier(yData, 'gesd');
        end
        data_outliersRemoved(:,i)=yData;
    end
end