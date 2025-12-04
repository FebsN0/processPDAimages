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
                BF_ImagePOST=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,'BrightField',mode);
                flag_PRE_POST = 1;
            end            
            if getValidAnswer("End the selection of BF files?",'',{'y','n'}) || i>2
                break
            end
        end
    else
        fileBF={fileList(idxBF).name};
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
    [TRITIC_ImagePRE,metaData_TRITIC]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,beforeFiles);               
    filenameND2='resultA6_2_2_TRITIC_After_Stimulation'; titleImage=sprintf('TRITIC After Stimulation - timeExp: %s',timeExp);
    TRITIC_ImagePOST=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,afterFiles);
    close all       
    metadata.TRITIC=metaData_TRITIC;
    % correct the tilted effect of BF
    pathFile=sprintf('%s/tiffImages/resultA6_3_1_comparisonOriginalCorrected_beforeAFM',folderResultsImg);
    BF_ImagePRE = A6_feature_correctBFtilted(BF_ImagePRE,idxMon,pathFile);
    if exist("BF_ImagePOST","var")
        pathFile=sprintf('%s/tiffImages/resultA6_3_2_comparisonOriginalCorrected_afterAFM',folderResultsImg);
        BF_ImagePOST = A6_feature_correctBFtilted(BF_ImagePOST,idxMon,pathFile);
    end
    % original images are not aligned
    showAlignOriginalImages(BF_ImagePRE,TRITIC_ImagePRE,folderResultsImg,'BF preAFM and TRITIC preAFM - pre alignement with postAFM','resultA7_0_1_BFpre_TRITICpre_preAlign',idxMon)    
    showAlignOriginalImages(TRITIC_ImagePRE,TRITIC_ImagePOST,folderResultsImg,'TRITIC preAFM and TRITIC postAFM - Not Aligned','resultA7_0_2_TRITIC_prePost_NotAligned',idxMon)
    showAlignOriginalImages(BF_ImagePRE,TRITIC_ImagePOST,folderResultsImg,'BF preAFM and TRITIC postAFM - Not Aligned','resultA7_0_3_BFpre_TRITICpost_NotAligned',idxMon)
    if exist('BF_ImagePOST','var')
        showAlignOriginalImages(BF_ImagePRE,BF_ImagePOST,folderResultsImg,'BF preAFM and BF postAFM - Not Aligned','resultA7_0_4_BF_prePost_NotAligned',idxMon)
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% ALIGN BF-TRITIC IMAGES PRE AND POST AFM %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % if there are BFpre and BFpost, alignment on these two only. Otherwise
    % keep the original method (i.e. two separate alignments) 
    %       TRITIC_After WITH TRITIC_Before
    %       BF with TRITIC_Before
    
    flagRepeatAlignWithTRITIC=true;
    if flag_PRE_POST
        % align BF_post to BF_pre. Then shift TRITIC_post with the obtained
        % offset. Required BF_ImagePRE_adjusted because of cutting borders
        % of BF_ImagePOST_aligned for alignment
        [BF_ImagePOST_aligned,BF_ImagePRE_aligned,offset]=A7_BF_TRITIC_imageAlignment(BF_ImagePOST,BF_ImagePRE,folderResultsImg,idxMon,'Brightfield','Yes');
        % fix TRITIC pre to BF pre
        TRITIC_ImagePRE_aligned=fixSize(TRITIC_ImagePRE,offset);
        TRITIC_ImagePOST_aligned=fixSize(TRITIC_ImagePOST,-offset);   % for some reason, put minus sign return correct alignment. Not sure if it works always
        showAlignOriginalImages(TRITIC_ImagePRE_aligned,TRITIC_ImagePOST_aligned,folderResultsImg,'TRITIC preAFM and TRITIC postAFM - PostAlignement','resultA7_1_2_TRITICpre_TRITICpost_postAlign',idxMon,'visible',true,'closeImmediately',false)           
        if any(size(TRITIC_ImagePOST_aligned)~=size(BF_ImagePOST_aligned))
            uiwait(msgbox('Something wrong in the correction matrix of TRITICpost because its matrix size is not the same as BFpost. Repeat the alignment using TRITICpre and TRITICpost','Warning','warn'));
        elseif getValidAnswer(sprintf('Is the registration of TRITICpre and TRITICpost postAlign ok?'),'',{'Yes','No'})
            close gcf
            flagRepeatAlignWithTRITIC=false;        
        end
    end
    if ~flag_PRE_POST && flagRepeatAlignWithTRITIC
        % Align the fluorescent images After with the BEFORE stimulation
        [TRITIC_ImagePOST_aligned,TRITIC_ImagePRE_aligned,offset]=A7_BF_TRITIC_imageAlignment(TRITIC_ImagePOST,TRITIC_ImagePRE,folderResultsImg,idxMon);        
        BF_ImagePRE_aligned=fixSize(BF_ImagePRE,offset);
        if flag_PRE_POST
            BF_ImagePOST_aligned=fixSize(BF_ImagePOST,-offset);
            showAlignOriginalImages(BF_ImagePRE_aligned,BF_ImagePOST_aligned,folderResultsImg,'BF preAFM and BF postAFM - PostAlignement','resultA7_1_2_BFpre_BFpost_postAlign',idxMon)                                   
        end
    end
    % END ALIGNMENT!
    showAlignOriginalImages(BF_ImagePRE_aligned,TRITIC_ImagePRE_aligned,folderResultsImg,'BF preAFM and TRITIC preAFM - PostAlignement','resultA7_2_1_BFpre_TRITICpre_postAlign',idxMon)               
    showAlignOriginalImages(BF_ImagePRE_aligned,TRITIC_ImagePOST_aligned,folderResultsImg,'BF preAFM and TRITIC postAFM - PostAlignement','resultA7_2_2_BFpre_TRITICpost_postAlign',idxMon)               

    if flag_PRE_POST
        showAlignOriginalImages(BF_ImagePOST_aligned,TRITIC_ImagePOST_aligned,folderResultsImg,'BF postAFM and TRITIC postAFM - PostAlignement','resultA7_2_3_BFpost_TRITICpost_postAlign',idxMon)                                     
    end
    
    
    % prepare the output data
    [mainPathOpticalData,~]=fileparts(fileparts(fileparts(filePathND2)));
    varargout{1}=metadata;      varargout{2}=mainPathOpticalData;       varargout{3}=timeExp;
    % put BF and TRITIC data in struct
    data_TRITIC.PRE=TRITIC_ImagePRE_aligned;        data_TRITIC.POST=TRITIC_ImagePOST_aligned;    
    data_BF.PRE=BF_ImagePRE_aligned;    
    if flag_PRE_POST
        data_BF.POST=BF_ImagePOST_aligned;
    end
    varargout{4}=data_TRITIC;
    varargout{5}=data_BF;
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

function showAlignOriginalImages(image1,image2,folderResultsImg,titleText,fileText,idxMon,varargin)
    p=inputParser();
    argName = 'visible';            defaultVal = false;      addParameter(p, argName, defaultVal);
    argName = 'closeImmediately';   defaultVal = true;      addParameter(p, argName, defaultVal);
    parse(p,varargin{:})
    
    if p.Results.visible
        f2=figure('Visible','on');
    else
        f2=figure('Visible','off');
    end
    imshow(imfuse(imadjust(image1),imadjust(image2)))
    title(titleText,'FontSize',15)
    objInSecondMonitor(f2,idxMon);
    fullfileName=fullfile(folderResultsImg,'tiffImages',fileText);
    saveas(f2,fullfileName,'tif')
    fullfileName=fullfile(folderResultsImg,'figImages',fileText);
    saveas(f2,fullfileName)
    if p.Results.closeImmediately
        close(f2)
    end    
end
       