clc, clear, close

[fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image');

question= 'Do you want to show the figures into a maximized window in a second monitor? [Y/N]: ';
if strcmpi(getValidAnswer(question,{'y','n'}),'y')
    question= 'Is the second monitor a main monitor? [Y/N]: ';
    secondMonitorMain = getValidAnswer(question,{'y','n'});
else
    secondMonitorMain = [];
end
clear question data filtData
% open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
% calculates alpha, based on the pub), it returns the location of the file.
data=A1_open_JPK(fullfile(filePathData,fileName));

%% Remove unnecessary channels to elaboration (necessary for memory save)
filtData=A2_CleanUpData2_AFM(data);

%% Extract the (1) height no Bk, which is not used, (2) cropped AFM channels, (3) I/O image of Height and
% (4) info of the cropped area
[~,Cropped_Images,AFM_height_IO,Rect]=A3_2_El_AFM(filtData,secondMonitorMain,'High');

%% Using the AFM_height_IO, fit the background again, yielding a more accurate height image
[AFM_noBk_TRCDA]=A4_El_AFM_TRCDA_masked(Cropped_Images,AFM_height_IO,secondMonitorMain);

%%
% find in which position the Height (measured) channel is in the AFM data
index_ch=find(strcmp({Cropped_Images.Channel_name},'Height (measured)')==1); % finds the AFM channel with name Height (measured)
POI=index_ch(1,find(ismember(find(strcmp({Cropped_Images.Channel_name},'Height (measured)')==1),find(strcmp({Cropped_Images.Trace_type},'Trace')==1)))); % finds whihc is the correct one requested ('TRACE')
% substitutes to the raw cropped date the Height with no BK

raw_data_Or=Cropped_Images(strcmp({Cropped_Images.Channel_name},'Height (measured)')).Cropped_AFM_image;


AFM_cropped_channels(POI).Cropped_AFM_image=AFM_H_NoBk; 




%%
[Corrected_LD_Trace,AFM_Elab,Bk_iterative]=A5_LD_Baseline_Adaptor_masked_TRCDA(AFM_Cropped,Alpha,AFM_height_IO,varargin);
