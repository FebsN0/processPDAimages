% Function to remove unnecessary AFM channels and leave only LD, VD and height TRACE. No RETRACE because of HOVER MODE!
%
% Author updates: Altieri F.
% University of Tokyo
% 
% Last update 26.August.2024
% 
% 
% INPUT: OUTPUT of A1_open_JPK (single struct data)

function [varargout]=A1_feature_CleanOrPrepFiguresRawData(data,varargin)
           
    %init instance of inputParser
    p=inputParser();
    addRequired(p, 'data', @(x) isstruct(x));
    argName = 'idxMon';         defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'folderSaveFig';  defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'cleanOnly';      defaultVal = false;     addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'SeeMe';          defaultVal = false;     addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'imageType';      defaultVal = 'Entire';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';  defaultVal = false;     addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    argName = 'metadata';       defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'postProcessed';  defaultVal = false;     addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    % validate and parse the inputs
    parse(p,data,varargin{:});

    if p.Results.cleanOnly
        cleanOnly=1;
    else
        cleanOnly=0;
        if p.Results.SeeMe, SeeMe=1; else, SeeMe=0; end       
        idxMon=p.Results.idxMon;
        folderSaveFig=p.Results.folderSaveFig;
        imageType=p.Results.imageType;
        if p.Results.Normalization; norm=1; else, norm=0; end
        if ~strcmp(imageType,"SingleSection")
            metadata=p.Results.metadata;        
        end
        if p.Results.postProcessed
            flagPostProcessed=true;
            textTypeData='PostProcessed';
            stepProcess='2';            
        else
            flagPostProcessed=false;
            stepProcess='1';
            textTypeData='Raw';
        end
    end
    clearvars argName defaultVal p

    if cleanOnly
        % Check if the data struct has exactly the specific fields and 5 or 10 rows (removed not useful data)
        fieldNames=fieldnames(data);
        for j=1:length(fieldnames(data))
            if ~((strcmpi(fieldNames{j},'Channel_name') || strcmpi(fieldNames{j},'Trace_type') ||  strcmpi(fieldNames{j},'Signal_type') || ...
                strcmpi(fieldNames{j},'Raw_afm_image') || strcmpi(fieldNames{j},'Scale_factor') || ...
                strcmpi(fieldNames{j},'Offset') || strcmpi(fieldNames{j},'AFM_image')) && (size(data, 2) == 5 || size(data, 2) == 10))       % first call there are 10 fields. After only 5 are left
                error('Invalid Input!');
            end
        end   
        %find only those rows of interest (trace: latDefle, Height and vertDefle, retrace: latDefle, vertDefle)
        traceMask=strcmpi([data.Trace_type],'Trace');
        channelMask1= strcmpi([data.Channel_name],'Height (measured)');
        channelMask2= strcmpi([data.Channel_name],'Vertical Deflection');
        channelMask3= strcmpi([data.Channel_name],'Lateral Deflection');
        defMask= (traceMask & channelMask1) | channelMask2 | channelMask3;
        varargout{1} = data(defMask);
    else
    % in case of the second call function, when the data is cleaned. In the specific case of more sections, the following
    % part assumes they already assembled. The following part does nothing to the data but solely extract them to make figures.
    % If savFig is false, then not save. However, vertical distribution is always plotted regardless the saveFig result.
    % Therefore, the following line is outside the figure processing        
        allTitles={sprintf('Height (measured) channel (%s - %s)',textTypeData,imageType)};
        allNameFig={sprintf('resultA%s_1_%s_HeightChannel_%s',stepProcess,textTypeData,imageType)};
        allLabelBar={sprintf('Height [nm]')};
        if flagPostProcessed    
            fieldToUse="AFM_images_2_PostProcessed";
            blockAllData=cell(1,5); % height + vertForce_avg + LF_tr + LF_rt + LF_maxPixel
            AFM_height_IO=data(strcmp([data.Channel_name],'Height (measured)')).AFMmask_heightIO;
            % take height channel
            data_Height=data(strcmp([data.Channel_name],'Height (measured)')).(fieldToUse);
            blockAllData{1}=data_Height;
            % take vertical channel
            blockAllData{2}=data(strcmp([data.Channel_name],'Vertical Force')).(fieldToUse);
            allTitles{2}=sprintf('Vertical Force PostProcessed (%s - %s)',textTypeData,imageType);
            allNameFig{2}=sprintf('resultA%s_2_%s_VertForcePostProcessed_%s',stepProcess,textTypeData,imageType);
            allLabelBar{2}='Force [nN]';
            % take force trace channel
            blockAllData{3}=data(strcmp([data.Channel_name],'Lateral Force') & strcmp([data.Trace_type],'Trace')).(fieldToUse);
            allTitles{3}=sprintf('Lateral Force Trace PostProcessed (%s - %s)',textTypeData,imageType);
            allNameFig{3}=sprintf('resultA%s_3_%s_LatForcePostProcessed_%s',stepProcess,textTypeData,imageType);
            allLabelBar{3}='Force [nN]';
            % take force retrace channel
            blockAllData{4}=data(strcmp([data.Channel_name],'Lateral Force') & strcmp([data.Trace_type],'ReTrace')).(fieldToUse);
            allTitles{4}=sprintf('Lateral Force ReTrace PostProcessed (%s - %s)',textTypeData,imageType);
            allNameFig{4}=sprintf('resultA%s_4_%s_LatForcePostProcessed_%s',stepProcess,textTypeData,imageType);
            allLabelBar{4}='Force [nN]';
            % take force maxPixel channel
            blockAllData{5}=data(strcmp([data.Channel_name],'Lateral Force') & strcmp([data.Trace_type],'MaxPixelValue')).(fieldToUse);
            allTitles{5}=sprintf('Lateral Force MaxPixelValue PostProcessed (%s - %s)',textTypeData,imageType);
            allNameFig{5}=sprintf('resultA%s_5_%s_LatForcePostProcessed_%s',stepProcess,textTypeData,imageType);
            allLabelBar{5}='Force [nN]';
            factor=[1e9,1,1,1,1,1,1];
        else
            fieldToUse='AFM_images_1_original';                        
            data_Height=    data(strcmp([data.Channel_name],'Height (measured)')).(fieldToUse);            
            % VD trace
            data_VD_trace=  data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'Trace')).(fieldToUse);
            allTitles{2}=sprintf('Vertical Deflection trace channel (%s - %s)',textTypeData,imageType);
            allNameFig{2}=sprintf('resultA%s_2_%s_VDChannel_trace_%s',stepProcess,textTypeData,imageType);
            allLabelBar{2}='Force [nN]';
            % VD retrace
            data_VD_retrace=data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'ReTrace')).(fieldToUse);
            allTitles{3}=sprintf('Vertical Deflection Retrace channel (%s - %s)',textTypeData,imageType);
            allNameFig{3}=sprintf('resultA%s_3_%s_VDChannel_retrace_%s',stepProcess,textTypeData,imageType);
            allLabelBar{3}='Force [nN]';
            % LD trace
            data_LD_trace=  data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'Trace')).(fieldToUse);            
            allTitles{4}=sprintf('Lateral Deflection Trace channel (%s - %s)',textTypeData,imageType);
            allNameFig{4}=sprintf('resultA%s_4_%s_LDChannel_trace_%s',stepProcess,textTypeData,imageType);
            allLabelBar{4}='Voltage [V]';  
            % LD retrace 
            data_LD_retrace=data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'ReTrace')).(fieldToUse);
            allTitles{5}=sprintf('Lateral Deflection ReTrace channel (%s - %s)',textTypeData,imageType);
            allNameFig{5}=sprintf('resultA%s_5_%s_LDChannel_retrace_%s',stepProcess,textTypeData,imageType);
            allLabelBar{5}='Voltage [V]';
            % prepare the block
            blockAllData={data_Height,data_VD_trace,data_VD_retrace,data_LD_trace,data_LD_retrace};
            factor=[1e9,1e9,1e9,1,1];                       
        end           
        clear fieldToUse
        % show results
        for i=1:length(blockAllData)
            data_tmp=blockAllData{i}*factor(i);
            showData(idxMon,SeeMe,data_tmp,allTitles{i},folderSaveFig,allNameFig{i},'normalized',norm,'labelBar',allLabelBar{i});
        end         
        %%%%% perform the following step ONLY after assembly %%%%%
        if ~strcmp(imageType,"SingleSection")
            if ~flagPostProcessed
                % perform the plotting VD distribution and baseline trend only once
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% VERTICAL FORCES DISTRIBUTION %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % If good, it should coincide approximately with the setpoint
                data=data_VD_trace*1e9;
                colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};
                if SeeMe
                    f_VDdistribution=figure('Visible','on');
                else
                    f_VDdistribution=figure('Visible','off');
                end
                axes1 = axes('Parent',f_VDdistribution);
                hold(axes1,'on');
                % EXTRACT ALL DATA
                % why flip? because the data has previously been flipped to coindide with the Fluorescence imaging. So
                % needed to flip also the setpoint vector (left high - right low)
                setpoints=metadata.SetP_N;
                % in case the setpoints of all sections are the same (like in case of postHeat data), treat the sections as single "big section"
                if all(setpoints==setpoints(1))
                    numSetpoints=1; 
                else
                    setpoints=flip(setpoints); numSetpoints=length(setpoints);
                end
                % init
                setN=cell(1,numSetpoints); avgN=cell(1,numSetpoints); h=cell(1,numSetpoints);
                vertForceAVG=zeros(1,numSetpoints);
                % plot lines indicating theoretical setpoint
                for i=1:numSetpoints                    
                    if numSetpoints==1
                        textLabel_setP='Setpoint';
                    else
                        textLabel_setP=sprintf('Setpoint section %d',i);
                    end
                    setN{i}=xline(axes1,setpoints(i)*1e9,'LineWidth',4,'DisplayName',textLabel_setP,'Color',colors{i});
                end
                % plot distribution and average of distribution
                for i=1:numSetpoints          
                    if numSetpoints==1
                        startSection=1;
                        endSection=metadata.y_scan_pixels(2,end);
                        textLabel_avg ='avg vertical force';
                        textLabel_raw='raw vertical force';
                    else
                        startSection=metadata.y_scan_pixels(1,i);
                        endSection=metadata.y_scan_pixels(2,i);
                        textLabel_avg =sprintf('avg vertical force section %d',i);
                        textLabel_raw=sprintf('raw vertical force section %d',i);
                    end
                    % extract the vertical force data. Although this step could be made before the assembly, I
                    % found optimal put here so it can be made even in case of single entire scan
                    verticalForceSingleSection= data(:,startSection:endSection);
                    % exclude 99.9 percentile and 0.1 for better visual
                    th=prctile(verticalForceSingleSection(:),99.9);
                    verticalForceSingleSection(verticalForceSingleSection>th)=NaN;
                    th=prctile(verticalForceSingleSection(:),0.1);
                    verticalForceSingleSection(verticalForceSingleSection<th)=NaN;
                    vertForceAVG(i)=mean(mean(verticalForceSingleSection),'omitnan');
                    avgN{i}=xline(axes1,vertForceAVG(i),'--','LineWidth',2,'DisplayName',textLabel_avg,'Color',colors{i});
                    h{i}=histogram(axes1,verticalForceSingleSection,200,'DisplayName',textLabel_raw,'FaceColor',colors{i},'Normalization','pdf');
                end
                legend1 = legend('FontSize',15);
                set(legend1,'Location','bestoutside'); ylim padded                
                title('Distribution Raw Vertical Forces','FontSize',18), xlabel('Force [nN]','FontSize',15)
                objInSecondMonitor(f_VDdistribution,idxMon);
                saveFigures_FigAndTiff(f_VDdistribution,folderSaveFig,'resultA1_6_distributionRawVerticalForces')
                vertForceAVG=unique(round(vertForceAVG));
                if length(vertForceAVG)~=numSetpoints
                    warndlg('Number of rounded vertical forces is less than number of setpoint!')
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%
                %%% BASELINE TREND PLOT %%%
                %%%%%%%%%%%%%%%%%%%%%%%%%%%            
                totTimeScan = (metadata.x_scan_pixels/metadata.Scan_Rate_Hz)/60;
                numSetpoints=length(setpoints);
                totTimeSection = totTimeScan/numSetpoints;
                if SeeMe
                    f_baselineTrend=figure('Visible','on');
                else
                    f_baselineTrend=figure('Visible','off');
                end
                axes1=axes('Parent',f_baselineTrend);
                % we dont have the baseline info at the end of the scan. It is saved only in the baseline.txt file
                arrayTime=0:totTimeSection:totTimeScan-totTimeSection;
                baselineN=metadata.Baseline_N*1e9;
                if length(baselineN) > 1
                    if abs(baselineN(2) - baselineN(1)) > 10 
                        warning('\n\tThe baseline of the first section varies by more than 10nN from the first one!!\n\tThe current scan is not really realiable... ')
                    end
                    plot(axes1,arrayTime,metadata.Baseline_N*1e9,'-*','LineWidth',2,'MarkerSize',15,'MarkerEdgeColor','red')
                    title(axes1,'Baseline Trend among the sections','FontSize',18)
                    ylabel(axes1,'Baseline shift [nN]','FontSize',15), xlabel(axes1,'Time [min]','FontSize',15), grid on, grid minor
                    objInSecondMonitor(f_baselineTrend,idxMon);
                    saveFigures_FigAndTiff(f_baselineTrend,folderSaveFig,'resultA1_7_baselineTrend')   
                else
                    warning('\n\tPlotting the baseline trend is not possible because only one baseline value is stored in the metadata (Scan = Section)')
                end
            else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%% HEIGHT DISTRIBUTION POST PROCESSING %%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Once the postProcessing is done, masking the height is now possible, therefore, better distinction between Foreground and Background.
                if SeeMe
                    f_heightDistribution=figure('Visible','on');
                else
                    f_heightDistribution=figure('Visible','off');
                end
                H_BK=data_Height(AFM_height_IO==0);
                H_FR=data_Height(AFM_height_IO==1);    
                % outliers removal
                H_BK = H_BK(~isnan(H_BK))*1e9;
                H_FR = H_FR(~isnan(H_FR))*1e9;
                edgesBK=min(H_BK):2:max(H_BK);
                edgesPDA=min(H_FR):2:max(H_FR);
                hold on    
                histogram(H_BK,edgesBK,'DisplayName','Background Height','Normalization','percentage');
                histogram(H_FR,edgesPDA,'DisplayName','Foreground Height','Normalization','percentage');
                legend('FontSize',15)
                xlabel(sprintf('Feature height [nm]'),'FontSize',15), ylabel('Percentage %','FontSize',15), grid minor, grid on
                title("Distribution PostProcessed Height",'FontSize',20)
                objInSecondMonitor(f_heightDistribution,idxMon);     
                saveFigures_FigAndTiff(f_heightDistribution,folderSaveFig,'resultA2_9_OptHeightDistribution_FR_BK')
                % Since now there is the assembled mask
                titleData='Final Binary AFM IO Image';
                nameFig='resultA2_8_finalMask';
                showData(idxMon,SeeMe,AFM_height_IO,titleData,folderSaveFig,nameFig,'binary',true);                

                % DISTRIBUTION OF FORCE AFTER CLEARING
                % mask the data, take only FR 
                force_masked_trace=blockAllData{3};
                force_masked_trace(~AFM_height_IO)=nan;
                force_masked_retrace=blockAllData{4};
                force_masked_retrace(~AFM_height_IO)=nan;
                force_masked_maxPixelValue=blockAllData{5};
                force_masked_maxPixelValue(~AFM_height_IO)=nan;
                % adjust xlim
                allDataHistog=[blockAllData{3}(:);blockAllData{4}(:)];
                pLow = prctile(allDataHistog, .5);
                pHigh = prctile(allDataHistog, 99.5);    
                figForceDist=figure(Visible="off");
                for i=1:2
                    ax = nexttile;
                    hold(ax, 'on'); 
                    if i==1
                        % take only all datapoint
                        vect_f_tr=blockAllData{3}(:);
                        vect_f_rt=blockAllData{4}(:);  
                        vect_f_maxV=blockAllData{5}(:);
                    else           
                        % exclude nan
                        vect_f_tr=force_masked_trace(:);
                        vect_f_rt=force_masked_retrace(:);
                        vect_f_maxV=force_masked_maxPixelValue(:);
                    end
                    vect_f_tr=vect_f_tr(~isnan(vect_f_tr));
                    vect_f_rt=vect_f_rt(~isnan(vect_f_rt));   
                    vect_f_maxV=vect_f_maxV(~isnan(vect_f_maxV));
                    [f_tr, xi_tr] = ksdensity(vect_f_tr);
                    [f_rt, xi_rt] = ksdensity(vect_f_rt); 
                    [f_mV, xi_mV] = ksdensity(vect_f_maxV); 
                    fill_between(ax, xi_tr, f_tr, globalColor(1), 0.25);     
                    fill_between(ax, xi_rt, f_rt, globalColor(2), 0.25);
                    fill_between(ax, xi_mV, f_mV, globalColor(3), 0.25); 
                    plot(ax, xi_tr,     f_tr,    '-', 'Color', globalColor(1), 'LineWidth', 2.0, 'DisplayName', 'Force-Trace');
                    plot(ax, xi_rt,     f_rt,    '-', 'Color', globalColor(2), 'LineWidth', 2.0, 'DisplayName', 'Force-ReTrace');
                    plot(ax, xi_mV,     f_mV,    '--', 'Color', globalColor(3), 'LineWidth', 1.0, 'DisplayName', 'Force-ReTrace');
                    % Mean/median lines
                    med_tr  = median(vect_f_tr);
                    med_rt  = median(vect_f_rt);
                    med_mV  = median(vect_f_maxV);
                    plot(ax, [med_tr  med_tr],  [0 max(f_tr)],  ':', 'Color', globalColor(1), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_tr));
                    plot(ax, [med_rt  med_rt],  [0 max(f_rt)],  ':', 'Color', globalColor(2), 'LineWidth', 2,'DisplayName',sprintf('Median: %.3g nN',med_rt));            
                    plot(ax, [med_mV  med_mV],  [0 max(f_mV)],  ':', 'Color', globalColor(3), 'LineWidth', 1,'DisplayName',sprintf('Median: %.3g nN',med_mV));            
                    legend(ax, 'AutoUpdate','off','EdgeColor',[0.3 0.3 0.3], 'Location','northeast','FontSize',14);
                    xlim(ax, [pLow, pHigh]);
                    xlabel(ax,"Lateral Force (nN)","FontSize",14),ylabel(ax,"KDE","FontSize",14)
                    if i==1
                        title(ax, 'KDE distributions of Lateral Force (full data)','FontSize', 16); grid(ax,"on")
                    else
                        title(ax, 'KDE distributions of Lateral Force (FR-only)','FontSize', 16); grid(ax,"on")
                    end
                end
                objInSecondMonitor(figForceDist,idxMon)
                nameFig="resultA2_10_LateralForce_KDEcomparisons";
                saveFigures_FigAndTiff(figForceDist,folderSaveFig,nameFig)
            end
        end
    end
end   