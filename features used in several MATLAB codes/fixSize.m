function adjustedImage=fixSize(originalImage,offset)
    % function to shift by given offset the originalImage with proper border cutting
    if iscell(originalImage)
        adjustedImage=cell(size(originalImage));
    end
    if ~isempty(offset)
        if length(offset)==2
            offset_x=offset(1);
            offset_y=offset(2);
            [rows, cols] = size(originalImage);
            x_start = max(1, 1 + offset_x);
            y_start = max(1, 1 + offset_y);
            x_end = min(cols, cols + offset_x);
            y_end = min(rows, rows + offset_y);     
        else
            y_start=offset(1);  y_end=offset(2);
            x_start=offset(3);  x_end=offset(4);
        end
        % in case the data is cell array in which each cell contains image with same dimension
        if iscell(originalImage)
            for i=1:numel(originalImage)
                tmp=originalImage{i};
                tmp_crop=tmp(y_start:y_end,x_start:x_end); 
                adjustedImage{i}=tmp_crop;
            end
        else
            adjustedImage = originalImage(y_start:y_end, x_start:x_end);
        end
    else
        adjustedImage = originalImage;
    end
end