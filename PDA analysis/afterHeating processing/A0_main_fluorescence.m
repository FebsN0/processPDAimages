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
fmain=figure;

answer=getValidAnswer('Choose an option','',{ ...
    'Compare SAME AFM scan with different TRITIC with DIFFERENT exposure time', ...
    'Compare DIFFERENT AFM scans with different TRITIC with SAME exposure time\nSuggestion: run this option after completing the first option when optimal exp time has been found.'});
if answer==1
    flag_sameScan_DifferentExposTime=true;
else
    flag_sameScan_DifferentExposTime=false;
end

% Init
maxScans=str2double(cell2mat(inputdlg('How many scans in total?')));
results_Height_fluo_allScans=cell(1,maxScans);
fitresult_allScans=cell(1,maxScans);
nameData=cell(1,maxScans);
ithScanAFM=1;
clear answer maxScans
while true
    % the big while cycle is when flag_sameScan_DifferentExposTime=false
    % ==> to compare same exp time but of different scans

    % prepare AFM Data (for this script, only AFM Height and AFM_IO are required)
    mainPath=uigetdir(pwd,sprintf('Locate the AFM directory which contains HVoff-postheat data of a specific scan'));
    tmp=strsplit(mainPath,'\');
    nameScan=tmp{end}; nameExperiment=tmp{end-2}; groupExperiment=tmp{end-3};
    pathDataPreProcess=fullfile(mainPath,'HoverMode_OFF');
    clear tmp
    if ~exist(fullfile(pathDataPreProcess,"data_preprocess.mat"),'file')
        [allData,otherParameters,SaveFigFolder]=A1_openANDprepareAFMdata('filePath',fullfile(mainPath,'HoverMode_OFF'));
        save(fullfile(pathDataPreProcess,"data_preprocess"),"allData","otherParameters","SaveFigFolder")
    else
        load(fullfile(pathDataPreProcess,"data_preprocess.mat"),"allData","otherParameters","SaveFigFolder")
    end
    clear pathDataPreProcess
    if ~exist(fullfile(SaveFigFolder,"data_postProcessedpostAssembled.mat"),'file')
        [AFM_images_final, AFM_height_IO, metaData_AFM]= A2_processAFMdata(allData,otherParameters,mainPath,SaveFigFolder,idxMon,'modeScan','postHeatScan');     
    else
        load(fullfile(SaveFigFolder,"data_postProcessedpostAssembled"),"AFM_images_final","AFM_height_IO","metaData")    
        metaData_AFM=metaData;
        clear metaData
    end
    clear allData
    fprintf("\nGROUP EXPERIMENT: %s\nNAME EXPERIMENT:  %s\nSCAN ID:          %s\n\n",groupExperiment,nameExperiment,nameScan)
    % Open Brightfield image after sample heating and AFM normal scanning, after correct tilted effect
    [metaData_NIKON,mainPathOpticalData,timeExp,TRITICdata,BFdata]=A3_prepareBFandTRITICimages(SaveFigFolder,idxMon,groupExperiment,nameExperiment,nameScan,'postHeatProcessing',true); 





        [BF_Image,~,metaData_BF]=A3_feature_Open_ND2(fullfile(filePathOpticalData,fileName)); 
        metaData_NIKON.BF=metaData_BF;
        filenameND2="resultA1_0_BrightField";
        showData(idxMon,false,imadjust(BF_Image),"BrightField - imadjusted",SaveFigFolder,filenameND2)    
        BF_Image = A3_feature_correctBFtilted(BF_Image,idxMon,SaveFigFolder,'resultA1_1_BrightField_corrected');
        % Produce the binary IO of Brightfield
        BF_Image_IO=A4_Mic_to_Binary(BF_Image,idxMon,SaveFigFolder,'postHeat',true); 
        % Align AFM to BF and extract the offset to adjust TRITIC later
        [AFM_IO_final,BF_Image_IO,AFM_data_final,~,offset]=A5_alignment_AFM_Microscope(BF_Image_IO,metaData_NIKON.BF,AFM_height_IO,metaData_AFM,AFM_images_final,SaveFigFolder,idxMon,'Margin',150);
        
    % start TRITIC extraction
    if flag_sameScan_DifferentExposTime
        % select one or more files TRITIC
        [fileNames, filePathOpticalData] = uigetfile({'*.nd2'}, 'Select one or more TRITIC files after heating',filePathOpticalData,'MultiSelect','on');
        if isequal(fileNameSections,0)
            error('No File Selected');
        else
            if ~iscell(fileNames)
                fileNames={fileNames};
            end
        end
        numFiles = length(fileNames);
        % init the var where store the data
        all_TRITIC_Images=cell(1,numFiles); 
        all_metadataTRITIC=cell(1,numFiles);
        nameScans=cell(1,numFiles);
        % for each TRITIC file, extract
        for ithScan=1:numFiles
            ithTRITICfilename=fullfile(filePathOpticalData,fileNames{ithScan});
            [Tritic_Image,~,metadataTRITIC]=A3_feature_Open_ND2(ithTRITICfilename);
            metaData_NIKON.TRITIC=metadataTRITIC;
            % get the information about time exposure and used gain 
            nameScans{ithScan}=sprintf('%dms_Gain%s',round(double(metadataTRITIC.ExposureTime)),metadataTRITIC.Gain);
            % save pic
            filenameND2=sprintf("resultA2_%d_TRITIC_%s",ithScan,nameScans{ithScan});
            titleTRITIC=sprintf("TRITIC (%s) - imadjusted",nameScans{ithScan});
            showData(idxMon,false,imadjust(Tritic_Image),titleTRITIC,SaveFigFolder,filenameND2)                
            % show BF and TRITIC overlapped. Note: no need to qlign the two images because taken fastily at the same moment
            f1=figure('Visible','off');
            imshow(imfuse(imadjust(BF_Image),imadjust(Tritic_Image)))
            title(sprintf("BF and TRITIC (%s) overlapped",nameScans{ithScan}),'FontSize',15,'Interpreter','none')
            objInSecondMonitor(f1,idxMon);
            filenameND2=sprintf("resultA3_%d_BF_TRITIC_%s_overlapped",ithScan,nameScans{ithScan});
            saveFigures_FigAndTiff(f1,SaveFigFolder,filenameND2)
            % using offset obtained from AFM alignment
            Tritic_Image=fixSize(Tritic_Image,offset);  




            
            % now TRITIC data is ready ==> correlation FLUORESCENCE AND AFM HEIGHT
            Data_finalResults=A6_correlation_AFM_BF(AFM_data_final,AFM_IO_final,metaData_AFM,metaData_NIKON,idxMon,SaveFigFolder,filePathOpticalData,metaData_NIKON.TRITIC.ExposureTime,'TRITIC_before',Tritic_Image,'afterHeating',true);
            results_Height_fluo=Data_finalResults.Height_FLUO;
            deltaADJ=Data_finalResults.DeltaData;
            results_Height_fluo_allScans{m}=results_Height_fluo;



            % select the end point in which create the curve fitting
            [xData, yData] = prepareCurveData(vertcat(results_Height_fluo.BinCenter),vertcat(results_Height_fluo.MeanBin)); 
            uiwait(msgbox('Click on the plot to select the index for which the underlying values are considered',''));
            closest_indices = selectRangeGInput(1,1,xData*1e9, yData);
    
            close gcf
            
            % show distribution of delta to check saturation (last bar very high)
            deltaADJ=deltaADJ(:); deltaADJ=deltaADJ(~isnan(deltaADJ));
            fh=figure('Visible','off');
            histogram(deltaADJ)
            xlabel('Absolute fluorescence increase (A.U.)','FontSize',15)
            title(sprintf('Distribution Delta Fluorescence - %s',nameData{m}),'FontSize',15)
            objInSecondMonitor(fh,idxMon);
            saveas(fh,sprintf('%s/A12_deltaFluorescenceDistribution - %s.tiff',SaveFigFolder,char(nameData{m})))
            close(fh)
    
            figure(fmain)
            hold on
            plot(xData, yData,'*','Color',globalColor(m),'DisplayName',sprintf('Exp - %s',nameData{m}))
            xData=xData(1:closest_indices);
            yData=yData(1:closest_indices);
            
            % Set up fittype and options.
            ft = fittype( 'poly1' ); opts = fitoptions( 'Method', 'LinearLeastSquares' ); opts.Robust = 'LAR';
            % Fit model to data.
            fitresult = fit( xData, yData, ft, opts );
            fitresult_allScans{m}=fitresult;
            hold on
            x=linspace(min(xData),max(xData),100);
            plot(x,x*fitresult.p1+fitresult.p2,'Color',globalColor(m),'LineWidth',2,'DisplayName',sprintf('Fit   - %s',nameData{m}))
            m=m+1;
        end
    end
    if flag_sameScan_DifferentExposTime
        break
    end    
end
%%
objInSecondMonitor(fmain,idxMon);

ylabel('Absolute fluorescence increase (A.U.)','FontSize',15)
xlabel('Feature height (nm)','FontSize',15)
title('Height Vs Fluorescence and Correlation ','FontSize',20)

% Create legend
legend1 = legend('Location','bestoutside','Fontsize',15);
saveas(fmain,sprintf('%s/A13_end_heighVSfluorescenceCorrelation.tiff',SaveFigFolder))

maxFluor=max(yData);
save(sprintf('%s\\dataResultsAfterHeating.mat',SaveFigFolder))