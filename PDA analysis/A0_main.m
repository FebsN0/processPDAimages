clc, clear, close

[fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image');
data=A1_open_JPK(fullfile(filePathData,fileName));
filtData=A2_CleanUpData2_AFM(data);
A3_2_El_AFM(filtData,'High')