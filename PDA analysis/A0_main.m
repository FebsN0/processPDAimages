clc, clear, close all

secondMonitorMain=objInSecondMonitor;
% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.
[AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,newFolder,setpoints,vertForceAVG]=A1_openANDassembly_JPK(secondMonitorMain);

% to extract the friction coefficient, choose which method use.
question=sprintf('Which method perform to extract the background friction coefficient?');
options={ ...
    sprintf('1) TRCDA (air) = 0.3405'), ...
    sprintf('2) PCDA  (air)  = 0.2626'), ... 
    sprintf('3) TRCDA-DMPC (air) = 0.2693'), ...
    sprintf('4) TRCDA-DOPC (air) = 0.3037'), ...
    sprintf('5) TRCDA-POPC (air) = 0.2090'), ...
    sprintf('6) Enter manually a value')};
choice = getValidAnswer(question, '', options);

if ~exist('newFolder','var')
    newFolder=[];
end
if ~exist('secondMonitorMain','var')
    secondMonitorMain=objInSecondMonitor;
end
% methods 2 and 3 require the .jpk file with HOVER MODE OFF but in the same condition (same scanned PDA area
% of when HOVER MODE is ON)
switch choice
    case 1, avg_fc = 0.3405;
    case 2, avg_fc = 0.2626;
    case 3, avg_fc = 0.2693;
    case 4, avg_fc = 0.3037;
    case 5, avg_fc = 0.2090;                     
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
clear choice question options
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
    [AFM_A6_LatDeflecFitted,~]=A6_LD_Baseline_Adaptor_masked(AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,avg_fc,secondMonitorMain,newFolder,'Accuracy',accuracy);
    if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
        break
    end
end

close all

%%

% Open Brightfield image and the TRITIC (Before and After stimulation images)
[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
[BF_Mic_Image,~,metaData_BF]=A7_open_ND2(fullfile(filePathData,fileName)); 
f1=figure('Visible','off');
imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
saveas(f1,sprintf('%s/resultA8_0_BrightField.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A7_open_ND2(fullfile(filePathData,fileName)); 
f2=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_Before)), title('TRITIC Before Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
saveas(f2,sprintf('%s/resultA8_0_TRITIC_Before_Stimulation.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A7_open_ND2(fullfile(filePathData,fileName)); 
f3=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_After)), title('TRITIC After Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
saveas(f3,sprintf('%s/resultA8_0_TRITIC_After_Stimulation.tif',newFolder))

close all

% Align the fluorescent images After with the BEFORE stimulation
while true
    Tritic_Mic_Image_After_aligned=A8_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,newFolder,secondMonitorMain);
    if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
        break
    end
end

% Align the Brightfield to TRITIC Before Stimulation
while true
    BF_Mic_Image_aligned=A8_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes');
    if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
        break
    end
end


uiwait(msgbox('Click to continue',''));
close gcf
clear f1 f2 f3 question options choice fileName


% Produce the binary IO of Brightfield
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A9_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,newFolder,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned); 

    
% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
while true
    [AFM_A10_IO_sizeOpt,AFM_A10_IO_padded_sizeBF,AFM_A10_data_optAlignment,results_AFM_BF_aligment]=A10_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A6_LatDeflecFitted,newFolder,secondMonitorMain,'Margin',70);
    if getValidAnswer('Satisfied of the alignment or restart?','',{'y','n'}) == 1
        break
    end
end



%%
% correlation FLUORESCENCE AND AFM DATA
[data_Height_LD,dataPlot_Height_LD_maxVD,data_Height_FLUO,data_LD_FLUO_padMask,dataPlot_LD_FLUO_padMask_maxVD, data_VD_FLUO, data_VD_LD]=A11_correlation_AFM_BF(AFM_A10_data_optAlignment,AFM_A10_IO_padded_sizeBF,vertForceAVG,secondMonitorMain,newFolder,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned);

save(sprintf('%s\\dataResults.mat',newFolder))

