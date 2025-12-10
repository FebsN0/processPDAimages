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
%
%   C:\Users\username>  python -m venv <nameVirtEnv> (example: pyenvXmatlab)    ====> nameVirtEnv folder will be created in C:\Users\username
%   C:\Users\username>  nameVirtEnv\Scripts\activate (<nameVirtEnv> will appear before C:\Users\username)
%       (to exit from venv: deactivate)
%   (nameVirtEnv) C:\Users\user\nameVirtEnv\Scripts\python.exe ====> check if properly created and python is properly working
%
% 2) activate venv, upgrade pip and Install libraries
%   C:\Users\username> nameVirtEnv\Scripts\activate
%   (nameVirtEnv) C:\Users\username> py -m pip install --upgrade pip
%   (nameVirtEnv) C:\Users\username> py -m pip --version ====> pip XX.X.X from C:\Users\username\nameVirtEnv\Lib\site-packages\pip (python 3.XX)
% if something is different, something is wrong. Repeat!
%   (nameVirtEnv) C:\Users\username> python -m pip install tifffile numpy scipy pip-review scikit-image matplotlib PyQt5 opencv-python cellpose
%
%   (nameVirtEnv) C:\Users\username> py -m pip freeze  ===> list installed libraries
% 3) Start python and Verify that modules can be loaded in Python. If so, everything is ready
%   (nameVirtEnv) C:\Users\username> python
%   >>> import tifffile
%
%       ADDITIONAL NOTE: UPDATING PACKAGES
%           - update pip first before updating other packages:      python -m pip install --upgrade pip
%           - update all packages in once with pip-review:          pip-review --auto
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
pv1=["2025b","2025a","2024b","3.9","3.10","3.11","3.12"];
pv2=["2024a","2023b","3.9", "3.10", "3.11"];
pv3=["2023a","3.8","3.9","3.10"];
if  ~(ismember(vers,pv1) && ismember(pe,pv1)) && ~(ismember(vers,pv2) && ismember(pe,pv2)) && ~(ismember(vers,pv3) && ismember(pe,pv3))
	error("Matlab and Python version not compatible. Check and update")
end
clear vers pv* pe
idxMon=objInSecondMonitor;
pause(1)

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
step2Start=checkExistingData(mainPath,nameExperiment,nameScan);

%% Aseembly sections if any, binarize height image and optimize it
if step2Start<1  
    % extract the data, metadata, other parameters and the directory where to store the figures from .jpk files
    [allData,otherParameters,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',fullfile(mainPath,'HoverMode_ON'));
    save(fullfile(SaveFigFolder,'resultsData_1_extractAFMdata'),"allData","otherParameters","SaveFigFolder")
end

if step2Start<2  
    [dataAFM_latDeflecFitted, AFM_height_IO, metaData_AFM]= A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon);     
    clear BW maskedImage accuracy 
    save(fullfile(SaveFigFolder,'resultsData_2_assemblyProcessAFMdata'))
end

%% Extract the Brightfield data and correctly align them (especially after-before TRITIC since longer time passed)
% includes A6 and A7
if step2Start<3
    fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\t\tSCAN i-th:\t %s\n\n',nameExperiment,nameScan) 
    [metaData_NIKON,mainPathOpticalData,timeExp,TRITICdata,BFdata]=A3_prepareBFandTRITICimages(SaveFigFolder,idxMon,nameExperiment,nameScan); 
    save(fullfile(SaveFigFolder,'resultsData_3_BF_TRITIC_ready'))
end

%%
if step2Start<4
    % in case there are two BF images (PRE and POST), choose which one to use for binarization and all the next steps. Use AFM mask for better help
    if numel(fieldnames(BFdata))==2
        BF_Mic_Image_aligned=compareAndChooseBF(AFM_height_IO,TRITICdata,BFdata,SaveFigFolder,idxMon);        
    else
        field=fieldnames(BFdata);
        BF_Mic_Image_aligned=BFdata.(field{1});
    end
    TRITIC_Before=TRITICdata.PRE;
    TRITIC_After=TRITICdata.POST;    
    % Produce the binary IO of Brightfield
    [BF_Mic_Image_IO,TRITIC_Before,TRITIC_After]=A4_Mic_to_Binary(BF_Mic_Image_aligned,idxMon,SaveFigFolder,'TRITIC_before',TRITIC_Before,'TRITIC_after',TRITIC_After); 
    clear BF_Mic_Image_aligned 
    save(fullfile(SaveFigFolder,'resultsData_4_BF_TRITIC_binarization'))
end
%% Align AFM to BF and extract the coordinates for alignment to be transferred to the other data
if step2Start<5
    [AFM_height_IO_final,BF_Mic_Image_IO,AFM_data_final,results_AFM_BF_aligment,offset]=A5_alignment_AFM_Microscope(BF_Mic_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,dataAFM_latDeflecFitted,SaveFigFolder,idxMon,'Margin',150);
    % adjust size BF and TRITIC
    %BF_Mic_Image_IO=fixSize(BF_Mic_Image_IO,offset);
    TRITIC_Before=fixSize(TRITIC_Before,offset);  
    TRITIC_After=fixSize(TRITIC_After,offset);  
    clear dataAFM_latDeflecFitted allData AFM_height_IO BFdata 
    save(fullfile(SaveFigFolder,'resultsData_5_AFM_TRITIC_alignment.mat'))
end
%% correlation FLUORESCENCE AND AFM DATA

if step2Start<6
    Data_finalResults=A6_correlation_AFM_BF(AFM_data_final,AFM_height_IO_final,metaData_AFM,metaData_NIKON,idxMon,SaveFigFolder,mainPathOpticalData,timeExp,'TRITIC_before',TRITIC_Before,'TRITIC_after',TRITIC_After,'innerBorderCalc',false);
end
%Data_finalResults=A10_correlation_AFM_BF__OLDVERSION(AFM_A10_data_final,AFM_A10_IO_final,metaData_BF.ImageHeight_umeterXpixel,setpoints,secondMonitorMain,SaveFigFolder,mainPathOpticalData,timeExp,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned,'innerBorderCalc',false);

clear flag* TRITIC_Before TRITIC_After AFM_A10_data_final AFM_A10_IO_final AFM_A4_HeightFittedMasked
close all
save(fullfile(SaveFigFolder,'resultsData_END_Force_Fluorescence_Correlation'))
disp('A10 - Correlation completed')
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% FUNCTIONS %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function idxLastOperation=checkExistingData(mainPath,nameExperiment,nameScan)
    if ~exist(fullfile(mainPath,'HoverMode_ON'),"dir" )
        % HoverMode_ON is the directory which contains the .jpk file in Hover Mode ON, so the first scan (the second scan is Hover Mode off. Required for calc the friction coefficient
        error('Data Scan %s Hover Mode ON doesn''t exist. Check the directory',nameScan)
    else
        % check if some data already exist to avoid to do again some parts of the postprocessing          
        % if A1 (extract data) is already done
        filePostA1  =  'resultsData_1_extractAFMdata.mat';
        question1   =   sprintf('(A1) AFM data extraction (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options1    =   {'(A2) Run next step: Assembly-Process AFM data','(A1) Redo Extraction AFM data'};
        % if A2 (process-assembly) is already done
        filePostA2  =  'resultsData_2_assemblyProcessAFMdata.mat';
        question2   =   sprintf('(A2) Assembly - Process of AFM data (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options2    =   {'(A3) Run next step: prepare TRITIC data','(A2) Redo Assembly-Process AFM data'};
        % if A3 (prepare TRITIC and BF data)
        filePostA3  =  'resultsData_3_BF_TRITIC_ready.mat';
        question3   =   sprintf('(A3) BF and TRITIC images preparation (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options3    =   {'(A4) Run next step: TRITIC binarization','(A3) Redo preparation BF-TRITIC data'};
        % if A4 (binarization TRITIC and BF data)
        filePostA4  =  'resultsData_4_BF_TRITIC_binarization.mat';
        question4   =   sprintf('(A4) BF and TRITIC images binarization (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options4    =   {'(A5) Run next step:  AFM-TRITIC alignment','(A4) Redo BF-TRITIC data binarization'};        
        % if A5 (conversion of lateral data from Volt into Force according to the friction by processing HVoff) is already done
        filePostA5  =  'resultsData_5_AFM_TRITIC_alignment.mat';
        question5   =   sprintf('(A5) AFM-TRITIC alignment (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options5    =   {'(A6) Run next step: Force-Fluorescence correlation','(A5) Redo AFM-TRITIC alignment'};            
        % if A5 (final data) is already obtained
        filePostA6end = 'resultsData_END_Force_Fluorescence_Correlation.mat';        
        question6     =   sprintf('(A6) Force-Fluorescence correlation (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
        options6      =   {'(END) Stop the process','(A6) Redo Force-Fluorescence correlation'};
        % prepare list
        fileList={filePostA1,filePostA2,filePostA3,filePostA4,filePostA5,filePostA6end};
        questionList={question1,question2,question3,question4,question5,question6};
        optionsList={options1,options2,options3,options4,options5,options6};
        % find the paths of the files. If not available, the i-th step cell will be empty. Therefore, more easy to find the last file
        flagPresenceFile=cellfun(@(x) fullfile({dir(fullfile(mainPath,'Results Processing AFM and fluorescence images*',x)).folder},x), ...
            fileList,'UniformOutput',false);        
        idxLastOperation=find(cellfun(@(x) ~isempty(x), flagPresenceFile),1,"last");

        if ~isempty(idxLastOperation)
            if getValidAnswer(questionList{idxLastOperation},'',optionsList{idxLastOperation})==1
            % first option choosen (CONTINUE)
                if idxLastOperation==6 %last step already done
                    error('Stopped by user.')
                end
                % take the last dataset
                tmpData=load(flagPresenceFile{idxLastOperation}{:});
            else
                % second option choosen (REDO)
                if idxLastOperation==1
                    % in case of redo first step, complete restart
                    idxLastOperation=0;
                else
                    % take the dataset before the last
                    tmpData=load(flagPresenceFile{idxLastOperation-1}{:});                      
                end
            end
        else
            idxLastOperation=0;
        end
        % move the data on the main workspace (here we are still inside a
        % function, so the variables must be copied outside).
        % no need to delete some vars created here. Only those from tmpData
        % will be copied
        if exist('tmpData','var')
            fieldNamesC = fieldnames(tmpData);
            for i = 1:length(fieldNamesC)
                assignin('base', fieldNamesC{i}, tmpData.(fieldNamesC{i}));
            end
        end        
    end
    clear options question
end

function BF_final=compareAndChooseBF(AFM_height_IO,TRITICdata,BFdata,folderResultsImg,idxMon)
    % prepare data
    TRITICpost=TRITICdata.POST;
    BFpre=BFdata.PRE;  BFpost=BFdata.POST;
    % show binarized AFM
    fAFM=figure;
    imagesc(AFM_height_IO), title("binarized AFM Height",'FontSize',15)
    axis on, axis equal, xlim tight, ylim tight
    % show BFpre overlapped with TRITICpost, then BFpost
    fcompare=figure;
    ax1=subplot(121);
    imshow(imfuse(imadjust(BFpre),imadjust(TRITICpost)))
    title("BFpre - TRITICpost","FontSize",12)
    ax2=subplot(122);
    imshow(imfuse(imadjust(BFpost),imadjust(TRITICpost)))
    title("BFpost - TRITICpost","FontSize",12)
    textTitle="Comparison BFpre and BFpost with TRITICpost overlapped";
    sgtitle(textTitle,"FontSize",20)
    options={"PRE","POST"};
    % see the figures and choose. Extract the definitive BF data
    choice=getValidAnswer("Which BF image do you want to use for the next steps?",'',options);
    zoom(ax1, 'reset'); axis(ax1, 'image');
    zoom(ax2, 'reset'); axis(ax2, 'image');
    fieldsN=fieldnames(BFdata);        
    BF_final=BFdata.(fieldsN{choice});
    % Highlight the chosen subplot
    axesHandles = [ax1, ax2];
    delete(findall(gcf, 'Tag', 'SelectionBox'));
    pos = get(axesHandles(choice), 'Position');
    % Create a green rectangle around it
    annotation('rectangle', pos, ...
        'Color', 'g', ...
        'LineWidth', 3, ...
        'Tag', 'SelectionBox');
    % (Optional) Bring rectangle to front
    uistack(findall(gcf, 'Tag', 'SelectionBox'), 'top');
    % prepare the final plot and save
    textTitle=sprintf("Selected BF_%s for the next steps!",options{choice});
    sgtitle(textTitle,"FontSize",20,'interpreter','no')
    objInSecondMonitor(fcompare,idxMon)
    nameFile="resultA3_7_DefinitiveSelectionFromComparison_BFpreBFpost_TRITICafterOverlapped";
    fullfileName=fullfile(folderResultsImg,'tiffImages',nameFile);
    saveas(fcompare,fullfileName,'tif')
    fullfileName=fullfile(folderResultsImg,'figImages',nameFile);
    saveas(fcompare,fullfileName)
    close(fcompare), close(fAFM)
end