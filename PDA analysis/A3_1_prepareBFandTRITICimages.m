function varargout=A3_1_prepareBFandTRITICimages(folderResultsImg,idxMon,groupExperiment,nameExperiment,nameScan,varargin)
% flag_BF_PRE_POST is for alignment between BF pre and BF post, rather than BF pre and TRITIC post
    p=inputParser();
    argName = 'pathOpticalImages';         defaultVal = [];        addOptional(p,argName,defaultVal);
    argName = 'postHeatProcessing';        defaultVal = false;     addOptional(p,argName,defaultVal, @(x) islogical(x));
    parse(p,varargin{:});
    text=sprintf("Select the directory having all .nd2 files for EXP %s - %s - SCAN %s",groupExperiment,nameExperiment,nameScan);
    if isempty(p.Results.pathOpticalImages)        
        filePathND2=uigetdir(pwd,text);
    else
        filePathND2=uigetdir(p.Results.pathOpticalImages,text);
    end
    postHeat=p.Results.postHeatProcessing;
    clear argName text defaultVal p varargin
    if exist(fullfile(filePathND2,"BFdata.mat"),"file")
        load(fullfile(filePathND2,"BFdata.mat"),"metadata","Image_BF","flag_BF_PRE_POST")            
    else        
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
                    filenameND2='resultA3_1_1_BrightField_preAFM';
                    [BF_ImagePRE,metaData_BF]=selectND2file( ...
                        'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                        'titleImage','BrightField - original - preAFM','typeImage','BrightField','mode','Before');
                    flag_BF_PRE_POST = 0;
                else
                    filenameND2='resultA3_1_2_BrightField_postAFM';
                    BF_ImagePOST=selectND2file( ...
                        'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                        'titleImage','BrightField - original - postAFM','typeImage','BrightField','mode','After');
                    flag_BF_PRE_POST = 1;
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
            filenameND2='resultA3_1_1_BrightField_preAFM'; 
            [BF_ImagePRE,metaData_BF]=selectND2file('fullfilePath',fullfilePath,...
                'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                'titleImage','BrightField - original - preAFM');
            % if exist, extract postAFM BF acquisition
            if any(contains(fileBF, {'post','after'}))            
                idxBFmode=contains(fileBF, {'post','after'});
                afterFiles=fileBF(idxBFmode);
                fullfilePath=fullfile(filePathND2,afterFiles{:});
                filenameND2='resultA3_1_2_BrightField_postAFM';
                BF_ImagePOST=selectND2file('fullfilePath',fullfilePath,...
                    'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                    'titleImage','BrightField - original - postAFM','mode','After');
                flag_BF_PRE_POST = 1;  % flag post
            else            
                flag_BF_PRE_POST = 0;
            end
        end
        metadata=struct();
        metadata.BF=metaData_BF;
        % correct the tilted effect of BF 
        nameFile='resultA3_2_1_comparisonOriginalCorrected_beforeAFM';
        titleImageOriginal="Original BF image (PRE-AFM)";
        titleImageCorrected="Corrected BF Image";
        BF_ImagePRE = correctArtifacts(BF_ImagePRE,idxMon,folderResultsImg,nameFile,titleImageOriginal,titleImageCorrected);
        if exist("BF_ImagePOST","var")
            nameFile='resultA3_2_2_comparisonOriginalCorrected_afterAFM';
            titleImageOriginal="Original BF image (POST-AFM)";
            BF_ImagePOST = correctArtifacts(BF_ImagePOST,idxMon,folderResultsImg,nameFile,titleImageOriginal,titleImageCorrected);
        end

        Image_BF.pre=BF_ImagePRE;
        if ~postHeat
            Image_BF.post=BF_ImagePOST;
        end
        save(fullfile(filePathND2,"BFdata"),"metadata","Image_BF","flag_BF_PRE_POST")
    end
    clear patternBF beforeFiles fileBF filenameND2 fullfilePath afterFiles idxBFmode idxBF matches metaData_BF titleImage
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% EXTRACT TRITIC IMAGES %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    if exist(fullfile(filePathND2,"TRITICdata.mat"),"file")
        load(fullfile(filePathND2,"TRITICdata.mat"),"metadata","Images_TRITIC")            
    else     
        fileList = dir(fullfile(filePathND2, '*.nd2'));
        pattern = '(?i)(?<=TRITIC\w*)\d+(?=ms)';  
        matches= regexp({fileList.name}, pattern, 'match');   % returns cell array, each cell may be empty or a cell array of matches
        matches = [matches{:}];                    % concatenates all matches found
        timeValues = sort(unique(str2double(matches(:))));
        timeList = cellstr(string(timeValues));    
        if ~isempty(timeList)
            % prepare cell array where to store image and metadata of all expTime. If postHeat, just 1 at 3rd dimention
            allMetadata_TRITIC_pre=cell(size(timeList));
            allExpTime_TRITIC_pre=cell(size(timeList));
            if ~postHeat
                allMetadata_TRITIC_post=cell(size(timeList));
                allExpTime_TRITIC_post=cell(size(timeList));
            end
        else
            error('This error occurs when the file .nd2 does not containt time exposure in the filename. part has not prepared. Modify in a second moment. Contact the coder if you have issues.')
        end
        time_th=1;
        % in case of postHeat=true, then extract TRITIC of each nd2 file in function of available exposure time
        while true
            timeExp=timeList{time_th};
            % select the files with the choosen time exposure
            matchingFiles = {fileList(contains({fileList.name}, [timeExp, 'ms'])).name};
            % auto selection. put into cell array
            beforeFiles = matchingFiles(contains(matchingFiles, {'pre','before'}, 'IgnoreCase', true));
            afterFiles = matchingFiles(contains(matchingFiles, {'post', 'after'}, 'IgnoreCase', true));        
            % in case of normal processing, TRITIC after and before AFM scan is mandatory. So, further check. If not found, return error
            if ~postHeat && (isempty(beforeFiles) || isempty(afterFiles))
                error('Issues in finding the files. Check the filenames naming. Must be in the format TRITIC<pre/before/after/post>_<number>ms..');  
            end
            % extract the TRITIC data. Note: the two figures that will be saved
            % are scaled differently, so the direct comparison on the images is not correct.
            beforeFiles=fullfile(filePathND2,beforeFiles);    
            if ~postHeat
                afterFiles=fullfile(filePathND2,afterFiles);
            end                            
            % since there may lot of TRITIC images at different exp time, save memory and data processing time
            for i=1:length(beforeFiles)
                % each column represent different condition at the same exposure time, usually different gain
                [Image_TRITIC,metaData_TRITIC]=selectND2file('fullfilePath',beforeFiles{i},'saveFig',false);                     
                allMetadata_TRITIC_pre{time_th,i}=metaData_TRITIC;
                allExpTime_TRITIC_pre{time_th,i}=Image_TRITIC;
                if ~postHeat
                    [Image_TRITIC,metaData_TRITIC]=selectND2file('fullfilePath',afterFiles{i},'saveFig',false);    
                    allMetadata_TRITIC_post{time_th,i}=metaData_TRITIC;
                    allExpTime_TRITIC_post{time_th,i}=Image_TRITIC;
                end
            end             
            time_th=time_th+1;
            if time_th>length(timeList)
                metadata.TRITIC.pre=allMetadata_TRITIC_pre;
                Images_TRITIC.pre=allExpTime_TRITIC_pre;
                if ~postHeat
                    metadata.TRITIC.post=allMetadata_TRITIC_post;
                    Images_TRITIC.post=allExpTime_TRITIC_post;
                end                    
                save(fullfile(filePathND2,"TRITICdata"),"metadata","Images_TRITIC",'-v7.3')
                break
            end     
        end        
    end
    % prepare the output data
    [mainPathOpticalData,~]=fileparts(fileparts(fileparts(filePathND2)));
    varargout{1}=metadata;
    varargout{2}=Image_BF;   
    varargout{3}=Images_TRITIC;
    varargout{4}=flag_BF_PRE_POST;
    varargout{5}=mainPathOpticalData;            
end


function [Image,metaData]=selectND2file(varargin)
% the function extract the given .nd2 image file and generate the picture with a given title
    p=inputParser();
    argName = 'titleImage';         defaultVal = [];            addOptional(p,argName,defaultVal);    
    argName = 'typeImage';          defaultVal = 'BrightField'; addOptional(p,argName,defaultVal,@(x) ismember(x,{'BrightField','TRITIC'}));  % Brightfield or TRITIC
    argName = 'mode';               defaultVal = 'Before';      addOptional(p,argName,defaultVal,@(x) ismember(x,{'Before','After','Empty'}));  % Before or After
    argName = 'fullfilePath';       defaultVal = [];            addOptional(p,argName,defaultVal);
    argName = 'saveFig';            defaultVal = true;          addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'idxMon';             defaultVal = [];            addOptional(p,argName,defaultVal);  
    argName = 'folderResultsImg';   defaultVal = [];            addOptional(p,argName,defaultVal);  
    argName = 'filenameND2';        defaultVal = [];            addOptional(p,argName,defaultVal);  
    parse(p,varargin{:});   
    fullfilePath=p.Results.fullfilePath;
    if isempty(fullfilePath)
        text= sprintf('Select the %s Image%s AFM acquisition',p.Results.typeImage,p.Results.mode);
        [fileName, filePathData] = uigetfile({'*.nd2'},text);
        fullfilePath=fullfile(filePathData,fileName);
    end
    [Image,~,metaData]=A3_feature_Open_ND2(fullfilePath);
    if p.Results.saveFig
        showData(p.Results.idxMon,false,imadjust(Image),sprintf("%s - imadjusted",p.Results.titleImage),p.Results.folderResultsImg,p.Results.filenameND2,'noLabels',true,'grayscale',true)  
    end
end
    
function imageCorr = correctArtifacts(image,idxMon,folderResultsImg,nameFile,titleImageOriginal,titleImageCorrected)  
    % the function aim to correct the artifact of tilted effect: always present
    % the function Nplanefitter hasnt been used because it resulted more distorted results especially for binarization
    x_Bk=1:size(image,2);
    y_Bk=1:size(image,1);
    % Prepare data inputs for surface fitting, similar to prepareCurveData but 3D. Transform the 2D image
    % into 3 arrays:
    % xData = 1 1 .. 1 2 .. etc = each block is long #row length of image
    % yData = 1 2 .. length(image) 1 2 .. etc
    [xData, yData, zData] = prepareSurfaceData( x_Bk, y_Bk, image );
    ft = fittype( 'poly11' );
    [fitresult, ~] = fit( [xData, yData], zData, ft );
    fit_surf=zeros(size(y_Bk,2),size(x_Bk,2));
    y_Bk_surf=repmat(y_Bk',1,size(x_Bk,2))*fitresult.p01;
    x_Bk_surf=repmat(x_Bk,size(y_Bk,2),1)*fitresult.p10;
    fit_surf=plus(min(min(image)),fit_surf);
    fit_surf=plus(y_Bk_surf,fit_surf);
    fit_surf=plus(x_Bk_surf,fit_surf);
    imageCorr=minus(image,fit_surf);
    showData(idxMon,false,imadjust(image),titleImageOriginal,folderResultsImg,nameFile,'extraData',imadjust(imageCorr),'extraTitles',titleImageCorrected,'noLabels',true,'grayscale',true)
end

       