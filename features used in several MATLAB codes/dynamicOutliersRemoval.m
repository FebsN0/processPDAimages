function [countOutliers,cleanData]=dynamicOutliersRemoval(data)
% for each line, find iteratively outliers until there arent anymore.
% The outliers' values are changed into NaN
% INPUT:    data            =   matrix from which clean out outliers
% OUTPUt:   countOutliers   =   number of outliers
%           cleanData       =   data without outliers
    num_lines = size(data, 2);
    tmp=zeros(size(data));
    countOutliers=0;
    for i=1:num_lines
        yData = data(:, i);
        firstIt=true;
        while firstIt || any(pos_outlier)
            firstIt=false;
            [pos_outlier] = isoutlier(yData, 'gesd');
            countOutliers=countOutliers+length(find(pos_outlier));
            yData(pos_outlier) = NaN;            
        end
        tmp(:,i) = yData;
    end
    totElements=nnz(~isnan(data(:)));
    percRemoval=countOutliers/totElements*100;
    fprintf("\nResults outliers removal: %d outliers have been removed from the data (%.1f%% of total)\n",countOutliers,percRemoval)
    cleanData=tmp;
end