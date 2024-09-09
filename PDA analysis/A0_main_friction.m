clc, clear, close all

% to extract the friction coefficient, choose which method use.
question=sprintf('Which method perform to extract the background friction coefficient?');
options={ ...
    sprintf('1) Average fast scan lines containing only background.\nUse the .jpk image containing only background'), ...
    sprintf('2) Masking PDA feature. Use the .jpk image containing both PDA and background\n(ReTrace Data required - Hover Mode OFF)'), ... 
    sprintf('3) Masking PDA + outlier removal features. Use the .jpk image containing both PDA and background\n(ReTrace Data required - Hover Mode OFF)')};
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
    case 1
        % method 1 : get the friction glass experiment .jpk file
        avg_fc=A5_frictionGlassCalc_method1(secondMonitorMain,newFolder);
        clear fileNameFriction filePathDataFriction dataGlass metaDataGlass
    case {2, 3}
        % before perform method 2 or 3, upload the data used to calc the glass friction coeffiecient. Basically it the same experiment but with Hover Mode OFF
        % then clean the data.
        [AFM_HeightFittedMasked_HVOFF,AFM_height_IO_HVOFF,metaDataHoverModeOFF,~,filePathHV,setpointN_HVOff]=A1_openANDassembly_JPK(secondMonitorMain,'saveFig','No','backgroundOnly','Yes'); %#ok<ASGLU>
        % METHOD 2 : MASKING ONLY
        % METHOD 3 : MASKING + OUTLIER REMOVAL
        eval(sprintf('avg_fc=A5_frictionGlassCalc_method%d(metaDataHoverModeOFF.Alpha,AFM_HeightFittedMasked_HVOFF,AFM_height_IO_HVOFF,setpointN_HVOff,secondMonitorMain,filePathHV);',choice));
        clear dataHoverModeOFF metaDataHoverModeOFF filtDataHVOFF AFM_cropped_ImagesHVOFF AFM_height_IO_HVOFF AFM_H_NoBkHVOFF AFM_HeightFittedMasked_HVOFF setpointN_HVOff
end
clear choice question options
close all