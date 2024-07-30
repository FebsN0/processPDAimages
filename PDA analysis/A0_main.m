clc, clear, close


% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.
[data,metaData_AFM,filePathData]=A1_openANDassembly_JPK;

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

% prepare figure and put in a second monitor if any
secondMonitorMain=objInSecondMonitor;
% Remove unnecessary channels to elaboration (necessary for memory save)
filtData=A2_CleanUpData2_AFM(data);
clear data

% Extract the (1) height no Bk, which is not used, (2) cropped AFM channels, (3) I/O image of Height and
% (4) info of the cropped area
[~,AFM_cropped_Images,AFM_height_IO,Rect]=A3_El_AFM(filtData,secondMonitorMain,newFolder,'Accuracy','High');
clear filtData
% Using the AFM_height_IO, fit the background again, yielding a more accurate height image
[AFM_H_NoBk,AFM_cropped_Images]=A4_El_AFM_masked(AFM_cropped_Images,AFM_height_IO,secondMonitorMain,newFolder);
close all

% to extract the friction coefficient, choose which method use.
question=sprintf('Which method perform to extract the glass friction coefficient?');
options={ ...
    sprintf('1) Average fast scan lines containing only glass.\nUse the .jpk image containing only glass'), ...
    sprintf('2) Masking PDA feature.\nUse the .jpk image containing both PDA and glass (ReTrace Data required - Hover Mode OFF)'), ... 
    sprintf('3) Masking PDA + outlier removal features\n(ReTrace Data required - Hover Mode OFF)'), ...
    sprintf('4) Use a previous calculated friction coefficient: TRCDA = 0.2920'), ...
    sprintf('5) Use a previous calculated friction coefficient: PCDA  = 0.2626'), ...
    sprintf('6) Enter manually a value')};
choice = getValidAnswer(question, '', options);

% methods 2 and 3 require the .jpk file with HOVER MODE OFF but in the same condition (same scanned PDA area
% of when HOVER MODE is ON)
switch choice
    case 1
        % method 1 : get the friction glass experiment .jpk file
        [fileNameFriction, filePathDataFriction] = uigetfile('*.jpk', 'Select the .jpk AFM image to extract glass friction coefficient');
        [dataGlass,metaDataGlass]=A1_open_JPK(fullfile(filePathDataFriction,fileNameFriction));
        avg_fc=A5_frictionGlassCalc_method1(metaDataGlass.Alpha,dataGlass,secondMonitorMain,newFolder);
        clear fileNameFriction filePathDataFriction dataGlass metaDataGlass
    case {2, 3}
        % before perform method 2 or 3, upload the data used to calc the glass friction coeffiecient. Basically it the same experiment but with Hover Mode OFF
        % then clean the data.
        [dataHoverModeOFF,metaDataHoverModeOFF,~]=A1_openANDassembly_JPK;
        filtDataHVOFF=A2_CleanUpData2_AFM(dataHoverModeOFF);
        [~,AFM_cropped_ImagesHVOFF,AFM_height_IOHVOFF,~]=A3_El_AFM(filtDataHVOFF,secondMonitorMain,newFolder,'Accuracy','Low','Silent','Yes');
        [~,AFM_cropped_ImagesHVOFF_fitted]=A4_El_AFM_masked(AFM_cropped_ImagesHVOFF,AFM_height_IOHVOFF,secondMonitorMain,newFolder,'Silent','Yes');
        % METHOD 2 : MASKING ONLY
        % METHOD 3 : MASKING + OUTLIER REMOVAL
        eval(sprintf('avg_fc=A5_frictionGlassCalc_method%d(metaDataHoverModeOFF.Alpha,AFM_cropped_ImagesHVOFF_fitted,AFM_height_IOHVOFF,secondMonitorMain,newFolder);',choice));
        clear dataHoverModeOFF metaDataHoverModeOFF filtDataHVOFF AFM_cropped_ImagesHVOFF AFM_height_IOHVOFF AFM_H_NoBkHVOFF AFM_cropped_ImagesHVOFF_fitted
    case 4  %TRCDA
        avg_fc = 0.2920;
    case 5                %PCDA
        avg_fc = 0.2626;
    case 6
        while true
            avg_fc = str2double(inputdlg('Enter a value for the glass fricction coefficient','',[1 50]));
            if any(isnan(avg_fc)) || avg_fc <= 0 || avg_fc >= 1
                questdlg('Invalid input! Please enter a numeric value','','OK','OK');
            else
                break
            end
        end
end
close all

% Substitute to the AFM cropped channels the baseline adapted LD
[~,AFM_Elab,~]=A6_LD_Baseline_Adaptor_masked(AFM_cropped_Images,AFM_height_IO,metaData_AFM.Alpha,avg_fc,secondMonitorMain,newFolder,'Accuracy','High');

close all

% Open Brightfield image and the TRITIC (Before and After stimulation images)

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image',filePathData);
[BF_Mic_Image,~,metaData_BF]=A7_open_ND2(fullfile(filePathData,fileName)); 
f1=figure;
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',20)
saveas(f1,sprintf('%s/resultA8_0_BrightField.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A7_open_ND2(fullfile(filePathData,fileName)); 
f2=figure;
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
imshow(imadjust(Tritic_Mic_Image_Before)), title('TRITIC Before Stimulation','FontSize',20)
saveas(f2,sprintf('%s/resultA8_0_TRITIC_Before_Stimulation.tif',newFolder))

close all

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A7_open_ND2(fullfile(filePathData,fileName)); 
f3=figure;
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
imshow(imadjust(Tritic_Mic_Image_After)), title('TRITIC After Stimulation','FontSize',20)
saveas(f3,sprintf('%s/resultA8_0_TRITIC_After_Stimulation.tif',newFolder))

% Align the fluorescent images After with the BEFORE stimulation
Tritic_Mic_Image_After_aligned=A8_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,newFolder,secondMonitorMain);

% Align the Brightfield to TRITIC Before Stimulation
BF_Mic_Image_aligned=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes');

uiwait(msgbox('Click to continue',''));
close all
clear f1 f2 f3 question options choice fileName Tritic_Mic_Image_After BF_Mic_Image

% Produce the binary IO of Brightfield
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,Details_On_BF_Image]=A9_Mic_to_Binary(BF_Mic_Image_aligned,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,secondMonitorMain,newFolder); 

% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
[AFM_IO_Padded,BF_Image_postAFMalign,AFM_channels_postBFalign,Coordinates_forAllighnment,details_it_reg]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,Details_On_BF_Image.Cropped,AFM_height_IO,metaData_AFM,AFM_Elab,newFolder,secondMonitorMain,'Margin',70);

%%