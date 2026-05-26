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

mainPath="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_25marchSample\1";
%mainPath="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DMPC_25marchSample\1";
%mainPath="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_DOPC_25marchSample\1";
%mainPath="D:\1_mixingPCinTRCDA\AFM data\4_sampleMarch2026\TRCDA_POPC_25marchSample\7";

if ~(exist("mainPath","var") && exist(mainPath,"dir") && getValidAnswer(sprintf("Is the selected path of the scan to process correct?\n%s",mainPath),"",{"Y","N"}))   
    mainPath=uigetdir(pwd,sprintf('Locate the directory of a scan of a specific experiment condition which contains HVon/HVoff directories.'));
end
% if exist, extract basic info regarding name experiment and other info
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
%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EXTRACT AFM RAW DATA %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Aseembly sections if any, binarize height image and optimize it
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
clear mainHVmode
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PROCESS AFM RAW DATA %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<2  
    [AFMdata,metaData_AFM]= A2_0_main_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,HVmodesInfo,idxMon);     
    clear BW maskedImage 
    save(fullfile(SaveFigFolder,'resultsData_2_assemblyProcessAFMdata'),"AFMdata","metaData_AFM")
end
clear allData otherParameters HVmodesInfo mainPath
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EXTRACT/REORGANIZE/ALIGN PRE-POST BF and TRITIC IMAGES %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<3
    fprintf("\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n" + ...
        "%%%%%%%%" + ...
        "----  Current Scan  processing details  ----%%%%%%%%\n" + ...
        "%%%%%%%% GROUP EXPERIMENT: %s\t%%%%%%%%\n" + ...
        "%%%%%%%% NAME  EXPERIMENT: %s\t\t%%%%%%%%\n" + ...
        "%%%%%%%% SCAN  ID:         %s\t\t\t%%%%%%%%\n" + ...
        "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n",...
    nameGroupExperiment,nameExperiment,nameScan);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% EXTRACT BF-TRITIC IMAGES PRE AND POST AFM (for normal AFM scans) %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    [metaData_NIKON,BFdata,TRITICdata_1_raw,mainPathOpticalData]=A3_1_prepareBFandTRITICimages(SaveFigFolder,idxMon,nameGroupExperiment,nameExperiment,nameScan);    
    % there might be many TRITIC files with different exposure times ==> choose the good one by checking TRITIC distribution and eventually saturation
    %       columns: highExpTime -> lowExpTime
    %       vectors: lowGain -> highGain
    [metaData_NIKON,TRITICdata_2_organized]=A3_2_checkIntensityTRITIC(metaData_NIKON,TRITICdata_1_raw,SaveFigFolder,idxMon);
    % since time passed between before and after AFM scan, the scan area might move ==> ALIGN OPTICAL IMAGES
    [BFdata,TRITICdata_3_Aligned] = A3_3_alignBFandTRITIC(BFdata,TRITICdata_2_organized,SaveFigFolder,idxMon);
    % save BF and TRITIC images
    save(fullfile(SaveFigFolder,'resultsData_3_BF_allTRITIC_extractedPreparedAligned'),"metaData_NIKON","BFdata","TRITICdata_3_Aligned","mainPathOpticalData",'-v7.3')     
end
clear TRITICdata_1_raw TRITICdata_2_organized

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% BINARIZATION OF BF IMAGE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<4
% in case there are more TRITIC Images at different exposure times, just pick the strongest clear AFTER AFM STIMULATION
% (even if there is saturation) just to guide the cropping before binarize to save computational time.
    if numel(TRITICdata_3_Aligned.pre)~=1
        TRITIC_After=TRITICdata_3_Aligned.post{1,end}; % first row: high expTime, last col: high gain
    else
        TRITIC_After=TRITICdata_3_Aligned.post{1};    
    end        
    % Produce the binary IO of Brightfield
    [BF_Image_IO,cropAreaInfo]=A4_binarizeBF(BFdata,idxMon,SaveFigFolder,'TRITIC_after',TRITIC_After); 
    % apply the same crop made in BF image to the TRITIC data to save computational time during correlation AFM-TRITIC
    if ~isempty(cropAreaInfo)
        TRITICdata_4_cropped.pre = fixSize(TRITICdata_3_Aligned.pre,cropAreaInfo);
        TRITICdata_4_cropped.post = fixSize(TRITICdata_3_Aligned.post,cropAreaInfo);               %%%%%%%%%%%%%%%%%%%% CHECK IF STILL EFFECTIVE
    else
        TRITICdata_4_cropped=TRITICdata_3_Aligned;
    end    
    save(fullfile(SaveFigFolder,'resultsData_4_BFbinarized'),"BF_Image_IO","TRITICdata_4_cropped")    
end
clear TRITIC_After TRITICdata_3_Aligned BFdata

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% ALIGNMENT AFM (IO+Data) and BF-IO IMAGES %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<5
    % prepare the AFM data taking only the necessary ones: Height, Lateral Force and Vertical Force.
    % NOTE: VF and LF ENTIRE images to prevent the NaN excessive distorsion during AFM-BF IO alignment. The most important thing is the masks alignment, because
    % the AFM mask already contains the excluded pixels in AFM-LF, not the cleared because the cleared images contains NaN)   
    tmpH=AFMdata(strcmp([AFMdata.Channel_name],"Height (measured)")).AFM_images_2_PostHeightProcessed;    
    tmpVF=AFMdata(strcmp([AFMdata.Channel_name],"Vertical Force")).AFM_images_2_PostLateralProcessed_0_entire;
    tmpLF=AFMdata(strcmp([AFMdata.Channel_name],"Lateral Force")).AFM_images_2_PostLateralProcessed_0_entire;    
    tmpIOclear=AFMdata(strcmp([AFMdata.Channel_name],"Height (measured)")).AFMmask_heightIO_cleared;    
    % cell array to be modified with the matrix modification
    AFM_StartData_vect={tmpH,tmpVF,tmpLF,tmpIOclear};
    % original mask (there is only one data in the struct) ==> used for alignment
    AFM_height_IO=AFMdata(strcmp([AFMdata.Channel_name],"Height (measured)")).AFMmask_heightIO;    
    % start the alignment (use the original AFM mask with the BF mask)
    [AFM_height_IO_End,BF_Image_IO_End,AFM_EndData_vect,~,offset]=A5_alignment_AFM_Microscope(BF_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,AFM_StartData_vect,SaveFigFolder,idxMon,'Margin',150);                  
    % take the cleared AFM mask, fix (different values from 0/1 because of interpolation)
    tmpIOclear=AFM_EndData_vect.AFM_2_aligned{end};
    tmpIOclear(tmpIOclear>=0.5)=1; tmpIOclear(tmpIOclear<0.5)=0;
    fMask=showData(idxMon,true,AFM_height_IO_End,"AFM-IO (original) Post alignment with BF-IO",SaveFigFolder,"resultA5_5_comparisonFinalMasks","binary",true,...
        "extraData",tmpIOclear,"extraBinary",true,"extraTitles","AFM-IO (cleared) Post alignment with BF-IO","saveFig",false);
    if getValidAnswer("Which binarized AFM image post alignment with the BF mask do you want to take as definitive final mask?","",{"Original mask","Cleared mask"},2)==2
        AFM_height_IO_End=tmpIOclear;
    end  
    close(fMask)
    % reorganize AFM data like original
    AFMdata_final(1).Channel_name="Height";          AFMdata_final(1).finalData=AFM_EndData_vect.AFM_2_aligned{1};
    AFMdata_final(2).Channel_name="Vertical Force";  AFMdata_final(2).finalData=AFM_EndData_vect.AFM_2_aligned{2};
    AFMdata_final(3).Channel_name="Lateral Force";   AFMdata_final(3).finalData=AFM_EndData_vect.AFM_2_aligned{3};
    % since before alignment BF-IO might have been cropped, crop again TRITIC data. This TRITIC data will be the definitive data that will be used for
    % fluorescence-force correlation. TRITIC data must have same size of AFM_height_IO_End because the latter has been padded to the same size of
    % cropped BF-IO
    if ~isempty(offset)
        TRITICdata_5_final.pre = fixSize(TRITICdata_4_cropped.pre,offset);
        TRITICdata_5_final.post = fixSize(TRITICdata_4_cropped.post,offset);               
    else
        TRITICdata_5_final=TRITICdata_4_cropped;
    end
    save(fullfile(SaveFigFolder,'resultsData_5_AFM_BF_alignment.mat'),"AFM_height_IO_End","BF_Image_IO_End","AFMdata_final","TRITICdata_5_final")    
end
clear BF_Image_IO AFMdata fMask offset AFM_height_IO AFM_StartData_vect AFM_EndData_vect tmp* TRITICdata_4_cropped % BF_Image_IO_End is not needed anymore
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% IF MORE EXPOSURE TIME TRITIC IMAGES EXIST, BETTER ANALYSIS WITH HEIGHT-TRITIC CORRELATION %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<6
    if numel(TRITICdata_5_final.post)~=1
        [TRITIC_Before,TRITIC_After,metaData_NIKON_definitive]=A6_selectExpTimeTRITICImages(TRITICdata_5_final,BF_Image_IO_End,metaData_NIKON,AFMdata_final,AFM_height_IO_End,metaData_AFM,SaveFigFolder,idxMon,nameExperiment,nameScan);
    else
        TRITIC_Before=TRITICdata_5_final.pre{1};
        TRITIC_After=TRITICdata_5_final.post{1};
    end
    if isempty(TRITIC_Before)
        disp("Interrupted. First, process all other scans so the comparison to choose optical parameter can be done.")
        return
    end
    save(fullfile(SaveFigFolder,'resultsData_6_definitiveTRITICdata.mat'),"TRITIC_Before","TRITIC_After")
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% CORRELATION AFM Data - FLUORESCENCE %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if step2Start<7
    Data_finalResults=A7_correlation_AFM_BF(AFM_data_final,AFM_height_IO_final,BF_Image_IO_final,metaData_AFM,metaData_NIKON,idxMon,SaveFigFolder,mainPathOpticalData,timeExp,'TRITIC_before',TRITIC_Before,'TRITIC_after',TRITIC_After,'innerBorderCalc',false);
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
    options2    =   {'(A3) Run next step: prepare BF and TRITIC data','(A2) Redo Assembly-Process AFM data'};
    % if A3_1 (prepare TRITIC and BF data)
    filePostA3_1  =  'resultsData_3_BF_allTRITIC_extractedPreparedAligned.mat';
    question3_1   =   sprintf('(A3) BF and TRITIC images extraction and preparation (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options3_1    =   {'(A4) Run next step: Brightfield Image Binarization','(A3) Redo preparation BF-TRITIC data'};
    % if A3_2 (binarize BF)
    filePostA3_2 =  'resultsData_4_BFbinarized.mat';
    question3_2  =   sprintf('(A4) BF Image Binarization (and eventually TRITIC cropping) (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options3_2   =   {'(A5) Run next step: AFM-BF alignment','(A4) Redo BF binarization'};
    % if A4 (AFM-TRITIC alignment)
    filePostA4  =  'resultsData_5_AFM_BF_alignment.mat';
    question4   =   sprintf('(A5) AFM-BF alignment (Experiment %s - scan #%s) already completed.\nChoose the right option:',nameExperiment,nameScan);
    options4    =  {'(A6) Run next step: Choose right TRITIC Exposure Time.','(A5) AFM-TRITIC alignment'};            

    
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
            [~,nameFile,ext]=fileparts(flagPresenceFile{i}{:});
            fprintf("\nLOADING FILE:\t%s%s\n",nameFile,ext)            
            tmpData=load(flagPresenceFile{i}{:});               
            % move the data on the main workspace (here we are still inside a function, so the variables must be copied outside).
            % no need to delete some vars created here. Only those from tmpData will be copied
            if exist('tmpData','var')
                fieldNamesC = fieldnames(tmpData);
                for j = 1:length(fieldNamesC)
                    assignin('base', fieldNamesC{j}, tmpData.(fieldNamesC{j}));
                end
            else
                error("file doesnt exist!")
            end
        end
    else
        idxLastOperation=0;
    end   
    clc
end
