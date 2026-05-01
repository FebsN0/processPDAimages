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
% - Bio-Formats (bfmatlab) :   from https://www.openmicroscopy.org/bio-formats/downloads/  (MATLAB icon)
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

mainPath=uigetdir(pwd,sprintf('Locate the directory of a scan of a specific experiment condition which contains HVon/HVoff directories.'));
if exist(fullfile(mainPath,"infoDataprocessing.mat"),"file")
    load(fullfile(mainPath,"infoDataprocessing"),"nameGroupExperiment","nameExperiment","nameScan")
else
    tmp=strsplit(mainPath,'\');
    nameScan=tmp{end}; nameExperiment=tmp{end-2}; nameGroupExperiment=tmp{end-3};
    question=sprintf('Name Group all exps: %s\nName experiment: %s\nScan i-th: %s\nIs everything okay?',nameGroupExperiment,nameExperiment,nameScan);
    display(tmp)
    if ~getValidAnswer(question,'',{'Yes','No'})
        while true
            res=inputdlg({"Name Group all exps","Name experiment (ex. TRCDA)","ID scan"},"Enter manually names",[1 80; 1 80; 1 80],{nameGroupExperiment,nameExperiment,nameScan,});
            if any(cellfun(@(x) isempty(x), res))
                disp('Input not valid')
            else
                nameGroupExperiment=res{1};
                nameExperiment=res{2};
                nameScan=res{3};                
                break
            end
        end
    end
    save(fullfile(mainPath,"infoDataprocessing"),"nameGroupExperiment","nameExperiment","nameScan")
end
clear question res tmp
%%
% check if data already exist. If so, upload.
HVmodesInfo=checkHVmode(mainPath);
step2Start=checkExistingData(mainPath,nameExperiment,nameScan);
%% Aseembly sections if any, binarize height image and optimize it
if step2Start<1  
    % extract the data, metadata, other parameters and the directory where to store the figures from .jpk files
    if strcmp(HVmodesInfo.mainData,"OFF")
        mainHVmode = HVmodesInfo.dirOFF{:};
    else
        mainHVmode = HVmodesInfo.dirON{:};
    end
    [allData,otherParameters,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',fullfile(mainPath,mainHVmode));
    save(fullfile(SaveFigFolder,'resultsData_1_extractAFMdata'),"allData","otherParameters","SaveFigFolder")
end
%%
if step2Start<2  
    [data_AFM,metaData_AFM]= A2_0_main_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,HVmodesInfo,idxMon);     
    clear BW maskedImage 
    save(fullfile(SaveFigFolder,'resultsData_2_assemblyProcessAFMdata'),"data_AFM","metaData_AFM")
end
clear allData otherParameters HVmodesInfo
%% Extract the Brightfield data and correctly align them (especially after-before TRITIC since longer time passed)         
% includes A6 and A7
if step2Start<3
    fprintf("\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n" + ...
        "%%%%%%%%" + ...
        "----  Current Scan  processing details  ----%%%%%%%%\n" + ...
        "%%%%%%%% GROUP EXPERIMENT: %s\t%%%%%%%%\n" + ...
        "%%%%%%%% NAME  EXPERIMENT: %s\t\t%%%%%%%%\n" + ...
        "%%%%%%%% SCAN  ID:         %s\t\t\t%%%%%%%%\n" + ...
        "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n",...
        nameGroupExperiment,nameExperiment,nameScan);
    % extract and prepare the data
        [metaData_NIKON,BFdata,TRITICdata,mainPathOpticalData]=A3_1_prepareBFandTRITICimages(SaveFigFolder,idxMon,nameGroupExperiment,nameExperiment,nameScan);    
        % there might be many TRITIC files with different exposure times ==> choose the good one by checking TRITIC distribution and eventually saturation
        [metaData_NIKON,TRITICdata]=A3_2_checkIntensityTRITIC(metaData_NIKON,TRITICdata,SaveFigFolder,idxMon);
        save(fullfile(SaveFigFolder,'resultsData_3_1_BF_allTRITIC_extractedPrepared'),"metaData_NIKON","BFdata","TRITICdata","mainPathOpticalData",'-v7.3')
end
%%
if step2Start<4
% in case there are more TRITIC Images at different exposure times, just pick the strongest clear AFTER AFM STIMULATION
% (even if there is saturation) just to guide the cropping before binarize to save computational time.
    if numel(TRITICdata.pre)~=1
        TRITIC_After=TRITICdata.post{1,end}; % first row: high expTime, last col: high gain
    else
        TRITIC_After=TRITICdata.post{1};    
    end        
    % Produce the binary IO of Brightfield
    [BF_Image_IO,cropAreaInfo]=A4_Mic_to_Binary(BFdata,idxMon,SaveFigFolder,'TRITIC_after',TRITIC_After); 
    % apply the same crop made in BF image to the TRITIC data to save computational time
    if ~isempty(cropAreaInfo)
        XBegin=cropAreaInfo(1); XEnd=cropAreaInfo(2);
        YBegin=cropAreaInfo(3); YEnd=cropAreaInfo(4);
        TRITICdata_crop.pre=cell(size(TRITICdata.pre));
        TRITICdata_crop.post=cell(size(TRITICdata.post));
        for i=1:numel(TRITICdata.pre)
            tmp=TRITICdata.pre{i};
            tmp_crop=tmp(XBegin:XEnd,YBegin:YEnd); 
            TRITICdata_crop.pre{i}=tmp_crop;
            tmp=TRITICdata.post{i};
            tmp_crop=tmp(XBegin:XEnd,YBegin:YEnd); 
            TRITICdata_crop.post{i}=tmp_crop;
        end
        clear tmp* i cropAreaInfo TRITICdata
        TRITICdata=TRITICdata_crop;
        clear TRITICdata_crop
    end
    clear TRITIC_After
    save(fullfile(SaveFigFolder,'resultsData_3_2_BFbinarized'),"BF_Image_IO","TRITICdata")
end
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% ALIGNMENT AFM and BF IO IMAGES %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<5
    % prepare the AFM data taking only the necessary ones: Height, Lateral Force and Vertical Force.
    % NOTE: VF and LF ENTIRE images to prevent the NaN excessive distorsion during AFM-BF IO alignment. The most important thing is the masks alignment, because
    % the AFM mask already contains the excluded pixels in AFM-LF, not the cleared because the cleared images contains NaN)   
    tmpH=data_AFM(strcmp([data_AFM.Channel_name],"Height (measured)")).AFM_images_2_PostHeightProcessed;    
    tmpVF=data_AFM(strcmp([data_AFM.Channel_name],"Vertical Force")).AFM_images_2_PostLateralProcessed_0_entire;
    tmpLF=data_AFM(strcmp([data_AFM.Channel_name],"Lateral Force")).AFM_images_2_PostLateralProcessed_0_entire;    
    tmpIOclear=data_AFM(strcmp([data_AFM.Channel_name],"Height (measured)")).AFMmask_heightIO_cleared;    
    % cell array to be modified with the matrix modification
    AFM_StartData={tmpH,tmpVF,tmpLF,tmpIOclear};
    % original mask (there is only one data in the struct) ==> used for alignment
    AFM_height_IO=data_AFM(strcmp([data_AFM.Channel_name],"Height (measured)")).AFMmask_heightIO;    
    % start the alignment (use the original AFM mask with the BF mask)
    [AFM_height_IO_End,BF_Image_IO_End,AFM_EndData,~,offset]=A5_alignment_AFM_Microscope(BF_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,AFM_StartData,SaveFigFolder,idxMon,'Margin',150);                
    clear tmp*
    save(fullfile(SaveFigFolder,'resultsData_4_AFM_BF_alignment.mat'),"AFM_height_IO_End","BF_Image_IO_End","AFM_EndData","offset")
end
%%
if step2Start<6

        % adjust size BF and TRITIC
    %BF_Mic_Image_IO=fixSize(BF_Mic_Image_IO,offset);
    TRITIC_Before=fixSize(TRITIC_Before,offset);  
    TRITIC_After=fixSize(TRITIC_After,offset); 
    % ANALYSE THE TRITIC exposure time for better choice

    % Align the Brightfield and TRITIC Images
    [aligned_BFimage,aligned_TRITICimages] = A3_3_alignBFandTRITIC(BFdata, TRITICdata, SaveFigFolder);
    




            % PLOT FLUORESCENCE IMAGES
    titleImagePRE=sprintf('TRITIC Before Stimulation - timeExp: %s - gain: %s',timeExp,gain);
    titleImagePOST=sprintf('TRITIC After Stimulation - timeExp: %s - gain: %s',timeExp,gain);
    filenameND2_PRE='resultA3_3_1_TRITIC_Before_Stimulation';
    filenameND2_POST='resultA3_3_2_TRITIC_Before_Stimulation';
end

%% Align AFM to BF and extract the coordinates for alignment to be transferred to the other data
if step2Start<6
 
    clear data_AFM AFM_height_IO BFdata 
    
end
%% correlation FLUORESCENCE AND AFM DATA

if step2Start<7
    Data_finalResults=A6_correlation_AFM_BF(AFM_data_final,AFM_height_IO_final,BF_Image_IO_final,metaData_AFM,metaData_NIKON,idxMon,SaveFigFolder,mainPathOpticalData,timeExp,'TRITIC_before',TRITIC_Before,'TRITIC_after',TRITIC_After,'innerBorderCalc',false);
end
%Data_finalResults=A10_correlation_AFM_BF__OLDVERSION(AFM_A10_data_final,AFM_A10_IO_final,metaData_BF.ImageHeight_umeterXpixel,setpoints,secondMonitorMain,SaveFigFolder,mainPathOpticalData,timeExp,'TRITIC_before',Tritic_Mic_Image_Before,'TRITIC_after',Tritic_Mic_Image_After_aligned,'innerBorderCalc',false);

clear flag* TRITIC_Before TRITIC_After AFM_A10_data_final AFM_A10_IO_final AFM_A4_HeightFittedMasked
close all
save(fullfile(SaveFigFolder,'resultsData_END_Force_Fluorescence_Correlation'))
disp('A10 - Correlation completed')
% restore warning
cleanupObj = onCleanup(@() warning(orig));  % will restore original state

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% FUNCTIONS %%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function idxLastOperation=checkExistingData(mainPath,nameExperiment,nameScan)          
    % check if some data already exist to avoid to do again some parts of the postprocessing          
    % if A1 (extract data) is already done
    filePostA1  =  'resultsData_1_extractAFMdata.mat';
    question1   =   sprintf('(A1) AFM data extraction (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options1    =   {'(A2) Run next step: Assembly-Process AFM data (single section processing may already have been started).','(A1) Redo Extraction AFM data'};
    % if A2 (process-assembly) is already done
    filePostA2  =  'resultsData_2_assemblyProcessAFMdata.mat';
    question2   =   sprintf('(A2) Assembly - Process of AFM data (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options2    =   {'(A3-1) Run next step: prepare BF and TRITIC data','(A2) Redo Assembly-Process AFM data'};
    % if A3_1 (prepare TRITIC and BF data)
    filePostA3_1  =  'resultsData_3_1_BF_allTRITIC_extractedPrepared.mat';
    question3_1   =   sprintf('(A3-1) BF and TRITIC images extraction and preparation (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options3_1    =   {'(A3-2) Run next step: Brightfield binarization','(A3-1) Redo preparation BF-TRITIC data'};
    % if A3_2 (binarize BF)
    filePostA3_2 =  'resultsData_3_2_BFbinarized.mat';
    question3_2  =   sprintf('(A3-2) BF binarization (and eventually TRITIC cropping) (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options3_2   =   {'(A4) Run next step: AFM-BF alignment','(A3-2) Redo BF binarization'};
    % if A4 (AFM-TRITIC alignment)
    filePostA4  =  'resultsData_4_AFM_BF_alignment.mat';
    question4   =   sprintf('(A4) AFM-BF alignment (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options4    =  {'(A5) Run next step: Choose right TRITIC Exposure Time and final BF-TRITIC alignment','(A3_2) AFM-TRITIC alignment'};            

    
    % if A5 (TRITIC analysis and choice exposure time)
    filePostA5 =  'resultsData_5_TRITICexpTimeAnalysis_BFAndTRITIC_Alignment.mat';
    question5  =   sprintf('(A5) TRITIC analysis and BF-TRITIC alignment (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options5   =   {'','(A3-3) Redo TRITIC analysis'};       
       % if A5 (Force-Fluorescence correlation) - FINAL
    filePostA6  =  'resultsData_5_Force_Fluorescence_Correlation.mat';
    question6   =   sprintf('(A5) Force-Fluorescence correlation (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options6    =   {'(END) Stop the process!','(A5) Redo Force-Fluorescence correlationt'};            
    % prepare list
    fileList={filePostA1,filePostA2,filePostA3_1,filePostA3_2,filePostA4,filePostA5,filePostA6};
    questList={question1,question2,question3_1,question3_2,question4,question5,question6};
    optList={options1,options2,options3_1,options3_2,options4,options5,options6};
    clear filePost* question* option*
    % find the paths of the files. If not available, the i-th step cell will be empty. Therefore, more easy to find the last file
    flagPresenceFile=cellfun(@(x) fullfile({dir(fullfile(mainPath,'Results Processing AFM and fluorescence images*',x)).folder},x), ...
        fileList,'UniformOutput',false);        
    idxLastOperation=find(cellfun(@(x) ~isempty(x), flagPresenceFile),1,"last");
    if ~isempty(idxLastOperation)
        answ=getValidAnswer(questList{idxLastOperation},'',optList{idxLastOperation});
        if answ==1 && idxLastOperation==6 %last step already done
        % first option choosen (CONTINUE)
            error('Stopped by user.')            
        elseif answ==2
            % second option choosen (REDO)
            if idxLastOperation==1
                % in case of redo first step, complete restart
                idxLastOperation=0;
                return
            else
                idxLastOperation=idxLastOperation-1;
            end
        end
        % take all dataset until last
        for i=1:idxLastOperation
            tmpData=load(flagPresenceFile{i}{:});                      
            % move the data on the main workspace (here we are still inside a function, so the variables must be copied outside).
            % no need to delete some vars created here. Only those from tmpData will be copied
            if exist('tmpData','var')
                fieldNamesC = fieldnames(tmpData);
                for j = 1:length(fieldNamesC)
                    assignin('base', fieldNamesC{j}, tmpData.(fieldNamesC{j}));
                end
            end   
        end
    else
        idxLastOperation=0;
    end   
end