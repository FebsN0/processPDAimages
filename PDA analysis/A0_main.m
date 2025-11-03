% before starting, check the pyenv compatibility with the current MATLAN version on the following website:
% https://www.mathworks.com/support/requirements/python-compatibility.html?s_tid=srchtitle_site_search_1_python+compatibility
% 
% In case multiple pythons version or not compatible current version occur,
% install the compatible version and run python using the proper version
% before continuing.
%
% Once verified which python version to use, then install the proper python libraries in a virtual environment 
% and setup matlab to use python in that venv. To check if it is not using the right venv, check with pyenv.
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
% 2) activate venv, upgrade pip and Install libraries
%   C:\Users\username> nameVirtEnv\Scripts\activate
%   (nameVirtEnv) C:\Users\username> py -m pip install --upgrade pip
%   (nameVirtEnv) C:\Users\username> py -m pip --version ====> pip XX.X.X from C:\Users\username\nameVirtEnv\Lib\site-packages\pip (python 3.XX)
% if something is different, something is wrong. Repeat!
%   (nameVirtEnv) C:\Users\username> python -m pip install tifffile numpy scipy
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
% 7) further check:
%    open the directory "test python on matlab" and run test.m
%           ===> ans = (matrix value) 
%
% AWESOME! EVERYTHING IS READY!
%
% %%%%%%%%%%%%%%%%%%%%%%%%%
% %%% REQUIRED PACKAGES %%%
% %%%%%%%%%%%%%%%%%%%%%%%%%
% - Image Processing Toolbox, polyfitn, Xcorr2_fft, settingsdlg:      from "Get More Apps" box as toolbox 
% - Bio-Formats :   from https://www.openmicroscopy.org/bio-formats/downloads/  (MATLAB icon)
%                       NOTE: move the package into <DISK>:\Users\<name-user>\Documents\MATLAB\Third-part Toolbox.
%                       If the folder doesn’t exist, create it. Save any plugin and extension in this directory.
%                       IMPORTANT: add such directory in the MATLAB path by using pathtool

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
idxMon=objInSecondMonitor;
% upload .jpk files. If more than one and if from same experiment in which setpoint is changed, then assembly.

% prepare the height data and extract the mask
mainPath=uigetdir(pwd,sprintf('Locate the main scan directory which contains both HVon and HVoff directories'));
tmp=strsplit(mainPath,'\');
nameScan=tmp{end}; nameExperiment=tmp{end-2}; clear tmp
question=sprintf('Name experiment: %s\nScan i-th: %s\nIs everything okay?',nameExperiment,nameScan);
if ~getValidAnswer(question,'',{'Yes','No'})
    while true
        nameExperiment=inputdlg('Enter manually name experiment');
        if isempty(nameExperiment) || isempty(nameExperiment{1})
            disp('Input not valid')
        else
            break
        end
    end
end
clear question

% check if data already exist. If so, upload.
[flagExeA1,flagExeA5,flagExeA6_A7_A8,flagExeA9]=checkExistingData(mainPath,nameExperiment,nameScan);


%% Aseembly sections if any, binarize height image and optimize it
if flagExeA1
    accuracy=chooseAccuracy("Step A3 - Fitting the baseline (i.e. Background) of AFM Height Data. Which fit order range use?");
    [AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,folderResultsImg,setpoints]=A1_openANDassembly_JPK(idxMon,'filePath',fullfile(mainPath,'HoverMode_ON'),'FitOrder',accuracy);
    clear BW maskedImage accuracy question
    save(fullfile(mainPath,'HoverMode_ON\resultsData_1_postProcessA4_HVon'))
end
%% prepare the lateral force by using a proper friction coefficient
if flagExeA1 || flagExeA5
    accuracy=chooseAccuracy("step A5 - Fitting the baseline (i.e. Background) of AFM Lateral Deflection Data. Which fit order range use?");
    AFM_A5_LatDeflecFitted=A5_LD_Baseline_Adaptor_masked(AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,idxMon,folderResultsImg,mainPath,'FitOrder',accuracy,'Silent','No');
    close all
    clear accuracy AFM_A4_HeightFittedMasked
    save(fullfile(mainPath,'HoverMode_ON\resultsData_2_postProcessA5'))
end
%% Extract the Brightfield data and correctly align them (especially after-before TRITIC since longer time passed)
% includes A6 and A7
if flagExeA1 || flagExeA5 || flagExeA6_A7_A8
    fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\t\tSCAN i-th:\t %s\n\n',nameExperiment,nameScan) 
    [metaData_BF,BF_Mic_Image_aligned,Tritic_Mic_Image_After_aligned,Tritic_Mic_Image_Before,mainPathOpticalData,timeExp]=A6_prepareBFandTRITIC(folderResultsImg,idxMon);
    % Produce the binary IO of Brightfield
    [BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A8_Mic_to_Binary(BF_Mic_Image_aligned,idxMon,folderResultsImg,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned); 
    clear BF_Mic_Image_aligned 
    close all
    save(fullfile(mainPath,'HoverMode_ON\resultsData_3_postProcessA8'))
end
%% Align AFM to BF and extract the coordinates for alignment to be transferred to the other data
if flagExeA1 || flagExeA5 || flagExeA6_A7_A8 || flagExeA9
    [AFM_A10_IO_final,AFM_A10_data_final,results_AFM_BF_aligment,offset]=A9_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A5_LatDeflecFitted,folderResultsImg,idxMon,'Margin',150);
    % adjust size BF and TRITIC
    BF_Mic_Image_IO=fixSize(BF_Mic_Image_IO,offset);
    Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);  
    Tritic_Mic_Image_After_aligned=fixSize(Tritic_Mic_Image_After_aligned,offset);  
    clear offset AFM_A5_LatDeflecFitted
    save(fullfile(mainPath,'HoverMode_ON\resultsData_4_postProcessA9.mat'))
end
%% correlation FLUORESCENCE AND AFM DATA
Data_finalResults=A10_correlation_AFM_BF(AFM_A10_data_final,AFM_A10_IO_final,metaData_BF.ImageHeight_umeterXpixel,setpoints,idxMon,folderResultsImg,mainPathOpticalData,timeExp,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned,'innerBorderCalc',false);

%Data_finalResults=A10_correlation_AFM_BF__OLDVERSION(AFM_A10_data_final,AFM_A10_IO_final,metaData_BF.ImageHeight_umeterXpixel,setpoints,secondMonitorMain,folderResultsImg,mainPathOpticalData,timeExp,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned,'innerBorderCalc',false);

clear flag* Tritic_Mic_Image_Before Tritic_Mic_Image_After_aligned AFM_A10_data_final AFM_A10_IO_final AFM_A4_HeightFittedMasked
close all
save(fullfile(folderResultsImg,'resultsData_A10_end'))
disp('A10 - Correlation completed')
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% FUNCTIONS %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [flagExeA1,flagExeA5,flagExeA6_A7_A8,flagExeA9]=checkExistingData(mainPath,nameExperiment,nameScan)
    if ~exist(fullfile(mainPath,'HoverMode_ON'),"dir" )
        % HoverMode_ON is the directory which contains the .jpk file in Hover Mode ON, so the first scan (the second scan is Hover Mode off. Required for calc the friction coefficient
        error('Data Scan %s Hover Mode ON doesn''t exist. Check the directory',nameScan)
    else
        % check if some data already exist to avoid to do again some parts of the postprocessing          
        % if A1 (assembly), A3 (binarization) and A4 (optminization) are already done
        filePostA4  =  'resultsData_1_postProcessA4_HVon.mat';
        flagExeA1=false;     % by default, run ENTIRE postprocess, otherwise skip to the next step (A5-A6-..)    
        % if A5 (conversion of lateral data from Volt into Force according to the friction by processing HVoff) is already done
        filePostA5  =  'resultsData_2_postProcessA5.mat';
        flagExeA5=false;     % by default, run postprocess step A5, otherwise skip to the next step (A6-A7-..)    
        % if A6 (BF and TRITIC extraction), A7 (BF and TRITIC alignment), A8 (BF binarization) are already done
        filePostA6_A7_A8  = 'resultsData_3_postProcessA8.mat';
        flagExeA6_A7_A8=false;     % by default, run postprocess steps A6-A7-A8, otherwise skip to the next step (A9)   
        % if A9 (AFM-IO and BF-IO alignment) is already done
        filePostA9  = 'resultsData_4_postProcessA9.mat';
        flagExeA9=false;      % by default, run postprocess A9, otherwise skip to the last step (A10)    
        % if A10 (final data) is already obtained
        fileFinalData = 'resultsData_A10_end.mat';           
        % Find final results recursively
        if ~isempty(dir(fullfile(mainPath, '**', fileFinalData)))
            %fullPath = fullfile(allFiles.folder, allFiles.name);
            question=sprintf('Final results (post A10, correlation force-fluorescence) of the %s scan #%s already exists.\nChoose the right option:',nameExperiment,nameScan);
            options={'Stop the process','Redo correlation force-fluorescence (A10)'};
            if getValidAnswer(question,'',options)==1
                error('Stopped by user.')
            else
                % redo A10        
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA9));
            end
        % A9 part
        elseif exist(fullfile(mainPath, 'HoverMode_ON', filePostA9),'file')
            question=sprintf('Results after alignment (A9) of the %s scan #%s already exists.\nChoose the right option:',nameExperiment,nameScan);
            options={'Run next step A10','Redo A9'};
            if getValidAnswer(question,'',options)==1
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA9));                
            else
                % redo A9                
                flagExeA9=true;
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA6_A7_A8));
            end
        % A6_A7_A8 part
        elseif exist(fullfile(mainPath, 'HoverMode_ON', filePostA6_A7_A8),'file')
            question=sprintf('Results after BF and TRITIC images preparation (A6-A7-A8) of the %s scan #%s already exists.\nChoose the right option:',nameExperiment,nameScan);
            options={'Run next step A9','Redo A6_A7_A8'};
            if getValidAnswer(question,'',options)==1                
                flagExeA9=true;
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA6_A7_A8));
            else
                % Redo A6_A7_A8                 
                flagExeA6_A7_A8=true;
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA5));
            end
        % A5 part
        elseif exist(fullfile(mainPath, 'HoverMode_ON', filePostA5),'file')
            question=sprintf('Results after conversion of lateral data from Volt to Force (A5) of the %s scan #%s already exists.\nChoose the right option:',nameExperiment,nameScan);
            options={'Run next steps A6_A7_A8','Redo A5'};
            if getValidAnswer(question,'',options)==1
                flagExeA6_A7_A8=true;
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA5));
            else
                % Redo A5
                flagExeA5=true;
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA4));
            end
        % A1-A2-A3-A4 part
        elseif exist(fullfile(mainPath, 'HoverMode_ON', filePostA4),'file')
            question=sprintf('Results after assembly, binarization and optminization (A1-A2-A3-A4) of the %s scan #%s already exists.\nChoose the right option:',nameExperiment,nameScan);
            options={'Run next step A5','Redo A1-A2-A3-A4'};
            if getValidAnswer(question,'',options)==1
                tmpData=load(fullfile(mainPath, 'HoverMode_ON', filePostA4));
                flagExeA5=true;
            else
                flagExeA1=true;
            end
        else
            flagExeA1=true;
        end
        if exist('tmpData','var')
            fieldNamesC = fieldnames(tmpData);
            for i = 1:length(fieldNamesC)
                assignin('base', fieldNamesC{i}, tmpData.(fieldNamesC{i}));
            end
        end
    end
    clear options question
end

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

function accuracy=chooseAccuracy(question)
    options={'Low (1-3)','Medium (1-6)','High (1-9)'};
    answer=getValidAnswer(question,'',options);
    switch answer
        case 1
            accuracy= 'Low';
        case 2
            accuracy= 'Medium';
        case 3
            accuracy= 'High';
    end      
end
