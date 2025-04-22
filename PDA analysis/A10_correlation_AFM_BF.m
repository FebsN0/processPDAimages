% OUTPUT:
%   dataResultsPlot = struct which contains the results of:
%       1) .DeltaNormalized         = flag normalized Delta (true/false);
%       2) .Delta_ADJ               = delta fluorescence data
%       3) .Height_LD               = Height VS Lateral Deflection           
%       4) .Height99perc_LD_maxVD   = Height (99 percentile removed) VS Lateral Deflection (up to max vertical deflection)
%       5) .Height_FLUO             = Height VS FLUORESCENCE         
%       6) .Height99perc_FLUO       = Height (99 percentile removed) VS FLUORESCENCE
%       7) .LD_FLUO                 = Lateral Deflection VS FLUORESCENCE
%       8) .LDmaxVD_FLUO            = Lateral Deflection (up to max vertical deflection) VS FLUORESCENCE 
%       9) .VD_FLUO                 = Vertical Deflection VS FLUORESCENCE
%      10) .VD_LD                   = Vertical Deflection VS Lateral Deflection
%      11) .VD_LDmaxVD              = Vertical Deflection VS Lateral Deflection (up to max vertical deflection)
%
% the following script process data from different situation:
%       1) normal experiment:   AFM + pre and post scan fluorescence image  + BF image
%       2) after heating:       AFM + single scan fluorescence image        + BF image
%               NOTE: it doesn't matter if before or after scanning
%       3) process only AFM data

function dataResultsPlot=A10_correlation_AFM_BF(AFM_data,AFM_IO_Padded,setpoints,secondMonitorMain,newFolder,mainPathOpticalData,timeExp,varargin)
    
    p=inputParser();
    addRequired(p,'AFM_data');
    addRequired(p,'AFM_IO_Padded')
    argName = 'TRITIC_before';      defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'TRITIC_after';       defaultVal = [];     addParameter(p,argName,defaultVal, @(x) ismatrix(x));
    argName = 'Silent';             defaultVal = true;   addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'afterHeating';       defaultVal = false;  addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'TRITIC_expTime';     defaultVal = '';     addParameter(p,argName,defaultVal, @(x) ischar(x));
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
    % in case of after heating, better specify which exposure time has been used to track the saturation upper limit
    if ~isempty(p.Results.TRITIC_expTime)
        expTime=sprintf('%s',p.Results.TRITIC_expTime);
    else
        expTime='';
    end
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

    % find the idx of Height and Lateral/vertical Deflection in Trace Mode
    idx_LD = strcmp([AFM_data.Channel_name],'Lateral Deflection') & strcmp([AFM_data.Trace_type],'Trace');
    idx_H = strcmp([AFM_data.Channel_name],'Height (measured)');
    idx_VD =  strcmp([AFM_data.Channel_name],'Vertical Deflection') & strcmp([AFM_data.Trace_type],'Trace');
 
    % prepare Delta in correspondence of PDA using AFM height I/O
    % (crystal/PDA/polymer == 1   ||   background = 0)
    % NOTE: AFM_IO_Padded has the same size as well the BF images original
    if ~flag_onlyAFM
        Delta_glass=Delta;
        % remove fluorescence data outside crystals 
        Delta_glass(AFM_IO_Padded==1)=nan;                          
        Delta_glass(Delta<=0)=nan;
        % remove the data outside the AFM data which is only zero
        Delta_glass(AFM_data(idx_LD).AFM_padded==0)=nan;
        % Intensity minimum in the glass region to be subtracted:
        Min_Delta_glass=min(min(Delta_glass,[],"omitnan"));
        % fix the fluorescence using the minimum value
        Delta_ADJ=Delta-Min_Delta_glass;
        ylabelAxis='Absolute fluorescence increase (A.U.)'; % in case of no normalization
        dataResultsPlot.DeltaNormalized=false;
        % normalize the fluorescence data: the normFactor is the average of
        % any cleared pixel from TRITIC images of heated samples
        if getValidAnswer('Normalize the fluorescence data?','',{'y','n'})
            [~,nameExperiment]=fileparts(mainPathOpticalData);
            normFactor=A10_feature_normFluorescenceHeat(mainPathOpticalData,timeExp,nameExperiment,secondMonitorMain);
            Delta_ADJ=Delta_ADJ/normFactor*100;
            ylabelAxis=string(sprintf('Normalised Fluorescence (%%)'));
            dataResultsPlot.DeltaNormalized=true;
        end
        % norm again to the max value to increase the contrast
        showData(secondMonitorMain,0,1,Delta_ADJ,true,'Delta Fluorescence (After-Before)','',newFolder,'resultA10_1_DeltaFluorescenceFull')
        % remove the data outside the AFM data which is only zero
        Delta_ADJ(AFM_data(idx_LD).AFM_padded==0)=nan;
        % exclude data of background prepared few lines before
        Delta_ADJ(Delta_ADJ<0 | ~isnan(Delta_glass))=nan;
        % save the delta in correspondence of crystal and background
        if ~flag_heat
            titleD1='Tritic glass';
            titleD2='Tritic whole';
            labelBar='Absolute Fluorescence';
            showData(secondMonitorMain,SeeMe,2,Delta_glass,false,titleD1,labelBar,newFolder,'resultA10_2_FluorescenceGlassPDA','data2',Delta_ADJ,'titleData2',titleD2,'background',true)
        end
    end
    dataResultsPlot.Delta_ADJ=Delta_ADJ;
    if innerBord 
        % Identification of borders from the binarised Height image
        AFM_IO_Padded_Borders=AFM_IO_Padded;
        AFM_IO_Padded_Borders(AFM_IO_Padded_Borders<=0)=nan;
        AFM_IO_Borders= edge(AFM_IO_Padded_Borders,'approxcanny');
        se = strel('square',5); % this value results a border of 3! pixels in the later images(as the outer dilation (2px) is gonna be subtracted later)
        AFM_IO_Borders_Grow=imdilate(AFM_IO_Borders,se); 
        showData(secondMonitorMain,SeeMe,3,AFM_IO_Borders_Grow,false,'Borders','',newFolder,'resultA10_3_Borders','Binarized',true)

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
        showData(secondMonitorMain,SeeMe,4,AFM_Height_Border*1e6,false,titleD1,labelBar,newFolder,'resultA10_4_BorderAndInner_AFM_Height','data2',AFM_Height_Inner*1e6,'titleData2',titleD2,'background',true)
    
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
        showData(secondMonitorMain,SeeMe,5,AFM_LD_Border*1e9,false,titleD1,labelBar,newFolder,'resultA10_5_BorderAndInner_AFM_LateralDeflection','data2',AFM_LD_Inner*1e9,'titleData2',titleD2,'background',true)

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
        showData(secondMonitorMain,SeeMe,6,AFM_VD_Border*1e9,false,titleD1,labelBar,newFolder,'resultA10_6_BorderAndInner_AFM_VerticalDeflection','data2',AFM_VD_Inner*1e9,'titleData2',titleD2,'background',true)
        
        % Elaboration of Fluorescent Images to extract inner and border regions
        if ~flag_heat
            TRITIC_Border_Delta=Delta_ADJ; 
            TRITIC_Border_Delta(isnan(AFM_LD_Border))=nan; 
            TRITIC_Inner_Delta=Delta_ADJ; 
            TRITIC_Inner_Delta(isnan(AFM_LD_Inner))=nan;
            titleD1='Tritic Border Delta';
            titleD2='Tritic Inner Delta';
            labelBar='Absolute Fluorescence';  
            showData(secondMonitorMain,SeeMe,7,TRITIC_Border_Delta,false,titleD1,labelBar,newFolder,'resultA10_7_BorderAndInner_TRITIC_DELTA','data2',TRITIC_Inner_Delta,'titleData2',titleD2,'background',true)     
        end
        close all 
    end    
    % Like what done to Delta_ADJ Remove glass regions from the big AFM_padded Height and LD and VD AFM images
    % take glass regions    
    AFM_data=apply_afm_mask(AFM_data,idx_H,AFM_IO_Padded);
    AFM_data=apply_afm_mask(AFM_data,idx_LD,AFM_IO_Padded);
    AFM_data=apply_afm_mask(AFM_data,idx_VD,AFM_IO_Padded);   
    % extract meaningful lateral force. Use setpoint+10% as upper limit: remember, lateral force cannot
    % be higher than vertical force. Those higher values are due to unstable tip scannings.
    limitVD=max(setpoints)*1.1;
    AFM_data(idx_LD).Padded_masked_maxVD=AFM_data(idx_LD).AFM_padded;   % copy lateral force channel
    AFM_data(idx_LD).Padded_masked_maxVD(~isnan(AFM_data(idx_LD).Padded_masked_glass) | AFM_data(idx_LD).AFM_padded<=0 | AFM_data(idx_LD).AFM_padded>limitVD)=nan;
    % high vertical may generate wrong height values. Remove 99* percentile
    percentile=99;
    AFM_data(idx_H).Padded_masked_maxVD=AFM_data(idx_H).AFM_padded; % copy height channel
    AFM_data(idx_H).Padded_masked_maxVD(~isnan(AFM_data(idx_H).Padded_masked_glass) | AFM_data(idx_H).AFM_padded<=0)=nan;
    AllHeightData=AFM_data(idx_H).Padded_masked_maxVD(:);
    threshold = prctile(AllHeightData, percentile); % automatically ignore NaN
    AFM_data(idx_H).Padded_masked_maxVD(AFM_data(idx_H).Padded_masked_maxVD>=threshold)=nan;
   
    if ~flag_heat
        % 7 - HEIGHT VS LATERAL FORCE
        % all lateral force
        dataResultsPlot.Height_LD=A10_feature_CDiB(AFM_data(idx_H).Padded_masked(:),AFM_data(idx_LD).AFM_padded(:),secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL',sprintf('Feature height (nm)'),'FigTitle','Height VS Lateral Deflection','FigFilename','Height_LD','NumFig',1);
        %[BC_H_Vs_LD_Border]=A10_feature_CDiB(AFM_Height_Border(:),AFM_LD_Border(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Border','NumFig',1);
        %[BC_H_Vs_LD_Inner]=A10_feature_CDiB(AFM_Height_Inner(:),AFM_LD_Inner(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Feature height (nm)','FigTitle','LD Vs Height Inner','NumFig',1);
        % lateral force up to max vertical force and removing 99* percentile of height
        dataResultsPlot.Height99perc_LD_maxVD=A10_feature_CDiB(AFM_data(idx_H).Padded_masked_maxVD(:),AFM_data(idx_LD).Padded_masked_maxVD(:),secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL',sprintf('Feature height (nm)'),'FigTitle','Height (99 percentile removed) VS Lateral Deflection (up to max vertical force)','FigFilename','Height99perc_LDmaxVD','NumFig',2);                            
    end

    if ~flag_onlyAFM
        % 8 - HEIGHT VS FLUORESCENCE INCREASE
        dataResultsPlot.Height_FLUO=A10_feature_CDiB(AFM_data(idx_H).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL',sprintf('Feature height (nm)'),'FigTitle',sprintf('Height Vs Fluorescence (time exp %s ms)',expTime),'FigFilename','Height_Fluo','NumFig',3);
        dataResultsPlot.Height99perc_FLUO=A10_feature_CDiB(AFM_data(idx_H).Padded_masked_maxVD(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',numBins,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL',sprintf('Feature height (nm)'),'FigTitle',sprintf('Height (99 percentile removed) Vs Fluorescence (time exp %s ms)',expTime),'FigFilename','Height99perc_Fluo','NumFig',4);        
        %[BC_Height_Border_Vs_Delta2ADJ_Border]=A10_feature_CDiB(AFM_Height_Border(:),TRITIC_Border_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (borders)','NumFig',2);
        %[BC_Height_Inner_Vs_Delta2ADJ_Inner]=A10_feature_CDiB(AFM_Height_Inner(:),TRITIC_Inner_Delta(:),secondMonitorMain,newFolder,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Feature height (nm)','FigTitle','Height Vs Fluorescence increase (inner regions)','NumFig',2);       
        if ~flag_heat
            % 9 - LATERAL DEFLECTION (glass removed) VS FLUORESCENCE INCREASE
            % all lateral force
            dataResultsPlot.LD_FLUO=A10_feature_CDiB(AFM_data(idx_LD).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',2500,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Lateral Force (nN)','FigTitle','LD Vs Fluorescence','FigFilename','LD_Fluo','NumFig',5);
            % lateral force up to max vertical force
            dataResultsPlot.LDmaxVD_FLUO=A10_feature_CDiB(AFM_data(idx_LD).Padded_masked_maxVD(:),Delta_ADJ(:),secondMonitorMain,newFolder,'NumberOfBins',500,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Lateral Force (nN)','FigTitle',sprintf('LD (up to the max vertical force) Vs Fluorescence (time exp %s ms)',timeExp),'FigFilename','LDmaxVD_Fluo','NumFig',6);           
            % 10 - VERTICAL FORCE VS FLUORESCENCE INCREASE
            dataResultsPlot.VD_FLUO=A10_feature_CDiB(AFM_data(idx_VD).Padded_masked(:),Delta_ADJ(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Vertical Force (nN)','FigTitle',sprintf('VD Vs Fluorescence (time exp %s ms)',timeExp),'FigFilename','VD_Fluo','NumFig',7); 
            %[BC_VD_Vs_Delta2ADJ_Border]=A10_feature_CDiB(AFM_VD_Border(:),TRITIC_Border_Delta(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (borders)','NumFig',5);
            %[BC_VD_Vs_Delta2ADJ_Inner]=A10_feature_CDiB(AFM_VD_Inner(:),TRITIC_Inner_Delta(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1,'YAyL',ylabelAxis','XAxL','Vertical Force (nN)','FigTitle','VD Vs Fluorescence increase (inner regions)','NumFig',5);
        end
    end
    if ~flag_heat
        % VERTICAL FORCE VS LATERAL FORCE
        dataResultsPlot.VD_LD=A10_feature_CDiB(AFM_data(idx_VD).Padded_masked(:),AFM_data(idx_LD).Padded_masked(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','Lateral Force Vs Vertical Force','FigFilename','LD_VD','NumFig',8);
        dataResultsPlot.VD_LDmaxVD=A10_feature_CDiB(AFM_data(idx_VD).Padded_masked(:),AFM_data(idx_LD).Padded_masked_maxVD(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','Lateral Force (up to the max vertical force) Vs Vertical Force','FigFilename','LD_VD','NumFig',9);
        %[BC_VD_Vs_LD_Border]=A10_feature_CDiB(AFM_VD_Border(:),AFM_LD_Border(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Border','NumFig',4);
        %[BC_VD_Vs_LD_Inner]=A10_feature_CDiB(AFM_VD_Inner(:),AFM_LD_Inner(:),secondMonitorMain,newFolder,'setpoints',setpoints,'xpar',1e9,'ypar',1e9,'YAyL','Lateral Force (nN)','XAxL','Vertical Force (nN)','FigTitle','LD Vs VD Inner','NumFig',4);
    end    
end


function AFM_data = apply_afm_mask(AFM_data,idx,AFM_IO_Padded)
        AFM_data(idx).Padded_masked_glass=AFM_data(idx).AFM_padded;
        AFM_data(idx).Padded_masked_glass(AFM_IO_Padded==1 | AFM_data(idx).AFM_padded<=0)=nan;
        AFM_data(idx).Padded_masked=AFM_data(idx).AFM_padded;
        AFM_data(idx).Padded_masked(~isnan(AFM_data(idx).Padded_masked_glass) | AFM_data(idx).AFM_padded<=0)=nan;
end

