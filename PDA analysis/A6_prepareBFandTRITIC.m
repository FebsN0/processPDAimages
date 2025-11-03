function varargout=A6_prepareBFandTRITIC(folderResultsImg,idxMon,nameExperiment,nameScan)
% flag_PRE_POST is for alignment between BF pre and BF post, rather than BF pre and TRITIC post

    text=sprintf("Select the directory having all .nd2 files for EXP %s - SCAN %s",nameExperiment,nameScan);
    filePathND2=uigetdir(pwd,text);
    % .nd2 files inside dir
    fileList = dir(fullfile(filePathND2, '*.nd2'));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% EXTRACT BRIGHTFIELD IMAGES %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % find all BF files having BF in the filename
    patternBF= 'BF';
    matches = regexp({fileList.name}, patternBF, 'match');
    idxBF=~cellfun(@isempty,matches);
    % in case there are no files with BF in the filename of the files, then
    % manual selection
    if nnz(idxBF)==0 
        i=1;
        while true
            if i==1
                mode='Before'; filenameND2='resultA6_1_1_BrightField_preAFM'; titleImage='BrightField - original - preAFM';
                [BF_ImagePRE,metaData_BF]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,'BrightField',mode);
                flag_PRE_POST = 0;
            else
                mode='After'; filenameND2='resultA6_1_2_BrightField_postAFM'; titleImage='BrightField - original - postAFM';
                BF_ImagePOST=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,fullfilePath);
                flag_PRE_POST = 1;
            end
            
            if getValidAnswer("End the selection of BF files?",'',{'y','n'}) || i>2
                break
            end
        end
    else
        fileBF={fileList(idxBF).name}; folderBF={fileList(idxBF).folder};
        % extract preAFM BF acquisition 
        if isscalar(fileBF)
            beforeFiles=fileBF;
        elseif any(contains(fileBF, {'pre','before'}))
            idxBFmode=contains(fileBF, {'pre','before'});
            beforeFiles=fileBF(idxBFmode);
        end        
        fullfilePath=fullfile(filePathND2,beforeFiles{:});
        filenameND2='resultA6_1_1_BrightField_preAFM'; titleImage='BrightField - original - preAFM';
        [BF_ImagePRE,metaData_BF]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,fullfilePath); 
        % if exist, extract postAFM BF acquisition
        if any(contains(fileBF, {'post','after'}))            
            idxBFmode=contains(fileBF, {'post','after'});
            afterFiles=fileBF(idxBFmode);
            fullfilePath=fullfile(filePathND2,afterFiles{:});
            filenameND2='resultA6_1_2_BrightField_postAFM'; titleImage='BrightField - original - postAFM';
            BF_ImagePOST=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,fullfilePath);
            flag_PRE_POST = 1;  % flag post
        else            
            flag_PRE_POST = 0;
        end
    end
    metadata=struct();
    metadata.BF=metaData_BF;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% EXTRACT TRITIC IMAGES %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
    pattern = '(?i)(?<=TRITIC\w*)\d+(?=ms)';  
    matches= regexp({fileList.name}, pattern, 'match');   % returns cell array, each cell may be empty or a cell array of matches
    matches = [matches{:}];                    % concatenates all matches found
    timeValues = sort(unique(str2double(matches(:))));
    timeList = cellstr(string(timeValues));    
    if ~isempty(timeList)
        timeExp=timeList{getValidAnswer('What exposure time do you want to take?','',timeList)};
    else
        error('This error occurs when the file .nd2 does not containt time exposure in the filename. part has not prepared. Modify in a second moment. Contact the coder if you have issues.')
    end
    % select the files with the choosen time exposure
    matchingFiles = {fileList(contains({fileList.name}, [timeExp, 'ms'])).name};
    % auto selection
    beforeFiles = matchingFiles(contains(matchingFiles, {'pre','before'}, 'IgnoreCase', true));
    afterFiles = matchingFiles(contains(matchingFiles, {'post', 'after'}, 'IgnoreCase', true));        
    % in case not found, manual selection
    if isempty(beforeFiles) || isempty(afterFiles)
        error('Issues in finding the files. Check the filenames');  
    % in case there are multiple file with same timeExp ==> for example, because of different Gain
    elseif length(beforeFiles)==2 || length(afterFiles)==2
         selectedOptions = selectOptionsDialog("Multiple file with same timeExp. Which select?",beforeFiles,afterFiles);
         beforeFiles=selectedOptions{1};
         afterFiles=selectedOptions{2};
    end
    % extract the TRITIC data. Note: the two figures that will be saved
    % are scaled differently, so the direct comparison on the images is
    % not correct.
    beforeFiles=fullfile(filePathND2,beforeFiles{:});
    afterFiles=fullfile(filePathND2,afterFiles{:});        
    filenameND2='resultA6_2_1_TRITIC_Before_Stimulation'; titleImage=sprintf('TRITIC Before Stimulation - timeExp: %s',timeExp);
    [Tritic_Mic_Image_Before,metaData_TRITIC]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,beforeFiles);               
    filenameND2='resultA6_2_2_TRITIC_After_Stimulation'; titleImage=sprintf('TRITIC After Stimulation - timeExp: %s',timeExp);
    Tritic_Mic_Image_After=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,afterFiles);
    close all       
    metadata.TRITIC=metaData_TRITIC;
    % correct the tilted effect of BF
    BF_ImagePRE = A6_feature_correctBFtilted(BF_ImagePRE,folderResultsImg,idxMon,1);
    if exist("BF_ImagePOST","var")
        BF_ImagePOST = A6_feature_correctBFtilted(BF_ImagePOST,folderResultsImg,idxMon,2);
    end
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% ALIGN BF-TRITIC IMAGES PRE AND POST AFM %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % if there are BFpre and BFpost, alignment on these two only. Otherwise
    % keep the original method (i.e. two separate alignments) 
    %       TRITIC_After WITH TRITIC_Before
    %       BF with TRITIC_Before
    if flag_PRE_POST
        [Tritic_Mic_Image_After_aligned,offset]=A7_limited_registration(BF_ImagePOST,BF_ImagePRE,folderResultsImg,idxMon);
    end

    
    while true          
        BF_Mic_Image_original=BF_Mic_Image;            
        % Align the fluorescent images After with the BEFORE stimulation
        [Tritic_Mic_Image_After_aligned,offset]=A7_limited_registration(Tritic_Mic_Image_After,Tritic_Mic_Image_Before,folderResultsImg,idxMon);
        % adjust BF and Tritic_Before depending on the offset
        BF_Mic_Image=fixSize(BF_Mic_Image,offset);
        Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);   
        % Align the Brightfield to TRITIC Before Stimulation
        if flag_PRE_POST
            [BF_Mic_Image_aligned,offset]=A7_limited_registration(BF_Mic_Image,Tritic_Mic_Image_After_aligned,folderResultsImg,idxMon,'Brightfield','Yes','Moving','Yes','typeTritic',flag_PRE_POST);                
        else
            [BF_Mic_Image_aligned,offset]=A7_limited_registration(BF_Mic_Image,Tritic_Mic_Image_Before,folderResultsImg,idxMon,'Brightfield','Yes','Moving','Yes');                
        end
        Tritic_Mic_Image_After_aligned=fixSize(Tritic_Mic_Image_After_aligned,offset);
        Tritic_Mic_Image_Before=fixSize(Tritic_Mic_Image_Before,offset);
        varargout{1}=metadata;
        varargout{2}=BF_Mic_Image_aligned;                
        varargout{3}=Tritic_Mic_Image_After_aligned;        
        varargout{4}=Tritic_Mic_Image_Before;

        [mainPathOpticalData,~]=fileparts(fileparts(fileparts(filePathData)));
        varargout{5}=mainPathOpticalData;
        varargout{6}=timeExp;
        if getValidAnswer(sprintf('Satisfied of all the registration of BF and fluorescence image?\nIf not, change time exposure for better alignment'),'',{'Yes','No'})
            close gcf
            break
        end
        % in case of no satisfaction, restore original data
        BF_Mic_Image=BF_Mic_Image_original;
        close all
    end
end



function [Image,metaData]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,varargin)
    % the function extract the given .nd2 image file and generate the picture with a given title
    % varargin:
    %   - if two elements ==> typeImage and Mode ====> MANUAL SELECTION
    %   - if 1 element    ==> already selected .nd2 file
    
    if length(varargin)==2
        typeImage = varargin{1}; % Brightfield or TRITIC
        mode = varargin{2};      % Before or After
        text= sprintf('Select the %s Image %s AFM acquisition',typeImage,mode);
        [fileName, filePathData] = uigetfile({'*.nd2'},text);
        fullfilePath=fullfile(filePathData,fileName);
    else
        fullfilePath=varargin{1};    % location of the file
    end
    [Image,~,metaData]=A6_feature_Open_ND2(fullfilePath); 
    f1=figure('Visible','off');
    imshow(imadjust(Image)), title(titleImage,'FontSize',17)
    objInSecondMonitor(f1,idxMon);
    fullfileName=fullfile(folderResultsImg,'tiffImages',filenameND2);
    saveas(f1,fullfileName,'tif')
    fullfileName=fullfile(folderResultsImg,'figImages',filenameND2);
    saveas(f1,fullfileName)
end