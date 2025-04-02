% Script for the heat normalisation of TRITC fluorescence images
% The script yields the fluorescence intensity of the heated PDA sample,
% averaged from 3 different images of the same sample (AVG_Avg_3_images).
% This value should be used later on to normalise the processed!
% fluorescent images so that different measurements (and PDA) can be
% compared.

questdlg('Select location for TRITIC 1 Data','TBF data location','OK','OK');
        [afm_file_name,AFM_file_path,afm_file_index]=uigetfile('Choose BF File');
    TRITIC_Before_File_Path=sprintf('%c%c',AFM_file_path,afm_file_name);
    
    [Tritic_Mic_Image_1]=open_ND2(TRITIC_Before_File_Path);
figure,imshow(imadjust(Tritic_Mic_Image_1))


[binary_image_1,Tritic_Mic_Image_1_cropped,FurtherDetails1]=Mic_to_Binary_TRITC(Tritic_Mic_Image_1,'Silent','No');
Tritic_Mic_Image_1_cropped_masked=Tritic_Mic_Image_1_cropped;
Tritic_Mic_Image_1_cropped_masked(binary_image_1==0)=nan;

Tritic_Mic_Image_1_cropped_masked_glass=Tritic_Mic_Image_1_cropped;
Tritic_Mic_Image_1_cropped_masked_glass(binary_image_1==1)=nan;
Tritic_Mic_Image_1_cropped__glass_min=nanmin(nanmin(Tritic_Mic_Image_1_cropped_masked_glass));

Tritic_Mic_Image_1_cropped_masked_bgsub=minus(Tritic_Mic_Image_1_cropped_masked,Tritic_Mic_Image_1_cropped__glass_min);
Tritic_Mic_Image_1_cropped_bgsub_average=nanmean(nanmean(Tritic_Mic_Image_1_cropped_masked_bgsub));
figure,imagesc(Tritic_Mic_Image_1_cropped_masked_bgsub)


questdlg('Select location for TRITIC 2 Data','TBF data location','OK','OK');
        [afm_file_name2,AFM_file_path2,afm_file_index2]=uigetfile('Choose BF File');
    TRITIC_Before_File_Path2=sprintf('%c%c',AFM_file_path2,afm_file_name2);
    
    [Tritic_Mic_Image_2]=open_ND2(TRITIC_Before_File_Path2);
figure,imshow(imadjust(Tritic_Mic_Image_2))


[binary_image_2,Tritic_Mic_Image_2_cropped,FurtherDetails2]=Mic_to_Binary_TRITC(Tritic_Mic_Image_2,'Silent','No');
Tritic_Mic_Image_2_cropped_masked=Tritic_Mic_Image_2_cropped;
Tritic_Mic_Image_2_cropped_masked(binary_image_2==0)=nan;

Tritic_Mic_Image_2_cropped_masked_glass=Tritic_Mic_Image_2_cropped;
Tritic_Mic_Image_2_cropped_masked_glass(binary_image_2==1)=nan;
Tritic_Mic_Image_2_cropped__glass_min=nanmin(nanmin(Tritic_Mic_Image_2_cropped_masked_glass));

Tritic_Mic_Image_2_cropped_masked_bgsub=minus(Tritic_Mic_Image_2_cropped_masked,Tritic_Mic_Image_2_cropped__glass_min);
Tritic_Mic_Image_2_cropped_bgsub_average=nanmean(nanmean(Tritic_Mic_Image_2_cropped_masked_bgsub));
figure,imagesc(Tritic_Mic_Image_2_cropped_masked_bgsub)



questdlg('Select location for TRITIC 3 Data','TBF data location','OK','OK');
        [afm_file_name3,AFM_file_path3,afm_file_index3]=uigetfile('Choose BF File');
    TRITIC_Before_File_Path3=sprintf('%c%c',AFM_file_path3,afm_file_name3);
    
    [Tritic_Mic_Image_3]=open_ND2(TRITIC_Before_File_Path3);
figure,imshow(imadjust(Tritic_Mic_Image_3))

[binary_image_3,Tritic_Mic_Image_3_cropped,FurtherDetails3]=Mic_to_Binary_TRITC(Tritic_Mic_Image_3,'Silent','No');
Tritic_Mic_Image_3_cropped_masked=Tritic_Mic_Image_3_cropped;
Tritic_Mic_Image_3_cropped_masked(binary_image_3==0)=nan;

Tritic_Mic_Image_3_cropped_masked_glass=Tritic_Mic_Image_3_cropped;
Tritic_Mic_Image_3_cropped_masked_glass(binary_image_3==1)=nan;
Tritic_Mic_Image_3_cropped__glass_min=nanmin(nanmin(Tritic_Mic_Image_3_cropped_masked_glass));

Tritic_Mic_Image_3_cropped_masked_bgsub=minus(Tritic_Mic_Image_3_cropped_masked,Tritic_Mic_Image_3_cropped__glass_min);
Tritic_Mic_Image_3_cropped_bgsub_average=nanmean(nanmean(Tritic_Mic_Image_3_cropped_masked_bgsub));
figure,imagesc(Tritic_Mic_Image_3_cropped_masked_bgsub)

Avg_3_images=zeros(1,3);
Avg_3_images(1,1)=Tritic_Mic_Image_1_cropped_bgsub_average;
Avg_3_images(1,2)=Tritic_Mic_Image_2_cropped_bgsub_average;
Avg_3_images(1,3)=Tritic_Mic_Image_3_cropped_bgsub_average;

AVG_Avg_3_images=mean(Avg_3_images);










