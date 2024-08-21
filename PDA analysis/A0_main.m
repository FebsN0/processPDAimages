clc, clear, close all

secondMonitorMain=objInSecondMonitor;
% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.
[AFM_FittedMasked,AFM_height_IO,metaData_AFM,filePathData,newFolder]=A1_openANDassembly_JPK(secondMonitorMain);






%%
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
        [dataHoverModeOFF,metaDataHoverModeOFF,~]=A1_openANDassembly_JPK; %#ok<ASGLU>
        filtDataHVOFF=A2_CleanUpData2_AFM(dataHoverModeOFF);
        [~,AFM_cropped_ImagesHVOFF,AFM_height_IOHVOFF,~]=A3_El_AFM(filtDataHVOFF,secondMonitorMain,newFolder,'Accuracy','Low','Silent','Yes');
        [~,AFM_cropped_ImagesHVOFF_fitted]=A4_El_AFM_masked(AFM_cropped_ImagesHVOFF,AFM_height_IOHVOFF,secondMonitorMain,newFolder,'Silent','Yes'); %#ok<ASGLU>
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
while true
    answer=getValidAnswer('Fitting AFM lateral channel data: which accuracy use?','',{'Low','Medium','High'});
    switch answer
        case 1
            accuracy= 'Low';
        case 2
            accuracy= 'Medium';
        case 3
            accuracy= 'High';
    end
    [~,AFM_Elab,~,setpoints]=A6_LD_Baseline_Adaptor_masked(AFM_FittedMasked,AFM_height_IO,metaData_AFM.Alpha,avg_fc,secondMonitorMain,newFolder,'Accuracy',accuracy);
    if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
        break
    end
end

clear AFM_FittedMasked
close all


% Open Brightfield image and the TRITIC (Before and After stimulation images)
[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image',filePathData);
[BF_Mic_Image,~,metaData_BF]=A7_open_ND2(fullfile(filePathData,fileName)); 
f1=figure;
imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
saveas(f1,sprintf('%s/resultA8_0_BrightField.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A7_open_ND2(fullfile(filePathData,fileName)); 
f2=figure;
imshow(imadjust(Tritic_Mic_Image_Before)), title('TRITIC Before Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
saveas(f2,sprintf('%s/resultA8_0_TRITIC_Before_Stimulation.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A7_open_ND2(fullfile(filePathData,fileName)); 
f3=figure;
imshow(imadjust(Tritic_Mic_Image_After)), title('TRITIC After Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
saveas(f3,sprintf('%s/resultA8_0_TRITIC_After_Stimulation.tif',newFolder))

close all

% Align the fluorescent images After with the BEFORE stimulation
Tritic_Mic_Image_After_aligned=A8_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,newFolder,secondMonitorMain);
% Align the Brightfield to TRITIC Before Stimulation
BF_Mic_Image_aligned=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes');

uiwait(msgbox('Click to continue',''));
close gcf
clear f1 f2 f3 question options choice fileName Tritic_Mic_Image_After BF_Mic_Image


% Produce the binary IO of Brightfield
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A9_Mic_to_Binary(BF_Mic_Image_aligned,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,secondMonitorMain,newFolder); 
clear BF_Mic_Image_aligned

% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
[AFM_IO_padded_sizeOpt,AFM_IO_padded_sizeBF,AFM_data_optAlignment,results_AFM_BF_aligment]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_Elab,newFolder,secondMonitorMain,'Margin',70);
clear AFM_height_IO AFM_Elab

% correlation FLUORESCENCE AND AFM DATA
A11_correlation_AFM_BF(Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,AFM_IO_padded_sizeBF,AFM_data_optAlignment,setpoints,secondMonitorMain,newFolder);

