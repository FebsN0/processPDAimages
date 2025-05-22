% Script for the heat normalisation of TRITC fluorescence images
% The script yields the fluorescence intensity of the heated PDA sample,
% averaged from 3 different images of the same sample (AVG_Avg_3_images).
% This value should be used later on to normalise the processed!
% fluorescent images so that different measurements (and PDA) can be
% compared.
function normFactor = A10_feature_normFluorescenceHeat(nameDir,timeExp,nameExperiment,secondMonitorMain)
    fprintf('\nAFM data is taken from the following experiment:\n\tEXPERIMENT: %s\n\n',nameExperiment)
    heatSubDirectories=uigetdirMultiSelect(nameDir,sprintf('Select the directories which contains heated TRITIC fluorescence images'));
    if ~iscell(heatSubDirectories)
        error("Data Folders not selected")
    end
    % check if the data_normFactor already exist
    for i = 1:length(heatSubDirectories)
        folderPath = heatSubDirectories{i};
        targetFile = fullfile(folderPath, 'data_normFactor.mat');        
        if exist(targetFile, 'file')
            load(fullfile(folderPath,"data_normFactor"),"normFactor")
            break            
        end        
    end

    if ~exist("normFactor","var")        
        % find all the .nd2 files with the same time exposure used to build
        % delta during the step A6
        allMatchingTRITICFiles = [];
        allMatchingBFFiles = [];
        % build the pattern for regularexp
        %patternTRITIC = sprintf('TRITIC\\s*%s\\s*ms', timeExp); % \\s* represent zero or more space
        patternTRITIC = sprintf('TRITIC.*\\s*%s\\s*ms', timeExp);
        patternBF = {'BFpre','^BF(\W|$)'};
        for i=1:length(heatSubDirectories)
            currentDir = heatSubDirectories{i};
            % ricorsive search: 
            % - currentDir : starting point
            % '**' : wildcard indicating "any number of subdirs (including zero)".
            % *.nd2 : any filename with .nd2 format
            fileList = dir(fullfile(currentDir, '**', '*.nd2')); 
            for j=1:length(fileList)
                [~,filename,~]=fileparts(fileList(j).name);
                foldername=fileList(j).folder;            
                % run the search (case-insensitive)
                if ~isempty(regexpi(filename, patternTRITIC, 'once'))
                    fullFilePath = fullfile(foldername, sprintf('%s.nd2',filename));
                    allMatchingTRITICFiles = [allMatchingTRITICFiles; {fullFilePath}]; %#ok<AGROW>
                end
                for k = 1:length(patternBF)
                    if ~isempty(regexpi(filename, sprintf('%s',patternBF{k}), 'once'))
                        fullFilePath = fullfile(foldername, sprintf('%s.nd2',filename));
                        allMatchingBFFiles = [allMatchingBFFiles; {fullFilePath}]; %#ok<AGROW>
                        break;
                    end
                end
            end
        end
        clear i j currentDir fileList pattern* filename fullFilePath foldername
        if isempty(allMatchingTRITICFiles)
            error(['No .nd2 files found containing "', timeExp, 'ms" in their filename.']);
        elseif length(allMatchingTRITICFiles)~=length(allMatchingBFFiles)
            error('Number of TRITIC files different from the number of BRIGHTFIELD files.');
        else
            % check if each file of allMatchingBFFiles is from the same directory of allMatchingTRITICFiles.
            % Moreover, sort them in case the order is different. 
            % extract directories path
            bfDirs = cellfun(@fileparts, allMatchingBFFiles, 'UniformOutput', false);
            triticDirs = cellfun(@fileparts, allMatchingTRITICFiles, 'UniformOutput', false);
            % sort and save the idxs
            [sortedBFDirs, bfSortIndices] = sort(bfDirs);
            [sortedTriticDirs, triticSortIndices] = sort(triticDirs);
            if ~isequal(sortedBFDirs, sortedTriticDirs)
                error('Same files are not from same directories. Check better the filenames of the files');
            else
                disp(['List of .nd2 files found containing "', timeExp, 'ms" in their filename:']);
                disp(allMatchingTRITICFiles);
                % If everything ok, then sort also the filepath
                sortedBFFiles = allMatchingBFFiles(bfSortIndices);
                sortedTRITICFiles = allMatchingTRITICFiles(triticSortIndices);
            end
        end
        clear bfDirs triticDirs bfSortIndices triticSortIndices allMatchingTRITICFiles allMatchingBFFiles sortedBFDirs sortedTriticDirs
        all_Tritic_masked=cell(1,length(sortedTRITICFiles));
        for i=1:length(sortedTRITICFiles)
            pathfile=fileparts(sortedTRITICFiles{i});
            if exist(fullfile(pathfile,sprintf('data_BF_TRITIC_postHeat_timeExp%sms.mat',timeExp)),"file")
                load(fullfile(pathfile,sprintf('data_BF_TRITIC_postHeat_timeExp%sms.mat',timeExp))) %#ok<LOAD>
            else
                % within the same directory, manage the TRITIC and BF images
                titleFig=sprintf('TRITIC post heat - TimeExp: %s',timeExp);
                Tritic_Image=openANDprepareND2(sortedTRITICFiles{i},titleFig,secondMonitorMain);
                titleFig='BF post heat';
                [BF_Image,metadataBF]=openANDprepareND2(sortedBFFiles{i},titleFig,secondMonitorMain);
                % align BF and TRITIC        
                [BF_Image_aligned,offset]=A7_limited_registration(BF_Image,Tritic_Image,pathfile,secondMonitorMain,'Brightfield','Yes','Moving','Yes','saveFig','No');    
                Tritic_Image=fixSize(Tritic_Image,offset);
                close all
                % generate the binarized BF. In case of cropping, also save the
                % cropped TRITIC. Usually dont crop, entire fluorescence data is useful data
                [binary_BF_image,Tritic_Image]=A8_Mic_to_Binary(BF_Image_aligned,secondMonitorMain,pathfile,'TRITIC_before',Tritic_Image,'saveFig','No');
                % mask the TRITIC using the new binarized BF to have PDA parts only
                Tritic_masked=Tritic_Image;
                Tritic_masked(binary_BF_image==0)=nan;      
                % mask the TRITIC using the new binarized BF to have BACKGROUND parts only
                Tritic_masked_glass=Tritic_Image;
                Tritic_masked_glass(binary_BF_image==1)=nan;
                Tritic_masked_glass_min=min(Tritic_masked_glass(:),[],'omitnan');
                Tritic_masked= Tritic_masked-Tritic_masked_glass_min;
                clear BF_Image Tritic_masked_glass_min offset Tritic_masked_glass titleFig BF_Image_aligned
                save(fullfile(pathfile,sprintf('data_BF_TRITIC_postHeat_timeExp%sms',timeExp)),"metadataBF","binary_BF_image","Tritic_Image","Tritic_masked","secondMonitorMain","timeExp")
            end
            all_Tritic_masked{i}=Tritic_masked;
        end
        % since there may be still some background data in PDA parts because of
        % not accurate binarization, remove BK outliers by considering all the
        % available scans.
        % first, remove NaN elements, then convert the the content of each cell array into a single array
        temp = cellfun(@(c) reshape(c(~isnan(c)), [], 1), all_Tritic_masked, 'UniformOutput', false);
        % convert cell array into simple array
        clearedPixelValues = vertcat(temp{:});
        clear temp
        % define the percentile threshold to remove lower outliers
        low_percentil= 1; % 1° percentil
        % considering all the pixels of every scan post heated, define the threshold to remove outliers from the single scan
        threshold = prctile(clearedPixelValues, low_percentil);            
        
        % original approach: calc the norm factor as average of average of the
        % pixels of single scan (double average)
        %{
        avgSingleScan=zeros(1,length(all_Tritic_masked));
        for i=1:length(all_Tritic_masked)
            pixelsSingleScan=all_Tritic_masked{i}(:);
            % remove NaN
            pixelsSingleScanNonNaN=pixelsSingleScan(~isnan(pixelsSingleScan));
            % remove lower outliers part of 1% percentile
            pixelsSingleScanCorrected=pixelsSingleScanNonNaN(pixelsSingleScanNonNaN>threshold);
            avgSingleScan(i)=mean(pixelsSingleScanCorrected);
        end
        normFactor=mean(avgSingleScan);
        %}
        
        % new approach: calc the norm factor as average of any pixels of any
        % scans all togheter (single average)
        clearedPixelValues_2 = clearedPixelValues(clearedPixelValues > threshold);
        normFactor.avg=mean(clearedPixelValues_2);
        normFactor.std=std(clearedPixelValues_2);        
        % show the histogram to check the distribution and where the avg locates
        fig=figure('Visible','off');
        edges=linspace(0,0.3,100);
        histogram(clearedPixelValues_2,edges,Normalization="percentage")
        ytickformat("percentage")
        grid on, grid minor,xlim padded
        objInSecondMonitor(secondMonitorMain,fig)
        xlabel("Fluorescence Absolute Intensity",'FontSize',20), ylabel('Frequency','FontSize',20)
        title({'Fluorescence Distribution';sprintf('Average of %d masked TRITIC postHeat images - TimeExp: %s',length(sortedTRITICFiles),timeExp)},'FontSize',20)
        hline=xline(normFactor.avg,'r--','LineWidth',5,'DisplayName',sprintf('Avg \x00B1 Std: %.3e \x00B1 %.2e',normFactor.avg,normFactor.std));
        legend(hline,'FontSize',16)
        folder=uigetdir(heatSubDirectories{1},'Where to save the distribution fluorescence?');
        fullfileName=fullfile(folder,'DistributionFluorescence_all');
        saveas(fig,fullfileName,'tif')
        close(fig)
        save(fullfile(folder,"data_normFactor"),"normFactor")
    end    
end

function [image,metaData]=openANDprepareND2(filepath,titleFig,secondMonitorMain)
    [image,~,metaData]=A6_feature_Open_ND2(filepath);
    [pathfile,nameFile]=fileparts(filepath);
    f1=figure('Visible','off');
    imshow(imadjust(image)), title(titleFig,'FontSize',17)
    if ~isempty(secondMonitorMain), objInSecondMonitor(secondMonitorMain,f1); end
    fullfileName=fullfile(pathfile,nameFile);
    saveas(f1,fullfileName,'tif')
end
