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
    % pixelSize calc
    lengthAxis=[metadata.x_scan_length_m,metadata.y_scan_length_m];
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
    clear filtData metadata setpointN temp_img
    % Extract the height channel
    height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_image;
    
    % after the first iteration, a mask and definitive corrected height
    % image have been generated. However, although the the definitive
    % height may be ok, the mask could be still not perfect. Since the mask
    % is the most important element for the lateral deflection section and
    % it highly depends on the height channel, it is suggested to
    % re-iterate the mask generation with a new and cleaner height channel
    iterationMain=1;
    flagMaskFromHVonAlreadyDone=false;
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
        fprintf("\nSTART HEIGHT PROCESSING ITERATION %d\nBefore 1st order plan and lineByline fitting, %d outliers have been removed!\n",iterationMain,countOutliers)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIRST FITTINGS: FIRST ORDER PLANE AND LINE FITTING ON ENTIRE DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % correct the 3d tilted effect
        planeFit = planeFitting_N_Order(height_2_outliersRemoved,1);                      
        % apply the correction plane to the data
        height_3_corrPlane = height_1_original-planeFit;
        % correct the 3d tilted effect
        lineFit = lineByLineFitting_N_Order(height_3_corrPlane,1);                      
        % apply the correction plane to the data
        height_4_corrLine = height_3_corrPlane-lineFit  ;
        if iterationMain==1
            imageStart="Raw Image";
        else
            imageStart=sprintf("Image of Iteration %d",iterationMain-1);
        end
        % Display and save result
        titleData1 = {'Starting Height Image';sprintf('%s - %d outliers removed before fitting',imageStart,countOutliers)};
        titleData2 = 'Height Image (1st order PlaneFit)';
        titleData3 = 'Height Image (1st order LineByLineFit) ';        
        nameFile = sprintf('resultA2_1_height_planeLineFit1_iteration%d',iterationMain);    
        showData(idxMon,SeeMe,height_2_outliersRemoved*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight, ...
            'extraData',{height_3_corrPlane*factor,height_4_corrLine*factor},'extraNorm',{norm,norm}, ...
            'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});           
        clear countOutliers i nameFile planeFit pos_outlier num_lines titleData* yData
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIRST FITTING: FIRST ORDER PLANE FITTING ON ENTIRE DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % if HOVER MODE OFF, the data is often messed. Therefore, try to use the AFM mask of HV_ON and resize it instead of making it again,
        % saving significant amount of time        
        flagHeightProcess=true;
        if strcmp(HVmode,"HoverModeOFF")            
            question="HV OFF Mask obtained from HV ON for the current height image already exist. Take it?";
            if exist(fullfile(SaveFigFolder,'TMP_DATA_1_MASKfromHVon.mat'),'file') && ~flagMaskFromHVonAlreadyDone
                if getValidAnswer(question,'',{'Y','N'})
                % in case of second iteration, skip the load. It is already stored in the workspace
                    flagHeightProcess=false;
                    flagMaskFromHVonAlreadyDone=true;
                    load(fullfile(SaveFigFolder,'TMP_DATA_1_MASKfromHVon'),'AFM_height_IO','AFM_Images','textTitleIO')
                    height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_image;
                end
            else
                question={"If the HoverModeOFF data has been generated in the approximately same scan area as the HoverModeON data,";"take the mask of HOVER MODE ON and re-align to save time? If not, then exe normal processing."};
                if getValidAnswer(question,'',{'Y','N'})
                    [tmp1,tmp2]=maskFromHVon(AFM_Images,height_4_corrLine,SaveFigFolder,typeProcess,idxMon);
                    if ~isempty(tmp1)
                        AFM_height_IO=tmp1;
                        AFM_Images=tmp2;
                        % images are now resized, update starting image
                        height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_image;
                        clear tmp*
                        binarizationMethod="Extracted from HV ON mask";
                        textTitleIO=sprintf('Binary Height Image - iteration %d\n%s',iterationMain,binarizationMethod);
                        save(fullfile(SaveFigFolder,'TMP_DATA_1_MASKfromHVon'),'AFM_height_IO','AFM_Images','textTitleIO')
                        flagMaskFromHVonAlreadyDone=true;
                        flagHeightProcess=false;
                    end
                end
            end
        end
        if flagHeightProcess
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%% BUTTERWORTH FILTERING : an automatic semi-binarization ==> transform into nan values over a certain threshold %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % this step is useful for a preliminar background detection
            [BK_1_butterworthFiltered] = butterworthFiltering(height_4_corrLine,idxMon);
            % since the step is not accurate since the data is not clean yet, manually remove portions if required
            [~,BK_2_butterworthFiltered_manualAdj] = featureRemovePortions(height_4_corrLine,"Data before ButterworthFiltering",idxMon, ...
                'additionalImagesToShow',BK_1_butterworthFiltered,...
                'additionalImagesTitleToShow',"Data after ButterworthFiltering",...
                'originalDataIndex',1);        
            % show the results
            titleData1='Background Height - Butterworth Filtered Height';        
            nameFile=sprintf('resultA2_2_BackgroundHeight_butterworth_iteration%d',iterationMain);   
            if isequal(BK_1_butterworthFiltered,BK_2_butterworthFiltered_manualAdj)
                showData(idxMon,SeeMe,B*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight);
            else
                titleData2="Background Height - after manual replace/removal step";
                showData(idxMon,SeeMe,BK_1_butterworthFiltered*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
                    'extraData',BK_2_butterworthFiltered_manualAdj*factor,'extraTitles',titleData2,'extraNorm',norm,'extraLabel',{labelHeight});
            end        
            clear fbutter closest_indices numBins Y E_height Wn b a Y_filtered dY locs bk_limit background_th nameFile question thresholdApproach titleData* BK_1_butterworthFiltered
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% SECOND FITTING: N ORDER PLANE FITTING ON BUTTERWORTH FILTERED BACKGROUND %%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
            [planeCorrection,metrics] = planeFitting_N_Order(BK_2_butterworthFiltered_manualAdj,limit);
            BK_3_butterworthFiltered_PlaneFitted=BK_2_butterworthFiltered_manualAdj-planeCorrection;
            height_5_afterButterworthBK_planeFit=height_4_corrLine-planeCorrection;
            % show the results
            titleData1={'Fitted Plane';sprintf('Order Plane: %s',metrics.fitOrder)};
            titleData2={'Background Height';'Butterworth Filtered Height and Plan Fitted'};
            titleData3={'Height Channel';'1st Background correction.'}; 
            nameFile=sprintf('resultA2_3_FittPlaneBK_corrHeight_iteration%d',iterationMain);   
            ftmp=showData(idxMon,true,planeCorrection*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
                'extraData',{BK_3_butterworthFiltered_PlaneFitted*factor,height_5_afterButterworthBK_planeFit*factor}, ...
                'extraNorm',{norm,norm},'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});               
            continueLineFit=getValidAnswer("Check the plane fitting results. Perform also LineByLine fitting?",'',{"y","n"});
            close(ftmp)
            clear titleData* nameFile BK_1_butterworthFiltered ftmp BK_2_butterworthFiltered_manualAdj        
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% THIRD FITTING: N ORDER LINE-BY-LINE FITTING THE NEW PLANE-FITTED HEIGHT %%%%        
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
            height_6_forBinarization=height_5_afterButterworthBK_planeFit;
            if continueLineFit
                allBaselines= lineByLineFitting_N_Order(BK_3_butterworthFiltered_PlaneFitted,limit);            
                BK_4_butterworthFiltered_LineFitted=BK_3_butterworthFiltered_PlaneFitted-allBaselines;
                height_tmp = height_5_afterButterworthBK_planeFit-allBaselines;
                % plot the resulting corrected data
                titleData1={'Fitted LineByLine'};
                titleData2={'Background Height';'Butterworth Filtered Height, Plan and LineByLine Fitted'};
                titleData3={'Height Channel';'2nd Background correction'}; 
                nameFile=sprintf('resultA2_4_FittLineByLine_corrHeight_iteration%d',iterationMain);
                ftmp=showData(idxMon,true,allBaselines*factor,titleData1,"","",'normalized',norm,'labelBar',labelHeight,'saveFig',false,...
                    'extraData',{BK_4_butterworthFiltered_LineFitted*factor,height_tmp*factor}, ...
                    'extraNorm',[norm,norm],'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});
                if getValidAnswer("Check the LineByLine results. Take them as final data that will be used for the binarization?",'',{"y","n"})
                    height_6_forBinarization=height_tmp;
                    saveFigures_FigAndTiff(ftmp,SaveFigFolder,nameFile)
                else
                    close(ftmp)
                end
            end        
            clear titleData* nameFile BK_*            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BINARIZATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
            % in case of MATLAB system failure, dont lost the work!
            flagRestartBin=true;
            if exist(fullfile(SaveFigFolder,sprintf("TMP_DATA_MASK_iteration%d.mat",iterationMain)),'file')
                if getValidAnswer("Mask AFM IO data of the current iteration has been already generated. Take it?","",{"y","n"})
                    load(fullfile(SaveFigFolder,sprintf("TMP_DATA_MASK_iteration%d.mat",iterationMain)),"AFM_height_IO","textTitleIO")
                    flagRestartBin=false;
                end
            end
            if flagRestartBin 
                % start the classic binarization to create the mask, i.e. the 0/1 height image (0 = Background, 1 = Foreground). 
                [AFM_height_IO,binarizationMethod]=binarization_autoAndManualHist(height_6_forBinarization,idxMon);                         
                % PYTHON BINARIZATION TECHNIQUES. It requires other options, when I will have more time. Especially for DeepLearning technique
                question="Satisfied of the first binarization method? If not, run the Python Binarization tools!";
                if ~getValidAnswer(question,"",{"Yes","No"},2)
                    [AFM_height_IO,binarizationMethod]=binarization_withPythonModules(idxMon,height_6_forBinarization);
                end    
                % show data and if it is not okay, start toolbox segmentation
                question=sprintf('Satisfied of the binarization of the iteration %d? If not, run ImageSegmenter ToolBox for better manual binarization',iterationMain);        
                if iterationMain>1 && ~getValidAnswer(question,'',{'Yes','No'})            
                    % Run ImageSegmenter Toolbox if at end of the second iteration, the mask is still not good enough
                    [AFM_height_IO,binarizationMethod]=binarization_ImageSegmenterToolbox(height_6_forBinarization,idxMon);                  
                end
                textTitleIO=sprintf('Binary Height Image - iteration %d\n%s',iterationMain,binarizationMethod);        
                % just for safety in case of interruption
                save(fullfile(SaveFigFolder,sprintf("TMP_DATA_2_MASKfromBinarizationTools_iteration%d.mat",iterationMain)),"AFM_height_IO","textTitleIO")
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% MASK GENERATED ==> MASK ORIGINAL HEIGHT IMAGE AND REMOVE PLANE BASELINE %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%             
        % Once the mask has been created, next step is remove new baseline by using the mask. This because is now easier to distinguish 
        % background from foreground, therefore a better plane-baseline fitting can be made, thus a more accurate AFM height image 
        % can be obtained directly from original AFM height image

        % in case of MATLAB system failure, dont lost the work!
        flagRestartRemoval=true;
        if exist(fullfile(SaveFigFolder,sprintf("TMP_DATA_REMOVAL_iteration%d.mat",iterationMain)),'file')
            if getValidAnswer("Data of Manually removed regions of the current iteration has been already generated. Take it?","",{"y","n"})
                load(fullfile(SaveFigFolder,sprintf("TMP_DATA_REMOVAL_iteration%d.mat",iterationMain)),"AFM_height_IO_corr","BK_5_heightMasked_corr")
                flagRestartRemoval=false;
            end
        end
        if flagRestartRemoval 
            % FIRST, check if there are some regions that may affect negatively the fitting. If so, then remove them.
            BK_5_heightMasked=height_1_original;
            % mask original AFM height image
            AFM_height_IO=double(AFM_height_IO);
            % obtain the data of background
            BK_5_heightMasked(AFM_height_IO==1)=NaN;
            % first output is a matrix of removed regions. Return also potentially the final adjusted mask
            [AFM_height_IO_corr,BK_5_heightMasked_corr] = featureRemovePortions(AFM_height_IO,textTitleIO,idxMon, ...
                'additionalImagesToShow',{BK_5_heightMasked,height_1_original}, ...
                'additionalImagesTitleToShow',{'Masked Raw Height Image\n(Black regions = NaN or manually removed areas)','Raw Height Image'},...
                'originalDataIndex',3);        
            % show final mask and masked raw heightin comparison with the original height            
            if isequal(AFM_height_IO_corr,AFM_height_IO)
                titleData2={'Masked Raw Height Image (Background).';' Data that will be used for PlaneFit.'};
            else
                titleData2={'Masked Raw Height Image (Background)';'Regions postHeightBinariz manually modified. Data that will be used for PlaneFit.'};
                % save results in case of system failure
                save(fullfile(SaveFigFolder,sprintf("TMP_DATA_REMOVAL_iteration%d.mat",iterationMain)),"AFM_height_IO_corr","BK_5_heightMasked_corr")
            end
            titleData3='Raw Height Image';
            nameFile=sprintf('resultA2_5_DefinitiveMask_iteration%d',iterationMain);
            showData(idxMon,false,AFM_height_IO_corr,textTitleIO,SaveFigFolder,nameFile,'binary',true,'saveFig',true,...
                'extraData',{BK_5_heightMasked_corr*factor,height_1_original*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight},'extraNorm',{norm,norm});           
        end        
        clear titleText* nameFile flagRemoval ftmpIO answ question textTitleIO binarizationMethod
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FORTH FITTING: N ORDER PLANE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [planeFit,metrics] = planeFitting_N_Order(BK_5_heightMasked_corr,1);
        height_7_planeFitOnFinalMaskBK=height_1_original-planeFit;
        % extract the background from the height data, rather than correct the previous background data
        BK_6_definitive_PlaneFit=height_7_planeFitOnFinalMaskBK;
        BK_6_definitive_PlaneFit(AFM_height_IO_corr==1)=NaN;    
    
        % Display and save result
        titleData1={'Results Plane Fitting with masked Height';sprintf('Order Plane: %s - iteration %d',metrics.fitOrder,iterationMain)};
        titleData2 = 'Resulting Masked Height';'Background from OPT-Height Image';
        titleData3={'Resulting OPT-Height Image'; sprintf('Iteration %d',iterationMain)};              
        nameFile=sprintf('resultA2_6_FittPlaneBKwithFinalMask_corrHeight_iteration%d',iterationMain);           
        showData(idxMon,SeeMe,planeFit*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
            'extraData',{BK_6_definitive_PlaneFit*factor,height_7_planeFitOnFinalMaskBK*factor}, ...
            'extraNorm',{norm,norm},'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIFTH FITTING: FIRST ORDER LINExLINE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5%%%%%%%%%%%%%%%%%%%%%%%
        % use the mask to remove the foreground so the line-by-line fitting will be done by considering lines containing only background image                        
        allBaselines = lineByLineFitting_N_Order(BK_6_definitive_PlaneFit,1);            
        height_8_LineFitOnFinalMaskBK=height_7_planeFitOnFinalMaskBK-allBaselines;
        BK_7_definitive_LineFit=height_8_LineFitOnFinalMaskBK;
        BK_7_definitive_LineFit(AFM_height_IO_corr==1)=NaN;
        % Display and save result
        titleData1={'Results LineByLine Fitting  with masked Height';'(Data after fitPlane then masked again)'};
        titleData2='Post LineByLineFit Masked Height';
        titleData3=sprintf('Resulting Height Channel. Iteration %d',iterationMain);
        nameFile=sprintf('resultA2_7_LineByLineFit_heightOptimized_iteration%d',iterationMain);
        showData(idxMon,false,allBaselines*factor,titleData1,SaveFigFolder,nameFile,...
                'extraData',{BK_7_definitive_LineFit*factor,height_8_LineFitOnFinalMaskBK*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight},'extraNorm',{norm,norm});
        % there may be still some anomalies. If so, permamently remove them from the height image
        height_8_LineFitOnFinalMaskBK_corr = featureRemovePortions(height_8_LineFitOnFinalMaskBK,'Optimixed Height Image. Check if there some parts to transform into NaN in the foreground',idxMon, ...
                   'normalize',false);       

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% HEIGHT CHANNEL PROCESSING TERMINATED. CHECK IF CONTINUE FOR BETTER MASK AND DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % stop the iteration of the mask and height channel generation and keep
        % those have been generated in the last iteration    
        question={"Satisfied of the definitive Height image and mask?";"If not, repeat again the process with the last height image to generate again a new mask.";"NOTE: ImageSegmenter Toolbox (Manual Binarization) is available from the second iteration\nso it can perform better with already optimized height image."};
        answ=getValidAnswer(question,'',{'y','n'},2);
        if answ
            height_FINAL=height_8_LineFitOnFinalMaskBK_corr;
            mask_FINAL=AFM_height_IO_corr;
            nameFile='resultA2_8_HeightFINAL';
            titleData1='Definitive Height Image';
            titleData2='Definitive Height Image - Normalized';
            showData(idxMon,false,height_FINAL*factor,titleData1,SaveFigFolder,nameFile,'labelBar',"Height (nm)",'lenghtAxis',lengthAxis,...
                'extraData',{height_FINAL}, ...
                'extraTitles',{titleData2},...
                'extraNorm',true);
            nameFile='resultA2_8_maskFINAL';
            titleData1='Definitive mask Height Image';
            showData(idxMon,false,mask_FINAL,titleData1,SaveFigFolder,nameFile,'binary',true,'lenghtAxis',lengthAxis) 
            % substitutes to the original height image with the new opt fitted heigh
            AFM_Images_final=AFM_Images;
            AFM_Images_final(strcmp([AFM_Images_final.Channel_name],'Height (measured)')).AFM_image=height_FINAL;
            break
        else
            iterationMain=iterationMain+1;
            height_1_original=height_8_LineFitOnFinalMaskBK_corr;
            AFM_height_IO=AFM_height_IO_corr;
        end 
    end
end


%%%%%%%%%%%%%%%%%
%%% FUNCTIONS %%%
%%%%%%%%%%%%%%%%%
function varargout=maskFromHVon(data_HV_OFF,height_HV_OFF,folderHVoff,typeProcess,idxMon)
    varargout=cell(1,2);
    parts = split(folderHVoff, filesep);   % split into folders
    idx = find(parts == "HoverMode_OFF");
    mainPath = strjoin(parts(1:idx-1), filesep);
    if strcmp(typeProcess,'SingleSection')
        % find the mask saved as figure of HV_ON for the specific section: open its figure and extract the data from it (better in this
        % way rather than find the file
        [~, tmp] = fileparts(folderHVoff);
        idxSectionHVon = sscanf(tmp, '%*[^_]_%d');
        pathFileFigMASK_HV_ON=fullfile(mainPath,'HoverMode_ON',"Results singleSectionProcessing",sprintf("section_%d",idxSectionHVon),"figImages","resultA2_8_maskFINAL.fig");
    else
        files_figHV_ON_mask=dir(fullfile(mainPath,"Results Processing AFM and fluorescence images*","figImages","resultA2_8_maskFINAL.fig"));
        % usually only one file, but just in case take the last 
        pathFileFigMASK_HV_ON=fullfile(files_figHV_ON_mask(end).folder, files_figHV_ON_mask(end).name);
    end
    % usually only one file (iteration 1), but just in case take the last iteration if any (which is already 1 in case of only one iteration)
    if ~exist(pathFileFigMASK_HV_ON,'file')
        error("Anomaly, the mask of HV ON should exist. Maybe different naming?")
    end
    hFig = openfig(pathFileFigMASK_HV_ON, 'invisible'); 
    ax = findobj(hFig, 'Type', 'axes');      % get axes handle(s)
    img = findobj(ax, 'Type', 'image');      % get image object(s)
    AFM_height_IO_HV_ON = get(img, 'CData');   % extract matrix data
    close(hFig);
    clear pathFileFigMASK_HV_ON files_figHV_ON_mask hFig ax img        

    % now there are both HV_ON and HV_OFF masks. Correlate them to exclude not correlated regions so the friction is derived to a
    % confined region which is guaranted to be same in both scan modes
    mask_HV_ON = double(AFM_height_IO_HV_ON);
    % since the data are different, move manually.
    offset = round(manual_align_images(mask_HV_ON, height_HV_OFF));
    dxInt=offset(1); dyInt=offset(2);
    % sizes
    [mH, mW] = size(mask_HV_ON); [dH, dW] = size(height_HV_OFF);    
    % compute overlapping ranges in mask and data coordinates
    xMaskStart = max(1, 1 + dxInt);    xMaskEnd   = min(mW, dW + dxInt);
    yMaskStart = max(1, 1 + dyInt);    yMaskEnd   = min(mH, dH + dyInt);    
    xDataStart = max(1, 1 - dxInt);    xDataEnd   = min(dW, mW - dxInt);
    yDataStart = max(1, 1 - dyInt);    yDataEnd   = min(dH, mH - dyInt);    
    % overlapping mask (aligned to data)
    mask_HV_OFF = mask_HV_ON(yMaskStart:yMaskEnd, xMaskStart:xMaskEnd);
    % corresponding data
    dataOverlap = height_HV_OFF(yDataStart:yDataEnd, xDataStart:xDataEnd);
    % optionally, apply mask to data
    maskedData = dataOverlap;
    maskedData(logical(mask_HV_OFF))=NaN;   % nan outside mask

    f_maskComparison=figure;
    subplot(1,3,1)
    imagesc(mask_HV_ON),axis equal, xlim tight,title('Original mask HV mode ON','Fontsize',14);
    subplot(1,3,2);
    imagesc(mask_HV_OFF),axis equal, xlim tight,title({'Mask HV mode OFF extracted from HV ON';sprintf('Resized data (%d - %d => %d - %d)',dH,dW,size(mask_HV_OFF))},'Fontsize',14);    
    subplot(1,3,3);
    imagesc(maskedData),axis equal, xlim tight,title({'Background';'Masked height image after 1st order fit Plane'},'Fontsize',14);    
    objInSecondMonitor(f_maskComparison,idxMon)     
    if getValidAnswer('Satisfied of the pseudo-mask of HoverMode OFF?','',{'Y','N'})
        varargout{1}=mask_HV_OFF;
        %%% === Trim AFM images (HVOFF) to the common region === %%%        
        for i = 1:length(data_HV_OFF)
            img = data_HV_OFF(i).AFM_image;
            img=img(yDataStart:yDataEnd, xDataStart:xDataEnd);
            data_HV_OFF(i).AFM_image = img;
        end 
        varargout{2}=data_HV_OFF;
        saveFigures_FigAndTiff(f_maskComparison,folderHVoff,"resultA2_2_maskHVoff_fromHVon")   
    end 
end

function [data_butterworthFiltered] = butterworthFiltering(data,idxMon)
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
    
    f1 = figure('Name','Butterworth data filtering Tool');
    tiledlayout(f1,1,3,'TileSpacing','compact');
    % --- Subplot 1: Original AFM image (always visible) ---
    axData=nexttile(1,[1 1]); cla(axData);
    imagesc(axData,data*1e9)
    title(axData,'Height Image post planeFit+outlierRemoval', 'FontSize',12);
    c = colorbar; c.Label.String = 'Height [nm]'; c.Label.FontSize=11;
    ylabel('fast scan line direction','FontSize',10), xlabel('slow scan line direction','FontSize',10)
    colormap parula, axis equal, xlim tight, ylim tight   
    % allocate histogram + preview axes
    axHist = nexttile(2); cla(axHist); title(axHist,'Histogram butterworth filtered data');
    axDataFilt = nexttile(3); cla(axDataFilt);    
    % --- Create an empty image object ONCE ---
    currImg = imagesc(axDataFilt, zeros(size(data)));   % placeholder matrix
    title(axDataFilt,'Result Height after manual threshold selection','FontSize',12); colormap(axDataFilt,parula);
    c = colorbar; c.Label.String = 'Height [nm]'; c.Label.FontSize=11;      
    ylabel('fast scan line direction','FontSize',10), xlabel('slow scan line direction','FontSize',10)
    axis(axDataFilt,'equal'), xlim(axDataFilt,'tight'), ylim(axDataFilt,'tight')       
    objInSecondMonitor(f1,idxMon);

    % Original code uses 10'000 bins, which may be too fine for most AFM height ranges
    % Therefore, automatically adapt the number of bins based on data range and image size.
    numBins = min(5000, max(100, round(numel(data)/100))); % adaptive bin count
    % distribute the fitted data among bins using N bins and Normalize Y before filtering to make it scale-independent.
    [Y,E_height] = histcounts(data,numBins,'Normalization', 'pdf');
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
    th_Y=Y_filtered(bk_limit);
    % HOWEVER, it doesnt work always, so also manual selection
    plot(axHist,E_height(1:end-1), Y_filtered, 'b', 'LineWidth', 2,'DisplayName','Butterworth-filtered Height');
    hold(axHist,"on")
    title(axHist,'Background detection with butterworth-filtered Height','FontSize',12); legend(axHist,'FontSize',10)
    xlabel(axHist,'Height (nm)','FontSize',10); ylabel(axHist,'PDF (Probability Density Function on Count','FontSize',10);
    xlim(axHist,"tight"), grid(axHist,"on")        
    % start the manual selection
    while true
        if exist('currLine','var') && ~isempty(currLine) && isvalid(currLine)
            delete(currLine); delete(currScatt)
        end
        currLine=xline(axHist,background_th, 'r--', 'LineWidth', 1.5,'DisplayName','Current Threshold');
        currScatt=scatter(axHist,background_th,th_Y,80,'g*');
        currScatt.Annotation.LegendInformation.IconDisplayStyle = 'off';
        % show and update the threshold filtered data. Background_th is orginally in nm unit
        % all pixels above this height (i.e., part of the actual structure) are
        % masked (NaN), leaving only the flat background    
        data_butterworthFiltered = data;
        data_butterworthFiltered(data_butterworthFiltered > background_th*1e-9) = NaN; 
        % Update ONLY the image, keep everything else
        currImg.CData = data_butterworthFiltered*1e9;
        choice=questdlg('Keep the current threshold or manually change by clicking on the histogram?', 'Manual Selection', 'Keep Current','Manual Selection','Keep Current');        
        if strcmp(choice,'Manual Selection')
            closest_indices=selectRangeGInput(1,1,axHist);
            background_th=E_height(closest_indices);
            th_Y=Y_filtered(closest_indices);
        else             
            close(f1)
            break
        end
    end
end

function [IO_Image,binarizationMethod] = binarization_autoAndManualHist(height2bin,idxMon)
% original script used this approach which is not really great
% for better comparison, first subplot there is height image (normalized for better show data)
    AFM_noBk_visible_data=imadjust(height2bin/max(height2bin(:))); 
    % prepare the layout showing three plots of which one is iterative
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
            prevXLine=xline(axHist,binCenters(closest_indices),'r--','LineWidth',2,'DisplayName','Previous selection');
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

