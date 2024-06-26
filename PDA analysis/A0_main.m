clc, clear, close

[fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image');

question= 'Do you want to show the figures into a maximized window in a second monitor? [Y/N]: ';
if strcmpi(getValidAnswer(question,{'y','n'}),'y')
    question= 'Is the second monitor a main monitor? [Y/N]: ';
    secondMonitorMain = getValidAnswer(question,{'y','n'});
else
    secondMonitorMain = [];
end
clear question
% open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
% calculates alpha, based on the pub), it returns the location of the file.
[data,metadata]=A1_open_JPK(fullfile(filePathData,fileName));

%% Remove unnecessary channels to elaboration (necessary for memory save)
filtData=A2_CleanUpData2_AFM(data);
clear data

%% Extract the (1) height no Bk, which is not used, (2) cropped AFM channels, (3) I/O image of Height and
% (4) info of the cropped area
[~,Cropped_Images,AFM_height_IO,Rect]=A3_El_AFM(filtData,secondMonitorMain,'High');
clear filtData

%% Using the AFM_height_IO, fit the background again, yielding a more accurate height image
[AFM_H_NoBk]=A4_El_AFM_masked(Cropped_Images,AFM_height_IO,secondMonitorMain);
% substitutes to the raw cropped date the Height with no BK
Cropped_Images(strcmp({Cropped_Images.Channel_name},'Height (measured)')).Cropped_AFM_image=AFM_H_NoBk;

%% extract only-glass friction coefficient

% method 1
% get the friction glass experiment .jpk file
[fileNameFriction, filePathDataFriction] = uigetfile('*.jpk', 'Select the .jpk AFM images where extract friction coefficient on glass-only');
[dataGlass,metaDataGlass]=A1_open_JPK(fullfile(filePathDataFriction,fileNameFriction));
%%%%%%% IMPORTANT CHECK ABOUT THIS. USE THE ALPHA FROM GLASS OR FROM PDA?
avg_fc1=A5_frictionGlassCalc_method1(metaDataGlass.Alpha,dataGlass,secondMonitorMain);

% method 2
avg_fc2=A5_frictionGlassCalc_method2(metadata.Alpha,Cropped_Images,AFM_height_IO,secondMonitorMain);

%% Substitute to the AFM cropped channels the baseline adapted LD
%[Corrected_LD_Trace,AFM_Elab,Bk_iterative]=A6_LD_Baseline_Adaptor_masked(Cropped_Images,alpha,AFM_height_IO,'Low');
