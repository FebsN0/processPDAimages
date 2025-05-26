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

function dataResultsPlot=A10_correlation_AFM_BF(AFM_data,AFM_IO_Padded,size_umeterXpix,setpoints,secondMonitorMain,newFolder,mainPathOpticalData,timeExp,varargin)
    
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
    % remove existing fig, tif, tiff files to avoid confusion
    allowedExt = {'.tif', '.tiff', '.fig'};
    % Recursively get all files in the directory and subdirectories
    files = dir(fullfile(newFolder, '**', 'resultA10_*'));
    % Loop through and delete each file
    for k = 1:length(files)
        [~, ~, ext] = fileparts(files(k).name);
        if ismember(lower(ext), allowedExt)
            filePath = fullfile(files(k).folder, files(k).name);
            delete(filePath);
        end
    end

    if p.Results.Silent; SeeMe=0; else, SeeMe=1; end
    if p.Results.innerBorderCalc; innerBord=1; else, innerBord=0; end
    % in case one of the two is missing, substract by min value
    if p.Results.afterHeating; flag_heat=true; else, flag_heat=false; end

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
        Delta = (isempty(p.Results.TRITIC_before)*(p.Results.TRITIC_after-min(p.Results.TRITIC_after(:)))) + ...
                (~isempty(p.Results.TRITIC_before)*(p.Results.TRITIC_before-min(p.Results.TRITIC_before(:))));
        numBins=500;            
    else
    % process only AFM data
        flag_onlyAFM=true;
    end
    % plot original Delta
    labelBar={'Absolute fluorescence increase (A.U.)'}; % in case of no normalization
    showData(secondMonitorMain,SeeMe,1,Delta,false,'Delta Fluorescence (After-Before, original)',labelBar,newFolder,'resultA10_1_DeltaFluorescenceOriginal','meterUnit',size_umeterXpix)
   
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
    mask_original=logical(AFM_IO_Padded);       
    % obtain the mask from Delta if it exists. 
    if ~flag_onlyAFM              
        % obtain the minimum value of background so Delta can be
        % substracted by such a value
        Delta_glass=Delta; Delta_glass(mask_original) = NaN;
        % Intensity minimum in the glass region to be subtracted:
        Min_Delta_glass=min(Delta_glass(:),[],"omitnan");
        % Fix Delta
        Delta_glass_ADJ=Delta_glass-Min_Delta_glass;
        Delta_ADJ=Delta-Min_Delta_glass;
        if ~flag_heat
            titleD1='Delta Fluorescence (Shifted)';
            titleD2='Delta Fluorescence background (Masked and Shifted)';            
            showData(secondMonitorMain,SeeMe,2,Delta_ADJ,false,titleD1,labelBar,newFolder,'resultA10_2_Fluorescence_PDA_BackGround','data2',Delta_glass_ADJ,'titleData2',titleD2,'background',true,'meterUnit',size_umeterXpix)
        end
        % create the first new mask (AFM IO + Delta Pos)
        mask_validValues= Delta_ADJ>0;                      % exclude zeros and negative values
        mask_first = mask_original & mask_validValues;                     % merge the mask with original AFM_IO_Padded        
        % copy Delta and apply first mask (AFM IO + pos values)
        Delta_ADJ_firstMasking=Delta_ADJ;
        Delta_ADJ_firstMasking(~mask_first)=nan;               
        % store Delta and its modifications
        DeltaData=struct();
        DeltaData.Delta_original=Delta;
        DeltaData.Delta_ADJ_minShifted=Delta_ADJ;
        DeltaData.Delta_ADJ_firstMasking_Delta=Delta_ADJ_firstMasking;           
    end
    % obtain the mask from each channel 
    idx=idx_H |idx_LD | idx_VD;
    mask = mask_first;
    for i=1:length(idx)
        if idx(i)
            mask_validValues= AFM_data(i).AFM_padded>0;     % exclude zeros and negative values
            mask = mask & mask_validValues;                 % merge the mask with the previous mask or with original AFM_IO_Padded 
        end
    end
    % obtain the definitive mask considering the removal of:
    % 1)    Lateral Force > 1.1*maxSetpoint
    % 2)    99°percentile height
    mask_second=mask; % keep the less "aggressive mask"
    % extract meaningful lateral force. Use setpoint+10% as upper limit:
    % remember, lateral force higher than vertical force is derived not from friction phenomena but rather 
    % the collision between the tip and the surface and other instabilities.
    limitVD=max(setpoints)*1.1;
    mask_validValues= AFM_data(idx_LD).AFM_padded<=limitVD;          % exclude values higher than limit setpoint  
    mask_third=mask_second & mask_validValues;         % merge the mask with the previous mask  
    % high vertical may generate wrong height values. Remove 99* percentile
    percentile=99;
    AFM_height_tmp = AFM_data(idx_H).AFM_padded; % copy height channel
    AFM_height_tmp(~mask_third) = NaN;    
    % exclude nan and transform into array
    AFM_height_tmp_array = AFM_height_tmp(~isnan(AFM_height_tmp));
    threshold = prctile(AFM_height_tmp_array, percentile);
    mask_validValues= AFM_data(idx_H).AFM_padded<threshold;     % exclude 99 percentile from the height
    mask_third=mask_third & mask_validValues;         % merge the mask with the previous mask

    masking = struct();
    % store delta original (AFM IO)
    masking.mask_original = mask_original;
    masking.mask_original_totElements = nnz(mask_original);
    % store mask after delta
    masking.mask_first_delta = mask_first;
    masking.mask_first_delta_totElements = nnz(mask_first);
    % store mask after each channel
    masking.mask_second_eachChannel = mask_second;
    masking.mask_second_eachChannel_totElements = nnz(mask_second);
    % store mask after 99perc and <maxSetpoint
    masking.mask_third_setpointLimit_99percRemoval = mask_third;
    masking.mask_third_setpointLimit_99percRemoval_totElements = nnz(mask_third);
    dataResultsPlot.maskingResults = masking;
    % show the plots
    showData(secondMonitorMain,SeeMe,3,mask_first,true,'First Mask (Delta)','',newFolder,'resultA10_3_FirstMask','Binarized',true,'meterUnit',size_umeterXpix)
    showData(secondMonitorMain,SeeMe,4,mask_second,true,'Second Mask (each AFM channel)','',newFolder,'resultA10_4_SecondMask','Binarized',true,'meterUnit',size_umeterXpix)
    showData(secondMonitorMain,SeeMe,5,mask_third,true,'Third Mask (99perc + <maxSP)','',newFolder,'resultA10_5_ThirdMask','Binarized',true,'meterUnit',size_umeterXpix)   
    clear masking mask_validValues 
    
    % Finally, applying the mask_definitive to all the data!
    if ~flag_onlyAFM
        % fix Delta using new mask
        Delta_ADJ_secondMasking=Delta_ADJ;
        Delta_ADJ_secondMasking(~mask_second) = NaN;
        % fix Delta using the definitive mask considering 99perc removal and LD>1.1*maxSetpoint removal
        Delta_ADJ_thirdMasking=Delta_ADJ;
        Delta_ADJ_thirdMasking(~mask_second) = NaN;
        % store the results
        DeltaData.Delta_ADJ_secondMasking_eachAFM=Delta_ADJ_secondMasking;
        DeltaData.Delta_ADJ_thirdMasking_99percMaxSet=Delta_ADJ_thirdMasking;
    end
    for i=1:length(idx)
        if idx(i)
            % apply original mask (AFM IO only)
            tmp = AFM_data(i).AFM_padded;
            tmp(~mask_original) = NaN;
            AFM_data(i).originalMasking = tmp;
            % apply first Masking (mask from Delta)
            tmp = AFM_data(i).AFM_padded;
            tmp(~mask_first) = NaN;
            AFM_data(i).firstMasking_Delta = tmp;
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
    
    % Delta with the first mask to show how really Delta is.
    showData(secondMonitorMain,SeeMe,6,Delta_ADJ_firstMasking,false,'Delta Fluorescence (1st mask)',labelBar,newFolder,'resultA10_6_DeltaFluorescenceFirstMask','meterUnit',size_umeterXpix)
    showData(secondMonitorMain,SeeMe,7,Delta_ADJ_secondMasking,false,'Delta Fluorescence (2nd mask)',labelBar,newFolder,'resultA10_7_DeltaFluorescenceDefinitiveMasked','meterUnit',size_umeterXpix)            
    showData(secondMonitorMain,SeeMe,8,Delta_ADJ_thirdMasking,false,'Delta Fluorescence (3rd mask)',labelBar,newFolder,'resultA10_8_DeltaFluorescenceDefinitiveMasked','meterUnit',size_umeterXpix)            
       
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% NORMALIZE DELTA DATA %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~flag_onlyAFM                
        ylabelAxis_noNorm=labelBar;
        ylabelAxis_norm=string(sprintf('Normalised Fluorescence (%%)'));
        % normalize the fluorescence data: the normFactor is the average of
        % any cleared pixel from TRITIC images of heated samples
        [~,nameExperiment]=fileparts(mainPathOpticalData);
        normFactor=A10_feature_normFluorescenceHeat(mainPathOpticalData,timeExp,nameExperiment,secondMonitorMain);            
        Delta=Delta/normFactor.avg*100;
        Delta_ADJ=Delta_ADJ/normFactor.avg*100;        
        Delta_ADJ_firstMasking=Delta_ADJ_firstMasking/normFactor.avg*100;
        Delta_ADJ_secondMasking=Delta_ADJ_secondMasking/normFactor.avg*100;
        Delta_ADJ_thirdMasking=Delta_ADJ_thirdMasking/normFactor.avg*100;
        % store the data normalized
        DeltaData.normFactor=normFactor;
        DeltaData.Delta_original_norm=Delta;
        DeltaData.Delta_ADJ_minShifted_norm=Delta_ADJ;
        DeltaData.Delta_ADJ_firstMasking_Delta_norm=Delta_ADJ_firstMasking;                
        DeltaData.Delta_ADJ_secondMasking_eachAFM_norm=Delta_ADJ_secondMasking;
        DeltaData.Delta_ADJ_thirdMasking_99percMaxSet_norm=Delta_ADJ_thirdMasking;        
    end
    dataResultsPlot.DeltaData=DeltaData;
    dataResultsPlot.AFM_Data=AFM_data; 
    clear Delta_ADJ Delta_ADJ_firstMasking Delta_ADJ_secondMasking Delta_ADJ_thirdMasking 
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% EXTRACT BORDERS AND DISTINGUISH INNER AND OUTER OF THE DATA %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    if innerBord
        calcBorders(AFM_data,AFM_IO_Padded,idx_H,idx_LD,idx_VD,DeltaData,flag_heat,secondMonitorMain,SeeMe,newFolder)        
    end    
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% FINAL PART: CORRELATE THE DATA %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Define data for masks
    maskFields = {
        'firstMasking_Delta',                'Delta_ADJ_firstMasking_Delta',        'Delta_ADJ_firstMasking_Delta_norm',            '1st mask',     '1M';
        'secondMasking_eachAFM',             'Delta_ADJ_secondMasking_eachAFM',     'Delta_ADJ_secondMasking_eachAFM_norm',         '2nd mask',     '2M';
        'thirdMasking_maxVD_99perc',         'Delta_ADJ_thirdMasking_99percMaxSet', 'Delta_ADJ_thirdMasking_99percMaxSet_norm',     '3rd mask',     '3M';
    };
    if ~flag_heat
        % 7 - HEIGHT VS LATERAL FORCE
        tmp=struct();
        for i=1:size(maskFields,1)
            x = AFM_data(idx_H).(maskFields{i,1})(:);
            y = AFM_data(idx_LD).(maskFields{i,1})(:);
            titleP = sprintf('Height VS Lateral Deflection (%s)', maskFields{i,4});
            figName = sprintf('Height_LD_%s', maskFields{i,5});
            tmp.(['Height_LD_' maskFields{i,5}]) = A10_feature_CDiB(x,y,secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'XAxL','Feature height (nm)','ypar',1e9,'YAyL','Lateral Force (nN)','FigTitle',titleP,'FigFilename',figName,'NumFig',1);
        end
        dataResultsPlot.Height_LD=tmp;
    end

    if ~flag_onlyAFM
        % 8 - HEIGHT VS FLUORESCENCE INCREASE
        tmp=struct();
        for i = 1:size(maskFields,1)
            x = AFM_data(idx_H).(maskFields{i,1})(:);
            y1 = DeltaData.(maskFields{i,2})(:); y2=DeltaData.(maskFields{i,3})(:);
            titleP = sprintf('Height Vs Fluorescence (%s - time exp %s ms)', maskFields{i,4}, timeExp);
            figName = sprintf('Height_Fluo_%s', maskFields{i,5});
            tmp.(['Height_FLUO_' maskFields{i,5}]) = A10_feature_CDiB(x,y1,secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'XAxL','Feature height (nm)','ypar',1,'YAyL',ylabelAxis_noNorm,'FigTitle',titleP,'FigFilename',figName,'NumFig',2);            
            %norm
            figName = sprintf('Height_Fluo_%s_norm', maskFields{i,5});
            tmp.(['Height_FLUO_' maskFields{i,5} '_norm'])=A10_feature_CDiB(x,y2,secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'XAxL','Feature height (nm)','ypar',1,'YAyL',ylabelAxis_norm,'FigTitle',titleP,'FigFilename',figName,'NumFig',3);
        end
        dataResultsPlot.Height_FLUO=tmp;

        if ~flag_heat
            % 9 - LATERAL DEFLECTION Vs FLUORESCENCE INCREASE
            tmp=struct();
            for i = 1:size(maskFields,1)
                x = AFM_data(idx_LD).(maskFields{i,1})(:);
                y1 = DeltaData.(maskFields{i,2})(:); y2=DeltaData.(maskFields{i,3})(:);
                titleP = sprintf('Lateral Force Vs Fluorescence (%s - time exp %s ms)', maskFields{i,4}, timeExp); 
                figName = sprintf('LD_Fluo_%s', maskFields{i,5});
                tmp.(['LD_FLUO_' maskFields{i,5}]) =        A10_feature_CDiB(x,y1,secondMonitorMain,newFolder,'NumberOfBins',2000,'xpar',1e9,'XAxL','Lateral Force (nN)','ypar',1,'YAyL',ylabelAxis_noNorm,'FigTitle',titleP,'FigFilename',figName,'NumFig',4);            
                %norm
                figName = sprintf('Height_Fluo_%s_norm', maskFields{i,5});
                tmp.(['LD_FLUO_' maskFields{i,5} '_norm'])= A10_feature_CDiB(x,y2,secondMonitorMain,newFolder,'NumberOfBins',2000,'xpar',1e9,'XAxL','Lateral Force (nN)','ypar',1,'YAyL',ylabelAxis_norm,'FigTitle',titleP,'FigFilename',figName,'NumFig',5);
            end
            dataResultsPlot.LD_FLUO=tmp;
           
            % 10 - VERTICAL FORCE VS FLUORESCENCE INCREASE
            tmp=struct();
            for i = 1:size(maskFields,1)
                x = AFM_data(idx_VD).(maskFields{i,1})(:);
                y1 = DeltaData.(maskFields{i,2})(:); y2=DeltaData.(maskFields{i,3})(:);
                titleP = sprintf('Vertical Force Vs Fluorescence (%s - time exp %s ms)', maskFields{i,4}, timeExp); 
                figName = sprintf('VD_Fluo_%s', maskFields{i,5});
                tmp.(['VD_FLUO_' maskFields{i,5}]) =        A10_feature_CDiB(x,y1,secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'XAxL','Vertical Force (nN)','ypar',1,'YAyL',ylabelAxis_noNorm,'FigTitle',titleP,'FigFilename',figName,'NumFig',6);            
                %norm
                figName = sprintf('VD_Fluo_%s_norm', maskFields{i,5});
                tmp.(['VD_FLUO_' maskFields{i,5} '_norm'])= A10_feature_CDiB(x,y2,secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'XAxL','Vertical Force (nN)','ypar',1,'YAyL',ylabelAxis_norm,'FigTitle',titleP,'FigFilename',figName,'NumFig',7);
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
            tmp.(['VD_LD_' maskFields{i,5}]) = A10_feature_CDiB(x,y,secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'XAxL','Vertical Force (nN)','ypar',1e9,'YAyL','Lateral Force (nN)','FigTitle',titleP,'FigFilename',figName,'NumFig',8);
        end
        dataResultsPlot.VD_LD=tmp;
    end    
end


function calcBorders(AFM_data,AFM_IO_Padded,idx_H,idx_LD,idx_VD,DeltaData,flag_heat,secondMonitorMain,SeeMe,newFolder)     
    % Identification of borders from the binarised Height image
    AFM_IO_Padded_Borders=AFM_IO_Padded;
    AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
    AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
    se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
    AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 
    showData(secondMonitorMain,SeeMe,9,AFM_IO_Borders_Grow,false,'Borders','',newFolder,'resultA10_6_Borders','Binarized',true)

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
    showData(secondMonitorMain,SeeMe,10,AFM_Height_Border*1e6,false,titleD1,labelBar,newFolder,'resultA10_7_BorderAndInner_AFM_Height','data2',AFM_Height_Inner*1e6,'titleData2',titleD2,'background',true)

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
    showData(secondMonitorMain,SeeMe,11,AFM_LD_Border*1e9,false,titleD1,labelBar,newFolder,'resultA10_8_BorderAndInner_AFM_LateralDeflection','data2',AFM_LD_Inner*1e9,'titleData2',titleD2,'background',true)

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
    showData(secondMonitorMain,SeeMe,12,AFM_VD_Border*1e9,false,titleD1,labelBar,newFolder,'resultA10_9_BorderAndInner_AFM_VerticalDeflection','data2',AFM_VD_Inner*1e9,'titleData2',titleD2,'background',true)
    
    % Elaboration of Fluorescent Images to extract inner and border regions
    if ~flag_heat           
        TRITIC_Border_Delta=DeltaData.Delta_ADJ_secondMasking_eachAFM; 
        TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
        TRITIC_Inner_Delta=Delta.completeMask; 
        TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;
        titleD1='Tritic Border Delta';
        titleD2='Tritic Inner Delta';
        labelBar='Absolute Fluorescence';  
        showData(secondMonitorMain,SeeMe,13,TRITIC_Border_Delta,false,titleD1,labelBar,newFolder,'resultA10_10_BorderAndInner_TRITIC_DELTA','data2',TRITIC_Inner_Delta,'titleData2',titleD2,'background',true)     
    end
    close all 
end
