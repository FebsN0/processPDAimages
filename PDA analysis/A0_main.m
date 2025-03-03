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
%
% BE SURE TO DOWNLOAD FROM "Get More Apps" box the toolbox "polyfitn"
%
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
    flagExeA1=true;
    if exist(fullfile(mainPath,'HoverMode_ON','resultsData_1_postProcessA4_HVon.mat'),'file')
        tmp=strsplit(mainPath,'\');
        nameScan=tmp{end}; clear tmp        
        question=sprintf('Results of the scan %s HoverModeON already exists. Take it? If not, remove the previous one.',nameScan);
        if getValidAnswer(question,'',{'Yes','No'})
            load(fullfile(mainPath,'HoverMode_ON\resultsData_1_postProcessA4_HVon'))
            flagExeA1=false;
        else
            delete(pathResultsData)           
        end        
    end
    if flagExeA1
        accuracy=chooseAccuracy("Step A3 - Fitting the baseline (i.e. Background) of AFM Height Data. Which fit order range use?");
        [AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM,folderResultsImg,setpoints]=A1_openANDassembly_JPK(secondMonitorMain,'filePath',fullfile(mainPath,'HoverMode_ON'),'FitOrder',accuracy);
        clear BW maskedImage accuracy question nameScan flagExeA1
        save(fullfile(mainPath,'HoverMode_ON\resultsData_1_postProcessA4_HVon'))
    end
end
%%
% prepare the lateral force by using a proper friction coefficient
accuracy=chooseAccuracy("step A5 - Fitting the baseline (i.e. Background) of AFM Lateral Deflection Data. Which fit order range use?");
AFM_A5_LatDeflecFitted=A5_LD_Baseline_Adaptor_masked(AFM_A4_HeightFittedMasked,AFM_height_IO,metaData_AFM.Alpha,secondMonitorMain,folderResultsImg,mainPath,'FitOrder',accuracy,'Silent','No');
close all
clear accuracy

%%
[nameDir,numberExperiment,~]=fileparts(fileparts(folderResultsImg));
[~,nameExperiment,~]=fileparts(fileparts(nameDir));
fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\t\tNUMBER:\t %s\n\n',nameExperiment,numberExperiment)
% Open Brightfield image and the TRITIC (Before and After stimulation images)

filenameND2='resultA6_1_BrightField'; titleImage='BrightField - original';
[BF_Mic_Image,metaData_BF,filePathData]=selectND2file(folderResultsImg,filenameND2,titleImage,secondMonitorMain);

% .nd2 files inside dir
fileList = dir(fullfile(filePathData, '*.nd2'));
pattern = '\d+ms';
matches = regexp({fileList.name}, pattern, 'match');
matches = [matches{:}];
timeValues = sort(unique(cellfun(@(x) str2double(erase(x, 'ms')), matches)));
timeList = cellstr(string(unique(timeValues)));
BF_Mic_Image_original=BF_Mic_Image;
while true
    if ~isempty(timeList)
        timeExp=timeList{getValidAnswer('What exposure time do you want to take?','',timeList)};
    end
    
    % select the files with the choosen time exposure
    matchingFiles = {fileList(contains({fileList.name}, [timeExp, 'ms'])).name};
    % auto selection
    beforeFiles = matchingFiles(contains(matchingFiles, 'before', 'IgnoreCase', true));
    afterFiles = matchingFiles(contains(matchingFiles, {'post', 'after'}, 'IgnoreCase', true));
    % in case not found, manual selection
    if isempty(beforeFiles) || isempty(afterFiles)
        disp('Issues in finding the files. Manual selection.');  
    end
    filenameND2='resultA6_2_TRITIC_Before_Stimulation'; titleImage='TRITIC Before Stimulation';
    Tritic_Mic_Image_Before=selectND2file(folderResultsImg,filenameND2,titleImage,secondMonitorMain,filePathData,'Before',beforeFiles);
    filenameND2='resultA6_3_TRITIC_After_Stimulation'; titleImage='TRITIC After Stimulation';
    Tritic_Mic_Image_After=selectND2file(folderResultsImg,filenameND2,titleImage,secondMonitorMain,filePathData,'Before',afterFiles);
    close all       
    % Align the fluorescent images After with the BEFORE stimulation
    [Tritic_Mic_Image_After_aligned,offset]=A7_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,folderResultsImg,secondMonitorMain);
    % adjust BF and Tritic_Before depending on the offset
    BF_Mic_Image=fixSize(BF_Mic_Image,offset);
    Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);   
    % Align the Brightfield to TRITIC Before Stimulation
    [BF_Mic_Image_aligned,offset]=A7_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,folderResultsImg,secondMonitorMain,'Brightfield','Yes','Moving','Yes');    
    Tritic_Mic_Image_After_aligned=fixSize(Tritic_Mic_Image_After_aligned,offset);
    Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);   
    if getValidAnswer(sprintf('Satisfied of all the registration of BF and fluorescence image?\nIf not, change time exposure for better alignment'),'',{'Yes','No'})
        close gcf
        break
    end
    % in case of no satisfaction, restore original data
    BF_Mic_Image=BF_Mic_Image_original;
    close all
end
% adjust the metadata BF size
nameExperiment=sprintf('%s_scan%s',nameExperiment,numberExperiment);
clear fileList numberExperiment proportionMeter2Pixel f1 f2 f3 matchingFiles question options choice fileName Tritic_Mic_Image_After
clear filePathData nameDir filenameND2 afterFiles beforeFiles BF_Mic_Image BF_Mic_Image_original offset time* titleImage pattern matches

% Produce the binary IO of Brightfield
[BF_Mic_Image_IO,Tritic_Mic_Image_Before,Tritic_Mic_Image_After_aligned,~]=A8_Mic_to_Binary(BF_Mic_Image_aligned,secondMonitorMain,folderResultsImg,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned); 
close all

clear BF_Mic_Image_aligned 
save(fullfile(mainPath,'HoverMode_ON\resultsData_2_postProcessA8_HVon'))
%%
% Align AFM to BF and extract the coordinates for alighnment to be transferred to the other data
[AFM_A10_IO_final,AFM_A10_data_final,results_AFM_BF_aligment,offset]=A9_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_BF,AFM_height_IO,metaData_AFM,AFM_A5_LatDeflecFitted,folderResultsImg,secondMonitorMain,'Margin',150);

BF_Mic_Image_IO=fixSize(BF_Mic_Image_IO,offset);
Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);  
Tritic_Mic_Image_After_aligned=fixSize(Tritic_Mic_Image_After_aligned,offset);  
clear offset
%%
% correlation FLUORESCENCE AND AFM DATA

% e stato rimosso da A1 vertForceAVG, quindi la variabile deve essere tolta. Forse stava qui da quando ancora
% non scoprivo la cosa del baseline e quindi si puo usare tranquillamente setpoint
Data_finalResults=A10_correlation_AFM_BF(AFM_A10_data_final,AFM_A10_IO_final,setpoints,secondMonitorMain,folderResultsImg,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned,'innerBorderCalc',true);
save(fullfile(folderResultsImg,'resultsData_A10_end'))

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

function [Image,metaData,filePathData]=selectND2file(folderResultsImg,filenameND2,titleImage,secondMonitorMain,varargin)
    for i=varargin
        filePathData=varargin{1};
        mode=varargin{2};
        if ~isempty(varargin{3})
            fileName=varargin{3};
            if ~isempty(fileName)
                fileName=fileName{1};
            end
        end        
    end
    if ~exist('filePathData','var')
        [fileName, filePathData] = uigetfile({'*.nd2'}, 'Select the BrightField image');
    else
        if isempty(varargin{3})
            [fileName, filePathData] = uigetfile({'*.nd2'}, sprintf('Select the TRITIC %s Stimulation image',mode),filePathData);
        end
    end
    [Image,~,metaData]=A6_open_ND2(fullfile(filePathData,fileName)); 
    f1=figure('Visible','off');
    imshow(imadjust(Image)), title(titleImage,'FontSize',17)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    fullfileName=fullfile(folderResultsImg,'tiffImages',filenameND2);
    saveas(f1,fullfileName,'tif')
    fullfileName=fullfile(folderResultsImg,'figImages',filenameND2);
    saveas(f1,fullfileName)
end

function fixedImage=fixSize(originalImage,offset)
    if length(offset)==2
        offset_x=offset(1);
        offset_y=offset(2);
        [rows, cols] = size(originalImage);
        x_start = max(1, 1 + offset_x);
        y_start = max(1, 1 + offset_y);
        x_end = min(cols, cols + offset_x);
        y_end = min(rows, rows + offset_y);     
    else
        y_start=offset(1);  y_end=offset(2);
        x_start=offset(3);  x_end=offset(4);
    end
    fixedImage = originalImage(y_start:y_end, x_start:x_end);
end