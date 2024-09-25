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
        % method 1 : get the friction glass experiment .jpk file. Upload one or more file of only background
        m=1;
        filePath=uigetdir(pwd,'Locate the main directory where there are all the background-only files of a specific condition');
        while true
            [AFM_HeightFittedMasked_HVOFF,~,metaDataHoverModeOFF]=A1_openANDassembly_JPK(secondMonitorMain,'backgroundOnly','Yes','filePath',filePath);
            AFM_onlyBK{m}=AFM_HeightFittedMasked_HVOFF; %#ok<SAGROW>
            metadata_onlyBK{m}=metaDataHoverModeOFF; %#ok<SAGROW>
            answer=questdlg('Upload another file of only background?','','Yes');
            if ~strcmp(answer,'Yes')
                break
            end
            m=m+1; clear metaDataHoverModeOFF AFM_HeightFittedMasked_HVOFF options question choice
        end

        avg_fc=A5_frictionGlassCalc_method1(AFM_onlyBK,metadata_onlyBK,secondMonitorMain,filePath);
        clear fileNameFriction filePathDataFriction dataGlass metaDataGlass
    case {2, 3}
        % before perform method 2 or 3, upload the data used to calc the glass friction coeffiecient. Basically it the same experiment but with Hover Mode OFF
        % then clean the data.
        [AFM_HeightFittedMasked_HVOFF,AFM_height_IO_HVOFF,metaDataHoverModeOFF,filePathHV,~,vertforceAVG_HVOff]=A1_openANDassembly_JPK(secondMonitorMain,'backgroundOnly','Yes'); %#ok<ASGLU>
        % METHOD 2 : MASKING ONLY
        % METHOD 3 : MASKING + OUTLIER REMOVAL
        eval(sprintf('avg_fc=A5_frictionGlassCalc_method%d(metaDataHoverModeOFF.Alpha,AFM_HeightFittedMasked_HVOFF,AFM_height_IO_HVOFF,vertforceAVG_HVOff,secondMonitorMain,filePathHV);',choice));
end
clear question options
close all