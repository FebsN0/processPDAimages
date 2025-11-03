function varargout=A6_prepareBFandTRITIC(folderResultsImg,idxMon)
    % Open Brightfield image and the TRITIC (Before and After stimulation images)
    filenameND2='resultA6_1_BrightField'; titleImage='BrightField - original';
    [BF_Mic_Image,metaData_BF,filePathData,fileName]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon);    
    [~, nameOnly, ~] = fileparts(fileName);
    nameLower = lower(nameOnly);    
    % check if filename include word post/after. In this way, it will take
    % the proper TRITIC image when it is compared with the BF 
    if contains(nameLower, 'post') || contains(nameLower, 'after')
        flag_PRE_POST = 1;  % flag post
    else
        flag_PRE_POST = 0;  % flag pre / none
    end

    varargout{1}=metaData_BF;
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
        else
            error('This error occurs when the file .nd2 does not containt time exposure in the filename. part has not prepared. Modify in a second moment. Contact the coder if you have issues.')
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
        % extract the TRITIC data. Note: the two figures that will be saved
        % are scaled differently, so the direct comparison on the images is
        % not correct.
        filenameND2='resultA6_2_TRITIC_Before_Stimulation'; titleImage=sprintf('TRITIC Before Stimulation - timeExp: %s',timeExp);
        Tritic_Mic_Image_Before=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,filePathData,'Before',beforeFiles);               
        filenameND2='resultA6_3_TRITIC_After_Stimulation'; titleImage=sprintf('TRITIC After Stimulation - timeExp: %s',timeExp);
        Tritic_Mic_Image_After=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,filePathData,'After',afterFiles);
        close all       
        
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


function [Image,metaData,filePathData,fileName]=selectND2file(folderResultsImg,filenameND2,titleImage,idxMon,varargin)
    % the function extract the given .nd2 image file and generate the
    % picture with a given title
    % varargin:
    %   - varargin{1} = filePathData : to select a .nd2 file from the same directory in which the current function has been previously
    %                   called (save time instead of selecting files by starting from pwd)
    %   - varargin{2} = mode : string text to give to the selected .nd2 file 
    % beforeFiles
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
    [Image,~,metaData]=A6_feature_Open_ND2(fullfile(filePathData,fileName)); 
    f1=figure('Visible','off');
    imshow(imadjust(Image)), title(titleImage,'FontSize',17)
    objInSecondMonitor(f1,idxMon);
    fullfileName=fullfile(folderResultsImg,'tiffImages',filenameND2);
    saveas(f1,fullfileName,'tif')
    fullfileName=fullfile(folderResultsImg,'figImages',filenameND2);
    saveas(f1,fullfileName)
end