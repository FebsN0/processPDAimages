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
[AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,newFolder,setpoints,vertForceAVG]=A1_openANDassembly_JPK(secondMonitorMain);

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
    [AFM_A6_LatDeflecFitted,~]=A5_LD_Baseline_Adaptor_masked(AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxPortionRemoved,secondMonitorMain,newFolder,'Accuracy',accuracy);
    if getValidAnswer('Satisfied of the fitting?','',{'y','n'}) == 1
        break
    end
end

close all
%%

[nameDir,numberExperiment,~]=fileparts(fileparts(newFolder));
[~,nameExperiment,~]=fileparts(fileparts(nameDir));
fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\t\tNUMBER:\t %s\n\n',nameExperiment,numberExperiment)
% Open Brightfield image and the TRITIC (Before and After stimulation images)
[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
[BF_Mic_Image,~,metaData_BF]=A6_open_ND2(fullfile(filePathData,fileName)); 
f1=figure('Visible','off');
imshow(imadjust(BF_Mic_Image)), title('BrightField - original','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
saveas(f1,sprintf('%s/resultA6_1_BrightField.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC Before Stimulation image',filePathData);
[Tritic_Mic_Image_Before]=A6_open_ND2(fullfile(filePathData,fileName)); 
f2=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_Before)), title('TRITIC Before Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f2); end
saveas(f2,sprintf('%s/resultA6_2_TRITIC_Before_Stimulation.tif',newFolder))

[fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the TRITIC After Stimulation image',filePathData);
[Tritic_Mic_Image_After]=A6_open_ND2(fullfile(filePathData,fileName)); 
f3=figure('Visible','off');
imshow(imadjust(Tritic_Mic_Image_After)), title('TRITIC After Stimulation','FontSize',17)
if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f3); end
saveas(f3,sprintf('%s/resultA6_3_TRITIC_After_Stimulation.tif',newFolder))

close all

% Align the fluorescent images After with the BEFORE stimulation
while true
    Tritic_Mic_Image_After_aligned=A7_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,newFolder,secondMonitorMain);
    if getValidAnswer('Satisfied of the alignment?','',{'y','n'}) == 1
        break
    else
        close gcf
    end
end

% Align the Brightfield to TRITIC Before Stimulation
while true
    BF_Mic_Image_aligned=A7_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,newFolder,secondMonitorMain,'Brightfield','Yes','Moving','Yes');
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
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A8_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,newFolder,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned); 
close gcf
    
% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
while true
    [AFM_A10_IO_sizeOpt,AFM_A10_IO_padded_sizeBF,AFM_A10_data_optAlignment,results_AFM_BF_aligment]=A9_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A6_LatDeflecFitted,newFolder,secondMonitorMain,'Margin',150);
    if getValidAnswer('Satisfied of the alignment (y) or restart (n)?','',{'y','n'}) == 1
        break
    end
end



%%
% correlation FLUORESCENCE AND AFM DATA
[data_Height_LD,dataPlot_Height_LD_maxVD,data_Height_FLUO,data_LD_FLUO_padMask,dataPlot_LD_FLUO_padMask_maxVD, data_VD_FLUO, data_VD_LD]=A10_correlation_AFM_BF(AFM_A10_data_optAlignment,AFM_A10_IO_padded_sizeBF,vertForceAVG,secondMonitorMain,newFolder,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned);

save(sprintf('%s\\dataResults.mat',newFolder))

