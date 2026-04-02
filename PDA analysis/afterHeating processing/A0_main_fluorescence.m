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

answer=getValidAnswer('Choose an option to investigate fluorescence intensity. Highly recommended run 1->2->3','',{ ...
    'Compare SAME AFM SCAN AREA with TRITIC at DIFFERENT exposure time\nNOTE: same exp condition', ...
    'Compare DIFFERENT AFM SCAN AREAS with TRITIC at SAME exposure time\nNOTE: same exp condition', ...
    'Compare average fluorescence intensity among different experiments (same exposure time)'});
if answer==1
    flag_sameScan_DifferentExposTime=true;
else 
    flag_sameScan_DifferentExposTime=false;
end

% Init
if ~flag_sameScan_DifferentExposTime
    maxScans=str2double(cell2mat(inputdlg('How many scans (different area) in total?')));
    results_Height_fluo_allScans=cell(1,maxScans);
    fitresult_allScans=cell(1,maxScans);
    nameData=cell(1,maxScans);
else
    maxScans=1;
end   
clear answer
mainPathOpticalData=[];
%%
while true
    % the big while cycle is when flag_sameScan_DifferentExposTime=false
    % ==> to compare same exp time but of different scans
    
    if flag_sameScan_DifferentExposTime
        % prepare AFM Data (for this script, only AFM Height and AFM_IO are required)
        mainPath=uigetdir(pwd,sprintf('Locate the AFM directory which contains HVoff-postheat data of a specific scan'));
        tmp=strsplit(mainPath,'\');
        nameScan=tmp{end}; nameExperiment=tmp{end-2}; groupExperiment=tmp{end-3};
        pathDataProcess=fullfile(mainPath,'HoverMode_OFF');
        clear tmp

        if exist(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled.mat"),'file')
            load(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData_AFM","SaveFigFolder")    
        else 
            if ~exist(fullfile(pathDataProcess,"1_data_preprocess.mat"),'file')
                load(fullfile(pathDataProcess,"1_data_preprocess.mat"),"allData","otherParameters","SaveFigFolder")
            else
                [allData,otherParameters,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',pathDataProcess);
                save(fullfile(pathDataProcess,"1_data_preprocess"),"allData","otherParameters","SaveFigFolder")
            end
            % the additional 'modeScan','postHeatScan' inputs will save time by avoiding to run lateral channel processing
            [AFM_images_final, AFM_height_IO, metaData_AFM]= A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,'modeScan','postHeatScan');     
            save(fullfile(pathDataProcess,"2_data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData_AFM","SaveFigFolder")
        end
        clear allData
        % end AFM processing.
        fprintf("\nGROUP EXPERIMENT: %s\nNAME EXPERIMENT:  %s\nSCAN ID:          %s\n\n",groupExperiment,nameExperiment,nameScan)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% START OPTICAL PROCESSING %%%
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if exist(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC.mat"),'file')
            load(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC"),"TRITICdata","BF_Image_IO","metaData_NIKON","mainPathOpticalData")
        else
            % Open BF and TRITIC image after sample heating (the function also corrects the tilted effect)
            [metaData_NIKON,mainPathOpticalData,TRITICdata,BFdata]=A3_prepareBFandTRITICimages(SaveFigFolder,idxMon,groupExperiment,nameExperiment,nameScan,'postHeatProcessing',true,'pathOpticalImages',mainPathOpticalData); 
            % Produce the binary IO of Brightfield
            BF_Image_IO=A4_Mic_to_Binary(BFdata,idxMon,SaveFigFolder,'postHeat',true); 
            % try to correct again the tilted effect
            if getValidAnswer("Run planeFitting on masked Brightfield data to get better mask?","",{"y","n"},2)
                BF_Image_IO=obtainBetterMaskWithTiltReCorrection(BFdata,BF_Image_IO,SaveFigFolder,"resultA4_2_comparisonBeforeAfterPlaneFittingMASK",idxMon);
            end
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
            gainGroup=sort(unique(gainAll));
            expTimeGroup=sort(unique(expTimeAll));
            % in case of mismatch between naming and metadata, reorganize the data according to exposure time and gain to regroup all the data properly
            if ~isequal([length(expTimeGroup),length(gainGroup)],size(metadataTRITIC))
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
            end  
            clear metadataTRITIC TRITICdata_corr metadataTRITIC_corr idx mask ithExpTime ithGain gainAll expTimeAll n
            save(fullfile(pathDataProcess,"3_dataOptical_BFmask_TRITIC"),"TRITICdata","BF_Image_IO","metaData_NIKON","mainPathOpticalData","-v7.3")
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% ALIGNMENT AFM and BF IO IMAGES %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [AFM_IO_final,~,AFM_data_final,~,offset]=A5_alignment_AFM_Microscope(BF_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,AFM_images_final,SaveFigFolder,idxMon,'Margin',150);                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% CORRELATION FLUORESCENCE AND AFM HEIGHT %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % process the correlation with a TRITIC at different time exposure. Use different figure for each used gain        
        for ithGain=1:size(TRITICdata,2)
            gain=metaData_NIKON.TRITIC{1,ithGain}.Gain;
            % prepare figure for the TRITIC fluorescence intensity distribution to investigate saturation
            figDistTRITIC_sameScan=figure; axDist=axes(figDistTRITIC_sameScan);
            hold(axDist,"on")
            xlabel(axDist,'Absolute fluorescence increase (A.U.)','FontSize',15), ylabel(axDist,"PDF",'FontSize',15)
            title(axDist,"Distribution Fluorescence (same scan area)","FontSize",20), legend('FontSize',12)
            subtitle(axDist,sprintf("Same Gain (%s) - Different Exposure Time",gain),"FontSize",15)
            % prepare the bin sizes so the distributions are more comparable
            maxTRITIC=max(cellfun(@(x) max(x(:)), TRITICdata),[],'all');
            minTRITIC=min(cellfun(@(x) min(x(:)), TRITICdata),[],'all');
            edges=linspace(minTRITIC,maxTRITIC,100);
            % prepare figure to plot the fluorescence-height correlation in function of intensity
            figCorrelFluoHeight_sameScan=figure; axCorr=axes(figCorrelFluoHeight_sameScan);
            hold(axCorr,"on")
            ylabel(axCorr,'Absolute fluorescence increase (A.U.)','FontSize',15), xlabel(axCorr,"Height (nm)",'FontSize',15)
            title(axCorr,"Correlation Averaged Fluorescence-Height (same scan area)","FontSize",20), legend('FontSize',12)
            subtitle(axCorr,sprintf("Same Gain (%s) - Different Exposure Time",gain),"FontSize",15)
            for ithTimeExp=1:size(TRITICdata,1) 
                ithTRITICdata=TRITICdata{ithTimeExp,ithGain};
                % get the information about time exposure and used gain 
                ithMetadataTRITIC=metaData_NIKON.TRITIC{ithTimeExp,ithGain};
                expTime=ithMetadataTRITIC.ExposureTime;
                nameScans=sprintf('%dms',round(double(expTime)));
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%% SHOW FLUORESCENCE DISTRIBUTION OF FULL TRITIC IMAGE %%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % important to understand the fluorescence saturation
                vectDelta=ithTRITICdata(:);                
                histogram(axDist,vectDelta,'BinEdges',edges,"DisplayName",nameScans,"Normalization","pdf",'FaceAlpha',0.2,"FaceColor",globalColor(ithTimeExp))                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%% EXTRACT CORRELATION FLUORESCENCE-AFM HEIGHT %%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %  originally, TRITIC has full original size, therefore resizing to the AFM (padded) size is required    
                ithTRITICdata=fixSize(ithTRITICdata,offset); 
                % now TRITIC data is ready ==> correlation FLUORESCENCE AND AFM HEIGHT
                Data_finalResults=A6_correlation_AFM_BF(AFM_data_final,AFM_IO_final,metaData_AFM,metaData_NIKON.BF,ithMetadataTRITIC,idxMon,SaveFigFolder,'TRITIC_before',ithTRITICdata,'afterHeating',true);
                FluoHeigh=Data_finalResults.Height_FLUO.Height_FLUO_1M;
                x_VDH_B=[FluoHeigh.BinCenter]*1e9; % 'Feature height (nm)'
                y_VDH_B=[FluoHeigh.MeanBin];
                plot(axCorr,x_VDH_B,y_VDH_B,"color",globalColor(ithTimeExp),"DisplayName",nameScans,"LineWidth",2);
            end
            % better show for the distribution
            xlim(axDist,"padded"); ylim(axDist,"tight"), grid(axDist,"on"), grid(axDist,"minor")
            legend(axDist,"Location","best")
            objInSecondMonitor(figDistTRITIC_sameScan,idxMon);
            nameFig=sprintf('resultA6_1_%d_DistributionFluorescenceDiffTimeExp_gain%s',ithGain,gain);
            saveFigures_FigAndTiff(figDistTRITIC_sameScan,SaveFigFolder,nameFig)
            % better show for the correlation
            xlim(axCorr,"padded"); ylim(axCorr,"padded"), grid(axCorr,"on"), grid(axCorr,"minor")
            legend(axCorr,"Location","best")
            objInSecondMonitor(figCorrelFluoHeight_sameScan,idxMon);
            nameFig=sprintf('resultA6_2_%d_CorrelationFluoHeightComparisonDiffTimeExp_gain%s',ithGain,gain);
            saveFigures_FigAndTiff(figCorrelFluoHeight_sameScan,SaveFigFolder,nameFig)
        end
    end
    if getValidAnswer("Interrupt here the comparison of different timeExp-Gain for the same scan area?","",{"Y","N"})
        break
    end
    

    resultsChoice=selectOptionsDialog("Which exposure time and/or gain to consider to compare different AFM scan areas?",false,gainGroup,expTimeGroup,'Titles',{'Exposure Time','Gain'});
    selectedGain=gainGroup(resultsChoice{1});
    selectedExpTime=expTimeGroup(resultsChoice{2});

    % Find matching index using logical indexing — no inner loop
    mask = (expTimeAll == expTimeGroup(resultsChoice{2})) & ...
           (gainAll    == gainGroup(resultsChoice{1}));            
    idx = find(mask, 1);   % expect exactly one match

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