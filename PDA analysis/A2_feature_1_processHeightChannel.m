function [AFM_Images_final,mask_FINAL,fitOrderHeight]=A2_feature_1_processHeightChannel(filtData,idxMon,SaveFigFolder,varargin)
% The function extracts Images from the experiments.
% It removes baseline and extracts foreground from the AFM image.
%
% INPUT:    1) input = output of A2_CleanUpData2_AFM function which contains Height (measured), Lateral
%                      Deflection and Vertical Deflection, all in TRACE
%           2) optional input:
%               A) Accuracy: Low (default)  | Medium | High
%
% The function uses a series a total of three parts to remove the baseline from the Height Image.
%   1) first order linear polinomial curve fitting for correct the height imahe by this baseline 
%   2) buttorworth filter backgrownd algorithm
%   3) Poly11: linear polynomial surface is fitted to results of Poly1 fitting, the fitted surface is subtracted from
%      the results of Poly1 fitting (poly_filt_data), yielding filt_data_no_Bk_visible_data
%   4) iterative backgrownd removal, in which R^2 and RMS residuals are used to calculate the final backgrownd
%
%
% Author: Altieri F.
% University of Tokyo

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    clear allWaitBars
    
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types and properties of inputs.
    p=inputParser();    % init instance of inputParser
    % Add required and default parameters and also check conditions
    addRequired(p, 'filtData', @(x) isstruct(x));
    argName = 'setpointsList';  defaultVal = [];                addParameter(p,argName,defaultVal);
    argName = 'SeeMe';          defaultVal = true;              addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'imageType';      defaultVal = 'Entire';          addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';  defaultVal = false;             addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'fitOrder';       defaultVal = '';                addParameter(p, argName, defaultVal, @(x) (ismember(x, {'Low', 'Medium', 'High'}) || isempty(x)));
    argName = 'metadata';       defaultVal = [];                addParameter(p,argName,defaultVal);
    argName = 'HoverModeImage'; defaultVal = 'HoverModeON';     addParameter(p, argName, defaultVal, @(x) (ismember(x, {'HoverModeOFF', 'HoverModeON'})));

    % validate and parse the inputs
    parse(p,filtData,varargin{:});
    metadata=p.Results.metadata;        
    setpointN=p.Results.setpointsList;
    typeProcess=p.Results.imageType;
    SeeMe=p.Results.SeeMe;
    norm=p.Results.Normalization;
    HVmode=p.Results.HoverModeImage;
    if norm, labelHeight=""; factor=1; else, labelHeight="Height (nm)"; factor=1e9; end    
    
    % for the first time or first section, request the max fitOrder
    if isempty(p.Results.fitOrder)
        fitOrderHeight=chooseAccuracy(sprintf("Choose the level of fit Order for lineXline baseline (i.e. Background) of AFM Height Deflection Data (%s).",HVmode));
    else
        fitOrderHeight=p.Results.fitOrder;
    end
    if strcmp(fitOrderHeight,'Low'), limit=3; elseif strcmp(fitOrderHeight,'Medium'), limit=6; else, limit=9; end    
    clearvars argName defaultVal p varargin

    % show the data prior the adjustments
    A1_feature_CleanOrPrepFiguresRawData(filtData,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'metadata',metadata,'imageType',typeProcess,'SeeMe',SeeMe,"setpointsList",setpointN,'Normalization',norm);
  
    % Orient the image by counterclockwise 180° and flip to coencide with the Microscopy image through rotations
    for i=1:size(filtData,2)
        temp_img=flip(rot90(filtData(i).AFM_image),2);
        AFM_Images(i)=struct(...
                'Channel_name', filtData(i).Channel_name,...
                'Trace_type', filtData(i).Trace_type, ...
                'AFM_image', temp_img); %#ok<AGROW>
    end
    clear filtData metadata typeProcess setpointN temp_img
    % Extract the height channel
    height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_image;
    
    % after the first iteration, a mask and definitive corrected height
    % image have been generated. However, although the the definitive
    % height may be ok, the mask could be still not perfect. Since the mask
    % is the most important element for the lateral deflection section and
    % it highly depends on the height channel, it is suggested to
    % re-iterate the mask generation with a new and cleaner height channel
    iterationMain=1;
    while true
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%% REMOVE OUTLIERS (remove anomalies like high spikes) %%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % this solution is more adaptive and less aggressive than removing 99.5
        % percentile. Remove outliers line by line ==> more prone to remove spikes!
        num_lines = size(height_1_original, 2);
        countOutliers=0;
        height_2_outliersRemoved=zeros(size(height_1_original));
        for i=1:num_lines
            yData = height_1_original(:, i);
            [pos_outlier] = isoutlier(yData, 'gesd');        
            while any(pos_outlier)
                countOutliers=countOutliers+nnz(pos_outlier);
                yData(pos_outlier) = NaN;
                [pos_outlier] = isoutlier(yData, 'gesd');
            end
            height_2_outliersRemoved(:,i)=yData;
        end
        fprintf("\nBefore First 1st order plan fitting, %d outliers have been removed!\n",countOutliers)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIRST FITTING: FIRST ORDER PLANE FITTING ON ENTIRE DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [height_3_corrPlane,planeFit] = planeFitting_N_Order(height_2_outliersRemoved,1);  
        height_3_corrPlane=height_3_corrPlane-min(height_3_corrPlane(:));
        % Display and save result
        titleData1 = {'First Order Plane';'Fitted on Raw Height Channel'};
        titleData2 = {'Height channel';sprintf('1st step: 1st order plane fitting + shifted toward zero (%d outliers removed)',countOutliers)};
        nameFile = sprintf('resultA2_1_Plane1order_correctedHeight_iteration%d',iterationMain);    
        showData(idxMon,SeeMe,planeFit*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight, ...
            'extraData',{height_3_corrPlane*factor},'extraNorm',{norm},'extraTitles',{titleData2},'extraLabel',{labelHeight});   
        
        clear countOutliers i nameFile planeFit pos_outlier num_lines titleData* yData
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% BUTTERWORTH FILTERING : an automatic binarization but not for binarize the image, rather for better fitting %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % After polynomial flattening, the image should have an average plane removed, but there can still be low-level background 
        % offsets or uneven residuals. The goal of this snippet is to automatically detect a "background" height threshold — a level 
        % that separates the flat background from the sample features — and to mask out (NaN) all pixels above that threshold.
        %
        % APPROACH: Rather than looking at the image spatially, the script looks at the statistical distribution of height values — i.e., the histogram.
        % The histogram often looks like this in AFM height maps:
        %   - a large peak at low height → background plane,
        %   - smaller counts at higher heights → real surface features
        % A low-pass Butterworth filter is applied to the histogram to smooth it and remove noise/spikes from pixel quantization or roughness variations.
        % Butterworth because it provides a smooth, monotonic response (flat in passband, no oscillations).
        % Ideal for cleaning noisy histogram data to identify peaks.
        
        % Original code uses 10'000 bins, which may be too fine for most AFM height ranges
        % Therefore, automatically adapt the number of bins based on data range and image size.
        numBins = min(5000, max(100, round(numel(height_3_corrPlane)/100))); % adaptive bin count
        % distribute the fitted data among bins using N bins and Normalize Y before filtering to make it scale-independent.
        [Y,E_height] = histcounts(height_3_corrPlane,numBins,'Normalization', 'pdf');
        % set the parameters for Butterworth filter ==> little recap: it is a low-pass filter with a frequency
        % response that is as flat as possible in the passband
        
        % Butterworth filter of order 6 with normalized cutoff frequency Wn
        % Return transfer function coefficients to be used in the filter function and then filter the data
        % ORIGINAL LINE: [b,a] = butter(order, fc/(fs/2)); where
        % - fc = 5                                      ==> Cut off frequency
        % - fs = fs = size(height_image_1_original,2)   ==> sampling frequency (number of pixels per line)
        % IMPROVED VERSION: Define fc as a fraction of Nyquist, directly specifying Wn (0–1 scale, where 1 corresponds to the Nyquist frequency).    
        Wn = 0.02;            % normalized cutoff (2% of Nyquist)
        [b,a] = butter(4, Wn);  % 4th order is usually enough
        Y_filtered = filtfilt(b,a,Y); % zero-phase filtering (better symmetry)
    
        % Second derivative of the filtered histogram to detect the inflection point — the point where the curvature changes sign.
        % That inflection marks the transition from the main background peak to the tail of higher-height values
        % ORIGINAL LINE: Y_filered_diff=diff(diff(Y_filtered)) ==> this approach is crude
        % it just looks for one zero crossing of the second derivative, which can fail if the histogram is multimodal or noisy.
        % IMPROVED VERSION: Use gradient-based peak analysis or findpeaks on the smoothed histogram derivative:
        % This finds the largest negative-to-positive transition, i.e., where the histogram slope changes most sharply
        dY = gradient(Y_filtered);    
        [~, locs] = findpeaks(-dY, 'NPeaks', 1, 'SortStr', 'descend');
        bk_limit = locs(1);
        E_height=E_height*1e9;
        background_th = E_height(bk_limit);     % express in nm
        thresholdApproach="Automatic";
        % HOWEVER, it doesnt work always, so also manual selection
        fbutter=figure; objInSecondMonitor(fbutter,idxMon)
        axFbutter=axes("Parent",fbutter); hold(axFbutter,"on")
        plot(axFbutter,E_height(1:end-1), Y_filtered, 'b', 'LineWidth', 2,'DisplayName','Butterworth-filtered Height');
        xline(axFbutter,background_th, 'r--', 'LineWidth', 1.5,'DisplayName','Background Automatic (2nd derivative) threshold');       
        title(axFbutter,'First background detection with butterworth-filtered Height','FontSize',16); legend(axFbutter,'FontSize',15)
        xlabel(axFbutter,'Height (nm)','FontSize',14); ylabel(axFbutter,'PDF (Probability Density Function on Count','FontSize',14);
        xlim(axFbutter,"tight"), grid(axFbutter,"on")        
        pause(1)
        question=sprintf(['Is the threshold to separate Background from Foreground good enough?\n'...
            'NOTE: it is not necessary to be precise because this step is not for binarization,\nbut at least should approximately separate the two regions.']);
        if ~getValidAnswer(question,"",{'Yes','No'})
            uiwait(msgbox('Click on the plot to define the threshold to separate Background from Foreground',''));
            closest_indices=selectRangeGInput(1,1,axFbutter);
            background_th=E_height(closest_indices);
            xline(background_th, 'g--', 'LineWidth', 1.5,'DisplayName','Background Manual threshold'); 
            thresholdApproach="Manual";
        end        
        close(fbutter)        
        % all pixels above this height (i.e., part of the actual structure) are
        % masked (NaN), leaving only the flat background    
        BK_butterworthFiltered = height_3_corrPlane;
        BK_butterworthFiltered(BK_butterworthFiltered > background_th*1e-9) = NaN;
        % show the results
        titleData=sprintf('Background Height - Butterworth Filtered Height and separated by %s threshold',thresholdApproach);     
        nameFile=sprintf('resultA2_2_BackgroundHeight_butterworth_iteration%d',iterationMain);   
        showData(idxMon,SeeMe,BK_butterworthFiltered*factor,titleData,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight);
        
        clear fbutter closest_indices numBins Y E_height Wn b a Y_filtered dY locs bk_limit background_th nameFile question thresholdApproach titleData
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% SECOND FITTING: N ORDER PLANE FITTING ON BUTTERWORTH FILTERED BACKGROUND %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
        [BK1_butterworthFiltered_PlaneFitted,planeCorrection,metrics] = planeFitting_N_Order(BK_butterworthFiltered,limit);
        height_4_firstBKfit=height_3_corrPlane-planeCorrection;  
        % shift the entire data toward zero (background should be zero)
        height_4_firstBKfit=height_4_firstBKfit-(min(height_4_firstBKfit(:)));
        % show the results
        titleData1={'Fitted Plane';sprintf('Order Plane: %s',metrics.fitOrder)};
        titleData2={'Background Height';'Butterworth Filtered Height and Plan Fitted'};
        titleData3={'Height Channel';'1st Background correction + shifted toward zero.'}; 

        nameFile=sprintf('resultA2_3_FittPlaneBK_corrHeight_iteration%d',iterationMain);   
        showData(idxMon,SeeMe,planeCorrection*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
            'extraData',{BK1_butterworthFiltered_PlaneFitted*factor,height_4_firstBKfit*factor}, ...
            'extraNorm',{norm,norm},'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});       
        
        clear titleData* nameFile BK_butterworthFiltered        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% THIRD FITTING: N ORDER LINE-BY-LINE FITTING THE NEW PLANE-FITTED HEIGHT %%%%
        %%%  (Note: NOT MASKED. It turned out using the previous BK as mask is worse) %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
        %[BK2_butterworthFiltered_PlaneFit_lineByLineFit,allBaseline] = lineByLineFitting_N_Order(BK1_butterworthFiltered_PlaneFitted,limit);
        %height_5_lineXlineFIT=height_4_firstBKfit-allBaseline;
        [height_5_lineXlineFIT,allBaseline] = lineByLineFitting_N_Order(height_4_firstBKfit,limit);        
        height_5_lineXlineFIT = height_5_lineXlineFIT-min(height_5_lineXlineFIT(:));
        % plot the resulting corrected data
        titleData1={'Fitted LineByLine'};
        titleData2={'Height Channel';'2nd Background correction + shifted toward zero.'}; 
        nameFile=sprintf('resultA2_4_FittLineByLine_corrHeight_iteration%d',iterationMain);
        showData(idxMon,SeeMe,allBaseline*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
            'extraData',{height_5_lineXlineFIT*factor}, ...
            'extraNorm',{norm},'extraTitles',{titleData2},'extraLabel',{labelHeight});
        
        clear titleData* nameFile            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BINARIZATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % start the classic binarization to create the mask, i.e. the 0/1 height image (0 = Background, 1 = Foreground). 
        [AFM_height_IO,binarizationMethod]=binarization_autoAndManualHist(height_5_lineXlineFIT,idxMon);      
                
        % PYTHON BINARIZATION TECHNIQUES. It requires other options, when I will have more time. Especially for DeepLearning technique
        question="Satisfied of the first binarization method? If not, run the Python Binarization tools!";
        if ~getValidAnswer(question,"",{"Yes","No"},2)
            [AFM_height_IO,binarizationMethod]=binarization_withPythonModules(idxMon,height_5_lineXlineFIT);
        end    
        % show data and if it is not okay, start toolbox segmentation
        question=sprintf('Satisfied of the binarization of the iteration %d? If not, run ImageSegmenter ToolBox for better manual binarization',iterationMain);        
        if iterationMain>1 && ~getValidAnswer(question,'',{'Yes','No'})            
            % Run ImageSegmenter Toolbox if at end of the second iteration, the mask is still not good enough
            [AFM_height_IO,binarizationMethod]=binarization_ImageSegmenterToolbox(height_5_lineXlineFIT,idxMon);                  
        end
        textTitleIO=sprintf('Binary Height Image - iteration %d\n%s',iterationMain,binarizationMethod);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% MASK GENERATED ==> MASK ORIGINAL HEIGHT IMAGE AND REMOVE PLANE BASELINE %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%             
        % Once the mask has been created, next step is remove new baseline by using the mask. This because is now easier to distinguish 
        % background from foreground, therefore a better plane-baseline fitting can be made, thus a more accurate AFM height image 
        % can be obtained directly from original AFM height image

        % FIRST, check if there are some regions that may affect negatively the fitting. If so, then remove them.
        height_6_Background=height_1_original;
        % mask original AFM height image
        AFM_height_IO=double(AFM_height_IO);
        % obtain the data of background
        height_6_Background(AFM_height_IO==1)=NaN;
        % show differences in mask and masked raw height
        ftmpIO=showData(idxMon,true,AFM_height_IO,textTitleIO,'','','binary',true,'saveFig',false,...
            'extraData',{height_6_Background*factor,height_1_original*factor}, ...
            'extraTitles',{'Masked Raw Height Image','Raw Height Image'},...
            'extraLabel',{labelHeight,labelHeight},'extraNorm',{norm,norm});
        question={"Check the comparison between mask, masked raw height and original height images.";"Do you want to remove some regions/lines?"};
        answ=getValidAnswer(question,"",{"Yes","No"},2);
        close(ftmpIO); flagRemoval=false;
        if answ
            % first output is a matrix of removed regions. Return also potentially the final adjusted mask
            [~,AFM_height_IO,height_6_Background,~] = featureRemovePortions(AFM_height_IO,'Binary Image',idxMon, ...
                'additionalImagesToShow',{height_6_Background,height_1_original}, ...
                'additionalImagesTitleToShow',{'Masked Raw Height Image\n(Black regions = NaN or manually removed areas)','Raw Height Image'});        
            flagRemoval=true;            
        end
        % prepare the plot of figures
        if flagRemoval
            titleData2={'Masked Raw Height Image (Background)';'Regions Manually Removed. Data that will be used for PlaneFit.'};
        else            
            titleData2={'Masked Raw Height Image (Background).';' Data that will be used for PlaneFit.'};
        end
        titleData3='Raw Height Image';
        nameFile=sprintf('resultA2_5_DefinitiveMask_iteration%d',iterationMain);
        showData(idxMon,false,AFM_height_IO,textTitleIO,SaveFigFolder,nameFile,'binary',true,...
                'extraData',{height_6_Background*factor,height_1_original*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight},'extraNorm',{norm,norm});  
        
        clear titleText* nameFile flagRemoval ftmpIO answ question textTitleIO binarizationMethod
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FORTH FITTING: FIRST ORDER PLANE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [BK2_definitive_PlaneFitted,planeFit,metrics] = planeFitting_N_Order(height_6_Background,limit);
        height_6_planeFitOnFinalMask=height_1_original-planeFit;
        height_6_planeFitOnFinalMask=height_6_planeFitOnFinalMask-min(height_6_planeFitOnFinalMask(:));
        % Display and save result
        titleData1={'Results Plane Fitting with masked Height';sprintf('Order Plane: %s - iteration %d',metrics.fitOrder,iterationMain)};
        titleData2 = 'Post PlaneFit Masked Height';
        titleData3={sprintf('Resulting Height Channel.Iteration %d',iterationMain)','(Data shifted toward zero)'};              
        nameFile=sprintf('resultA2_6_FittPlaneBKwithFinalMask_corrHeight_iteration%d',iterationMain);           
        showData(idxMon,SeeMe,planeFit*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
            'extraData',{BK2_definitive_PlaneFitted*factor,height_6_planeFitOnFinalMask*factor}, ...
            'extraNorm',{norm,norm},'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIFTH FITTING: FIRST ORDER PLANE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % use the mask to remove the foreground so the line-by-line fitting will be done by considering lines containing only background image                
        BK3_maskedHeightPlaneFit=height_6_planeFitOnFinalMask;
        BK3_maskedHeightPlaneFit(AFM_height_IO==1)=NaN;
        [BK4_maskedHeight_LineByLineFit,allBaselines] = lineByLineFitting_N_Order(BK3_maskedHeightPlaneFit,1);            
        % obtain the corrected height image
        height_7_linebylineFit=height_6_planeFitOnFinalMask-allBaselines;
        height_7_linebylineFit=height_7_linebylineFit-min(height_7_linebylineFit(:));
        % Display and save result
        titleData1={'Results LineByLine Fitting  with masked Height';'(Data after fitPlane then masked again)'};
        titleData2='Post LineByLineFit Masked Height';
        titleData3={sprintf('Resulting Height Channel. Iteration %d',iterationMain);'Data shifted toward zero'};
        nameFile=sprintf('resultA2_7_LineByLineFit_heightOptimized_iteration%d',iterationMain);
        fHeightOpt=showData(idxMon,true,allBaselines*factor,titleData1,SaveFigFolder,nameFile,...
                'extraData',{BK4_maskedHeight_LineByLineFit*factor,height_7_linebylineFit*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight},'extraNorm',{norm,norm});
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% HEIGHT CHANNEL PROCESSING TERMINATED. CHECK IF CONTINUE FOR BETTER MASK AND DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % stop the iteration of the mask and height channel generation and keep
        % those have been generated in the last iteration    
        question={"Satisfied of the definitive Height image and mask?";"If not, repeat again the process with the last height image to generate again a new mask.";"NOTE: ImageSegmenter Toolbox (Manual Binarization) is available from the second iteration\nso it can perform better with already optimized height image."};
        answ=getValidAnswer(question,'',{'y','n'},2);
        close(fHeightOpt)
        if answ
            height_FINAL=height_7_linebylineFit;
            mask_FINAL=AFM_height_IO;
            nameFile='resultA2_8_HeightFINAL';
            titleData1='Definitive Height Image';
            titleData2='Definitive Height Image - Normalized';
            showData(idxMon,false,height_FINAL*factor,titleData1,SaveFigFolder,nameFile,'labelBar',"Height (nm)",'pixelSizeMeterUnit',1e6,...
                'extraData',{height_FINAL}, ...
                'extraTitles',{titleData2},...
                'extraNorm',true,...
                'extraPixelSizeUnit',1e6);
            nameFile='resultA2_8_maskFINAL';
            titleData1='Definitive mask Height Image';
            showData(idxMon,false,mask_FINAL,titleData1,SaveFigFolder,nameFile,'binary',true,'pixelSizeMeterUnit',1e6) 
            % substitutes to the original height image with the new opt fitted heigh
            AFM_Images_final=AFM_Images;
            AFM_Images_final(strcmp([AFM_Images_final.Channel_name],'Height (measured)')).AFM_image=height_FINAL;
            break
        else
            iterationMain=iterationMain+1;
            height_1_original=height_7_linebylineFit;
        end 
    end
end


%%%%%%%%%%%%%%%%%
%%% FUNCTIONS %%%
%%%%%%%%%%%%%%%%%

function [IO_Image,binarizationMethod] = binarization_autoAndManualHist(height2bin,idxMon)
% original script used this approach which is not really great
    % for better comparison, first subplot there is height image (normalized for better show data)
    AFM_noBk_visible_data=imadjust(height2bin/max(height2bin(:))); 
    f1 = figure('Name','Binarization Tool');
    tiledlayout(f1,2,2,'TileSpacing','compact');
    % --- Subplot 1: Original AFM image (always visible) ---
    axDataNorm=nexttile(1,[2 1]); cla(axDataNorm); title(axDataNorm,{'Height (measured) channel';'After LineByLine Fitting with Butterworth-filtered Height'}, 'FontSize',15);
    imshow(AFM_noBk_visible_data),colormap parula, axis on   
    c = colorbar; c.Label.String = 'normalized Height'; c.Label.FontSize=15;
    ylabel('fast scan line direction','FontSize',12), xlabel('slow scan line direction','FontSize',12)
    % allocate histogram + preview axes
    axHist = nexttile(2); cla(axHist); title(axHist,'Histogram (manual mode)');
    axBinImage = nexttile(4); cla(axBinImage); title(axBinImage,'Binarized preview'); colormap(axBinImage,parula);
    objInSecondMonitor(f1,idxMon);
    % start the binarization
    first_In=true;
    no_sub_div=1000;
    kernel = strel('square',3);   % constant morphological kernel    
    prevXLine = [];
    while true
        % ---- Automatic thresholding (first iteration) ----
        if first_In
            T = adaptthresh(mat2gray(height2bin));
            segAFM = imbinarize(mat2gray(height2bin),T);
        else            
        % ---- Manual thresholding (subsequent iterations) ----
            % Compute histogram ONLY once
            if ~exist('Y','var')
                [Y,E_height] = histcounts(height2bin, no_sub_div);
                binCenters = (E_height(1:end-1) + diff(E_height)/2)*1e9;  % compute center of each bin, convert it into nm
                axes(axHist); cla(axHist); %#ok<LAXES>
                plot(axHist, binCenters,Y,'LineWidth',1.3,'DisplayName','Height Distribution'), hold(axHist,'on')
                title(axHist,'Manual Threshold Selection'); xlabel(axHist,'Height (nm)'); ylabel(axHist,'Count')
            end
            % --- Let user click on histogram ---
            uiwait(msgbox('Click on the histogram to manually select the threshold.'));
            closest_indices=selectRangeGInput(1,1,axHist);
            % eventually, delete previous existing line (two iterations earlier)
            if ~isempty(prevXLine) && isvalid(prevXLine)
                delete(prevXLine);
            end
            if any(closest_indices)
                prevXLine=xline(axHist,binCenters(closest_indices),'r--','LineWidth',2,'DisplayName','Previous selection');
            end
            thSeg=E_height(closest_indices);
            % Apply threshold
            segAFM = height2bin >= thSeg;                
        end
        % ---- Morphological cleaning ----
        segBin = imerode(segAFM, kernel);
        segBin = imdilate(segBin, kernel);

        % -------- Update preview subplot --------
        axes(axBinImage); cla(axBinImage); %#ok<LAXES>
        imshow(segBin,'Parent',axBinImage);
        title(axBinImage,'Binarized Image','FontSize',12); colormap(axBinImage,parula(2))
        colorbar(axBinImage,'Ticks',[0 1],'TickLabels',{'Background','Foreground'},'FontSize',10);

        choice=questdlg('Keep the current binarized image or select the threshold from the histogram?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');
        % If first iteration and user wants manual mode → prepare histogram
        if strcmp(choice, 'Manual Selection')               
            first_In = false;
        else
            IO_Image=segBin;
            break
        end
    end
    close(f1)
    binarizationMethod="Original method Binarization";
end

function mod=extractBinarizationPYmodule()
% the python file is assumed to be in a directory called "PythonCodes". Find it to a max distance of 4 upper
    % folders
    % Maximum levels to search
    maxLevels = 4; originalPos=pwd;
    for i=1:maxLevels
        if isfolder(fullfile(pwd, 'PythonCodes'))
            cd 'PythonCodes'
            % Call the Python function
            mod = py.importlib.import_module("binarize_stripe_image");
            py.importlib.reload(mod);
                    
            break
        elseif i==4
            error("file python not found")
        else
            cd ..        
        end            
    end 
    % return to original position
    cd(originalPos)  
end

function [IO_Image,binarizationMethod]=binarization_withPythonModules(idxMon,height2bin)    
    modulePython=extractBinarizationPYmodule();
    % show height image for help
    titletext={'Height (measured) channel';'After LineByLine Fitting with Butterworth-filtered Height'};
    ftmp=showData(idxMon,true,height2bin,titletext,'','','normalized',true,'saveFig',false);            
    % NOTE, output from python function are py.numpy.ndarray, not MATLAB arrays. Therefore, take BW and corrected directly appear unusable.
    options={'Otsu','Multi-Otsu','Sauvola','Niblack','Bradley-Roth','Adaptive-Gaussian','Yen','Li','Triangle','Isodata','Watershed'};
    BW_allMethods=cell(1,length(options));
    figPy=cell(1,length(options));
    for i=1:length(options)
        method=options{i};
        result=modulePython.binarize_stripe_image(height2bin,method);
        % Convert to MATLAB arrays
        BW = double(result);
        figPy{i}=figure; imagesc(BW), axis equal, xlim tight, title(sprintf("METHOD BINARIZATION: %s",method),"Fontsize",16)
        BW_allMethods{i}=BW;
    end
    choice=getValidAnswer('Which Binarization method do you choose?',"",options);
    IO_Image=BW_allMethods{choice};
    binarizationMethod=sprintf("Python Binarization Method %s",options{choice});
    close(ftmp), clear ftmp
    for i=1:length(options)
        if isgraphics(figPy{i})   % <- figure still open & valid
            close(figPy{i})
        end
    end
end

function [IO_Image,binarizationMethod]=binarization_ImageSegmenterToolbox(height2bin,idxMon)
    textTitle='Height (measured) channel - CLOSE THIS WINDOW WHEN SEGMENTATION TERMINATED';
    fImageSegToolbox=showData(idxMon,true,height2bin,textTitle,'','','saveFig',false,'normalized',true);
    % ImageSegmenter return vars and stores in the base workspace, outside the current
    % function. So take it from there. Save the workspace of before and after and take
    % the new variables by checking the differences of workspace
    tmp1=evalin('base', 'who');
    height2bin_norm=height2bin/max(height2bin(:));
    imageSegmenter(height2bin_norm), colormap parula
    waitfor(fImageSegToolbox)
    tmp2=evalin('base', 'who');
    varBase=setdiff(tmp2,tmp1);
    for i=1:length(varBase)            
        text=sprintf('%s',varBase{i});
        var = evalin('base', text);
        ftmp=figure;
        imshow(var), colormap parula            
        if getValidAnswer('Is the current figure the right binarized AFM?','',{'Yes','No'})
            close(ftmp)
            IO_Image=var;
            break
        end
        close(ftmp)
    end
    binarizationMethod="ImageSegmenter Toolbox";    
end
