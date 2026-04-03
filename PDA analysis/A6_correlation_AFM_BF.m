% OUTPUT:
%   dataResultsPlot = struct which contains the results of:
%       1) .Delta               = delta fluorescence data
%       2) .Height_LD               = Height VS Lateral Deflection           
%       3) .Height99perc_LD_maxVD   = Height (99 percentile removed) VS Lateral Deflection (up to max vertical deflection)
%       4) .Height_FLUO             = Height VS FLUORESCENCE         
%       5) .Height99perc_FLUO       = Height (99 percentile removed) VS FLUORESCENCE
%       6) .LD_FLUO                 = Lateral Deflection VS FLUORESCENCE
%       7) .LDmaxVD_FLUO            = Lateral Deflection (up to max vertical deflection) VS FLUORESCENCE 
%       8) .VD_FLUO                 = Vertical Deflection VS FLUORESCENCE
%       9) .VD_LD                   = Vertical Deflection VS Lateral Deflection
%      10) .VD_LDmaxVD              = Vertical Deflection VS Lateral Deflection (up to max vertical deflection)
%
% the following script process data from different situation:
%       1) normal experiment:   AFM + pre and post scan fluorescence image  + BF image
%       2) after heating:       AFM + single scan fluorescence image        + BF image
%               NOTE: it doesn't matter if before or after scanning
%       3) process only AFM data

function dataResultsPlot=A6_correlation_AFM_BF(AFM_data,AFM_IO_Padded,metadataAFM,metadataBF,metadataTRITIC,idxMon,folderResultsImg,varargin)
    
    p=inputParser();
    addRequired(p,'AFM_data');
    addRequired(p,'AFM_IO_Padded')
    argName = 'TRITIC_before';      defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'TRITIC_after';       defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'Silent';             defaultVal = true;   addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'afterHeating';       defaultVal = false;  addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'innerBorderCalc';    defaultVal = false;  addParameter(p,argName,defaultVal,@(x) islogical(x));

    parse(p,AFM_data,AFM_IO_Padded,varargin{:});
    clearvars argName defaultVal
    if p.Results.Silent; SeeMe=0; else, SeeMe=1; end
    if p.Results.innerBorderCalc; innerBord=1; else, innerBord=0; end
    % in case one of the two is missing, substract by min value
    if p.Results.afterHeating; flag_heat=true; else, flag_heat=false; end
    if ~flag_heat
        % remove existing fig, tif, tiff files to avoid confusion
        allowedExt = {'.tif', '.tiff', '.fig'};
        % Recursively get all files in the directory and subdirectories
        files = dir(fullfile(folderResultsImg, '**', 'resultA6_*'));
        % Loop through and delete each file
        for k = 1:length(files)
            [~, ~, ext] = fileparts(files(k).name);
            if ismember(lower(ext), allowedExt)
                filePath = fullfile(files(k).folder, files(k).name);
                delete(filePath);
            end
        end
    end      
    setpoints=metadataAFM.SetP_N;
    % extract the required values from metadata
    timeExp=metadataTRITIC.ExposureTime;
    size_meterXpix=metadataBF.ImageHeight_umeterXpixel*metadataBF.pixelSizeUnit;

    % init var where store results
    dataResultsPlot=struct();
    numBins=100; %default
    flag_onlyAFM=false;
    % prepare the fluorescence data X normal experiment and calc Delta fluorescence
    if ~flag_heat && (~isempty(p.Results.TRITIC_before) && ~isempty(p.Results.TRITIC_after))
        BF_Before=p.Results.TRITIC_before;
        BF_After=p.Results.TRITIC_after;
        Delta = BF_After-BF_Before;
    % prepare the fluorescence data X afterHeating experiment. At least one fluorescence image must be provided
    elseif flag_heat && (xor(isempty(p.Results.TRITIC_before),isempty(p.Results.TRITIC_after)))     
        % Calc the fluorescence delta by removing the minimum value
        % when (p.Results.TRITIC_before) = 0, take the after, otherwise the before
        if isempty(p.Results.TRITIC_before)
            Delta = p.Results.TRITIC_after - min(p.Results.TRITIC_after(:));
        else
            Delta = p.Results.TRITIC_before - min(p.Results.TRITIC_before(:));
        end
        numBins=500;            
    else
    % process only AFM data
        flag_onlyAFM=true;
    end
 
    % find the idx of Height and Lateral/vertical Deflection in Trace Mode
    idx_LD = strcmp([AFM_data.Channel_name],'Lateral Deflection') & strcmp([AFM_data.Trace_type],'Trace');
    idx_H = strcmp([AFM_data.Channel_name],'Height (measured)');
    idx_VD =  strcmp([AFM_data.Channel_name],'Vertical Deflection') & strcmp([AFM_data.Trace_type],'Trace');
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% prepare the data before do anything: it means removing background data and negative values %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % In the previous versions, a mask was generated in each type of data, resetting the previous ones.
    % Therefore, the data of each channel and Fluorescence don't have NaN at the same pixel position 
    % (i.e. negative value in a specific pixel of a channel may be not negative in the same pixel 
    % position in another channel).
    % The new solution is merging the mask of Delta with any channel before applying it to the single data.
    % In this way, the same mask is applied to any data!
    % crystal/PDA/polymer == 1   ||   background = 0
    mask_AFM=logical(AFM_IO_Padded);   

    % There may be NaN values in height and lateral channel that have been manually removed at the end of the Height/Lateral data processing
    % steps. To avoid vector incompatibilities during the correlation calculation, prepare the mask before starting the additional masking
    mask_validValues= ~isnan(AFM_data(idx_H).AFM_padded);  
    mask_AFM = mask_AFM & mask_validValues;
    mask_validValues= ~isnan(AFM_data(idx_LD).AFM_padded);
    mask_AFM = mask_AFM & mask_validValues;
    
    % obtain the mask from Delta if it exists. 
    if ~flag_onlyAFM     
        % both last and original version shifted data to kind of minimum
        % original version: 
        % Min_Delta_glass=min(Delta_glass(:),[],"omitnan");
        % last version (two pixels at same position of the two different TRITIC (after and before) often may significantly
        % different values although the BK should be identical.
        % threshold = prctile(Delta_BK_clean, percentile=0.1);        
        % Delta_BK_ADJ=Delta_BK-threshold; Delta_ADJ=Delta-threshold;
        % but it has been decided to keep the values as they are.
        % create the first new mask (AFM IO + Delta Pos)
        mask_validValues= Delta>0;                      % exclude zeros and negative values
        mask_first = mask_AFM & mask_validValues;                     % merge the mask with original AFM_IO_Padded        
        % copy Delta and apply first mask (AFM IO + pos values)
        Delta_firstMasking=Delta;        
        Delta_firstMasking(~mask_first)=nan; % FOREGROUND DELTA               
        % store Delta and its modifications
        DeltaData=struct();        
        DeltaData.Delta_original=Delta;
        DeltaData.Delta_firstMasking=Delta_firstMasking;
        % show Delta Foreground and Background after first mask
        Delta_BK=Delta; Delta_BK(mask_AFM) = NaN; 
        Delta_FR=Delta; Delta_FR(~mask_AFM) = NaN;                 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% SHOW DELTA DISTRIBUTION %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if ~flag_heat
           % To avoid too many single figures for each time exposure, plot after
            fDistDelta=figure('Visible','off'); hold on
            xlabel('Delta Fluorescence','FontSize',15), ylabel("PDF",'FontSize',15)
            vectDeltaFR=Delta_FR(:); vectDeltaFR=vectDeltaFR(~isnan(vectDeltaFR));  
            vectDeltaBK=Delta_BK(:); vectDeltaBK=vectDeltaBK(~isnan(vectDeltaBK)); 
            % prepare histogram. round not work to excess but to nearest.
            xmin=floor(min(min(vectDeltaBK),min(vectDeltaFR)) * 1000) / 1000;
            xmax=ceil(max(max(vectDeltaBK),max(vectDeltaFR)) * 1000) / 1000;
            edges=linspace(xmin,xmax,500);
            histogram(vectDeltaBK,'BinEdges',edges,"DisplayName","Delta Background","Normalization","pdf",'FaceAlpha',0.5,"FaceColor",globalColor(1))
            histogram(vectDeltaFR,'BinEdges',edges,"DisplayName","Delta Foreground","Normalization","pdf",'FaceAlpha',0.5,"FaceColor",globalColor(2))
            xline(prctile(vectDeltaBK,90),'--','LineWidth',2,'DisplayName','90° percentile Delta Background','Color',globalColor(1));
            xline(prctile(vectDeltaFR,90),'--','LineWidth',2,'DisplayName','90° percentile Delta Foreground','Color',globalColor(2));
            % better show
            allData = [vectDeltaBK; vectDeltaFR];
            pLow = prctile(allData, 0.1);
            pHigh = prctile(allData, 98);
            xlim([pLow, pHigh]); ylim tight, grid on, grid minor
            title(sprintf("Distribution Delta"),"FontSize",20), legend('FontSize',12)
            subtitle(sprintf("(Data shown is within 0.1° - 98° percentile of the entire data. Used AFM-IO mask after BF-AFM registration)"),"FontSize",15)
            objInSecondMonitor(fDistDelta,idxMon);
            nameFig='resultA6_0_DistributionDelta';
            saveFigures_FigAndTiff(fDistDelta,folderResultsImg,nameFig)     
        end
    end
    %%% the next mask filtering is only for normal AFM scans. In case of heated samples, setpoint limit is meaningless.
    idx=idx_H |idx_LD | idx_VD;
    if ~flag_heat
        % obtain the mask from each channel and ignore:
        %   - negative and zeros values
        % then merge the valid mask with the main mask        
        mask = mask_first;
        for i=1:length(idx)
            if idx(i)
                mask_validValues= AFM_data(i).AFM_padded>0;
                mask = mask & mask_validValues;
            end
        end
        mask_second=mask; 
        % obtain the definitive third mask (more aggressive) considering the removal of Lateral Force > 2*maxSetpoint
        % NOTE, lateral force higher than vertical force is derived not from friction phenomena but rather 
        % the collision between the tip and the surface and other instabilities.
        limitVD=max(setpoints)*2;
        mask_validValues= AFM_data(idx_LD).AFM_padded<=limitVD;          % exclude values higher than limit setpoint  
        mask_third=mask_second & mask_validValues;         % merge the mask with the previous mask  
    end
    masking = struct();
    % store delta original (AFM IO)
    masking.mask_original = mask_AFM;
    masking.mask_original_totElements = nnz(mask_AFM);
    % store mask after delta
    masking.mask_first_delta = mask_first;
    masking.mask_first_delta_totElements = nnz(mask_first);
    % store mask after each channel (only for normal AFM scans)
    if ~flag_heat
        masking.mask_second_eachChannel = mask_second;
        masking.mask_second_eachChannel_totElements = nnz(mask_second);
        % store mask after 99perc and <maxSetpoint
        masking.mask_third_setpointLimit_99percRemoval = mask_third;
        masking.mask_third_setpointLimit_99percRemoval_totElements = nnz(mask_third);        
    end
    dataResultsPlot.maskingResults = masking;
    % show the plots of the masks in case of normal AFM scans
    if ~flag_heat
        showData(idxMon,SeeMe,mask_AFM,{'Original Mask';'Generated from AFM-Height Binarization + modification due to registration'},folderResultsImg,'resultA6_1_1_OriginalMask','binary',true,'lenghtAxis',size_meterXpix*size(mask_first))
        showData(idxMon,SeeMe,mask_first,{'First Mask';'From Delta Positive value only'},folderResultsImg,'resultA6_1_2_FirstMask','binary',true,'lenghtAxis',size_meterXpix*size(mask_first))
        showData(idxMon,SeeMe,mask_second,{'Second Mask';'From any AFM channel with Positive values'},folderResultsImg,'resultA6_1_3_SecondMask','binary',true,'lenghtAxis',size_meterXpix*size(mask_second))
        showData(idxMon,SeeMe,mask_third,{'Third Mask';'From AFM Height 99° percentile + AFM Lateral < 2*maxSetP'},folderResultsImg,'resultA6_1_4_ThirdMask','binary',true,'lenghtAxis',size_meterXpix*size(mask_third))   
    end
    clear masking mask_validValues     
    %%%%%%%---------- Finally, applying the mask_definitive to all the data! ----------%%%%%%%
    if ~flag_onlyAFM && ~flag_heat
        % fix Delta using new mask
        Delta_secondMasking=Delta;
        Delta_secondMasking(~mask_second) = NaN;
        % fix Delta using the definitive mask considering 99perc removal and LD>1.1*maxSetpoint removal
        Delta_thirdMasking=Delta;
        Delta_thirdMasking(~mask_third) = NaN;
        % store the results
        DeltaData.Delta_secondMasking_eachAFM=Delta_secondMasking;
        DeltaData.Delta_thirdMasking_99percMaxSet=Delta_thirdMasking;
    end
    for i=1:length(idx)
        if idx(i)
            % apply original mask (AFM IO only)
            tmp = AFM_data(i).AFM_padded;
            tmp(~mask_AFM) = NaN;
            AFM_data(i).originalMasking = tmp;
            % apply first Masking (mask from Delta)
            tmp = AFM_data(i).AFM_padded;
            tmp(~mask_first) = NaN;
            AFM_data(i).firstMasking_Delta = tmp;
            if ~flag_heat
                % apply second Masking (mask from merging AFM channel masking)
                tmp = AFM_data(i).AFM_padded;
                tmp(~mask_second) = NaN;
                AFM_data(i).secondMasking_eachAFM = tmp;
                % apply third Masking (mask from 99perc + <maxSP)
                tmp = AFM_data(i).AFM_padded;
                tmp(~mask_third) = NaN;
                AFM_data(i).thirdMasking_maxVD_99perc = tmp;
            end
        end
    end   
  
    % Delta with the first mask to show how really Delta is.
    labelBar="Absolute fluorescence increase (A.U.)";
    size_meterXpix=metadataTRITIC.ImageHeight_umeterXpixel*metadataTRITIC.pixelSizeUnit;
    % in case of normal AFM scans
    if ~flag_heat
        % delta BK  
        showData(idxMon,false,Delta_BK,"Delta Fluorescence Background (original AFM-IO mask)",folderResultsImg,'resultA6_2_0_DeltaFluorescenceBackground_originalMask','lenghtAxis',size_meterXpix*size(Delta),'labelBar',labelBar)  
        % delta masked
        showData(idxMon,SeeMe,Delta_FR,"Delta Fluorescence (original AFM-IO mask)",folderResultsImg,'resultA6_2_1_DeltaFluorescence_originalMask','lenghtAxis',size_meterXpix*size(Delta),'labelBar',labelBar)  
        showData(idxMon,SeeMe,Delta_firstMasking,'Delta Fluorescence (1st mask)',folderResultsImg,'resultA6_2_2_DeltaFluorescenceFirstMask','lenghtAxis',size_meterXpix*size(Delta_firstMasking),'labelBar',labelBar)            
        showData(idxMon,SeeMe,Delta_secondMasking,'Delta Fluorescence (2nd mask)',folderResultsImg,'resultA6_2_3_DeltaFluorescenceDefinitiveMasked','lenghtAxis',size_meterXpix*size(Delta_firstMasking),'labelBar',labelBar)            
        showData(idxMon,SeeMe,Delta_thirdMasking,'Delta Fluorescence (3rd mask)',folderResultsImg,'resultA6_2_4_DeltaFluorescenceDefinitiveMasked','lenghtAxis',size_meterXpix*size(Delta_firstMasking),'labelBar',labelBar)              
    end    
    dataResultsPlot.DeltaData=DeltaData;
    dataResultsPlot.AFM_Data=AFM_data; 
    clear Delta Delta_firstMasking Delta_secondMasking Delta_thirdMasking 
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% EXTRACT BORDERS AND DISTINGUISH INNER AND OUTER OF THE DATA %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    if innerBord && ~flag_heat
        calcBorders(AFM_data,AFM_IO_Padded,idx_H,idx_LD,idx_VD,DeltaData,flag_heat,idxMon,SeeMe,folderResultsImg)        
    end    
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% FINAL PART: CORRELATE THE DATA %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    % Define data for masks
    if flag_heat
        maskFields = {
            'firstMasking_Delta',                'Delta_firstMasking',              '1st mask',     '1M';            
        };
    else
        maskFields = {
            'firstMasking_Delta',                'Delta_firstMasking',              '1st mask',     '1M';
            'secondMasking_eachAFM',             'Delta_secondMasking_eachAFM',     '2nd mask',     '2M';
            'thirdMasking_maxVD_99perc',         'Delta_thirdMasking_99percMaxSet', '3rd mask',     '3M';
        };
    end
    if ~flag_heat
        % 7 - HEIGHT VS LATERAL FORCE
        tmp=struct();
        for i=1:size(maskFields,1)
            % use the AFM masked data
            x = AFM_data(idx_H).(maskFields{i,1})(:);
            y = AFM_data(idx_LD).(maskFields{i,1})(:);
            titleP = sprintf('Height VS Lateral Deflection (%s)', maskFields{i,4});
            figName = sprintf('Height_LD_%s', maskFields{i,5});
            tmp.(['Height_LD_' maskFields{i,5}]) = A6_feature_corrForceFluorescence(x,y,idxMon,folderResultsImg,'NumberOfBins',numBins, ...
                'xpar',1e9,'XAxL','Feature height (nm)','ypar',1e9,'YAyL','Lateral Force (nN)','FigTitle',titleP,'FigFilename',figName,'NumFig',1);
        end
        dataResultsPlot.Height_LD=tmp;
    end

    if ~flag_onlyAFM
        % 8 - HEIGHT VS FLUORESCENCE INCREASE
        tmp=struct();
        for i = 1:size(maskFields,1)
            x = AFM_data(idx_H).(maskFields{i,1})(:);
            y1 = DeltaData.(maskFields{i,2})(:); 
            titleP = sprintf('Height Vs Fluorescence (%s - time exp %g ms)', maskFields{i,3}, timeExp);
            figName = sprintf('Height_Fluo_%s', maskFields{i,4});
            tmp.(['Height_FLUO_' maskFields{i,4}]) = A6_feature_corrForceFluorescence(x,y1,idxMon,folderResultsImg,'NumberOfBins',numBins, ...
                'xpar',1e9,'XAxL','Feature height (nm)','ypar',1,'YAyL',labelBar,'FigTitle',titleP,'FigFilename',figName,'NumFig',2,'flagHeat',true);            
        end
        dataResultsPlot.Height_FLUO=tmp;

        if ~flag_heat
            % 9 - LATERAL DEFLECTION Vs FLUORESCENCE INCREASE
            tmp=struct();
            for i = 1:size(maskFields,1)
                x = AFM_data(idx_LD).(maskFields{i,1})(:);
                y1 = DeltaData.(maskFields{i,2})(:); 
                titleP = sprintf('Lateral Force Vs Fluorescence (%s - time exp %s ms)', maskFields{i,4}, timeExp); 
                figName = sprintf('LD_Fluo_%s', maskFields{i,5});
                tmp.(['LD_FLUO_' maskFields{i,5}]) =        A6_feature_corrForceFluorescence(x,y1,idxMon,folderResultsImg,'NumberOfBins',2000, ...
                    'xpar',1e9,'XAxL','Lateral Force (nN)','ypar',1,'YAyL',labelBar,'FigTitle',titleP,'FigFilename',figName,'NumFig',4);            
            end
            dataResultsPlot.LD_FLUO=tmp;
           
            % 10 - VERTICAL FORCE VS FLUORESCENCE INCREASE
            tmp=struct();
            for i = 1:size(maskFields,1)
                x = AFM_data(idx_VD).(maskFields{i,1})(:);
                y1 = DeltaData.(maskFields{i,2})(:); 
                titleP = sprintf('Vertical Force Vs Fluorescence (%s - time exp %s ms)', maskFields{i,4}, timeExp); 
                figName = sprintf('VD_Fluo_%s', maskFields{i,5});
                tmp.(['VD_FLUO_' maskFields{i,5}]) =        A6_feature_corrForceFluorescence(x,y1,idxMon,folderResultsImg,'setpoints',setpoints, ...
                    'xpar',1e9,'XAxL','Vertical Force (nN)','ypar',1,'YAyL',labelBar,'FigTitle',titleP,'FigFilename',figName,'NumFig',6);            
            end
            dataResultsPlot.VD_FLUO=tmp;
        end
    end
    if ~flag_heat
        % 11 - VERTICAL FORCE VS LATERAL FORCE
        tmp=struct();
        for i=1:size(maskFields,1)
            x = AFM_data(idx_VD).(maskFields{i,1})(:);
            y = AFM_data(idx_LD).(maskFields{i,1})(:); 
            titleP = sprintf('Vertical Force VS Lateral Force (%s)', maskFields{i,4});
            figName = sprintf('VD_LD_%s', maskFields{i,5});
            tmp.(['VD_LD_' maskFields{i,5}]) = A6_feature_corrForceFluorescence(x,y,idxMon,folderResultsImg,'setpoints',setpoints, ...
                'xpar',1e9,'XAxL','Vertical Force (nN)','ypar',1e9,'YAyL','Lateral Force (nN)','FigTitle',titleP,'FigFilename',figName,'NumFig',8);
        end
        dataResultsPlot.VD_LD=tmp;
    end    
end


function calcBorders(AFM_data,AFM_IO_Padded,idx_H,idx_LD,idx_VD,DeltaData,flag_heat,secondMonitorMain,SeeMe,folderResultsImg)     
    % Identification of borders from the binarised Height image
    AFM_IO_Padded_Borders=AFM_IO_Padded;
    AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
    AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
    se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
    AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 
    showData(secondMonitorMain,SeeMe,AFM_IO_Borders_Grow,false,'Borders','',folderResultsImg,'resultA6_4_1_Borders','Binarized',true)

    % Elaboration of Height to extract inner and border regions
    AFM_Height_Border=AFM_data(idx_H).AFM_padded;
    AFM_Height_Border(AFM_IO_Padded==0)=nan;
    AFM_Height_Border(AFM_IO_Borders_Grow==0)=nan; 
    AFM_Height_Border(AFM_Height_Border<=0)=nan;
    
    AFM_Height_Inner=AFM_data(idx_H).AFM_padded;
    AFM_Height_Inner(AFM_IO_Padded==0)=nan; 
    AFM_Height_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_Height_Inner(AFM_Height_Inner<=0)=nan;
    
    titleD1='AFM Height Border';
    titleD2='AFM Height Inner';
    labelBar=sprintf('Height (\x03bcm)');
    showData(secondMonitorMain,SeeMe,AFM_Height_Border*1e6,false,titleD1,labelBar,folderResultsImg,'resultA6_4_2_BorderAndInner_AFM_Height','data2',AFM_Height_Inner*1e6,'titleData2',titleD2,'background',true)

    % Elaboration of LD to extract inner and border regions
    AFM_LD_Border=AFM_data(idx_LD).AFM_padded;
    AFM_LD_Border(AFM_IO_Padded==0)=nan; 
    AFM_LD_Border(AFM_IO_Borders_Grow==0)=nan;
    AFM_LD_Border(AFM_LD_Border<=0)=nan;

    AFM_LD_Inner=AFM_data(idx_LD).AFM_padded;
    AFM_LD_Inner(AFM_IO_Padded==0)=nan;
    AFM_LD_Inner(AFM_IO_Borders_Grow==1)=nan;
    AFM_LD_Inner(AFM_LD_Inner<=0)=nan; 

    titleD1='AFM LD Border';
    titleD2='AFM LD Inner';
    labelBar='Force [nN]';  
    showData(secondMonitorMain,SeeMe,AFM_LD_Border*1e9,false,titleD1,labelBar,folderResultsImg,'resultA6_4_3_BorderAndInner_AFM_LateralDeflection','data2',AFM_LD_Inner*1e9,'titleData2',titleD2,'background',true)

    % Elaboration of VD to extract inner and border regions
    AFM_VD_Border=AFM_data(idx_VD).AFM_padded;
    AFM_VD_Border(AFM_IO_Padded==0)=nan; 
    AFM_VD_Border(AFM_IO_Borders_Grow==0)=nan;  
    AFM_VD_Border(AFM_VD_Border<=0)=nan;
    
    AFM_VD_Inner=AFM_data(idx_VD).AFM_padded;
    AFM_VD_Inner(AFM_IO_Padded==0)=nan; 
    AFM_VD_Inner(AFM_IO_Borders_Grow==1)=nan;  
    AFM_VD_Inner(AFM_VD_Inner<=0)=nan;

    titleD1='AFM VD Border';
    titleD2='AFM VD Inner';
    labelBar='Force [nN]';  
    showData(secondMonitorMain,SeeMe,AFM_VD_Border*1e9,false,titleD1,labelBar,folderResultsImg,'resultA6_4_4_BorderAndInner_AFM_VerticalDeflection','data2',AFM_VD_Inner*1e9,'titleData2',titleD2,'background',true)
    
    % Elaboration of Fluorescent Images to extract inner and border regions
    if ~flag_heat           
        TRITIC_Border_Delta=DeltaData.Delta_ADJ_secondMasking_eachAFM; 
        TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
        TRITIC_Inner_Delta=Delta.completeMask; 
        TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;
        titleD1='Tritic Border Delta';
        titleD2='Tritic Inner Delta';
        labelBar='Absolute Fluorescence';  
        showData(secondMonitorMain,SeeMe,TRITIC_Border_Delta,false,titleD1,labelBar,folderResultsImg,'resultA6_4_5_BorderAndInner_TRITIC_DELTA','data2',TRITIC_Inner_Delta,'titleData2',titleD2,'background',true)     
    end
    close all 
end
