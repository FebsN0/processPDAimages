% before continuing, install the proper python libraries in a virtual environment and setup matlab to use
% python in that venv. To check if it is not using the right venv, check with pyenv.
% If you have like:
%   Executable: "C:\Users\username\AppData\Local\Programs\Python\Python311\pythonw.exe"
% You have not setted the venv! Follow the next instruction
% Source: https://www.mathworks.com/matlabcentral/answers/1750425-python-virtual-environments-with-matlab
%
% 1) create virtual environment to save libraries in there to avoid conflicts and activate it
% from prompt terminal (Be sure to use the right Python version, like python311 or py)
%   C:\Users\username>  python -m venv nameVirtEnv
%  ====> nameVirtEnv folder will be created in C:\Users\username
%   C:\Users\username>  nameVirtEnv\Scripts\activate (name venv appear before C:\Users\username> )
%       (to exit from venv: deactivate)
% check if properly created:
%   where python   ===> C:\Users\user\nameVirtEnv\Scripts\python.exe
%
% 2) upgrade pip and Install libraries
%   (nameVirtEnv) C:\Users\username> py -m pip install upgrade pip
%   (nameVirtEnv) C:\Users\username> py -m pip --version ====> pip XX.X.X from C:\Users\username\nameVirtEnv\Lib\site-packages\pip (python 3.XX)
% if something is different, something is wrong. Repeat!
%   (nameVirtEnv) C:\Users\username> python -m pip install tifffile numpy
%   (nameVirtEnv) C:\Users\username> py -m pip freeze  ===> list installed libraries
% 3) Start python and Verify that modules can be loaded in Python. If so, everything is ready
%   (nameVirtEnv) C:\Users\username> python
%   >>> import tifffile
%
% 4) Find the location of the Python executable in the virtual environment. A symbolic path will be like
%           "C:\Users\username\nameVirtEnv\Scripts\python.exe"
%   (nameVirtEnv) C:\Users\username$ python 
%   >>> import sys 
%   >>> sys.executable 
%
% 5) Setup steps in MATLAB: in command window, set the Python environment to match the location of the Python executable in the virtual environment. 
%   pyenv('Version', 'C:\Users\username\nameVirtEnv\Scripts\python','ExecutionMode','OutOfProcess') 
% The Executable contains now the new path to the venv
%
% 6) check if everything is properly prepared:
%   py.importlib.import_module('tifffile') 
%           ===> ans = Python module with properties: ...
% AWESOME! EVERYTHING IS READY!

clc, clear, close all
% check python and matlab version https://www.mathworks.com/support/requirements/python-compatibility.html
vers=version('-release'); pe = pyenv; pe=pe.Version;
pv1=["2024b","3.9","3.10","3.11","3.12"];
pv2=["2024a","2023b","3.9", "3.10", "3.11"];
pv3=["2023a","3.8","3.9","3.10"];
if  ~(ismember(vers,pv1) && ismember(pe,pv1)) && ~(ismember(vers,pv2) && ismember(pe,pv2)) && ~(ismember(vers,pv3) && ismember(pe,pv3))
	error("Matlab and Python version not compatible. Check and update")
end
clear vers pv* pe
secondMonitorMain=objInSecondMonitor;
% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.

% prepare the height data and extract the mask
mainPath=uigetdir(pwd,sprintf('Locate the main scan directory which contains both HVon and HVoff directories'));
if ~exist(fullfile(mainPath,'HoverMode_ON'),"dir" )
    % HoverMode_ON is the directory which contains the .jpk file in Hover Mode ON, so the first scan (the second scan is Hover Mode off. Required for calc the friction coefficient
    error('Data Hover Mode ON doesn''t exist. Check the directory')  
else
    if ~exist(fullfile(mainPath,'HoverMode_ON','resultsData_1_postProcessA4_HVon.mat'),'file')
        [AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,folderResultsImg,setpoints]=A1_openANDassembly_JPK(secondMonitorMain,'filePath',fullfile(mainPath,'HoverMode_ON'));
        save(fullfile(mainPath,'HoverMode_ON\resultsData_1_postProcessA4_HVon'))
    else
        load(fullfile(mainPath,'HoverMode_ON\resultsData_1_postProcessA4_HVon'))
    end
end

% prepare the lateral force by using a proper friction coefficient
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
    AFM_A6_LatDeflecFitted=A5_LD_Baseline_Adaptor_masked(AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,secondMonitorMain,folderResultsImg,mainPath,'Accuracy',accuracy);
    if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
        break
    end
end
close all
%%

[nameDir,numberExperiment,~]=fileparts(fileparts(folderResultsImg));
[~,nameExperiment,~]=fileparts(fileparts(nameDir));
fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\t\tNUMBER:\t %s\n\n',nameExperiment,numberExperiment)
% Open Brightfield image and the TRITIC (Before and After stimulation images)
[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
[BF_Mic_Image,~,metaData_BF]=A6_open_ND2(fullfile(filePathData,fileName)); 
f1=figure('Visible','off');
imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
saveas(f1,sprintf('%s/resultA6_1_BrightField.tif',folderResultsImg))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A6_open_ND2(fullfile(filePathData,fileName)); 
f2=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_Before)), title('TRITIC Before Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
saveas(f2,sprintf('%s/resultA6_2_TRITIC_Before_Stimulation.tif',folderResultsImg))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A6_open_ND2(fullfile(filePathData,fileName)); 
f3=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_After)), title('TRITIC After Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
saveas(f3,sprintf('%s/resultA6_3_TRITIC_After_Stimulation.tif',folderResultsImg))

close all

% Align the fluorescent images After with the BEFORE stimulation
while true
    Tritic_Mic_Image_After_aligned=A7_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,folderResultsImg,secondMonitorMain);
    if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
        break
    else
        close gcf
    end
end
%%
% Align the Brightfield to TRITIC Before Stimulation
while true
    BF_Mic_Image_aligned=A7_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,folderResultsImg,secondMonitorMain,'Brightfield','Yes','Moving','Yes');
    if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
        break
    else
        close gcf
    end
end

uiwait(msgbox('Click to continue',''));
close gcf
clear f1 f2 f3 question options choice fileName


% Produce the binary IO of Brightfield
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A8_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,folderResultsImg,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned); 
close gcf
    
% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
while true
    [AFM_A10_IO_sizeOpt,AFM_A10_IO_padded_sizeBF,AFM_A10_data_optAlignment,results_AFM_BF_aligment]=A9_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A6_LatDeflecFitted,folderResultsImg,secondMonitorMain,'Margin',150);
    if getValidAnswer('Satisfied of the alignment (y) or restart (n)?','',{'y','n'}) == 1
        break
    end
end


%%
% correlation FLUORESCENCE AND AFM DATA

% e stato rimosso da A1 vertForceAVG, quindi la variabile deve essere tolta. Forse stava qui da quando ancora
% non scoprivo la cosa del baseline e quindi si puo usare tranquillamente setpoint
[data_Height_LD,dataPlot_Height_LD_maxVD,data_Height_FLUO,data_LD_FLUO_padMask,dataPlot_LD_FLUO_padMask_maxVD, data_VD_FLUO, data_VD_LD]=A10_correlation_AFM_BF(AFM_A10_data_optAlignment,AFM_A10_IO_padded_sizeBF,setpoints,secondMonitorMain,folderResultsImg,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned);
save(fullfile(folderResultsImg,'resultsData_2_postProcessA10_end'))

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% FUNCTIONS %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [AFM_data_cleared,AFM_heightIO_cleared,idxRemovedPortion]=removePortions(AFM_data,AFM_heightIO,secondMonitorMain,filepath)
% before start pre-process the lateral data, it may be necessary to manually remove portions which contains 
% outliers by substuting the values with the minimum. For better details, see the documentation of the function
    [AFM_data_cleared,AFM_heightIO_cleared,idxRemovedPortion]=A3_featureRemovePortion(AFM_data,AFM_heightIO,secondMonitorMain);
    % show the results  
    AFM_height_cleared=AFM_data_cleared(1).AFM_image;
    textTitle='Height (measured) channel - Masked, Fitted, Optimized, portions removed';
    idImg=4;
    textColorLabel='Height (nm)'; 
    textNameFile=sprintf('%s/resultA4_4_OptFittedHeightChannel_PortionRemoved.tif',filepath);
    showData(secondMonitorMain,false,idImg,AFM_height_cleared,true,textTitle,textColorLabel,textNameFile)
    % fig is invisible
    close gcf

    textTitle='Baseline and foreground processed - portions removed';
    idImg=5;
    textNameFile=sprintf('%s/resultA4_5_BaselineForeground_PortionRemoved.tif',filepath);
    showData(secondMonitorMain,false,idImg,AFM_heightIO_cleared,false,textTitle,'',textNameFile,true)
    % fig is invisible
    close gcf
end
