% Function to process and subtract the background from the AFM LD images, this updated function
% uses the AFM IO image as a mask to select the background, thus a more
% precise fitting is possible.
% Check manually the processed image afterwards and compare with the AFM VD
% image!

function varargout=A2_feature_2_processLateralChannel(AFM_data,AFM_height_IO,alpha,idxMon,newFolder,mainPath,varargin)
    % in case of code error, the waitbar won't be removed. So the following command force its closure
    warning ('off','all'); 
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)       

    p=inputParser();    %init instance of inputParser
    %Add default parameters. When call the function, use 'argName' as well you use 'LineStyle' in plot! And
    %then the values
    argName = 'FitOrderHVON_Lat';           defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'FitOrderHVOFF_Height';       defaultVal = '';     addOptional(p,argName,defaultVal, @(x) (ismember(x,{'Low','Medium','High'}) || isempty(x)));
    argName = 'SeeMe';                      defaultVal = true;      addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'Normalization';              defaultVal = false;     addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'flagSingleSectionProcess';   defaultVal = false;     addOptional(p,argName,defaultVal, @(x) islogical(x));
    argName = 'idxSectionHVon';             defaultVal = [];        addOptional(p,argName,defaultVal);

    parse(p,varargin{:});
    % setup optional input
    if p.Results.SeeMe; SeeMe=1; else, SeeMe=0; end    
    if p.Results.Normalization, norm=1; unitDataLabel="" ;else, norm=0; unitDataLabel='Voltage [V]'; end
    unitDataLabel=string(unitDataLabel);
    if p.Results.flagSingleSectionProcess, flagSingleSectionProcess=1; else, flagSingleSectionProcess=0; end
    if ~isempty(p.Results.idxSectionHVon), idxSectionHVon=p.Results.idxSectionHVon; end  
    
    % for the first time or first section, request the max fitOrder
    if isempty(p.Results.FitOrderHVON_Lat)
        FitOrderHVON_Lat=chooseAccuracy("Choose the level of fit Order for lineXline baseline (i.e. Background) of AFM Lateral Deflection Data.");
    else
        FitOrderHVON_Lat=p.Results.FitOrderHVON_Lat;
    end
    if strcmp(FitOrderHVON_Lat,'Low'), limit=3; elseif strcmp(fitOrder,'Medium'), limit=6; else, limit=9; end       
    FitOrderHVOFF_Height=p.Results.FitOrderHVOFF_Height;
    clearvars argName defaultVal p varargin    
    if ~exist(fullfile(newFolder,'TMP_DATA_3_LATERAL_PART.mat'),'file')
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% PREPARE THE PLOTTING OF THE LATERAL DATA PROCESSING %%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % select a single line manually to check the LD
        fLineChoose=figure; axFig=axes('Parent',fLineChoose); imagesc(AFM_height_IO), axis equal, xlim tight, ylim tight, objInSecondMonitor(fLineChoose,idxMon)
        title('Select two points on the mask to analyze two different single fast scan lines','FontSize',16);
        idxLine=sort(selectRangeGInput(2,1,axFig));
        close(fLineChoose), clear fLineChoose        
        % Mask the Lateral Data with the mask obtained from height channel processing. 
        % GOAL: exclude FOREGROUND data to have BACKGROUND data for which perform the fitting so the original Lateral data can be adjusted
        % extract data (lateral deflection Trace + vertical deflection Trace)
        Lateral_Image_1_Raw   = (AFM_data(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_1_original);
        vertical_Trace  = (AFM_data(strcmpi([AFM_data.Channel_name],'Vertical Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_1_original);            
        Lateral_BK_1= Lateral_Image_1_Raw;
        Lateral_BK_1(AFM_height_IO==1)=NaN;        
        Lateral_FR_1 = Lateral_Image_1_Raw;
        Lateral_FR_1(AFM_height_IO==0)=NaN;
        %%%%---------------------%%%%%
        %%%%%------- plot -------%%%%%
        %%%%---------------------%%%%%
        titleData1="Raw Background Lateral Deflection";
        titleData2="Raw Lateral Deflection";    
        nameFig='resultA2_9_RawLateralData_BackgroundNoOutliers';
        showData(idxMon,false,Lateral_BK_1,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
            'extraData',{Lateral_Image_1_Raw},'extraTitles',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
        % check distribution of the LD data between FR and BK
        DataXdistribution= {Lateral_BK_1,'Raw BK'; ...
                            Lateral_FR_1,'Raw FR'};
        figDistr=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution);
        % show LD of a single fast scan line (idx manually selected previously)
        figSingleLine=plotSingleLineCheck(idxMon,Lateral_Image_1_Raw,idxLine,'mask',AFM_height_IO);
        
        clear Lateral_FR_1 titleData* nameFig   
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% PLANE FITTING ON LATERAL DEFLECTION BACKGROUND (masked LAT image) %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % For better fitting, remove outliers line by line before planeFit using the masked AFM data containing only background
        [~,Lateral_BK_1]=dynamicOutliersRemoval(Lateral_BK_1);        
        % obtain the planeFit and save fitting's metrics
        [correction_plane,metricsBestPlaneFit]=planeFitting_N_Order(Lateral_BK_1,limit);
        varargout{2}=metricsBestPlaneFit;
        % correct the raw original data by applyting the correction_plane
        Lateral_Image_2_planeFit = Lateral_Image_1_Raw - correction_plane;
        
        % prepare the new updated background data
        Lateral_BK_2= Lateral_Image_2_planeFit;
        Lateral_BK_2(AFM_height_IO==1)=NaN;
        Lateral_FR_2 = Lateral_Image_2_planeFit;
        Lateral_FR_2(AFM_height_IO==0)=NaN;        
        %%%%---------------------%%%%%
        %%%%%------- plot -------%%%%%
        %%%%---------------------%%%%%      
        titleData1='PlaneFit Background Lateral Deflection';
        titleData2={'Lateral Deflection'; 'After PlaneFit correction'};
        nameFig='resultA2_10_planeBKfit_LateralDeflectionCorr';    
        figTmp=showData(idxMon,true,correction_plane,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
            'extraData',{Lateral_Image_2_planeFit},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});    
        % check distribution of the LD data between FR and BK
        DataXdistribution= {Lateral_BK_2,'1st correction - PlaneFit BK'; ...
                            Lateral_FR_2,'1st correction - PlaneFit FR'};    
        figDistr=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution,'prevFig',figDistr,'idCall',2);
        % show LD of a single fast scan line (idx manually selected previously)
        figSingleLine=plotSingleLineCheck(idxMon,Lateral_Image_2_planeFit,idxLine,'prevFig',figSingleLine,'nameLine','1st correction - PlaneFit');
        
        clear Lateral_BK_1 Lateral_FR_2    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%% LINE-BY-LINE FITTING ON LATERAL DEFLECTION BACKGROUND (masked LAT image) %%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % fit lineXline, with the further line check in case the border parts of a line contains significant amount of no data (i.e. no BK but only FR) 
        % potentially bringing to wrong fit          
        answ=getValidAnswer('Continue with LineXLine fitting?','',{'Yes','No'});
        close(figTmp), clear figTmp                
        if ~answ
            noFitLine=true;
        else       
            % outliers removal in the background data
            [~,Lateral_BK_2]=dynamicOutliersRemoval(Lateral_BK_2);                 
            [baselineFit,metricsBestLineFit]=lineByLineFitting_N_Order(Lateral_BK_2,limit,'CheckBordersLine',true,'idxMon',idxMon);              
            % Remove background
            Lateral_Image_3_lineFit = Lateral_Image_2_planeFit - baselineFit;
            % Plot the fitted backround:               
            titleData1={'Lateral Deflection'; 'After PlaneFit correction'};
            titleData2={'Lateral Deflection'; 'After LineByLineFit correction'};
            figTmp=showData(idxMon,true,Lateral_Image_2_planeFit,titleData1,'','','normalized',norm,'labelBar',unitDataLabel,'saveFig',false, ...
                'extraData',{Lateral_Image_3_lineFit},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
            % plot distribution and lineAnalysis
            Lateral_Trace_corrLine_BK_2= Lateral_Image_3_lineFit;
            Lateral_Trace_corrLine_BK_2(AFM_height_IO==1)=NaN;
            % check distribution of the LD data
            Lateral_Trace_corrLine_FR_2 = Lateral_Image_3_lineFit;
            Lateral_Trace_corrLine_FR_2(AFM_height_IO==0)=NaN;
            DataXdistribution= {Lateral_Trace_corrLine_BK_2,'2nd correction - LineXLineFit BK'; ...
                                Lateral_Trace_corrLine_FR_2,'2nd correction - LineXLineFit FR'};
            figDistrTmp=checkDistributionDataLD(SeeMe,idxMon,DataXdistribution,'prevFig',figDistr,'idCall',3);        
            figSingleLineTmp=plotSingleLineCheck(idxMon,Lateral_Image_3_lineFit,idxLine,'prevFig',figSingleLine,'nameLine','2nd correction - LineXLineFit');
            pause(1)
            answ=getValidAnswer('Satisfied of the fitting? If not, keep the original and skip to the next part.','',{'y','n'});
            close(figTmp)
            if answ
                varargout{3}=metricsBestLineFit;  
                % take the definitive last figures
                figDistr=figDistrTmp;
                figSingleLine=figSingleLineTmp;
                titleData1='Line x Line Fitted Background'; titleData2={"Lateral Deflection - Trace";"Plane+LineByLine Fitted"};
                nameFig='resultA2_11_LineBKfit_LateralDeflection';
                showData(idxMon,false,baselineFit,titleData1,newFolder,nameFig,'normalized',norm,'labelBar',unitDataLabel, ...
                    'extraData',{Lateral_Image_3_lineFit},'extraTitle',{titleData2},'extraNorm',{norm},'extraLabel',{unitDataLabel});
                noFitLine=false;
            else
                noFitLine=true;            
            end            
        end
        if noFitLine
            varargout{3}="LineByLine Fitting not available (user skipped or refused this step)";
            Lateral_Image_3_lineFit=Lateral_Image_2_planeFit;
        end
        % Finalise the distribution and signleLineAnalysis figures
        % adjust xlim, especially show the 99.5 percentile of the data in the distribution
        ax = findobj(figDistr, 'Type', 'Axes');           % find axes inside the figure
        hList = findobj(ax, 'Type', 'Histogram');         % locate the histograms
        % since there more than one histogram, store the data in cell array
        allData = cell2mat(arrayfun(@(h) h.Data(:), hList, 'UniformOutput', false));
        pLow = prctile(allData, 1);
        pHigh = prctile(allData, 99.5);
        xlim(ax, [min(allData)-abs(pLow), pHigh]); ylim(ax,"padded");
        clear allData pLow pHigh ax hList
        % save distribution and singleLine
        nameResults='resultA2_12_DistributionLD_eachCorrectionStep';
        saveFigures_FigAndTiff(figDistr,newFolder,nameResults)
        nameResults='resultA2_13_singleFastScanLineLD_eachCorrectionStep';
        saveFigures_FigAndTiff(figSingleLine,newFolder,nameResults)
        close all
        clear nameResults titleData* noFitLine
        save(fullfile(newFolder,'TMP_DATA_3_LATERAL_PART'),"Lateral_Image_3_lineFit","idxLine",'vertical_Trace')
    else
        load(fullfile(newFolder,'TMP_DATA_3_LATERAL_PART.mat'),'Lateral_Image_3_lineFit','idxLine','vertical_Trace')
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%--------- CONVERSION LATERAL DEFLECTIO [V] ==> LATERAL FORCE [N] ---------%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % choose friction coefficients depending on the case (experimental results done in another moment), or manually put the value
    question=sprintf('Which background friction coefficient use?');
    options={ ...
        sprintf('1) TRCDA (air) = 0.3040'), ...
        sprintf('2) PCDA  (air)  = 0.2626'), ... 
        sprintf('3) TRCDA-DMPC (air) = 0.1305'), ...
        sprintf('4) TRCDA-DOPC (air) = 0.1650'), ...
        sprintf('5) TRCDA-POPC (air) = 0.1250'), ...
        sprintf('6) Enter manually a value'),...
        sprintf('7) Extract the fc from the same scan area with HV mode off')};
    choice = getValidAnswer(question, '', options);
    
    while true
        switch choice
            case 1, avg_fc = 0.3040;
            case 2, avg_fc = 0.2626;
            case 3, avg_fc = 0.1305;
            case 4, avg_fc = 0.1650;
            case 5, avg_fc = 0.1250;                     
            case 6
                while true
                    avg_fc = str2double(inputdlg('Enter a value for the glass fricction coefficient','',[1 50]));
                    if any(isnan(avg_fc)) || avg_fc <= 0 || avg_fc >= 1
                        questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                    else
                        break
                    end
                end
            case 7
                if ~exist(fullfile(mainPath,'HoverMode_OFF'),"dir")
                    error('The directory HoverMode_OFF doesn''t exist. Select another option')
                end
                [avg_fc,FitOrderHVOFF_Height] = A2_feature_2_1_FrictionCalcFromSameScanHVOFF(idxMon,mainPath,flagSingleSectionProcess,'idxSectionHVon',idxSectionHVon,'FitOrderHVOFF_Height',FitOrderHVOFF_Height);
                if isempty(avg_fc)
                    fprintf('For some reasons, the scan in HoverMode OFF is messed up. Choose a standard value if possible')
                    continue
                end
        end
        break
    end
    clear choice question options wb   
    % Friction force = friction coefficient * Normal Force
    Baseline_Friction_Force= vertical_Trace*avg_fc;
    figSingleLineForce=plotSingleLineCheck(idxMon,Baseline_Friction_Force*1e9,idxLine,'mask',AFM_height_IO,'typeData','force','nameLine','OFFSET (VD*fc)');
    
    % Friction force = calibration coefficient * Lateral Trace (V)
    Lateral_Trace_Force= Lateral_Image_3_lineFit*alpha;
    figSingleLineForce=plotSingleLineCheck(idxMon,Lateral_Trace_Force*1e9,idxLine,'prevFig',figSingleLineForce,'nameLine','F=Deflection*Alpha');
    
    % To read the baseline friction, to obtain the processed image:
    Corrected_LD_Trace= Lateral_Trace_Force + Baseline_Friction_Force;
    figSingleLineForce=plotSingleLineCheck(idxMon,Corrected_LD_Trace*1e9,idxLine,'prevFig',figSingleLineForce,'nameLine','Corrected Force (F+OFFSET)');   
    
    % save results force
    nameFig='resultA2_14_singleFastScanLineLD_FORCE';
    saveFigures_FigAndTiff(figSingleLineForce,newFolder,nameFig)

    % plot the definitive corrected lateral force
    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA2_15_ResultsDefinitiveLateralDeflectionsNewton_normalized';
    showData(idxMon,SeeMe,Corrected_LD_Trace,titleData,newFolder,nameFig,'normalized',true)

    titleData='Fitted and corrected Lateral Force';
    nameFig='resultA2_16_ResultsDefinitiveLateralDeflectionsNewton';
    labelFig='Force [nN]';
    showData(idxMon,SeeMe,Corrected_LD_Trace*1e9,titleData,newFolder,nameFig,'labelBar',labelFig)

    % save the corrected lateral force into cropped AFM image
    AFM_Elab=AFM_data;    
    AFM_Elab(strcmpi([AFM_data.Channel_name],'Lateral Deflection') & strcmpi([AFM_data.Trace_type],'Trace')).AFM_images_2_PostProcessed=Corrected_LD_Trace;
    varargout{1}=AFM_Elab; 
    varargout{4}=FitOrderHVON_Lat;
    varargout{5}=FitOrderHVOFF_Height;
    varargout{6}=avg_fc;
end


%%%%%%%%%%%%%%%%%%%%%
%%%%% FUNCTIONS %%%%%
%%%%%%%%%%%%%%%%%%%%%
function updatePatches(ax)
    % Find all patches inside this axes
    patches = findall(ax, 'Type', 'patch');
    if isempty(patches), return; end    
    % Get the new updated y-limits
    yl = ylim(ax);
    ymin = yl(1);
    ymax = yl(2);
    % Update patch YData to fill the whole axis height
    for p = patches'
        p.YData = [ymin ymin ymax ymax];
    end
end

function figDistr=checkDistributionDataLD(SeeMe,idxMon,Data,varargin)
    p=inputParser();
    argName = 'prevFig';    defaultVal = [];   addOptional(p,argName,defaultVal);   
    argName = 'idCall';     defaultVal = 1;    addOptional(p,argName,defaultVal);   
    parse(p,varargin{:});
    if isempty(p.Results.prevFig)
        if SeeMe
            figDistr=figure('Visible','on'); 
        else
            figDistr=figure('Visible','off'); 
        end
        % adjust pic
        legend('FontSize',15), grid on, grid minor
        xlabel('Lateral Deflection [V]','FontSize',15)
        title("Distribution Lateral Deflection and minimum values","FontSize",20)
        subtitle("(99.5 percentile of the entire data)","FontSize",15)
        objInSecondMonitor(figDistr,idxMon);        
        pause(1)        
    else
        figDistr=p.Results.prevFig;
        figure(figDistr)              
    end
    idCall=p.Results.idCall;
    ax = findall(figDistr, 'type', 'axes');    
    hold(ax,"on")
    % extract the data
    DataBK=Data{1,1}; DataBK=DataBK(~isnan(DataBK)); NameBK=Data{1,2};
    DataFR=Data{2,1}; DataFR=DataFR(~isnan(DataFR)); NameFR=Data{2,2};
    % prepare histogram. round not work to excess but to nearest.
    xmin=floor(min(min(DataBK(:)),min(DataFR(:))) * 1000) / 1000;
    xmax=ceil( max(max(DataBK(:)),max(DataFR(:))) * 1000) / 1000;
    edges=(xmin:0.01:xmax);

    % show the original LD of BK
    DataCleaned_BK=DataBK(:); DataCleaned_BK(~isnan(DataCleaned_BK));
    histogram(ax,DataCleaned_BK,'BinEdges',edges,"DisplayName",NameBK)
    % show the original LD of FR
    DataCleaned_FR=DataFR(:); DataCleaned_FR(~isnan(DataCleaned_FR));
    histogram(ax,DataCleaned_FR,'BinEdges',edges,"DisplayName",NameFR)
    % check the abs min
    absMinBK=min(DataCleaned_BK);
    % check the min in corrispondence of 1 percentile
    percentile=1;      
    threshold = prctile(DataCleaned_BK, percentile);
    % show vertical line of different min BK
    xline(ax,absMinBK,':','LineWidth',1.5,     'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min BK:       %.2e',absMinBK))
    xline(ax,threshold,'--','LineWidth',1.5,   'Color',globalColor(idCall),'DisplayName',sprintf('Min 1 percentile BK:   %.2e',threshold))        
    % show vertical line of min FR
    absMinFR=min(DataCleaned_FR);
    xline(ax,absMinFR,'.-','LineWidth',1.5,    'Color',globalColor(idCall),'DisplayName',sprintf('Absolute Min FR:       %.2e',absMinFR))
    pause(2)
end

function figSingleLine=plotSingleLineCheck(idxMon,data,idxLine,varargin)
    p=inputParser();
    argName = 'prevFig';        defaultVal = [];         addOptional(p,argName,defaultVal);
    argName = 'typeData';       defaultVal = 'voltage';  addOptional(p,argName,defaultVal,@(x) ismember(x,{'voltage','force'}));  
    argName = 'nameLine';       defaultVal = '';         addOptional(p,argName,defaultVal);  
    argName = 'mask';           defaultVal = [];         addOptional(p,argName,defaultVal);
    parse(p,varargin{:});
    clearvars argName defaultVal
    numberLines=length(idxLine);  
    nameLine=p.Results.nameLine;
    if isempty(p.Results.prevFig)        
        AFM_height_IO=p.Results.mask;     
        x = 1:size(AFM_height_IO,1);
        % prepare the main fig
        figSingleLine=figure('Name','Fast Scan Lines Analysis'); % dont hide, it can be useful in deciding if perform lineXline fitting
        tiledlayout(figSingleLine,numberLines,1,'TileSpacing','compact'); % create n rows to show separately different lines
        objInSecondMonitor(figSingleLine,idxMon);
        if strcmp(p.Results.typeData,'voltage')
            ylabeltext='Lateral Deflection [V]';
            nameLine='Raw LD';
            typeData='';
        else
            ylabeltext='Force [nN]';   
            typeData='(FORCE) ';
        end
        %%%%%%----------------------------------
        %%%%%% start the line plottings %%%%%%%%
        %%%%%%----------------------------------
        for i=1:numberLines
            y = data(:,idxLine(i));
            % identify the masked regions so they can be easily recognised
            y_mask=AFM_height_IO(:,idxLine(i));            
            % prepare the subfig
            currLine=nexttile; cla(currLine);                            
            hold(currLine,"on")       
            % set limits for transparent rects
            ymin = min(0,min(y) - round(0.1*range(y)));
            ymax = max(1,max(y) + round(0.1*range(y)));
            xmin = min(x) - round(0.05*range(x));
            xmax = max(x) + round(0.05*range(x));
            % Find contiguous regions with same value in the mask (find changes)
            LD_mask_diff = [true; diff(y_mask(:)) ~= 0; true];
            idx_edges = find(LD_mask_diff);
            segments = [idx_edges(1:end-1), idx_edges(2:end)-1];
            % color region for each found segment
            for j = 1:size(segments,1)
                idx_start = segments(j,1);
                idx_end = segments(j,2);
                col = y_mask(idx_start);  % 0 o 1                
                if col == 1
                    c = [0 0 1];  % blue
                    typeIO='Foreground';
                else
                    c = [1 0 0];  % red
                    typeIO='Background';
                end        
                % create rectangules on the plot to distinguish BF from FR
                xPatch = [x(idx_start) x(idx_end) x(idx_end) x(idx_start)];
                yPatch = [ymin ymin ymax ymax];
                f=fill(currLine,xPatch, yPatch, c, 'FaceAlpha', 0.2, 'EdgeColor', 'none','DisplayName',typeIO);
                if j~=1 && j~=2 
                    f.Annotation.LegendInformation.IconDisplayStyle = 'off';
                end
            end
            plot(currLine,y,'DisplayName',nameLine,'LineWidth',1.5)  
            % adjust pic
            title(currLine,sprintf("%sFast scan line #%d",typeData,idxLine(i)), 'FontSize',15);
            legend(currLine,'FontSize',11),
            grid on, grid minor 
            xlabel(currLine,'Fast scan line [pixel]','FontSize',10)
            ylabel(currLine,ylabeltext,'FontSize',10)
            xlim(currLine,[xmin xmax]);
            ylim(currLine,[ymin ymax]);
            hold(currLine,"off") 
        end        
    else
        % take the existing fig and find all axes inside
        figSingleLine=p.Results.prevFig;
        figure(figSingleLine)    
        axAll = findall(figSingleLine, 'type', 'axes');
        % Sort up-to-bottom
        [~, idx] = sort(arrayfun(@(ax) ax.Position(2), axAll),'descend');
        axAll = axAll(idx);        
        for i=1:numberLines
            y=data(:,idxLine(i));
            axSelected=axAll(i);
            axes(axSelected) %#ok<LAXES>
            hold(axSelected, 'on');        
            plot(axSelected,y,'DisplayName',nameLine,'LineWidth',1.5)
 
            % Autoscale based only on line objects (exclude patches)
            lines = findall(axSelected, 'Type', 'line');
            if ~isempty(lines)
                allY = get(lines, 'YData');
                allY = cell2mat(allY(:));
                ymin = min(allY(:));
                ymax = max(allY(:));
                pad = 0.1 * (ymax - ymin);
                if pad == 0, pad = 1; end  % avoid zero-range issues
                new_ylim = [ymin-pad, ymax+pad];
            else
                new_ylim = ylim(axSelected); % fallback
            end
            % Freeze the limits
            ylim(axSelected, new_ylim);
            set(axSelected, 'YLimMode', 'manual');            
            % Recompute patch heights based on new limits
            updatePatches(axSelected);
            hold(axSelected, 'off');
        end
    end
    pause(2)
end


