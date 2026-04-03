function varargout=A3_prepareBFandTRITICimages(folderResultsImg,idxMon,groupExperiment,nameExperiment,nameScan,varargin)
% flag_PRE_POST is for alignment between BF pre and BF post, rather than BF pre and TRITIC post
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
        load(fullfile(filePathND2,"BFdata.mat"),"metadata","BF_ImagePRE","BF_ImagePOST","flag_PRE_POST","fileList")            
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
                    flag_PRE_POST = 0;
                else
                    filenameND2='resultA3_1_2_BrightField_postAFM';
                    BF_ImagePOST=selectND2file( ...
                        'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                        'titleImage','BrightField - original - postAFM','typeImage','BrightField','mode','After');
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
                flag_PRE_POST = 1;  % flag post
            else            
                flag_PRE_POST = 0;
            end
        end
        metadata=struct();
        metadata.BF=metaData_BF;
        % correct the tilted effect of BF
        BF_ImagePRE = A3_feature_correctBFtilted(BF_ImagePRE,idxMon,folderResultsImg,'resultA3_3_1_comparisonOriginalCorrected_beforeAFM');
        if exist("BF_ImagePOST","var")
            BF_ImagePOST = A3_feature_correctBFtilted(BF_ImagePOST,idxMon,folderResultsImg,'resultA3_3_2_comparisonOriginalCorrected_afterAFM');
        else
            BF_ImagePOST=[];
        end
        save(fullfile(filePathND2,"BFdata"),"metadata","BF_ImagePRE","BF_ImagePOST","flag_PRE_POST","fileList")
    end
    clear patternBF beforeFiles fileBF filenameND2 fullfilePath afterFiles idxBFmode idxBF matches metaData_BF titleImage
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% EXTRACT TRITIC IMAGES %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
    if exist(fullfile(filePathND2,"TRITICdata.mat"),"file")
        if postHeat
            load(fullfile(filePathND2,"TRITICdata.mat"),"metadata","allImage_TRITIC")   
        else
            load(fullfile(filePathND2,"TRITICdata.mat"),"metadata","TRITIC_ImagePRE","TRITIC_ImagePOST")            
        end
    else 
        flagSubfolders=false;
        allFiles=dir(fullfile(filePathND2));
        dirsIDX=[allFiles.isdir];
        subDirs= allFiles(dirsIDX);
        subDirs = subDirs(3:end);        % skip . and ..
        % additional subfolder where there are files
        if length(fileList)==2 && ~isempty(subDirs)
            question=sprintf("There are only two .nd2 files (likely BF images) but %d subfolders.\nIf more subfolders, which one to take and explore inside automatically?",length(subDirs));
            options=cell(1,length(subDirs));
            for i=1:length(subDirs)
                options{i}=sprintf("Subfolder %s",subDirs(i).name);
            end
            choice=getValidAnswer(question,'',options);
            subDirName=options{choice};
            filePathND2_sub=fullfile(filePathND2,subDirs(choice).name);
            fileList = dir(fullfile(filePathND2_sub, '*.nd2'));
            flagSubfolders=true;
        end
        pattern = '(?i)(?<=TRITIC\w*)\d+(?=ms)';  
        matches= regexp({fileList.name}, pattern, 'match');   % returns cell array, each cell may be empty or a cell array of matches
        matches = [matches{:}];                    % concatenates all matches found
        timeValues = sort(unique(str2double(matches(:))));
        timeList = cellstr(string(timeValues));    
        if ~isempty(timeList)
            if ~postHeat
                timeExp=timeList{getValidAnswer('What exposure time do you want to take?','',timeList)};
            else
                % prepare cell array where to store image and metadata of all expTime
                allMetadata_TRITIC=cell(size(timeList));
                allImage_TRITIC=cell(size(timeList));
            end
        else
            error('This error occurs when the file .nd2 does not containt time exposure in the filename. part has not prepared. Modify in a second moment. Contact the coder if you have issues.')
        end
        time_th=1;
        % in case of postHeat=true, then extract TRITIC of each nd2 file in function of available exposure time
        while true
            if postHeat
                timeExp=timeList{time_th};
            end
            % select the files with the choosen time exposure
            matchingFiles = {fileList(contains({fileList.name}, [timeExp, 'ms'])).name};
            % auto selection. put into cell array
            beforeFiles = matchingFiles(contains(matchingFiles, {'pre','before'}, 'IgnoreCase', true));
            afterFiles = matchingFiles(contains(matchingFiles, {'post', 'after'}, 'IgnoreCase', true));        
            % in case of normal processing, TRITIC after and before AFM scan is mandatory. So, further check. If not found, return error
            if ~postHeat && (isempty(beforeFiles) || isempty(afterFiles))
                error('Issues in finding the files. Check the filenames naming. Must be in the format TRITIC<pre/before/after/post>_<number>ms..');  
            % in case there are multiple file with same timeExp ==> for example, because of different Gain all saved in the same directory. Otherwise
            % pick all of them for further analysis
            elseif ~postHeat && (length(beforeFiles)~=1 || length(afterFiles)~=1)
                 selectedOptions = selectOptionsDialog("Multiple file with same timeExp. Which select?",false,beforeFiles,afterFiles);
                 % cell array into string
                 beforeFiles=beforeFiles{selectedOptions{1}};
                 afterFiles=afterFiles{selectedOptions{2}};
            end
            % extract the TRITIC data. Note: the two figures that will be saved
            % are scaled differently, so the direct comparison on the images is
            % not correct.
            if flagSubfolders
                beforeFiles=fullfile(filePathND2_sub,beforeFiles{:});            
                if ~postHeat
                    titleImagePRE=sprintf('TRITIC Before Stimulation - timeExp: %s - %s',timeExp,subDirName);
                    titleImagePOST=sprintf('TRITIC After Stimulation - timeExp: %s - %s',timeExp,subDirName);
                    afterFiles=fullfile(filePathND2_sub,afterFiles{:});
                end           
            else
                beforeFiles=fullfile(filePathND2,beforeFiles);            
                if ~postHeat
                    afterFiles=fullfile(filePathND2,afterFiles);  
                    titleImagePRE=sprintf('TRITIC Before Stimulation - timeExp: %s',timeExp);
                    titleImagePOST=sprintf('TRITIC After Stimulation - timeExp: %s',timeExp);
                end                       
            end            
            filenameND2='resultA3_2_1_TRITIC_Before_Stimulation';
            % since there may lot of TRITIC images at different exp time, save memory and data processing time
            if postHeat
                for i=1:length(beforeFiles)
                    % each column represent different condition at the same exposure time, usually different gain
                    [TRITIC_ImagePRE,metaData_TRITIC]=selectND2file('fullfilePath',beforeFiles{i},'saveFig',false);     
                    allMetadata_TRITIC{time_th,i}=metaData_TRITIC;
                    allImage_TRITIC{time_th,i}=TRITIC_ImagePRE;
                end             
                time_th=time_th+1;
                if time_th>length(allImage_TRITIC)
                    metadata.TRITIC=allMetadata_TRITIC;
                    save(fullfile(filePathND2,"TRITICdata"),"metadata","allImage_TRITIC",'-v7.3')
                    break
                end
            else
                % in case of normal scan, a specific exposure time and gain have been selected, therefore there will be just one TRITICpost and one TRITICpre
                [TRITIC_ImagePRE,metaData_TRITIC]=selectND2file('fullfilePath',beforeFiles,...
                        'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                        'titleImage',titleImagePRE,'typeImage','TRITIC');
                filenameND2='resultA3_2_2_TRITIC_After_Stimulation'; 
                TRITIC_ImagePOST=selectND2file('fullfilePath',afterFiles,...
                        'folderResultsImg',folderResultsImg,'filenameND2',filenameND2,'idxMon',idxMon, ...
                        'titleImage',titleImagePOST,'typeImage','TRITIC','mode','After');
                metadata.TRITIC=metaData_TRITIC;
                save(fullfile(filePathND2,"TRITICdata"),"metadata","TRITIC_ImagePRE","TRITIC_ImagePOST")
                break
            end        
        end
    end
    if ~postHeat
        % original images are not aligned. This part is only for AFM normal scans
        showAlignOriginalImages(BF_ImagePRE,TRITIC_ImagePRE,folderResultsImg,'BF preAFM and TRITIC preAFM','resultA3_4_BFpre_TRITICpre',idxMon)    
        if flag_PRE_POST
            showAlignOriginalImages(BF_ImagePOST,TRITIC_ImagePOST,folderResultsImg,'BF postAFM and TRITIC postAFM','resultA3_5_BFpost_TRITICpost',idxMon)
            showAlignOriginalImages(BF_ImagePRE,BF_ImagePOST,folderResultsImg,'BF preAFM and BF postAFM - Not Aligned','resultA3_6_1_BF_prePost_NotAligned',idxMon)            
        end
        showAlignOriginalImages(TRITIC_ImagePRE,TRITIC_ImagePOST,folderResultsImg,'TRITIC preAFM and TRITIC postAFM - Not Aligned','resultA3_7_1_TRITIC_prePost_NotAligned',idxMon)
        
        if flag_PRE_POST
            save(fullfile(folderResultsImg,"TMP_BF_TRITIC_rawFiles.mat"),"flag_PRE_POST","filePathND2","BF_ImagePOST","BF_ImagePRE","TRITIC_ImagePRE","TRITIC_ImagePOST","metadata","timeExp")
        else
            save(fullfile(folderResultsImg,"TMP_BF_TRITIC_rawFiles.mat"),"flag_PRE_POST","filePathND2","BF_ImagePRE","TRITIC_ImagePRE","TRITIC_ImagePOST","metadata","timeExp")
        end
    end
    clear fileList
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% ALIGN BF-TRITIC IMAGES PRE AND POST AFM (for normal AFM scans) %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~postHeat
        % if there are BFpre and BFpost, alignment on these two only. Otherwise
        % keep the original method (i.e. two separate alignments) 
        %       TRITIC_After WITH TRITIC_Before
        %       BF with TRITIC_Before
        if flag_PRE_POST
            flagRepeatAlignWithTRITIC=true;
            % align BF_post to BF_pre. Then shift TRITIC_post with the obtained
            % offset. Required BF_ImagePRE_adjusted because of cutting borders
            % of BF_ImagePOST_aligned for alignment
            [BF_ImagePOST_aligned,BF_ImagePRE_aligned,offset]=A3_feature_BF_TRITIC_imageAlignment(BF_ImagePOST,BF_ImagePRE,idxMon,'Brightfield','Yes');
            % fix TRITIC pre to BF pre
            TRITIC_ImagePRE_aligned=fixSize(TRITIC_ImagePRE,offset);
            TRITIC_ImagePOST_aligned=fixSize(TRITIC_ImagePOST,-offset);   % minus because post images was fixed during alignment with pre image
            if any(size(TRITIC_ImagePOST_aligned)~=size(BF_ImagePOST_aligned))
                uiwait(msgbox('Something wrong in the correction matrix of TRITICpost because its matrix size is not the same as BFpost. Repeat the alignment using TRITICpre and TRITICpost','Warning','warn'));
            elseif getValidAnswer(sprintf('Is the registration of TRITICpre and TRITICpost postAlign ok?'),'',{'Yes','No'})
                close gcf
                flagRepeatAlignWithTRITIC=false;        
            end
        end
        if ~flag_PRE_POST && flagRepeatAlignWithTRITIC
            % Align the fluorescent images After with the BEFORE stimulation
            [TRITIC_ImagePOST_aligned,TRITIC_ImagePRE_aligned,offset]=A3_feature_BF_TRITIC_imageAlignment(TRITIC_ImagePOST,TRITIC_ImagePRE,idxMon);        
            BF_ImagePRE_aligned=fixSize(BF_ImagePRE,offset);
        end
        % END ALIGNMENT!
        if flag_PRE_POST
            showAlignOriginalImages(BF_ImagePRE_aligned,BF_ImagePOST_aligned,folderResultsImg,'BF preAFM and BF postAFM - Aligned','resultA3_6_2_BF_prePost_Aligned',idxMon)            
        end
        showAlignOriginalImages(TRITIC_ImagePRE_aligned,TRITIC_ImagePOST_aligned,folderResultsImg,'TRITIC preAFM and TRITIC postAFM - Aligned','resultA3_7_2_TRITIC_prePost_Aligned',idxMon)

        % SHOW FLUORESCENCE DISTRIBUTION OF TRITIC BEFORE AND AFTER. ONLY FOR NORMAL AFM SCANS
        fDist=figure("Visible","off");
        legend('FontSize',15), grid on, grid minor
        xlabel('TRITIC (absolute fluorescence)','FontSize',15)
        ylabel('PDF','FontSize',15)
        title("Distribution TRITIC values","FontSize",20)
        subtitle(sprintf("(Data shown is within 1e^-^4° - 98° percentile of the entire data)"),"FontSize",15)
        objInSecondMonitor(fDist,idxMon);                
        hold on
        % prepare the data
        vectPRE=TRITIC_ImagePRE_aligned(:); 
        vectPOST=TRITIC_ImagePOST_aligned(:);
        % prepare histogram. round not work to excess but to nearest.
        xmin=floor(min(min(vectPRE),min(vectPOST)) * 1000) / 1000;
        xmax=ceil(max(max(vectPRE),max(vectPOST)) * 1000) / 1000;
        edges=linspace(xmin,xmax,5000);
        histogram(vectPRE,'BinEdges',edges,"DisplayName","TRITIC preAFM","Normalization","pdf",'FaceAlpha',0.5,"FaceColor",globalColor(1))
        histogram(vectPOST,'BinEdges',edges,"DisplayName","TRITIC postAFM","Normalization","pdf",'FaceAlpha',0.5,"FaceColor",globalColor(2))
        xline(prctile(vectPRE,90),'--','LineWidth',2,'DisplayName','90° percentile TRITIC preAFM','Color',globalColor(1));
        xline(prctile(vectPOST,90),'--','LineWidth',2,'DisplayName','90° percentile TRITIC postAFM','Color',globalColor(2));
        % better show
        allData = [vectPRE; vectPOST];
        pLow = prctile(allData, 0.0001);
        pHigh = prctile(allData, 98);
        xlim([pLow, pHigh]); ylim tight
        clear allData pLow pHigh
        % save distribution and singleLine
        nameResults='resultA3_8_DistributionTRITIC_PRE_POST';
        saveFigures_FigAndTiff(fDist,folderResultsImg,nameResults)
    
        % SHOW DELTA DISTRIBUTION
        fDistDelta=figure('Visible','off');   
        xlabel('Delta Fluorescence','FontSize',15), ylabel("PDF",'FontSize',15)
        Delta=TRITIC_ImagePOST_aligned-TRITIC_ImagePRE_aligned;
        vectDelta=Delta(:);       
        xmin=floor(min(vectDelta)*1000)/1000;
        xmax=ceil(max(vectDelta)*1000)/1000;
        edges=linspace(xmin,xmax,500);
        histogram(vectDelta,edges,'Normalization','pdf')
        grid on, grid minor
        pHigh=prctile(vectDelta(:),99); pLow=min(prctile(vectDelta,1e-4));
        x1=round(pLow,2,TieBreaker="minusinf");
        x2=round(pHigh,2,TieBreaker="plusinf");
        xlim([x1 x2]), ylim tight
        title(sprintf("Distribution Delta"),"FontSize",20)
        subtitle(sprintf("(Data shown is within 1e^-^4° - 98° percentile of the entire data)"),"FontSize",15)
        objInSecondMonitor(fDistDelta,idxMon);
        nameFig='resultA3_9_DistributionDelta';
        saveFigures_FigAndTiff(fDistDelta,folderResultsImg,nameFig)
        % SHOW DELTA FIGURE
        titleTxt="Delta Fluorescence";
        nameFile='resultA3_2_3_DeltaFluorescence';
        size_meterXpix=metadata.TRITIC.ImageHeight_umeterXpixel*metadata.TRITIC.pixelSizeUnit;
        showData(idxMon,false,imadjust(Delta),sprintf("%s - imadjusted",titleTxt),folderResultsImg,nameFile,'lenghtAxis',size_meterXpix*size(Delta))  
    end
    % prepare the output data
    [mainPathOpticalData,~]=fileparts(fileparts(fileparts(filePathND2)));
    varargout{1}=metadata;      varargout{2}=mainPathOpticalData;      
    if ~postHeat
        varargout{3}=timeExp;
        % put BF and TRITIC data in struct
        data_TRITIC.PRE=TRITIC_ImagePRE_aligned;        data_TRITIC.POST=TRITIC_ImagePOST_aligned;    
        data_BF.PRE=BF_ImagePRE_aligned;    
        if flag_PRE_POST
            data_BF.POST=BF_ImagePOST_aligned;
        end
        varargout{4}=data_TRITIC;
        varargout{5}=data_BF;
        % delete TMP file after completed alignment
        delete(fullfile(folderResultsImg,"TMP_BF_TRITIC_rawFiles.mat"),"file")
    else
        varargout{3}=allImage_TRITIC;
        varargout{4}=BF_ImagePRE;
    end
end


function [Image,metaData]=selectND2file(varargin)
% the function extract the given .nd2 image file and generate the picture with a given title
    p=inputParser();
    argName = 'titleImage';         defaultVal = [];            addOptional(p,argName,defaultVal);    
    argName = 'typeImage';          defaultVal = 'BrightField'; addOptional(p,argName,defaultVal,@(x) ismember(x,{'BrightField','TRITIC'}));  % Brightfield or TRITIC
    argName = 'mode';               defaultVal = [];            addOptional(p,argName,defaultVal,@(x) ismember(x,{[],' Before',' After'}));  % Before or After
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
        showData(p.Results.idxMon,false,imadjust(Image),sprintf("%s - imadjusted",p.Results.titleImage),p.Results.folderResultsImg,p.Results.filenameND2)  
    end
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
    saveFigures_FigAndTiff(f2,folderResultsImg,fileText,'closeImmediately',p.Results.closeImmediately)
end
       