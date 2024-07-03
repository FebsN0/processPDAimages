clc, clear, close

[fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image');
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
question=sprintf('Which method perform to extract the glass friction coefficient?\n 1) Average fast scan lines containing only glass.\tUse the .jpk image containing only glass\n 2) Masking PDA feature.\tuse the .jpk image containing both PDA and glass (ReTrace Data required - Hover Mode OFF)\n 3) Masking PDA + outlier removal features (ReTrace Data required - Hover Mode OFF)\n selection: \n');
answer = getValidAnswer(question, {'1','2','3'});
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
