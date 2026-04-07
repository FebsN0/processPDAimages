%%%%%%%%%%%%%%%
% The main goal of this script is to extract the slope of Height-Fluorescence after heating the sample
% In this way, it is also possible to choose correctly the exposure time for normal scans.
% After heating, the PDA crystals emit fluorescence at max intensity. If exp time is too high, the fluorescence signal
% will be saturated, compromising the validity of future curves.
% the code run in two ways (but as start, the first way should be used):
%   1) Compare TRITIC images with DIFFERENT exposure times for the same AFN scan area.
%           ( 1 AFM - multiple TRITIC)
%                                           ==> understand which exp time is correct
%   2) Compare different AFM scans with TRITIC Images at the same exposure time
%           ( 1 AFM - single TRITIC at specific exp time ) xMultiple time
%                                           ==> average Height-Fluorescence among different scans
%%%%%%%%%%%%%%

clc, clear, close all
idxMon=objInSecondMonitor;

answer=getValidAnswer('Choose an option to investigate fluorescence intensity. Highly recommended run 1->2','',{ ...
    'Compare one or more AFM SCAN AREAS of a single experiment condition\n  1st step)   for each scan, comparison of TRITIC at DIFFERENT exposureTime/Gain\n  2nd step)  once selected a SPECIFIC exposureTime/Gain condition, comparison of TRITIC of DIFFERENT scans.', ...
    'Compare fluorescence intensity among different experiments (at SPECIFIC exposureTime/Gain)'});
if answer==1
    flag_sameExperimentCondition=true;
    mainPaths=uigetdirMultiSelect(pwd,sprintf('Select the AFM directories which contains different scans of a specific postHeated sample'));
    % Init
    nScans=length(mainPaths);
    allScans_results_Height_fluo=cell(1,nScans);
    allScans_Metadata_AFM_NIKON=struct;
    mainPathOpticalData=[];
else 
    %%%% to be completed later
    flag_sameExperimentCondition=false;
end
clear answer
%%
if flag_sameExperimentCondition
    % main cycle is to process each scan
    for iScan=1:nScans
        clc        
        % extract the path of a specific scan
        ithMainPathScan=mainPaths{iScan};
        tmp=strsplit(ithMainPathScan,'\');
        nameScan=tmp{end}; nameExperiment=tmp{end-2}; nameGroupExperiment=tmp{end-3};
        fprintf("%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%\n%%%%%%%%\tCurrent Scan processing\t: %g\t%%%%%%%%\n%%%%%%%%%%%%%%%%%%%%%%%%--------------------%%%%%%%%%%%%%%%%%%%%%%%%\n\n",str2double(nameScan))
        pathDataProcess=fullfile(ithMainPathScan,'HoverMode_OFF');
        clear tmp
        % if the processing of the single scan is already done, skip to the next scan
        if exist(fullfile(pathDataProcess,"5_dataCorrelationFluoHeight.mat"),"file")
            load(fullfile(pathDataProcess,"5_dataCorrelationFluoHeight"),"Data_finalResultsAllTimeExpGain")            
        else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%% FIRST STEP: processing the single scan ==> comparison of TRITIC at DIFFERENT exposureTime/Gain %%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if exist(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled.mat"),'file')
                load(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData_AFM","SaveFigFolder")    
            else 
                if exist(fullfile(pathDataProcess,"1_data_preprocess.mat"),'file')
                    load(fullfile(pathDataProcess,"1_data_preprocess.mat"),"allData","otherParameters","SaveFigFolder")
                else
                    [allData,otherParameters,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',pathDataProcess);
                    save(fullfile(pathDataProcess,"1_data_preprocess"),"allData","otherParameters","SaveFigFolder")
                end
                % the additional 'modeScan','postHeatScan' inputs will save time by avoiding to run lateral channel processing
                [AFM_images_final, AFM_height_IO, metaData_AFM]= A2_processAFMdata(allData,otherParameters,ithMainPathScan,SaveFigFolder,idxMon,'modeScan','postHeatScan');     
                save(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData_AFM","SaveFigFolder")
            end
            clear allData otherParameters
            % end AFM processing.
            fprintf("\nGROUP EXPERIMENT: %s\nNAME EXPERIMENT:  %s\nSCAN ID:          %s\n\n",nameGroupExperiment,nameExperiment,nameScan)
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% START OPTICAL PROCESSING %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if exist(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC.mat"),'file')
                load(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC"),"TRITICdata","BF_Image_IO","metaData_NIKON","mainPathOpticalData")
            else
                % Open BF and TRITIC image after sample heating (the function also corrects the tilted effect)
                [metaData_NIKON,mainPathOpticalData,TRITICdata,BFdata]=A3_prepareBFandTRITICimages(SaveFigFolder,idxMon,nameGroupExperiment,nameExperiment,nameScan,'postHeatProcessing',true,'pathOpticalImages',mainPathOpticalData); 
                % Produce the binary IO of Brightfield
                BF_Image_IO=A4_Mic_to_Binary(BFdata,idxMon,SaveFigFolder,'postHeat',true); 
                % try to correct again the tilted effect
                if getValidAnswer("Run planeFitting on masked Brightfield data to get better mask?","",{"y","n"},2)
                    BF_Image_IO=obtainBetterMaskWithTiltReCorrection(BFdata,BF_Image_IO,SaveFigFolder,"resultA4_2_comparisonBeforeAfterPlaneFittingMASK",idxMon);
                end
                clear BFdata
                % additional check: the dataset has been organized as column in term of timeExp, while the vector in term of gain. Everything according to
                % the name of the extracted file. It might be no the same from metadata.
                metadataTRITIC=metaData_NIKON.TRITIC;
                n = numel(metadataTRITIC);
                gainAll    = zeros(1, n);
                expTimeAll = zeros(1, n);      
                for i = 1:n
                    gainAll(i)    = str2double(metadataTRITIC{i}.Gain);   % convert once
                    expTimeAll(i) = metadataTRITIC{i}.ExposureTime;
                end
                clear n i
                gainGroup=sort(unique(gainAll),'ascend');
                expTimeGroup=sort(unique(expTimeAll),'descend');
                % in case of mismatch between naming and metadata, reorganize the data according to exposure time and gain to regroup all the data properly
                % even if everything is okay, organize as 
                % columns: highExpTime -> lowExpTime
                % vectors: lowGain -> highGain
                % in this way, low expTime TRITIC distribution will be shown frontally
                if ~isequal([length(expTimeGroup),length(gainGroup)],size(metadataTRITIC))
                    expTimeGroup_text=num2str(expTimeGroup);
                    gainGroup_text=num2str(gainGroup);
                    uiwait(warndlg(sprintf("Aware! Additional settings found in the metadata of TRITIC.\n" + ...
                        "I.e. different gain/expTime than expected from the TRITIC filename\n" + ...
                        "gain: %s\nExposure Time: %s",gainGroup_text,expTimeGroup_text)))
                    clear expTimeGroup_text gainGroup_text
                end
                % init data and metadata
                metadataTRITIC_corr=cell(length(expTimeGroup),length(gainGroup));
                TRITICdata_corr=cell(length(expTimeGroup),length(gainGroup));
                for ithGain=1:length(gainGroup)
                    for ithExpTime=1:length(expTimeGroup)
                        % Find matching index using logical indexing — no inner loop
                        mask = (expTimeAll == expTimeGroup(ithExpTime)) & ...
                               (gainAll    == gainGroup(ithGain));            
                        idx = find(mask, 1);   % expect exactly one match
                        if ~isempty(idx)
                            metadataTRITIC_corr{ithExpTime, ithGain} = metadataTRITIC{idx};
                            TRITICdata_corr{ithExpTime, ithGain}     = TRITICdata{idx};
                        else
                            warning('No match found for gain=%.1f, expTime=%.4f', ...
                                gainGroup(ithGain), expTimeGroup(ithExpTime));
                        end                       
                    end
                end
                TRITICdata=TRITICdata_corr;
                metadataTRITIC=metadataTRITIC_corr;
                metaData_NIKON.TRITIC=metadataTRITIC;        
                clear metadataTRITIC TRITICdata_corr metadataTRITIC_corr idx mask ithExpTime ithGain 
                save(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC"),"TRITICdata","BF_Image_IO","metaData_NIKON","mainPathOpticalData","-v7.3")
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% ALIGNMENT AFM and BF IO IMAGES %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if exist(fullfile(pathDataProcess,"4_dataPostAlignment_BF-IO_AFM-IO.mat"),'file')
                load(fullfile(pathDataProcess,"4_dataPostAlignment_BF-IO_AFM-IO"),"AFM_IO_final","AFM_data_final","offset")
            else
                [AFM_IO_final,~,AFM_data_final,~,offset]=A5_alignment_AFM_Microscope(BF_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,AFM_images_final,SaveFigFolder,idxMon,'Margin',150);                
                save(fullfile(pathDataProcess,"4_dataPostAlignment_BF-IO_AFM-IO"),"AFM_IO_final","AFM_data_final","offset")
            end
            clear AFM_images_final AFM_height_IO BF_Image_IO
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% CORRELATION FLUORESCENCE AND AFM HEIGHT %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % process the correlation with a TRITIC at different time exposure. Use different figure for each used gain  
            Data_finalResultsAllTimeExpGain=cell(size(TRITICdata));
            for ithGain=1:size(TRITICdata,2)
                % sometimes, data are corrupted, to avoid to process again, save temporarily the results of this current cycle
                if exist(fullfile(pathDataProcess,sprintf("TMP_dataCorrelationFluoHeight_%d.mat",ithGain)),"file")
                    load(fullfile(pathDataProcess,sprintf("TMP_dataCorrelationFluoHeight_%d",ithGain)),"Data_finalResultsAllTimeExpGain")
                else
                    gain=metaData_NIKON.TRITIC{1,ithGain}.Gain;
                    % prepare figure for the TRITIC fluorescence intensity distribution to investigate saturation
                    figDistTRITIC_sameScan=figure; axDist=axes(figDistTRITIC_sameScan);
                    hold(axDist,"on")
                    xlabel(axDist,'Absolute fluorescence increase (A.U.)','FontSize',15), ylabel(axDist,"PDF",'FontSize',15)
                    title(axDist,"Distribution Fluorescence (Full TRITIC image)","FontSize",20), legend('FontSize',12)
                    subtitle(axDist,sprintf("Same Gain (%s) - Different Exposure Time",gain),"FontSize",15)
                    % prepare the bin sizes so the distributions are more comparable
                    maxTRITIC=max(cellfun(@(x) max(x(:)), TRITICdata),[],'all');
                    minTRITIC=min(cellfun(@(x) min(x(:)), TRITICdata),[],'all');
                    edges=linspace(minTRITIC,maxTRITIC,100);
                    % prepare figure to plot the fluorescence-height correlation in function of intensity
                    figCorrelFluoHeight_sameScan=figure; axCorr=axes(figCorrelFluoHeight_sameScan);
                    hold(axCorr,"on")
                    ylabel(axCorr,'Absolute fluorescence increase (A.U.)','FontSize',15), xlabel(axCorr,"Height (nm)",'FontSize',15)
                    title(axCorr,"Correlation Averaged Fluorescence-Height (TRITIC over only PDA)","FontSize",20), legend('FontSize',12)
                    subtitle(axCorr,sprintf("Same Gain (%s) - Different Exposure Time",gain),"FontSize",15)
                    for ithTimeExp=1:size(TRITICdata,1)
                        % get the information about time exposure
                        ithMetadataTRITIC=metaData_NIKON.TRITIC{ithTimeExp,ithGain};
                        expTime=ithMetadataTRITIC.ExposureTime;
                        fprintf("Current phase processing\n\tGain: %g\n\tExposureTime: %g\n",str2double(gain),expTime)
                        ithTRITICdata=TRITICdata{ithTimeExp,ithGain};                
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%% SHOW FLUORESCENCE DISTRIBUTION OF FULL TRITIC IMAGE %%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        % important to understand the fluorescence saturation
                        vectDelta=ithTRITICdata(:);    
                        % find the percentage of saturated values
                        ratioSat=nnz(vectDelta>edges(end-1))/length(vectDelta)*100;                
                        % prepare the name for legend
                        nameScans=sprintf('%dms - ratioSaturation: %.2f%%',round(double(expTime)),ratioSat);
                        % show distribution of all TRITIC image
                        histogram(axDist,vectDelta,'BinEdges',edges,"DisplayName",nameScans,"Normalization","pdf",'FaceAlpha',0.3,"FaceColor",globalColor(ithTimeExp))                
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %%%% EXTRACT CORRELATION FLUORESCENCE-AFM HEIGHT %%%%
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                        %  originally, TRITIC has full original size, therefore resizing to the AFM (padded) size is required    
                        ithTRITICdata=fixSize(ithTRITICdata,offset); 
                        % now TRITIC data is ready ==> correlation FLUORESCENCE AND AFM HEIGHT
                        Data_finalResults=A6_correlation_AFM_BF(AFM_data_final,AFM_IO_final,metaData_AFM,metaData_NIKON.BF,ithMetadataTRITIC,idxMon,SaveFigFolder,'TRITIC_before',ithTRITICdata,'afterHeating',true);
                        FluoHeigh=Data_finalResults.Height_FLUO.Height_FLUO_1M;
                        x=[FluoHeigh.BinCenter]*1e9; % 'Feature height (nm)'
                        y=[FluoHeigh.MeanBin];
                        s=[FluoHeigh.STDBin];
                        % ensure column vectors
                        x = x(:); y = y(:); s = s(:);
                        % remove NaNs if needed
                        valid = ~(isnan(x) | isnan(y) | isnan(s));
                        x = x(valid); y = y(valid); s = s(valid);
                        % sort by x in case data are not monotonic
                        [x, idx] = sort(x); y = y(idx); s = s(idx);
                        % build shaded region
                        xpatch = [x; flipud(x)];
                        ypatch = [y-s; flipud(y+s)];
                        patch(axCorr, xpatch, ypatch, globalColor(ithTimeExp), 'FaceAlpha', 0.30,'EdgeColor', 'none','HandleVisibility', 'off');
                        hold(axCorr,'on')
                        % find the percentage of saturated values in corrispondence of only PDA (Delta has been masked by using AFM IO mask)
                        tmp=Data_finalResults.DeltaData.Delta_firstMasking(:);
                        % since masking introduces nan into matrix to consider only FR, remove them
                        tmp=tmp(~isnan(tmp));
                        ratioSat=nnz(tmp>edges(end-1))/length(tmp)*100;          
                        clear tmp
                        % prepare the name for legend
                        nameScans=sprintf('%dms - ratioSaturation: %.2f%%',round(double(expTime)),ratioSat);
                        % plot the correlation
                        plot(axCorr, x, y,'Color', globalColor(ithTimeExp),'LineWidth', 2,"DisplayName",nameScans);        
                        Data_finalResultsAllTimeExpGain{ithTimeExp,ithGain}=FluoHeigh;
                    end
                    % better show for the distribution
                    xlim(axDist,"padded"); ylim(axDist,"tight"), grid(axDist,"on"), grid(axDist,"minor")
                    legend(axDist,"Location","best")
                    objInSecondMonitor(figDistTRITIC_sameScan,idxMon);
                    nameFig=sprintf('resultA6_1_%d_DistributionFluorescenceDiffTimeExp_gain%s',ithGain,gain);
                    uiwait(warndlg("Adjust eventually the legend position if not good. Click ""OK"" to continue"))
                    saveFigures_FigAndTiff(figDistTRITIC_sameScan,SaveFigFolder,nameFig)
                    % better show for the correlation
                    xlim(axCorr,"padded"); ylim(axCorr,"padded"), grid(axCorr,"on"), grid(axCorr,"minor")
                    legend(axCorr,"Location","best")
                    objInSecondMonitor(figCorrelFluoHeight_sameScan,idxMon);
                    nameFig=sprintf('resultA6_2_%d_CorrelationFluoHeightComparisonDiffTimeExp_gain%s',ithGain,gain);
                    uiwait(warndlg("Adjust eventually the legend position if not good. Click ""OK"" to continue"))
                    saveFigures_FigAndTiff(figCorrelFluoHeight_sameScan,SaveFigFolder,nameFig)   
                    % sometimes, some data are corrupted causing error, to avoid to process again, save temporarily the results of this current cycle
                    save(fullfile(pathDataProcess,sprintf("TMP_dataCorrelationFluoHeight_%d",ithGain)),"Data_finalResultsAllTimeExpGain","-v7.3")
                end
            end
            save(fullfile(pathDataProcess,"5_dataCorrelationFluoHeight"),"Data_finalResultsAllTimeExpGain","-v7.3")
            % remove not useful files
            delete(fullfile(pathDataProcess,"TMP_dataCorrelationFluoHeight*"))
            clear pathDataProcess SaveFigFolder AFM_IO_final AFM_data_final axCorr axDist x y s edges expTime figCorrelFluoHeight_sameScan figDistTRITIC_sameScan
            clear Data_finalResults ratioSat FluoHeigh gain idx ith maxTRITIC minTRITIC offset valid vectDelta xpatch ypatch
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% COMPLETED THE PROCESSING OF THE SINGLE SCAN %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % store the result of the single scan into the main cell array
        allScans_results_Height_fluo{iScan}=Data_finalResultsAllTimeExpGain;
        allScans_Metadata_AFM_NIKON{iScan}.AFM=metaData_AFM;
        allScans_Metadata_AFM_NIKON{iScan}.NIKON=metaData_NIKON;
    end
    % in case data is extracted from file, some vars dont exist because created internally
    if ~exist("gainGroup","var") || ~exist("expTimeGroup","var")
        % pick the first metadataTRITIC. It assumed that any scans have same TRITIC parameters        
        metadataTRITIC=allMetadata_AFM_NIKON{1}.NIKON.TRITIC;
        n = numel(metadataTRITIC);
        gainAll    = zeros(1, n);
        expTimeAll = zeros(1, n);      
        for i = 1:n
            gainAll(i)    = str2double(metadataTRITIC{i}.Gain);   % convert once
            expTimeAll(i) = metadataTRITIC{i}.ExposureTime;
        end
        clear n i
        gainGroup=sort(unique(gainAll),'ascend');
        expTimeGroup=sort(unique(expTimeAll),'descend');
    end
    % before compare different scans of the same sample, select the optimal exposure time 
    resultsChoice=selectOptionsDialog("Which exposure time and/or gain to consider to compare different AFM scan areas?",false,gainGroup,expTimeGroup,'Titles',{'Exposure Time','Gain'});
    selectedGain=gainGroup(resultsChoice{1});
    selectedExpTime=expTimeGroup(resultsChoice{2});
    clear expTimeGroup gainGroup iScan ith* resultsChoice tmp i mainPaths mainPathOpticalData metadata* metaData* n name* TRITIC* nScans
    % Find matching index using logical indexing — no inner loop
    mask = (expTimeAll == selectedExpTime) & ...
           (gainAll    == selectedGain);            
    idx = find(mask, 1);   % expect exactly one match
    % extract the data generated with selected parameters
    

    
    selectedMetadataTRITIC=metaData_NIKON.TRITIC{idx};
    selectedDataTRITIC=TRITICdata{idx};
end

%%%%% FUNCTIONS
function BF_Image_IO=obtainBetterMaskWithTiltReCorrection(BFdata,BF_Image_IO,pathFile,fileName,idxMon)
    % correct tilt effect
    BFdata_masked=BFdata;
    BFdata_masked(BF_Image_IO==1)=NaN;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%% FIRST ORDER PLANE FITTING ON MASKED DATA %%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    planeFit = planeFitting_N_Order(BFdata_masked,1);
    BFdata_correct=BFdata-planeFit;
    % show the comparison between original and fitted BrightField
    f1=figure("Visible","on");
    subplot(1,2,1)
    imshow(imadjust(BFdata)),title('BF image before BK fitting','FontSize',14)
    subplot(1,2,2)
    imshow(imadjust(BFdata_correct)),title('BF image after BK fitting','FontSize',14)
    objInSecondMonitor(f1,idxMon);
    saveFigures_FigAndTiff(f1,pathFile,fileName)
end