function varargout=A2_feature_1_processHeightChannel(filtData,idxMon,SaveFigFolder,varargin)
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
    warning('off', 'stats:robustfit:IterationLimit');
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    clear allWaitBars    
    % A tool for handling and validating function inputs.  define expected inputs, set default values, and validate the types and properties of inputs.
    p=inputParser();    % init instance of inputParser
    % Add required and default parameters and also check conditions
    addRequired(p, 'filtData', @(x) isstruct(x));
    argName = 'SeeMe';              defaultVal = true;              addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'imageType';          defaultVal = 'Entire';          addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';      defaultVal = false;             addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'fitOrder';           defaultVal = '';                addParameter(p, argName, defaultVal, @(x) (ismember(x, {'Low', 'Medium', 'High'}) || isempty(x)));
    argName = 'metadata';           defaultVal = [];                addParameter(p,argName,defaultVal);
    argName = 'HoverModeImage';     defaultVal = 'HoverModeON';     addParameter(p, argName, defaultVal, @(x) (ismember(x, {'HoverModeOFF', 'HoverModeON'})));
    argName = 'offset_HVon_HVoff';  defaultVal = [];                addParameter(p,argName,defaultVal);
    argName = 'BackgroundOnly';     defaultVal = [];               addParameter(p,argName,defaultVal, @(x) ismember(x,{'backgroundOnly','background_PDA'}));
    % validate and parse the inputs
    parse(p,filtData,varargin{:});
    metadata=p.Results.metadata;        
    typeProcess=p.Results.imageType;
    SeeMe=p.Results.SeeMe;
    norm=p.Results.Normalization;
    HVmode=p.Results.HoverModeImage;
    if norm, labelHeight=""; factor=1; else, labelHeight="Height (nm)"; factor=1e9; end    
    % pixelSize calc
    lengthAxis=[metadata.x_scan_length_m,metadata.y_scan_length_m];
    % for the first time or first section, request the max fitOrder
    if isempty(p.Results.fitOrder)
        question=sprintf("Choose the level of the maxFitOrder for AFM Height Channel Background Data (%s).",HVmode);
        fitOrderHeight=chooseAccuracy(question);
    else
        fitOrderHeight=p.Results.fitOrder;
    end
    if strcmp(fitOrderHeight,'Low')
        limitPlaneFit=3; 
        limitLineFit=1;
    elseif strcmp(fitOrderHeight,'Medium')
        limitPlaneFit=6;
        limitLineFit=2;
    else
        limitPlaneFit=9;
        limitLineFit=3;
    end    
    clearvars argName defaultVal varargin
    varargout{3}=fitOrderHeight;
    % Orient image of every channel by clockwise 90° and flip along long axis so the image coencide with the Microscopy image direction
    for i=1:size(filtData,2)
        tmp_img_0=flip(rot90(filtData(i).Raw_afm_image),2);
        tmp_img_1=flip(rot90(filtData(i).AFM_image),2);
        AFM_Images(i)=struct(...
                'Channel_name', filtData(i).Channel_name,...
                'Trace_type', filtData(i).Trace_type, ...
                'AFM_images_0_raw', tmp_img_0, ...
                'AFM_images_1_original', tmp_img_1);
    end        
    % show the data prior the height processing
    A1_feature_CleanOrPrepFiguresRawData(AFM_Images,'idxMon',idxMon,'folderSaveFig',SaveFigFolder,'metadata',metadata,'imageType',typeProcess,'SeeMe',SeeMe,'Normalization',norm);
    clear tmp* filtData
    % Extract the height channel
    height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_images_1_original;

    % after the first iteration, a mask and definitive corrected height
    % image have been generated. However, although the the definitive
    % height may be ok, the mask could be still not perfect. Since the mask
    % is the most important element for the lateral deflection section and
    % it highly depends on the height channel, it is suggested to
    % re-iterate the mask generation with a new and cleaner height channel
    iterationMain=1;
    flagExeMaskGen=true;
    while true
        % in case of MATLAB system failure, dont lose the work! Also AFM_Images because it may be different in case of HV mode OFF due to resizing
        if exist(fullfile(SaveFigFolder,"TMP_DATA_MASK_definitive.mat"),'file') && getValidAnswer('Mask AFM IO for the current section has been already generated. Take it definitively?','',{'y','n'})
            load(fullfile(SaveFigFolder,"TMP_DATA_MASK_definitive.mat"),"AFM_height_IO_corr","binarizationMethod","AFM_Images")
            flagExeMaskGen=false;
            answMaskAgain=false;
            if strcmp(HVmode,"HoverModeOFF") && strcmp(typeProcess,'SingleSection')
                load(fullfile(SaveFigFolder,"TMP_DATA_MASK_definitive.mat"),'metadata','offset_HVon_HVoff');
            end
        end         
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
        fprintf("START HEIGHT PROCESSING ITERATION %d - %s\nBefore 1st order plan and lineByline fitting, %d outliers have been removed!\n",iterationMain,HVmode,countOutliers)
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% START HEIGHT PROCESS: GOAL OF THE FOLLOWING PART IS TO GENERATE THE MASK OF HEIGHT TO SEPARATE FOREGROUND AND BACKGROUND %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if flagExeMaskGen
        % For the first time, there are no files, so it assumes already first iteration.
        % If the generated mask is already good enough or it already exists, skip the following step to save time
        % The butterworth filtering is used to help to create the mask at least in the first iteration, but later it can be annoying.            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% FIRST FITTINGS: FIRST ORDER PLANE AND LINE FITTING ON ENTIRE DATA %%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if iterationMain==1 || getValidAnswer(sprintf("Started %d iteration.\nPerform the 1st order plane/line fitting on the entire data?",iterationMain),'',{'Y','N'})
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
                clear countOutliers i nameFile planeFit lineFit pos_outlier num_lines titleData* yData imageStart
            else
                height_4_corrLine=height_1_original;
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% HOVER MODE OFF MASK GENERATION (skipped in case of HV ON) %%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % if HOVER MODE OFF, the data is often messed. Therefore, try to use the AFM mask of HV_ON and resize it instead of making it again,
            % saving significant amount of time. If not, just run the normal height process like in case of HV on     
            answerFromHVon=false;
            if strcmp(p.Results.BackgroundOnly, "backgroundOnly")
                % if the data contains only BK, skip the mask generation and create a full zero mask
                flagExeMaskGen=false;
                AFM_height_IO=zeros(size(height_4_corrLine));
                binarizationMethod="No binarization, data is BK only";
                offset_HVon_HVoff=p.Results.offset_HVon_HVoff;
                answMaskAgain=false;
            else            
                foldHVON=fullfile(fileparts(fileparts(fileparts(SaveFigFolder))),"HoverModeON");
                if strcmp(HVmode,"HoverModeOFF") && strcmp(typeProcess,'SingleSection')                 
                    if exist(foldHVON,"dir")        
                        question="Is the HoverModeOFF data generated in the approximately same scan area as the HoverModeON data?";
                        options={"If yes, take the mask of HOVER MODE ON and re-align to avoid to perform binarization.";
                        "If not, then exe normal processing, therefore binarization from the Height Image (HV mode OFF)."};                
                        answerFromHVon=getValidAnswer(question,'',options);
                    end
                    offset_HVon_HVoff=p.Results.offset_HVon_HVoff;
                    if answerFromHVon==1 
                        [tmp1,tmp2,offset_HVon_HVoff]=maskFromHVon(AFM_Images,height_4_corrLine,SaveFigFolder,typeProcess,idxMon,offset_HVon_HVoff);
                        if ~isempty(tmp1)
                            AFM_height_IO=tmp1;
                            AFM_Images=tmp2; % resized channels
                            % images are now resized, update starting image
                            height_1_original=AFM_Images(strcmp([AFM_Images.Channel_name],'Height (measured)')).AFM_images_2_PostProcessed;
                            % update metadata regarding y pixel size
                            oldSizePixel_y=metadata.y_scan_pixels;
                            oldSizeMeter_y=metadata.y_scan_length_m;
                            oldSizePixel_x=metadata.x_scan_pixels;
                            oldSizeMeter_x=metadata.x_scan_length_m;
                            % Update metadata regarding x pixel size
                            metadata.y_scan_pixels = size(AFM_height_IO,2);
                            metadata.y_scan_length_m=oldSizeMeter_y*metadata.y_scan_pixels/oldSizePixel_y;
                            metadata.x_scan_pixels = size(AFM_height_IO,1);
                            metadata.x_scan_length_m=oldSizeMeter_x*metadata.x_scan_pixels/oldSizePixel_x;
                            clear tmp*
                            binarizationMethod="Extracted from HV ON mask";
                            flagExeMaskGen=false;                        
                        end
                        answerFromHVon=true;                    
                    else
                        answerFromHVon=false;
                    end
                end
                clear foldHVON
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%% BUTTERWORTH FILTERING : an automatic semi-binarization ==> transform into nan values over a certain threshold %%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if flagExeMaskGen       % the flag may change inside the same flag check
                if iterationMain~=1 && ~getValidAnswer("Perform Butterworth filtering to extract background data? If not, skip to the binarization.",'',{'y','n'})                
                    height_6_forBinarization=height_4_corrLine;                
                else                      
                    if exist(fullfile(SaveFigFolder,sprintf("TMP_DATA_1_afterButterworthMASKoperations_iteration%d.mat",iterationMain)),'file')
                        if getValidAnswer('Result of ButterworthFiltering+ManualAdjust for the current step already exists. Take it?','',{'Y','N'})
                            load(fullfile(SaveFigFolder,sprintf("TMP_DATA_1_afterButterworthMASKoperations_iteration%d.mat",iterationMain)),"BK_2_butterworthFiltered_manualAdj")
                        end
                    else
                        % this step is useful for a preliminar background detection
                        [BK_1_butterworthFiltered] = butterworthFiltering(height_4_corrLine,idxMon);                    
                        % since the step is not accurate since the data is not clean yet, manually remove portions if required
                        [~,~,BK_2_butterworthFiltered_manualAdj] = featureRemovePortions(height_4_corrLine,"Data before ButterworthFiltering",idxMon, ...
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
                            % save results in case of system failure
                            save(fullfile(SaveFigFolder,sprintf("TMP_DATA_1_afterButterworthMASKoperations_iteration%d.mat",iterationMain)),"BK_2_butterworthFiltered_manualAdj")
                        end
                    end                               
                    clear nameFile titleData* BK_1_butterworthFiltered
                
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%% SECOND FITTING: N ORDER PLANE FITTING ON BUTTERWORTH FILTERED BACKGROUND %%%%
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
                    [planeCorrection,metrics] = planeFitting_N_Order(BK_2_butterworthFiltered_manualAdj,limitPlaneFit);
                    BK_3_butterworthFiltered_PlaneFitted=BK_2_butterworthFiltered_manualAdj-planeCorrection;
                    height_5_afterButterworthBK_planeFit=height_4_corrLine-planeCorrection;
                    % show the results
                    titleData1={'Fitted Plane';sprintf('Order Plane: %s',metrics.fitOrder)};
                    titleData2={'Background Height';'Butterworth Filtered Height and Plan Fitted'};
                    titleData3={'Height Channel';'1st Background correction.'}; 
                    nameFile=sprintf('resultA2_3_FittPlaneBK_corrHeight_iteration%d',iterationMain);   
                    ftmp=showData(idxMon,true,planeCorrection*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
                        'extraData',{BK_3_butterworthFiltered_PlaneFitted*factor,height_5_afterButterworthBK_planeFit*factor}, ...
                        'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});               
                    continueLineFit=getValidAnswer("Check the plane fitting results using butterworth filtered background data. Perform also LineByLine fitting?",'',{"y","n"});
                    close(ftmp)
                    clear titleData* nameFile ftmp BK_2_butterworthFiltered_manualAdj planeCorrection metrics
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%% THIRD FITTING: N ORDER LINE-BY-LINE FITTING THE NEW PLANE-FITTED HEIGHT %%%%        
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
                    height_6_forBinarization=height_5_afterButterworthBK_planeFit;
                    if continueLineFit
                        allBaselines= lineByLineFitting_N_Order(BK_3_butterworthFiltered_PlaneFitted,limitLineFit);            
                        BK_4_butterworthFiltered_LineFitted=BK_3_butterworthFiltered_PlaneFitted-allBaselines;
                        height_tmp_afterButterworthBK_lineFit = height_5_afterButterworthBK_planeFit-allBaselines;
                        % plot the resulting corrected data and check comparison with the height
                        titleData1={'Height Channel';'1st Background correction (PlaneFit).'};
                        titleData2={'Height Channel';'2nd Background correction (LineByLineFit)'};
                        ftmp=showData(idxMon,true,height_5_afterButterworthBK_planeFit*factor,titleData1,'','','normalized',norm,'labelBar',labelHeight,'saveFig',false,...
                                'extraData',{height_tmp_afterButterworthBK_lineFit*factor}, ...
                                'extraNorm',norm,'extraTitles',{titleData2},'extraLabel',{labelHeight});
                        if getValidAnswer("Check the LineByLine results. Take them as final data that will be used for the binarization?",'',{"y","n"})
                            height_6_forBinarization=height_tmp_afterButterworthBK_lineFit;                             
                            titleData1={'Fitted LineByLine'};
                            titleData2={'Background Height';'Butterworth Filtered Height, Plan and LineByLine Fitted'};
                            titleData3={'Height Channel';'2nd Background correction'}; 
                            nameFile=sprintf('resultA2_4_FittLineByLine_corrHeight_iteration%d',iterationMain);
                            showData(idxMon,false,allBaselines*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
                                'extraData',{BK_4_butterworthFiltered_LineFitted*factor,height_tmp_afterButterworthBK_lineFit*factor}, ...
                                'extraNorm',[norm,norm],'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight});
                        end
                        close(ftmp)                                  
                    end        
                    clear titleData* nameFile BK_* ftmp
                end                
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BINARIZATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                disp('Processing now the binarization of Height channel after LineByLine Fitting with Butterworth-filtered Height')
                [AFM_height_IO,binarizationMethod]=binarizeImageMain(height_6_forBinarization*1e9,idxMon,'Height',iterationMain);             
            end  
            if answerFromHVon
                heightTmp=height_4_corrLine;
            else
                if strcmp(p.Results.BackgroundOnly, "backgroundOnly")
                    heightTmp=height_4_corrLine;
                else
                    heightTmp=height_6_forBinarization;
                end
            end
            %%% here, both HVmode ON and OFF parts (if the user chose to use HV on MASK to generate the HV off mask) undergo the following parts
            textTitleIO=sprintf('Binary Height Image - iteration %d\n%s',iterationMain,binarizationMethod);                        
            % before getting the definitive mask, let the user have the option to delete some areas for better mask and consequently fitting 
            % in case automatic/manual/python in the first iteration are still not good enough
            BK_5_heightMasked=heightTmp;
            % mask original AFM height image
            AFM_height_IO=double(AFM_height_IO);
            BK_5_heightMasked(AFM_height_IO==1)=NaN;
            % first output is a matrix of selected regions. It will not be used
            [~,AFM_height_IO_corr,BK_5_heightMasked_corr,~] = featureRemovePortions(AFM_height_IO,textTitleIO,idxMon, ...
                'additionalImagesToShow',{BK_5_heightMasked*factor,heightTmp*factor}, ...
                'additionalImagesTitleToShow',{'Masked Height Image\n(Black regions = NaN or manually removed areas)','Height Image'},...
                'originalDataIndex',3,'normalize', false);        
            % show final mask and masked raw heightin comparison with the original height 
            BK_5_heightMasked_corr=BK_5_heightMasked_corr/factor;
            if isequal(AFM_height_IO_corr,AFM_height_IO)
                titleData2={'Masked Height Image (Background).';'Data that will be used for Plane and LineByLine Fit.'};
            else
                titleData2={'Masked Height Image (Background)';'Data manually modified that will be used for Plane and LineByLine Fit.'};
            end                
            titleData3='Original Height Image';
            nameFile=sprintf('resultA2_5_DefinitiveMask_iteration%d',iterationMain);
            showData(idxMon,false,AFM_height_IO_corr,textTitleIO,SaveFigFolder,nameFile,'binary',true,'saveFig',true,...
                'extraData',{BK_5_heightMasked_corr*factor,height_1_original*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight});       
            % save in case of system failure
            save(fullfile(SaveFigFolder,sprintf("TMP_DATA_2_MASK_iteration%d",iterationMain)),"AFM_height_IO_corr","BK_5_heightMasked_corr","binarizationMethod")
            % decide to stop completely the mask generation if the current one is already good enough
            if ~strcmp(p.Results.BackgroundOnly, "backgroundOnly")
                answMaskAgain=~getValidAnswer('Is the generated mask the definitive one? If not, it will be generated another one at the next step.','',{'y','n'});
            end
            if ~answMaskAgain
                % delete the other tmp files since they will not be used anymore
                tmp=dir(fullfile(SaveFigFolder,"TMP_DATA_*_iteration*"));
                files_tmp=fullfile({tmp.folder},{tmp.name});
                delete(files_tmp{:})
                flagExeMaskGen=false;
                % just for safety in case of interruption or system failure. If the mask is definitive, save it and dont restart again the entire binarization process
                if strcmp(HVmode,"HoverModeOFF") && strcmp(typeProcess,'SingleSection')             
                    save(fullfile(SaveFigFolder,"TMP_DATA_MASK_definitive"),"AFM_height_IO_corr","binarizationMethod","AFM_Images","metadata","offset_HVon_HVoff")
                else
                    save(fullfile(SaveFigFolder,"TMP_DATA_MASK_definitive"),"AFM_height_IO_corr","binarizationMethod","AFM_Images")
                end
            end
            clear titleText* nameFile flagRemoval ftmpIO answ question textTitleIO allBaselines continueLineFit files_tmp tmp
        end
                
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% NOW THE MASK IS OBTAINED ==> LAST SERIES OF FITTING 1st ORDER USING MASKED BACKGROUND: ORIGINAL HEIGHT + FINAL MASKSKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            
        % Once the mask has been created, next step is remove new baseline by using the mask. This because is now easier to distinguish 
        % background from foreground, therefore a better plane-baseline fitting can be made, thus a more accurate AFM height image 
        % can be obtained directly from original AFM height image
        heightRaw_masked=height_1_original;
        heightRaw_masked(AFM_height_IO==1)=NaN;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FORTH FITTING: FIRST ORDER PLANE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        [planeFit,metrics] = planeFitting_N_Order(heightRaw_masked,1);
        height_7_planeFitOnFinalMaskBK=height_1_original-planeFit;
        % extract the background from the height data, rather than correct the previous background data
        BK_6_definitive_PlaneFit=height_7_planeFitOnFinalMaskBK;
        BK_6_definitive_PlaneFit(AFM_height_IO_corr==1)=NaN;    
    
        % Display and save result
        titleData1={'Results Plane Fitting with masked Height';sprintf('Order Plane: %s - iteration %d',metrics.fitOrder,iterationMain)};
        titleData2 = 'Post PlaneFit Masked Height';'Background from OPT-Height Image';
        titleData3={'Resulting OPT-Height Image'; sprintf('Iteration %d',iterationMain)};              
        nameFile=sprintf('resultA2_6_FittPlaneBKwithFinalMask_corrHeight_iteration%d',iterationMain);           
        showData(idxMon,SeeMe,planeFit*factor,titleData1,SaveFigFolder,nameFile,'normalized',norm,'labelBar',labelHeight,...
            'extraData',{BK_6_definitive_PlaneFit*factor,height_7_planeFitOnFinalMaskBK*factor}, ...
            'extraNorm',{norm,norm},'extraTitles',{titleData2,titleData3},'extraLabel',{labelHeight,labelHeight}); 
        clear metrics
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% FIFTH FITTING: FIRST ORDER LINExLINE FITTING ON MASKED DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5%%%%%%%%%%%%%%%%%%%%%%%
        % use the mask to remove the foreground so the line-by-line fitting will be done by considering lines containing only background image                        
        allBaselines = lineByLineFitting_N_Order(BK_6_definitive_PlaneFit,1);            
        height_8_LineFitOnFinalMaskBK=height_7_planeFitOnFinalMaskBK-allBaselines;
        BK_7_definitive_LineFit=height_8_LineFitOnFinalMaskBK;
        BK_7_definitive_LineFit(AFM_height_IO_corr==1)=NaN;
               
        % there may be still some anomalies. If so, permamently remove them from the height image
        textTitle={'Optimixed Height Image';'Check if there some parts to transform into NaN in the foreground. The resulting image will be definitive for the current iteration.'};
        [~,height_9_corr] = featureRemovePortions(height_8_LineFitOnFinalMaskBK*1e9,textTitle,idxMon,'normalize',false);       
        
        height_9_corr=height_9_corr/factor;
        
        % Display and save result
        titleData1={'Post PlaneFit';'(Data after fitPlane then masked again)'};
        titleData2='Post LineByLineFit Masked Height';
        titleData3={'Resulting OPT-Height Image'; sprintf('Iteration %d',iterationMain)};   
        nameFile=sprintf('resultA2_7_LineByLineFit_heightOptimized_iteration%d',iterationMain); 
        showData(idxMon,false,height_7_planeFitOnFinalMaskBK*factor,titleData1,SaveFigFolder,nameFile,'labelBar',labelHeight,...
                'extraData',{BK_7_definitive_LineFit*factor,height_8_LineFitOnFinalMaskBK*factor}, ...
                'extraTitles',{titleData2,titleData3},...
                'extraLabel',{labelHeight,labelHeight});
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%% HEIGHT CHANNEL PROCESSING TERMINATED. CHECK IF CONTINUE FOR BETTER MASK AND DATA %%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % stop the iteration of the mask and height channel generation and keep
        % those have been generated in the last iteration    
        question={"Satisfied of the definitive Height image and mask?";"If not, repeat again the process with the last height image to generate again a new mask.";"NOTE: ImageSegmenter Toolbox (Manual Binarization) is available from the second iteration\nso it can perform better with already optimized height image."};
        if ~answMaskAgain && getValidAnswer(question,'',{'y','n'},1)
            titleData1 = 'Definitive Height Image';
            titleTemplate = 'Definitive Height Image - clipped above %.2fth percentile';
            % REMOVE th percentile from height channel through slider (not in the AFM-IO because it will be used later and it is informative keep it as it is
            [th,dataClean] = percentileClipSlider(idxMon, height_9_corr*factor, ...
                titleData1, titleTemplate, "Height (nm)", lengthAxis,'pInit', 99, 'pMin', 95, 'pMax', 100);            
            % User cancelled
            if isnan(th)
                height_FINAL = height_9_corr;
                nameFile='resultA2_8_HeightFINAL';
                nameFileMask='resultA2_8_maskFINAL';
                titleData1={titleData1;'No prctile thresholding'}; %#ok<*AGROW>
            else
                % Convert back to unscaled if you want the raw stored:
                height_10_prctile=dataClean/factor;
                nameFile="resultA2_8_HeightBeforePrctileTH";
                showData(idxMon,false,height_9_corr*factor,"Definitive Height before threshold",SaveFigFolder,nameFile,'labelBar',"Height (nm)",'lenghtAxis',lengthAxis);
                nameFile='resultA2_9_HeightFINAL';  
                nameFileMask='resultA2_9_maskFINAL';              
                height_FINAL=height_10_prctile;
                subtext=sprintf('Removed <%.2f° and >%.2f° from the data',th(1),th(2));
                titleData1={titleData1;sprintf('%s',subtext)};
            end        
            % save final height
            showData(idxMon,false,height_FINAL*factor,titleData1,SaveFigFolder,nameFile,'labelBar',"Height (nm)",'lenghtAxis',lengthAxis);
            % save mask            
            titleData1='Definitive Mask Height Image';
            mask_FINAL=AFM_height_IO_corr;
            showData(idxMon,false,mask_FINAL,titleData1,SaveFigFolder,nameFileMask,'binary',true,'lenghtAxis',lengthAxis) 
            % substitutes to the original height image with the new opt fitted heigh
            AFM_Images_final=AFM_Images;            
            for i=1:length(AFM_Images_final)
                if strcmp(AFM_Images_final(i).Channel_name,"Height (measured)")
                    % The height channel will be changed with the new optimized final height previosuly obtained.
                    % The height will keep the size. Therefore, if HV OFF and resizing, the height is ok. But for the other channels, they
                    % have been already copied!
                    AFM_Images_final(i).AFM_images_2_PostProcessed=height_FINAL;
                elseif ~strcmp(binarizationMethod,"Extracted from HV ON mask") 
                    % Copy the the original data as new column except height. 
                    AFM_Images_final(i).AFM_images_2_PostProcessed=AFM_Images_final(i).AFM_images_1_original; 
                end
            end
            varargout{1}=AFM_Images_final;
            varargout{2}=mask_FINAL;
            if strcmp(HVmode,"HoverModeOFF") && strcmp(typeProcess,'SingleSection')      
                varargout{4}=metadata;
                varargout{5}=offset_HVon_HVoff;
            end
            break
        else
            iterationMain=iterationMain+1;
            height_1_original=height_9_corr;
            AFM_height_IO=AFM_height_IO_corr;
        end 
    end
end


%%%%%%%%%%%%%%%%%
%%% FUNCTIONS %%%
%%%%%%%%%%%%%%%%%
function varargout=maskFromHVon(data_HV_OFF,height_HV_OFF,folderHVoff,typeProcess,idxMon,offset_HVon_HVoff)
    varargout=cell(1,3);
    parts = split(folderHVoff, filesep);   % split into folders
    idx = find(parts == "HoverMode_OFF");
    mainPath = strjoin(parts(1:idx-1), filesep);
    if strcmp(typeProcess,'SingleSection')
        % find the mask saved as figure of HV_ON for the specific section: open its figure and extract the data from it (better in this
        % way rather than find the file
        [~, tmp] = fileparts(folderHVoff);
        idxSectionHVon = sscanf(tmp, '%*[^_]_%d');
        pathFileFigMASK_HV_ON=fullfile(mainPath,'HoverMode_ON',"Results singleSectionProcessing",sprintf("section_%d",idxSectionHVon),"figImages","resultA2_*_maskFINAL.fig");
    else
        pathFileFigMASK_HV_ON=fullfile(mainPath,"Results Processing AFM and fluorescence images*","figImages","resultA2_*_maskFINAL.fig");
    end
    % usually only one file (iteration 1), but just in case take the last iteration if any (which is already 1 in case of only one iteration)
    fileHVonMask=dir(pathFileFigMASK_HV_ON);        
    if isempty(fileHVonMask)
        error("Anomaly, the mask of HV ON should exist. Maybe different naming?")
    end
    filepathEffective=fullfile(fileHVonMask(end).folder, fileHVonMask(end).name);
    % extraxt the data from fig
    hFig = openfig(filepathEffective, 'invisible'); 
    ax = findobj(hFig, 'Type', 'axes');      % get axes handle(s)
    img = findobj(ax, 'Type', 'image');      % get image object(s)
    AFM_height_IO_HV_ON = get(img, 'CData');   % extract matrix data
    close(hFig);
    clear pathFileFigMASK_HV_ON fileHVonMask filepathEffective hFig ax img        
    % now there are both HV_ON and HV_OFF masks. Correlate them to exclude not correlated regions so the friction is derived to a
    % confined region which is guaranted to be same in both scan modes
    mask_HV_ON = double(AFM_height_IO_HV_ON);
    % since the data are different, move manually. If offset_HVon_HVoff has been already calculated from first section, take it
    if isempty(offset_HVon_HVoff)
        offset_HVon_HVoff = round(manual_align_images(mask_HV_ON, height_HV_OFF));
    end
    dxInt=offset_HVon_HVoff(1); dyInt=offset_HVon_HVoff(2);
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
     
    varargout{1}=mask_HV_OFF;
    %%% === Trim AFM images (HVOFF) to the common region === %%%        
    for i = 1:length(data_HV_OFF)
        img = data_HV_OFF(i).AFM_images_1_original;
        img=img(yDataStart:yDataEnd, xDataStart:xDataEnd);
        data_HV_OFF(i).AFM_images_2_PostProcessed = img;
    end 
    varargout{2}=data_HV_OFF;
    saveFigures_FigAndTiff(f_maskComparison,folderHVoff,"resultA2_2_maskHVoff_fromHVon")  
    varargout{3}=offset_HVon_HVoff;
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
    title(axData,'Height Image post outlierRemoval+planeFit+lineFit', 'FontSize',12);
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

