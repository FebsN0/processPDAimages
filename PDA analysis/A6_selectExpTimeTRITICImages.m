function varargout=A6_selectExpTimeTRITICImages(TRITICdata,BF_IO,metadata_NIKON,AFMdata_1_original,AFM_IO,metadata_AFM,SaveFigFolder,idxMon,nameExperiment,nameScan)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% CORRELATION FLUORESCENCE AND AFM HEIGHT %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% process the correlation with a TRITIC at different time exposure. Use different figure for each used gain 
% in case of normal scans, TRITICdata has pre and post AFM scan, whereas postHeated scans only pre AFM scan. 
% since the routine is the same for both, the first for cycle prepare just the data and plot all together for each case
% once completed, then the user has to select the proper optical parameters
mainFolderExps=uigetdir(fileparts(fileparts(SaveFigFolder)),"Select the folder which contains ALL EXPERIMENTS dirs (i.e. TRCDA, TRCDA_DMPC,etc)");
warning('off','curvefit:prepareFittingData:removingNaNAndInf')
% if comparison with specific optical parameters has been already done. Save time
    if ~exist(fullfile(mainFolderExps,"finalComparisonTRITIC","ComparisonResults_allExps_allScans.mat"),"file")
        if ~exist(fullfile(SaveFigFolder,"resultsData_6_1_allTRITIC.mat"),"file")
            fnames=fieldnames(TRITICdata);    
            allConditionsResults=struct;
            allConditionsResults.ID_SCAN=nameScan;
            allConditionsResults.nameExperiment=nameExperiment;
            for thTRITIC=1:numel(fnames)
                thTRITICdata=TRITICdata.(fnames{thTRITIC});
                if numel(fnames)==2
                    conditionsTRITICtext={" - PRE-AFM scan"," - POST-AFM scan"};
                elseif isscalar(fnames)
                    conditionsTRITICtext=[];
                else
                    error("More fields in the TRITIC data (other than Pre and Post) than expected! Something went wrong!")
                end
                fprintf("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%-------------------------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n" + ...
                    "%%%%%%%%" + ...
                    "----  Current TRITIC CONDITION processing: %s AFM scan  ----%%%%%%%%\n" + ...            
                    "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%-------------------------------------%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n\n",fnames{thTRITIC});
        
                % if tmp of a specific TRITIC condition already exist, take it
                nameFile=fullfile(SaveFigFolder,sprintf("TMP_%sAFM_dataCorrelationFluoHeight_allGain.mat",fnames{thTRITIC}));
                if exist(nameFile,"file")
                    load(nameFile,"DataFluoHeight_AllTimeExpGain","ratioSatOverAFM","defMASK","DataAFMHeight_AllTimeExpGain")
                else
                    % init
                    DataFluoHeight_AllTimeExpGain=cell(size(thTRITICdata));
                    DataAFMHeight_AllTimeExpGain=cell(size(thTRITICdata));
                    ratioSatOverAFM=zeros(numel(thTRITICdata),3); % store expTime - Gain - ratioSaturation
                    countRatSat=1;
                    for ithGain=1:size(thTRITICdata,2)
                        % sometimes, data are corrupted, to avoid to process again, save temporarily the results of this current cycle
                        if exist(fullfile(SaveFigFolder,sprintf("TMP_dataCorrelationFluoHeight_%d.mat",ithGain)),"file")
                            load(fullfile(SaveFigFolder,sprintf("TMP_dataCorrelationFluoHeight_%d",ithGain)),"DataFluoHeight_AllTimeExpGain","DataAFMHeight_AllTimeExpGain","ratioSatOverAFM")
                        else
                            gain=metadata_NIKON.TRITIC{1,ithGain}.Gain;
                            % prepare figure for the TRITIC fluorescence intensity distribution to investigate saturation
                            figDistTRITIC_sameScan=figure("Visible","off"); axDist=axes(figDistTRITIC_sameScan); %#ok<LAXES>
                            hold(axDist,"on")
                            xlabel(axDist,'Absolute fluorescence increase (A.U.)','FontSize',15), ylabel(axDist,"Percentage (%)",'FontSize',15)
                            title(axDist,sprintf("Distribution TRITIC (Full image)%s",conditionsTRITICtext{thTRITIC}),"FontSize",20), legend('FontSize',12)
                            subtitle(axDist,sprintf("Same Gain (%s) - Different Exposure Time",gain),"FontSize",15)
                            % prepare the bin sizes so the distributions are more comparable
                            maxTRITIC=max(cellfun(@(x) max(x(:)), thTRITICdata),[],'all');
                            minTRITIC=min(cellfun(@(x) min(x(:)), thTRITICdata),[],'all');
                            edges=linspace(minTRITIC,maxTRITIC,100);
                            % prepare figure to plot the fluorescence-height correlation in function of intensity
                            figCorrelFluoHeight_sameExp=figure("Visible","off"); axCorrInterp=axes(figCorrelFluoHeight_sameExp); %#ok<LAXES>
                            hold(axCorrInterp,"on")
                            ylabel(axCorrInterp,'Absolute fluorescence increase (A.U.)','FontSize',15), xlabel(axCorrInterp,"Height (nm)",'FontSize',15)
                            title(axCorrInterp,sprintf("Correlation Averaged TRITIC-Height (TRITIC over only PDA)%s",conditionsTRITICtext{thTRITIC}),"FontSize",20), legend('FontSize',12)
                            subtitle(axCorrInterp,sprintf("Same Gain (%s) - Different Exposure Time ; median + 25-75th percentile",gain),"FontSize",15)
                            for ithTimeExp=1:size(thTRITICdata,1)
                                % get the information about time exposure
                                ithMetadataTRITIC=metadata_NIKON.TRITIC{ithTimeExp,ithGain};
                                expTime=ithMetadataTRITIC.ExposureTime;
                                fprintf("Height-fluorescence correlation processing. Current optical parameters:\n\tGain: %g\n\tExposureTime: %g\n",str2double(gain),expTime)
                                ithTRITICdata=thTRITICdata{ithTimeExp,ithGain};                
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                %%%% SHOW FLUORESCENCE DISTRIBUTION OF FULL TRITIC IMAGE %%%%
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                % important to understand the fluorescence saturation
                                vectDelta=ithTRITICdata(:);    
                                % find the percentage of saturated values
                                ratioSat=nnz(vectDelta>edges(end-1))/length(vectDelta)*100;                
                                % prepare the name for legend
                                nameScanText=sprintf('%dms - ratioSaturation: %.2f%%',round(double(expTime)),ratioSat);
                                % show distribution of all TRITIC image
                                histogram(axDist,vectDelta,'BinEdges',edges,"DisplayName",nameScanText,"Normalization","percentage",'FaceAlpha',0.3,"FaceColor",globalColor(ithTimeExp))                
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                %%%% EXTRACT CORRELATION FLUORESCENCE-AFM HEIGHT %%%%
                                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                                % now TRITIC data is ready ==> correlation FLUORESCENCE AND AFM HEIGHT. afterHeating = true because it will process only for height-fluorescence correlation
                                Data_finalResults=A7_correlation_AFM_BF(AFMdata_1_original,AFM_IO,BF_IO,metadata_AFM,metadata_NIKON.BF,ithMetadataTRITIC,idxMon,SaveFigFolder,'TRITIC_before',ithTRITICdata,'afterHeating',true);
                                FluoHeight=Data_finalResults.Height_FLUO.Height_FLUO_1M;
                                % extract definitive masked height 
                                AFMdata_2_corr=Data_finalResults.AFM_Data;
                                idx_H = strcmp([AFMdata_2_corr.Channel_name],'Height');
                                AFMHeight_final=AFMdata_2_corr(idx_H).firstMasking_Delta;
                                if ithTimeExp==1
                                    defMASK=Data_finalResults.maskingResults.mask_first_delta;
                                end
                                % find the percentage of saturated values in corrispondence of only PDA (Delta has been masked by using AFM IO mask)
                                x=Data_finalResults.DeltaData.Delta_firstMasking(:);
                                % since masking introduces nan into matrix to consider only FR, remove them
                                x=x(~isnan(x));
                                ratioSat=nnz(x>edges(end-1))/length(x)*100;          
                                clear x
                                % prepare the name for legend
                                nameScanText=sprintf('%dms - ratioSaturation: %.2f%%',round(double(expTime)),ratioSat);             
                                % update the curve correlation of Fluorescence-Height
                                A6_feature_plotFluoHeighCorrCurve_medianPatch(axCorrInterp,FluoHeight,ithTimeExp,nameScanText)
                                % store the data                              
                                DataFluoHeight_AllTimeExpGain{ithTimeExp,ithGain}=FluoHeight;
                                DataAFMHeight_AllTimeExpGain{ithTimeExp,ithGain}=AFMHeight_final;
                                % store the ratio into the table which collect the ratio of every scan
                                ratioSatOverAFM(countRatSat,:)=[str2double(gain),expTime,ratioSat];
                                countRatSat=countRatSat+1;
                            end
                            % better show for the distribution
                            xlim(axDist,"padded"); ylim(axDist,"tight"), grid(axDist,"on"), grid(axDist,"minor")
                            legend(axDist,"Location","best")
                            objInSecondMonitor(figDistTRITIC_sameScan,idxMon);                    
                            nameFig=sprintf('resultA6_2_%d_%d_DistributionFluorescenceDiffTimeExp_gain%s_%sAFM',ithGain,thTRITIC,gain,fnames{thTRITIC});
                            pause(1)
                            saveFigures_FigAndTiff(figDistTRITIC_sameScan,SaveFigFolder,nameFig)
                            % better show for the correlation
                            xlim(axCorrInterp,"padded"); ylim(axCorrInterp,"padded"), grid(axCorrInterp,"on"), grid(axCorrInterp,"minor")
                            legend(axCorrInterp,"Location","best")
                            objInSecondMonitor(figCorrelFluoHeight_sameExp,idxMon);                        
                            nameFig=sprintf('resultA6_3_%d_%d_CorrelationFluoHeightComparisonDiffTimeExp_gain%s_%sAFM',ithGain,thTRITIC,gain,fnames{thTRITIC});
                            pause(1)
                            saveFigures_FigAndTiff(figCorrelFluoHeight_sameExp,SaveFigFolder,nameFig)   
                            % sometimes, some data are corrupted causing error, to avoid to process again, save temporarily the results of this current cycle
                            save(fullfile(SaveFigFolder,sprintf("TMP_dataCorrelationFluoHeight_%d",ithGain)),"DataFluoHeight_AllTimeExpGain","DataAFMHeight_AllTimeExpGain","ratioSatOverAFM","defMASK","-v7.3")
                        end
                    end
                    % delete the single tmp files but save the overall result for each TRITIC condition (pre-post of a single scan)
                    save(fullfile(SaveFigFolder,sprintf("TMP_%sAFM_dataCorrelationFluoHeight_allGain",fnames{thTRITIC})),"DataFluoHeight_AllTimeExpGain","DataAFMHeight_AllTimeExpGain","ratioSatOverAFM","defMASK","-v7.3")
                    % remove not useful files
                    delete(fullfile(SaveFigFolder,"TMP_dataCorrelationFluoHeight*"))
                    clear AFM_IO_final AFM_data_final axCorrInterp axDist x y s edges expTime figCorrelFluoHeight_sameExp figDistTRITIC_sameScan
                    clear Data_finalResults ratioSat FluoHeight gain idx ith maxTRITIC minTRITIC offset valid vectDelta xpatch ypatch thTRITICdata AFMdata_2_corr countRatSat 
                end
                % store the result of the TRITIC scan into the main cell array
                allConditionsResults.Height_fluo{thTRITIC}=DataFluoHeight_AllTimeExpGain;                
                allConditionsResults.TRITICcondition{thTRITIC}=fnames{thTRITIC};
                allConditionsResults.ratioSatOverAFM{thTRITIC}=ratioSatOverAFM;
                allConditionsResults.defMask{thTRITIC}=defMASK;
                allConditionsResults.HeightAFM{thTRITIC}=DataAFMHeight_AllTimeExpGain;
            end        
            % if everything is completed, save the last var into new file and delete the TMP files
            save(fullfile(SaveFigFolder,"resultsData_6_1_allTRITIC"),"allConditionsResults")
            % remove not useful files
            delete(fullfile(SaveFigFolder,"TMP_p*"))
        end  
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% END SINGLE SCAN PROCESSING %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~getValidAnswer(sprintf("Are the TRITIC data of EVERY SCANS - SPECIFIC SINGLE EXPERIMENT (%s) already processed?",nameExperiment),"",{"Y","N"},2)
            varargout{1}=[];
            varargout{2}=[];
            varargout{3}=[];
            return
        end
        clear AFM_IO AFMdata_1_original BF_IO  

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%% START THE COMPARISON PRE-POST and with other scans and conditions %%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % same experimental condition (like only TRCDA) but ALL SCANS with specific TRITIC condition (pre post)
        mainFolderScans=fileparts(fileparts(SaveFigFolder));
        ls(mainFolderScans)
        answ=getValidAnswer(sprintf("BASE FOLDER: %s\nIs the base folder which contains all the scans at the same experiment condition correct?\nCheck the Command Window (result ls).",mainFolderScans),"",{"Yes","No, upper folder","No, lower folder"});
        if answ==2
            mainFolderScans=fileparts(fileparts(fileparts(SaveFigFolder)));
        elseif answ==3
            mainFolderScans=fileparts(SaveFigFolder);
        end
        clear answ
        % check if saturation % of scan comparison has been already made. If not
        if ~exist(fullfile(mainFolderScans,"resultsComparisonScans","resultsComparisonSaturation_allScans_A6.mat"),"file")
            % Automatically find all resultsComparisonSaturation_allScans_A6.mat files
            hits = dir(fullfile(mainFolderScans, '**', 'resultsData_6_1_allTRITIC.mat'));
            if isempty(hits)
                warning("No 'resultsData_6_1_allTRITIC.mat' files found under:\n  %s", mainFolderScans);
            else
                filepathsScans = cell(numel(hits), 1);
                for k = 1:numel(hits)
                    filepathsScans{k} = fullfile(hits(k).folder, hits(k).name);
                    fprintf("Found scan filepath: %s\n", fileparts(hits(k).folder));
                end
            end   
            nScans=numel(filepathsScans);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% -- COMPARE THE PERCENTAGE OF SATURATED PIXELS AMONG DIFFERENT SCANS -- %%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            allScansConditionsResults=cell(1,nScans);
            allScans_Metadata_AFM_NIKON=struct;
            for thScan=1:nScans
                load(filepathsScans{thScan},"allConditionsResults")
                allScansConditionsResults{thScan}=allConditionsResults;
                allScans_Metadata_AFM_NIKON.AFM{thScan}=metadata_AFM;
                allScans_Metadata_AFM_NIKON.NIKON{thScan}=metadata_NIKON;
            end
            clear allConditionsResults thScan
            % first check: check if the nameExperiment are all the same among the scan
            nameExperiments = cellfun(@(s) s.nameExperiment, allScansConditionsResults, 'UniformOutput', false);        
            if ~all(contains(nameExperiments,nameExperiment))
                disp(nameExperiments)
                error("Some selected data has different nameExperiment, check it out before continuing processing.")
            end  
            numConditions=checkTRITICconditions(allScansConditionsResults);        
            % prepare comparison for each TRITIC condition: within the for-loop, process every scan at same TRITIC condition
            for j=1:numConditions
                TRITICcondition=allScansConditionsResults{1}.TRITICcondition{j};            
                % prepare the table where to store the percentage of saturated pixels    
                clear ratioSatOverAFM_all
                ratioSatOverAFM_all = table('Size', [300 5], ...
                     'VariableTypes', {'double','string','double','double','double'}, ...
                     'VariableNames', {'ID_Scan','TRITICcondition','Gain','ExpTime','PercentageSaturedPixels'});
                countData=1;                    % data counter for ratioSatOverAFM
                for i=1:nScans
                    tmpData=allScansConditionsResults{i}.ratioSatOverAFM{j};
                    tmpNameScan=allScansConditionsResults{i}.ID_SCAN;
                    tmpNameCondition=TRITICcondition;
                    for n=1:size(tmpData,1)
                        ratioSatOverAFM_all.ID_Scan(countData)=str2double(tmpNameScan);
                        ratioSatOverAFM_all.TRITICcondition(countData)=tmpNameCondition;
                        ratioSatOverAFM_all.Gain(countData)=tmpData(n,1);
                        ratioSatOverAFM_all.ExpTime(countData)=tmpData(n,2);
                        ratioSatOverAFM_all.PercentageSaturedPixels(countData)=tmpData(n,3);
                        countData=countData+1;
                    end
                end
                % remove excess rows
                ratioSatOverAFM_all=ratioSatOverAFM_all(1:countData-1,:);
                % reorganize
                ExpTimes = sort(unique(ratioSatOverAFM_all.ExpTime, 'stable'));
                gains    = sort(unique(ratioSatOverAFM_all.Gain,    'stable'));
                nRows = numel(gains) * numel(ExpTimes);
                nG=numel(gains);
                nE=numel(ExpTimes);            
                % create the table containing the saturation % among all the scans
                ratioSatOverAFM_avg = table('Size', [nRows 5], ...
                             'VariableTypes', {'double','double','double','double','double'}, ...
                             'VariableNames', {'expTime','gain','avgPerc','maxPerc','minPerc'});
                % Preallocate
                avgP = zeros(nE,nG);
                errLo = zeros(nE,nG);   % avg - min
                errHi = zeros(nE,nG);   % max - avg    
                % Build matrix: rows = expTime, cols = gain
                count = 1;
                for gi = 1:numel(gains)
                    for ei = 1:numel(ExpTimes)
                        % take for the same gain and time exp the data from different scans
                        mask = ratioSatOverAFM_all.Gain == gains(gi) & ratioSatOverAFM_all.ExpTime == ExpTimes(ei);
                        selectedPerc = ratioSatOverAFM_all.PercentageSaturedPixels(mask);
                        ratioSatOverAFM_avg.expTime(count)=ExpTimes(ei);
                        ratioSatOverAFM_avg.gain(count)=gains(gi);
                        ratioSatOverAFM_avg.avgPerc(count)=mean(selectedPerc);
                        ratioSatOverAFM_avg.maxPerc(count)=max(selectedPerc);
                        ratioSatOverAFM_avg.minPerc(count)=min(selectedPerc);
                        avgP(ei,gi)  = ratioSatOverAFM_avg.avgPerc(count);
                        errLo(ei,gi) = ratioSatOverAFM_avg.avgPerc(count) - ratioSatOverAFM_avg.minPerc(count);
                        errHi(ei,gi) = ratioSatOverAFM_avg.maxPerc(count) - ratioSatOverAFM_avg.avgPerc(count);        
                        count = count + 1;
                    end
                end
                % now we have all information to plot the saturation rate data of all the scans at same TRITIC condition - experiment
                % Grouped bar chart
                figPercSatComparison=figure("visible","off");
                b = bar(avgP, 'grouped');
                hold on;        
                for gi = 1:nG
                    b(gi).FaceColor = globalColor(gi);
                    b(gi).DisplayName = "Gain " + gains(gi);
                end    
                % Add error bars on top of each bar group
                for gi = 1:nG
                    % Get x positions of each bar in the group
                    xPos = b(gi).XEndPoints;
                    errorbar(xPos, avgP(:,gi), errLo(:,gi), errHi(:,gi), ...
                        'k', 'LineStyle', 'none', 'LineWidth', 1.2, 'CapSize', 5);
                end    
                xticklabels(string(ExpTimes));
                xlabel('Exposure Time (ms)','FontSize',15);
                ylabel('％ of saturated pixels over AFM area','FontSize',15);
                ylim([0 100])
                legend(b,'FontSize',15,'Location','northwest');
                hold off; grid on, grid minor
                if numConditions==2
                    if strcmp(TRITICcondition,'pre')
                        additionalText=" (PRE-AFM)";
                    else
                        additionalText=" (POST-AFM)";
                    end
                else
                    additionalText="";
                end
                title(sprintf("TRITIC%s %% Pixel Saturation across all %d Scans over AFM Area — Gain × Exposure Time - %s",additionalText,nScans,nameExperiment),'FontSize',18)
                objInSecondMonitor(figPercSatComparison,idxMon)
                saveFigures_FigAndTiff(figPercSatComparison,fullfile(mainFolderScans,"resultsComparisonScans"),sprintf("percentageSaturationAVG_comparisonScans_%s",TRITICcondition)) 
                RatioSatOverAFM.(TRITICcondition).All=ratioSatOverAFM_all;
                RatioSatOverAFM.(TRITICcondition).Avg=ratioSatOverAFM_avg;
                clear ratioSatOverAFM_avg additionalText avgP b count countData ei err* ExpTimes fig* flagRestart gains gi i j mask n nE nG nRows ratioSatOverAFM_avg ratioSatOverAFM_all selectedPerc tmp* xPos TRITICcondition
            end
            save(fullfile(mainFolderScans,"resultsComparisonScans","resultsComparisonSaturation_allScans_A6"),"RatioSatOverAFM","allScansConditionsResults","allScans_Metadata_AFM_NIKON",'-v7.3')
        else
            fprintf("All scans of the current experiment (%s) has been already processed.\n",nameExperiment)
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% END ALL SCAN PROCESSING SINGLE EXPERIMENT %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~getValidAnswer("Are the TRITIC data of ALL SCANS - ALL EXPERIMENTS already processed?","",{"Y","N"},2)
            varargout{1}=[];
            varargout{2}=[];
            varargout{3}=[];
            return
        end
        clc
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% -- COMPARE THE FLUORESCENCE-HEIGHT OF AVERAGED (ALL SCANS) CURVES OF ALL EXPERIMENTS -- %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % extract the data from all the files to plot the average interpolated curves of all scan of any experiment
      
        % Automatically find all resultsComparisonSaturation_allScans_A6.mat files
        hits = dir(fullfile(mainFolderExps, '**', 'resultsComparisonSaturation_allScans_A6.mat'));
        if isempty(hits)
            warning("No 'resultsComparisonSaturation_allScans_A6.mat' files found under:\n  %s", mainFolderExps);
        else
            filepathsExperiment = cell(numel(hits), 1);
            for k = 1:numel(hits)
                filepathsExperiment{k} = fullfile(hits(k).folder, hits(k).name);
                fprintf("Found experiment filepath: %s\n", fileparts(hits(k).folder));
            end
        end        
        nExps=numel(filepathsExperiment);        
        % prepare the figure to collect HEIGHT DISTRIBUTION of all experiments for each scan
        numConditions=numel(fieldnames(TRITICdata));
        % prepare the figure to collect averaged FLUORESCENCE-HEIGHT curves of all experiments for each 
        fig_allExpAvgCurvesCorr=figure("Visible","off");
        % prepare the figure to collect height distribution of all experiments. Doesnt matter PRE POST since Height is from AFM data, unlikely from Fluo-Height
        fig_allExpDistHeight=figure("Visible","off");               
        axDistHeightAllExp=axes(fig_allExpDistHeight); hold(axDistHeightAllExp,"on"), grid(axDistHeightAllExp,"on")
        xlabel(axDistHeightAllExp,'Height (nm)','FontSize',15), ylabel(axDistHeightAllExp,"Percentage (%)",'FontSize',15)   
        title(axDistHeightAllExp,"Distribution Height of all Experiments-Scans (FOREGROUND)","FontSize",20)
        if numConditions~=2
            % if only PRE condition, just one fig
            axCorrInterp{1}=axes(fig_allExpAvgCurvesCorr); hold(axCorrInterp,"on"), grid(axCorrInterp,"on")
            ylabel(axCorrInterp,'Absolute fluorescence increase (A.U.)','FontSize',15), xlabel(axCorrInterp,"Height (nm)",'FontSize',15)            
        else
            % if PRE and ONLY
            t1 = tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact',"Parent",fig_allExpAvgCurvesCorr);
            typeTRITIC={"PRE-AFM","POST-AFM"};
            for i=1:2
                axCorrInterp{i} = nexttile(t1);
                % prepare the fig to put together the curves of all experiments
                hold(axCorrInterp{i},"on")
                ylabel(axCorrInterp{i},'Absolute fluorescence increase (A.U.)','FontSize',15), xlabel(axCorrInterp{i},"Height (nm)",'FontSize',15)
                subtitle(axCorrInterp{i},sprintf("Curves as median + 25-75th percentile - %s",typeTRITIC{i}),"FontSize",16), legend('FontSize',12)               
            end
        end
        plotHandles = gobjects(0); % empty graphics object array
        nameAllExp=cell(1,nExps);
        % try to change timeExp and Gain for each loop if not satisfied
        while true   
            % init
            avgCurveCorr_allExp=struct; 
            vectHeightValues_allExp=cell(nExps,2); % min/max
            % vectHeightValues_allExp=struct; %cell(nExps,1);
            disp("PROCESSING COMPARISON ALL EXPERIMENTS.")
            for c=1:nExps                
                ithExpMainPath=filepathsExperiment{c};                 
                load(ithExpMainPath,"allScansConditionsResults","allScans_Metadata_AFM_NIKON")
                nameExp=allScansConditionsResults{1}.nameExperiment;
                nameAllExp{c}=nameExp;
                fprintf("Extraction dataset Exp Completed:\n\tEXP: %s\n",nameExp)
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%% -- CHOOSE EXP_TIME and GAIN and extract the selected data -- %%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % at the first iteration, specific optical parameters must be selected before make the final comparisons
                if c==1
                    % extract NIKON metadata from the first scan. It assumed that any scans have same TRITIC parameters (there is eventually a check)
                    metadataTRITIC=metadata_NIKON.TRITIC;
                    %metadataTRITIC=allScans_Metadata_NIKON{1}.TRITIC;
                    n = numel(metadataTRITIC);
                    gainAll    = zeros(1, n);
                    expTimeAll = zeros(1, n);            
                    for i = 1:n
                        gainAll(i)    = str2double(metadataTRITIC{i}.Gain);   % convert once
                        expTimeAll(i) = metadataTRITIC{i}.ExposureTime;
                    end
                    gainGroup=sort(unique(gainAll),'ascend');
                    expTimeGroup=sort(unique(expTimeAll),'descend');    
                    % the optimal exposure time 
                    resultsChoice=selectOptionsDialog("Which exposure time and/or gain to consider to compare different AFM scan areas?",false,gainGroup,expTimeGroup,'Titles',{'Exposure Time','Gain'});
                    selectedGain=gainGroup(resultsChoice{1});
                    selectedExpTime=expTimeGroup(resultsChoice{2});
                    clear expTimeGroup gainGroup resultsChoice i n
                    % Find matching index using logical indexing — no inner loop
                    mask = (expTimeAll == selectedExpTime) & ...
                           (gainAll    == selectedGain);            
                    idx_selectedOpticalParameters = find(mask, 1);   % expect exactly one match
                end
                clear gainAll expTimeAll mask
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % START THE EXTRACTION AND PREPARE COMPARISON %
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % once the idx is created, extract automatically the final results corrisponding with a SPECIFIC TRITIC optical parameters
                nScans=numel(allScansConditionsResults);
                % init single cleaned vector containing height values of all scans
                cellHeightValues=cell(1,nScans);
                allScanSelectedFluoHeight=cell(1,nScans);
                for ithScan=1:nScans                   
                    % check from metadata if the TRITIC with selected optical parameters exist
                    selectedMetadataTRITIC=allScans_Metadata_AFM_NIKON.NIKON{ithScan}.TRITIC{idx_selectedOpticalParameters};
                    if ~(str2double(selectedMetadataTRITIC.Gain)==selectedGain && selectedMetadataTRITIC.ExposureTime==selectedExpTime)
                        error("No data found with the selected optical conditions!")
                    end                   
                    for condTRITIC=1:numConditions
                        % extract height fluo data
                        tmp=allScansConditionsResults{ithScan}.Height_fluo{condTRITIC}{idx_selectedOpticalParameters};
                        allScanSelectedFluoHeight{ithScan}.(allScansConditionsResults{ithScan}.TRITICcondition{condTRITIC}) = tmp;                    
                        % extract height data
                        tmp=allScansConditionsResults{ithScan}.HeightAFM{condTRITIC}{idx_selectedOpticalParameters};
                        cellHeightValues{ithScan}=tmp(~isnan(tmp));
                    end
                end
                % transform pixel height into vect
                vectHeightValues=vertcat(cellHeightValues{:});
                % better show for the correlation
                % prepare the height distibution in corrispondence of only PDA-TRITIC of all scans at specific optical conditions
                vectHeightValues=vectHeightValues*1e9; % convert into nm        
                vectHeightValues_allExp{c}=vectHeightValues;
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%% --- SHOW CORRELATION CURVES AMONG ALL EXPERIMENTS --- %%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                fnames=fieldnames(allScanSelectedFluoHeight{1});
                for condTRITIC=1:numConditions
                    % prepare the average of the Fluo-Height data of all scans at specific experiment condition
                    curvesData_xy=cell(1,nScans);
                    % necessary understand min and max
                    for ithScan=1:nScans
                        x_range=[allScanSelectedFluoHeight{ithScan}.(fnames{condTRITIC}).BinCenter]*1e9; % convert into nm
                        y_range=[allScanSelectedFluoHeight{ithScan}.(fnames{condTRITIC}).BinMedian];
                        [x_clean,y_clean]=prepareCurveData(x_range,y_range);
                        curvesData_xy{ithScan}=[x_clean,y_clean];
                    end
                    % interpolation of the range data since x axis among the different scan-dataset are different other than each cell has different size
                    x_min = max(cellfun(@(c) c(1,1),   curvesData_xy));  % most restrictive left edge
                    x_max = min(cellfun(@(c) c(end,1), curvesData_xy));  % most restrictive right edge
                    N     = max(cellfun(@(c) size(c,1), curvesData_xy));  % finest resolution
                    % Define common x grid
                    x_common = linspace(x_min, x_max, N);  % or use a fixed step        
                    % Interpolate each curve-scan
                    y_interp = zeros(nScans, length(x_common));        
                    for i = 1:nScans
                        x_i = curvesData_xy{i}(:,1);
                        y_i = curvesData_xy{i}(:,2);
                        y_interp(i,:) = interp1(x_i, y_i, x_common, 'linear', NaN);
                    end
                    % Average (ignoring NaNs at edges where grids don't perfectly overlap)
                    y_mean = mean(y_interp, 1);
                    sUp = max(y_interp);
                    sDown = min(y_interp);        
                    % build shaded region
                    xpatch = [x_common, fliplr(x_common)];
                    ypatch = [sDown,    fliplr(sUp)];
                    p1=patch(axCorrInterp{condTRITIC}, xpatch, ypatch, globalColor(c), 'FaceAlpha', 0.30,'EdgeColor','none','HandleVisibility','off');
                    % plot the correlation                
                    p2=plot(axCorrInterp{condTRITIC}, x_common, y_mean,'Color', globalColor(c),'LineWidth', 2,"DisplayName",nameExp);  
                    avgCurveCorr_allExp.(fnames{condTRITIC}){c,1}=y_mean;
                    avgCurveCorr_allExp.(fnames{condTRITIC}){c,2}=x_common;                    
                    plotHandles = [plotHandles, p1, p2]; %#ok<AGROW> % accumulate the plots
                end
            end
            clear t1 selectedMetadataTRITIC selectedAFMHeight x* y* c curvesData_xy h i ith* metadataTRITIC nameExp nameFig nameScan nScans sDown sUp N vectHeightValues allS*            
            %%%%%% HEIGHT DISTRIBUTION PLOT
            % for better plot, use the height showed in the averaged correlation curves for xlim. Although more conditions, height is still the same for both condition,
            % therefore, just take the data from the first condition 
            maxheight=max(cellfun(@(c) max(c),avgCurveCorr_allExp.(fnames{1})(:,2)));
            minheight=min(cellfun(@(c) min(c),avgCurveCorr_allExp.(fnames{1})(:,2)));    
            edges=linspace(minheight,maxheight,100);
            for c=1:length(nameAllExp)
                vect=vectHeightValues_allExp{c};
                histogram(axDistHeightAllExp,vect,'BinEdges',edges,"DisplayName",nameAllExp{c},"Normalization","percentage",'FaceAlpha',0.3,"FaceColor",globalColor(c)) 
                perc90=prctile(vect,90);
                xline(axDistHeightAllExp,perc90,"--","Color",globalColor(c),"LineWidth",2,"DisplayName",sprintf("90th percentile - %.2f nm",perc90))
            end
            legend(axDistHeightAllExp,'Interpreter','none',"Location","best",'FontSize',15);
            fig_allExpDistHeight.Visible="on";
            objInSecondMonitor(fig_allExpDistHeight,idxMon)
            nameFig=sprintf('allExpDistHeight_gain%d_expTime%d',selectedGain,selectedExpTime);
            saveFigures_FigAndTiff(fig_allExpDistHeight,fullfile(mainFolderExps,"finalComparisonTRITIC"),nameFig,'closeImmediately',false)
            %%%%%% CURVE HEIGHT FLUORESCENCE CORRELATION            
            fig_allExpAvgCurvesCorr.Visible="on";
            objInSecondMonitor(fig_allExpAvgCurvesCorr,idxMon)
            sgtitle(fig_allExpAvgCurvesCorr,sprintf("Correlation Interpolated-Scans Fluorescence-Height - Gain: %d - Exposure Time: %d ms - Data from only FR",selectedGain,selectedExpTime),'FontSize',18,'Interpreter','none');
            for i=1:numConditions
                legend(axCorrInterp{i},'Interpreter','none',"Location","best",'FontSize',15);
                xlim(axCorrInterp{i},"padded"), ylim(axCorrInterp{i},"padded")
            end               
            nameFig=sprintf('allExpAvgCurvesCorr_gain%d_expTime%d',selectedGain,selectedExpTime);
            saveFigures_FigAndTiff(fig_allExpAvgCurvesCorr,fullfile(mainFolderExps,"finalComparisonTRITIC"),nameFig,'closeImmediately',false)
            clear edges c vect perc90 maxh* minh* nameFig    
            % show figures of TRITIC for better help
            [fig1,fig2]=checkAndExtractFinalData(TRITICdata,metadata_NIKON,idx_selectedOpticalParameters,selectedExpTime,selectedGain,"",false,idxMon);                      
            % end while loop. decide if interrupt here or explore a different optical parameter conditions
            if getValidAnswer("Satisfied of the selected optical parameters? If yes, take the relative TRITIC data and continue with the Force-Fluorescence correlation.","",{"Yes","No"})
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%--------- PREPARE OUTPUT ---------%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % save the choice to save time next time
                save(fullfile(mainFolderExps,"finalComparisonTRITIC","ComparisonResults_allExps_allScans.mat"),"avgCurveCorr_allExp","idx_selectedOpticalParameters","selectedGain","selectedExpTime")
                close all
                break
            else
                close(fig1), close(fig2)
                delete(plotHandles);       % removes all patch/line objects from the axes
                plotHandles = gobjects(0); % reset the array
            end
        end
    else
        load(fullfile(mainFolderExps,"finalComparisonTRITIC","ComparisonResults_allExps_allScans.mat"),"idx_selectedOpticalParameters","selectedGain","selectedExpTime")
        if getValidAnswer(sprintf("Optical parameters already previously selected.\nGAIN: %d\nEXPOSURE TIME: %d\nSelect the option:",selectedGain,selectedExpTime),"",{"Keep the current parameters","Change"})==2
            disp("No")
        end
    end
    [TRITIC_Before,TRITIC_After,metaData_NIKON_updated]=checkAndExtractFinalData(TRITICdata,metadata_NIKON,idx_selectedOpticalParameters,selectedExpTime,selectedGain,SaveFigFolder,true,idxMon);
    varargout{1}=TRITIC_Before;
    varargout{2}=TRITIC_After;
    varargout{3}=metaData_NIKON_updated;        
end        



   
function numConditions=checkTRITICconditions(allScansConditionsResults)
% check if all scans contains same TRITICcondition format (all pre-post or all pre)
    allTRITICcondition = cellfun(@(s) s.TRITICcondition, allScansConditionsResults, 'UniformOutput', false);
    % Get the contents of each cell as a sorted string for comparison
    formats = cellfun(@(c) strjoin(sort(c), '|'), allTRITICcondition, 'UniformOutput', false);
    % Check if all are identical and what type of conditions (pre or pre-post)
    if ~isscalar(unique(formats))
        disp(formats)
        error("Some selected data has different TRITIC condition, check it out before continuing processing.")
    else
        % check if there is pre or pre-post TRITIC conditions
        if isequal(formats{1},"post|pre")
            numConditions=2;
        else
            numConditions=1;
        end
    end
end

function varargout=checkAndExtractFinalData(TRITICdata,metadata_NIKON,idx_selectedOpticalParameters,selectedExpTime,selectedGain,SaveFigFolder,saveFig,idxMon)
    % extract definitive fluorescence
    TRITIC_Before=TRITICdata.pre{idx_selectedOpticalParameters};
    TRITIC_After=TRITICdata.post{idx_selectedOpticalParameters};
    metaData_NIKON_updated=metadata_NIKON.TRITIC{idx_selectedOpticalParameters};
    % check if selected Gain and TimeExp coincide with those from MetadataNikon
    if selectedGain ~= str2double(metaData_NIKON_updated.Gain) || selectedExpTime ~= metaData_NIKON_updated.ExposureTime
        error('Selected optical parameters do not match metadata.');
    end
    size_meterXpix=metaData_NIKON_updated.ImageHeight_umeterXpixel*metaData_NIKON_updated.pixelSizeUnit;
    % PLOT FLUORESCENCE IMAGES    
    titleImagePRE=sprintf('TRITIC Before Stimulation - timeExp: %d - gain: %d',selectedExpTime,selectedGain);
    titleImagePOST=sprintf('TRITIC After Stimulation - timeExp: %d - gain: %d',selectedExpTime,selectedGain);
    figTRITICpre=showData(idxMon,~saveFig,imadjust(TRITIC_Before),sprintf("%s - imadjusted",titleImagePRE),"","",'lenghtAxis',size_meterXpix*size(TRITIC_Before),'saveFig',false);
    figTRITICpost=showData(idxMon,~saveFig,imadjust(TRITIC_After),sprintf("%s - imadjusted",titleImagePOST),"","",'lenghtAxis',size_meterXpix*size(TRITIC_After),'saveFig',false);
    if saveFig
        filenameND2_PRE='resultA6_4_1_TRITIC_Before_Stimulation';
        filenameND2_POST='resultA6_4_2_TRITIC_Before_Stimulation';
        saveFigures_FigAndTiff(figTRITICpre,SaveFigFolder,filenameND2_PRE)
        saveFigures_FigAndTiff(figTRITICpost,SaveFigFolder,filenameND2_POST)
        varargout{1}=TRITIC_Before;
        varargout{2}=TRITIC_After;
        varargout{3}=metaData_NIKON_updated;
    else
        varargout{1}=figTRITICpre;
        varargout{2}=figTRITICpost;
    end
end