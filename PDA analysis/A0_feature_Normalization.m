function definitiveNormFactor=A0_feature_Normalization
    selectedExpTime=100;
    selectedGain=1;
    if ~getValidAnswer(sprintf("Current OpticalParameters:\nGain: %g\nExposure Time: %g ms\nAre the values ok?",selectedGain,selectedExpTime),"",{"Y","N"})
        error("change values!")
    end
    finalNormData=sprintf("6_normalizationData_G%g_expT%g.mat",selectedGain,selectedExpTime);
    baseFolder="D:\1_mixingPCinTRCDA\AFM data\3_newSample_fromJuly2025";    
    
    if ~exist(fullfile(baseFolder,"resultNormalizationAllExp",finalNormData),'file')
        % find the main folders which contains the fluorescebce results of each experiment
        hits= dir(fullfile(baseFolder, '**', 'finalResultsFluoAllScans.mat'));
        if isempty(hits)
            warning("No 'finalResultsFluoAllScans.mat' files found under:\n  %s", baseFolder);
        else
            allResultsData_pathfile = cell(numel(hits), 1);
            for k = 1:numel(hits)
                allResultsData_pathfile{k} = fullfile(hits(k).folder, hits(k).name);
                fprintf("\tFound result data in filepath: %s\n", fileparts(hits(k).folder));
            end
        end 
        clear k hits
        nExp=length(allResultsData_pathfile);
        nameExps=cell(nExp,1);
        allPathfile=cell(nExp,1);
        if ~exist(fullfile(baseFolder,"tmp_6_normalizationData.mat"),"file")
            normFactors=struct();
        else
            load(fullfile(baseFolder,"resultNormalizationAllExp","tmp_6_normalizationData.mat"),"normFactors")
        end
        
        for thExp=1:nExp
            allPathfile{thExp}=allResultsData_pathfile{thExp};  
            nameExps{thExp}=extractName(allPathfile{thExp});
        end
        clear allResultsData_pathfile
        for thExp=1:nExp
            pathfile=allPathfile{thExp};
            normFactors(thExp).name=nameExps{thExp};
            mainExpFolder=fileparts(pathfile);
            load(fullfile(mainExpFolder,"finalResultsFluoAllScans.mat"),"allScans_otherData")
            % Extract relevant data from allScans_otherData
            for j = 1:numel(allScans_otherData.IDscan)               
                if (isempty(normFactors) || thExp > numel(normFactors) || isempty(normFactors(thExp).name) || isempty(normFactors(thExp).TRITIC) || j > numel(normFactors(thExp).TRITIC))
                    currentScan=allScans_otherData.IDscan{j};  
                    normFactors(thExp).scan(j)=currentScan;
                    currentFolder=fullfile(mainExpFolder,sprintf("%d",currentScan));
                    currentSaveFigFolder=fullfile(currentFolder,"Results Processing AFM and fluorescence images - Assembled");
                    % load the data: TRITIC, metadata, BF-IO postaligned mask, offset to crop TRITIC
                    load(fullfile(currentFolder,"3_dataOptical_BFmask_TRITIC"),"TRITICdata","metaData_NIKON") 
                    load(fullfile(currentFolder,"4_dataPostAlignment_BF-IO_AFM-IO")) %#ok<LOAD>
                    heightAFM=AFM_data_final(1).AFM_padded;        
                    finalMask=(heightAFM>=0 & AFM_IO_final==1 & BF_IO_final==1);
                    clear AFM_data_final AFM_IO_final BF_IO_final heightAFM
                    metadataTRITIC=metaData_NIKON.TRITIC;
                    n = numel(metadataTRITIC);
                    gainAll    = zeros(1, n);
                    expTimeAll = zeros(1, n);            
                    for i = 1:n
                        gainAll(i)    = str2double(metadataTRITIC{i}.Gain);   % convert once
                        expTimeAll(i) = metadataTRITIC{i}.ExposureTime;
                    end
                    clear expTimeGroup gainGroup resultsChoice i n
                    % Find matching index using logical indexing — no inner loop
                    mask = (expTimeAll == selectedExpTime) & ...
                           (gainAll    == selectedGain);            
                    idx_selectedOpticalParameters = find(mask, 1);   % expect exactly one match
                    % extract TRITIC data, crop using offset and mask
                    TRITICdata_1_selected=TRITICdata{idx_selectedOpticalParameters};
                    TRITICdata_2_adjusted=fixSize(TRITICdata_1_selected,offset);
                    TRITICdata_3_masked=TRITICdata_2_adjusted;
                    TRITICdata_3_masked(finalMask==0)=nan;
                    % FULL TRITIC
                    vect=TRITICdata_1_selected(:);
                    normFactors(thExp).TRITIC(j).Full=mean(vect);
                    maxTRITIC=max(vect);
                    minTRITIC=min(vect);
                    edges=linspace(minTRITIC,maxTRITIC,100);
                    ratioSat=nnz(vect>edges(end-1))/length(vect)*100; 
                    normFactors(thExp).ratioSaturationPerc(j).Full=ratioSat;
                    text=sprintf("TRITIC Full Image\nGain: %.2g - TimeExp: %g ms - ratioSaturation: %.2f%%",selectedGain,selectedExpTime,ratioSat);
                    ftmp=figure("Visible","off");
                    imagesc(TRITICdata_1_selected), axis equal, title(text,'FontSize',18),
                    h=colorbar;
                    t=get(h,'Limits');
                    set(h,'Ticks',linspace(t(1),t(2),5))
                    xlim tight, ylim tight
                    objInSecondMonitor(ftmp,1)
                    saveFigures_FigAndTiff(ftmp,currentSaveFigFolder,sprintf("resultA7_TRITICimage1_Full_G%g_ET%g",selectedGain,selectedExpTime))
                    % CROPPED TRITIC
                    vect=TRITICdata_2_adjusted(:);
                    normFactors(thExp).TRITIC(j).Cropped=mean(vect);
                    ratioSat=nnz(vect>edges(end-1))/length(vect)*100; 
                    normFactors(thExp).ratioSaturationPerc(j).Cropped=ratioSat;
                    text=sprintf("TRITIC Cropped Image (AFM area offset)\nGain: %.2g - TimeExp: %g ms - ratioSaturation: %.2f%%",selectedGain,selectedExpTime,ratioSat);
                    ftmp=figure("Visible","off");
                    imagesc(TRITICdata_2_adjusted), axis equal,title(text,'FontSize',18),
                    h=colorbar;
                    set(h,'Ticks',linspace(t(1),t(2),5))
                    xlim tight, ylim tight
                    objInSecondMonitor(ftmp,1)
                    saveFigures_FigAndTiff(ftmp,currentSaveFigFolder,sprintf("resultA7_TRITICimage2_Cropped_G%g_ET%g",selectedGain,selectedExpTime))
                    % MASKED TRITIC
                    vect=TRITICdata_3_masked(:);
                    vect=vect(~isnan(vect));
                    normFactors(thExp).TRITIC(j).Masked=mean(vect);
                    ratioSat=nnz(vect>edges(end-1))/length(vect)*100; 
                    normFactors(thExp).ratioSaturationPerc(j).Masked=ratioSat;
                    text=sprintf("TRITIC Cropped Image (AFM area offset)\nGain: %.2g - TimeExp: %g ms - ratioSaturation: %.2f%%",selectedGain,selectedExpTime,ratioSat);
                    ftmp=figure("Visible","off");
                    imagesc(TRITICdata_3_masked), axis equal, title(text,'FontSize',18)
                    h=colorbar;
                    set(h,'Ticks',linspace(t(1),t(2),5))
                    xlim tight, ylim tight
                    objInSecondMonitor(ftmp,1)
                    saveFigures_FigAndTiff(ftmp,currentSaveFigFolder,sprintf("resultA7_TRITICimage3_Masked_G%g_ET%g",selectedGain,selectedExpTime))
                    clear h ftmp text ratioSat vect pathfile
                    % update the normalization data
                    save(fullfile(baseFolder,"tmp_6_normalizationData"),"normFactors")
                end
             end
        end
        % finalize
        mkdir(fullfile(baseFolder,"resultNormalizationAllExp"))
        save(fullfile(baseFolder,"resultNormalizationAllExp",finalNormData),"normFactors")
        delete(fullfile(baseFolder,"tmp_6_normalizationData.mat"))
    else
        load(fullfile(baseFolder,"resultNormalizationAllExp",finalNormData),"normFactors")
    end
    clear finalNormData select*
    nExp=numel(normFactors);
    definitiveNormFactor=struct();
    avgFull_allScan=cell(1,nExp);
    avgMask_allScan=cell(1,nExp);
    for thExp=1:nExp
        definitiveNormFactor(thExp).name=normFactors(thExp).name;
        avgFull_allScan{thExp}=[normFactors(thExp).TRITIC_avgValue.Full];
        avgMask_allScan{thExp}=[normFactors(thExp).TRITIC_avgValue.Masked];
    end
    % Find max length for padding
    maxLen = max(cellfun(@numel, avgFull_allScan));
    nGroups = numel(avgFull_allScan);
    % bar() needs a full matrix, so build it per experiment
    dataFull = NaN(nGroups, maxLen);
    dataMask = NaN(nGroups, maxLen);
    for i = 1:nGroups
        v = avgFull_allScan{i};
        dataFull(i, 1:numel(v)) = v(:)';
        v = avgMask_allScan{i};
        dataMask(i, 1:numel(v)) = v(:)';
    end   

    if ~exist(fullfile(baseFolder,"resultNormalizationAllExp","tiffImages","barGrouped_MaskedTRITIC.tif"),"file")
        % Grouped bar chart
        fHist_full=figure; axHistFull=axes(fHist_full); hold(axHistFull,"on");
        title(axHistFull,"Normalization Factor value for each scan-experiment","FontSize",20)
        subtitle(axHistFull,"TRITIC FULL","FontSize",17)
        fHist_mask=figure; axHistMask=axes(fHist_mask); hold(axHistMask,"on");
        title(axHistMask,"Normalization Factor value for each scan-experiment","FontSize",20)
        subtitle(axHistMask,"TRITIC MASKED","FontSize",17)
        bFull = bar(dataFull, 'grouped','Parent',axHistFull);
        bMask = bar(dataMask, 'grouped','Parent',axHistMask);
        for scanIdx = 1:maxLen
            bFull(scanIdx).FaceColor = 'flat';
            bMask(scanIdx).FaceColor = 'flat';
            for expIdx = 1:nGroups
                bFull(scanIdx).CData(expIdx, :) = globalColor(expIdx);
                bMask(scanIdx).CData(expIdx, :) = globalColor(expIdx);
            end
        end
        set(axHistFull, 'XTick', 1:nGroups, 'XTickLabel', arrayfun(@(i) normFactors(i).name, 1:nGroups, 'UniformOutput', false),'FontSize',14);
        set(axHistMask, 'XTick', 1:nGroups, 'XTickLabel', arrayfun(@(i) normFactors(i).name, 1:nGroups, 'UniformOutput', false),'FontSize',14);   
        axHistFull.YGrid="on";  axHistMask.YGrid="on";
    
        objInSecondMonitor(fHist_full,1)    
        saveFigures_FigAndTiff(fHist_full,fullfile(baseFolder,"resultNormalizationAllExp"),"barGrouped_FullTRITIC")
        objInSecondMonitor(fHist_mask,1)    
        saveFigures_FigAndTiff(fHist_mask,fullfile(baseFolder,"resultNormalizationAllExp"),"barGrouped_MaskedTRITIC")
    end
    % calc norm factors
    for thExp=1:nExp        
        definitiveNormFactor(thExp).avgFull=mean(dataFull(thExp,:),'omitnan');
        definitiveNormFactor(thExp).stdFull=std(dataFull(thExp,:),'omitnan');
        definitiveNormFactor(thExp).avgMask=mean(dataMask(thExp,:),'omitnan');
        definitiveNormFactor(thExp).stdMask=std(dataMask(thExp,:),'omitnan');
    end
end
 

function nameExp=extractName(pathfile)
    tmp=strsplit(pathfile,'\');   
    nameExp=sprintf(tmp{end-2});         
    question=sprintf('Name experiment: %s\nIs the name correct? They will be used in the figures.',nameExp);
    if ~getValidAnswer(question,'',{'Yes','No'},2)
        while true
            res=inputdlg("Name experiment (ex. TRCDA)","Enter manually names",[1 80],{nameExp});
            if any(cellfun(@(x) isempty(x), res))
                disp('Input not valid')
            else
                nameExp=res{1};
                break
            end
        end
    end    
end