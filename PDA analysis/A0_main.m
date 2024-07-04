clc, clear, close

[fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image');
if isequal(fileName,0)
    error('No File Selected');
end
% save the useful figures into a directory
newFolder = fullfile(filePathData, 'Results Processing AFM and fluorescence images');
% check if dir already exists
if exist(newFolder, 'dir')
    question= sprintf('Directory already exists and it may already contain results.\nDo you want to overwrite it?');
    options= {'Yes','No'};
    if getValidAnswer(question,'',options) == 1
        rmdir(newFolder, 's');
        mkdir(newFolder);
    end
else
    mkdir(newFolder);
end

secondMonitorMain=objInSecondMonitor;

clear question
% open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
% calculates alpha, based on the pub), it returns the location of the file.
[data,metaData]=A1_open_JPK(fullfile(filePathData,fileName));

%% Remove unnecessary channels to elaboration (necessary for memory save)
filtData=A2_CleanUpData2_AFM(data);
clear data

%% Extract the (1) height no Bk, which is not used, (2) cropped AFM channels, (3) I/O image of Height and
% (4) info of the cropped area
[~,AFM_cropped_Images,AFM_height_IO,Rect]=A3_El_AFM(filtData,secondMonitorMain,'Accuracy','High');
clear filtData

%% Using the AFM_height_IO, fit the background again, yielding a more accurate height image
[AFM_H_NoBk,AFM_cropped_Images]=A4_El_AFM_masked(AFM_cropped_Images,AFM_height_IO,secondMonitorMain);

%% to extract the friction coefficient, choose which method use.
question=sprintf('Which method perform to extract the glass friction coefficient?');
options={ ...
    sprintf('1) Average fast scan lines containing only glass.\nUse the .jpk image containing only glass'), ...
    sprintf('2) Masking PDA feature.\nUse the .jpk image containing both PDA and glass (ReTrace Data required - Hover Mode OFF)'), ... 
    sprintf('3) Masking PDA + outlier removal features\n(ReTrace Data required - Hover Mode OFF)')};
choice = getValidAnswer(question, '', options);

% methods 2 and 3 require the .jpk file with HOVER MODE OFF but in the same condition (same scanned PDA area
% of when HOVER MODE is ON)
switch answer
    case '1'    % method 1 : get the friction glass experiment .jpk file
        [fileNameFriction, filePathDataFriction] = uigetfile('*.jpk', 'Select the .jpk AFM image to extract glass friction coefficient');
        [dataGlass,metaDataGlass]=A1_open_JPK(fullfile(filePathDataFriction,fileNameFriction));
        avg_fc=A5_frictionGlassCalc_method1(metaDataGlass.Alpha,dataGlass,secondMonitorMain);
    case '2'    % method 2: masking
        avg_fc=A5_frictionGlassCalc_method2(metaData.Alpha,AFM_cropped_Images,AFM_H_NoBk,secondMonitorMain);
    case '3'    % method 3: masking + outlier removal method
        avg_fc=A5_frictionGlassCalc_method3(metaData.Alpha,AFM_cropped_Images,AFM_H_NoBk,secondMonitorMain);
end

% previous friction coefficients (determined by separate measurements)
% TRCDA : 0.2920
% PCDA  : 0.2626 (2020 July 7)

%% Substitute to the AFM cropped channels the baseline adapted LD
[Corrected_LD_Trace,AFM_Elab,~]=A6_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,metaData.Alpha,avg_fc,secondMonitorMain,'Accuracy','Low');

%% Open Brightfield image and the TRITIC (Before and After stimulation images)

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image',filePathData);
[BF_Mic_Image]=A7_open_ND2(fullfile(filePathData,fileName)); 
figure,imshow(imadjust(BF_Mic_Image))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A7_open_ND2(fullfile(filePathData,fileName)); 
figure,imshow(imadjust(Tritic_Mic_Image_Before))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A7_open_ND2(fullfile(filePathData,fileName)); 
figure,imshow(imadjust(Tritic_Mic_Image_After))

%% Align the fluorescent images After with the BEFORE stimulation
Tritic_Mic_Image_After_Registered=A8_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before);

% Align the Brightfield to TRITIC Before Stimulation
BF_Mic_Image_Registered=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,'brightfield','moving');

