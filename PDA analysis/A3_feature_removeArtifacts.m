function [outputArg1,outputArg2] = A3_feature_removeArtifacts(inputArg1,inputArg2)
% idee:
% - rimuovere tanti pezzi quanti si vuole. idealmente cancellare intere righe corrispondenti al rettangolo
% selezionato

 [~]=questdlg("Crop the Area","","OK","OK");
    % Crop AFM image
    % Rect = Size and position of the crop rectangle [xmin ymin width height].
    [~,~,cropped_image,Rect]=imcrop();
    close(f1)

    % Extract the data relative to the cropped area for each channel
    for i=1:size(filtData,2)
        %rotate and flip because the the crop area reference is already rotated and flipped
        temp_img=flip(rot90(filtData(i).AFM_image),2);
        size_Max_r=size(temp_img,1);
        size_Max_c=size(temp_img,2);
        end_y=round(Rect(1,1))+round(Rect(1,3));
        if(end_y>size_Max_c)
            end_y=size_Max_c;
        end
        start_y=round(Rect(1,1));
        end_x=round(Rect(1,2))+round(Rect(1,4));
        if(end_x>size_Max_r)
            end_x=size_Max_r;
        end  
        start_x=round(Rect(1,2));
        Cropped_Images(i)=struct(...
            'Channel_name', filtData(i).Channel_name,...
            'Trace_type', filtData(i).Trace_type, ...
            'Cropped_AFM_image', temp_img(start_x:end_x,start_y:end_y));
    end


end

