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
    argName = 'AFM_IO';         defaultVal = [];        addParameter(p,argName,defaultVal, @(x) ismatrix(x));
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
            stepProcess='2_end';
            AFM_height_IO=p.Results.AFM_IO;
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
        
        if flagPostProcessed
            fieldToUse='AFM_images_2_PostProcessed';
        else
            fieldToUse='AFM_images_1_original';
        end
        
        data_VD_trace=  data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'Trace')).(fieldToUse);
        data_Height=    data(strcmp([data.Channel_name],'Height (measured)')).(fieldToUse);
        data_LD_trace=  data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'Trace')).(fieldToUse);
        data_LD_retrace=data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'ReTrace')).(fieldToUse);
        data_VD_retrace=data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'ReTrace')).(fieldToUse);        
        % start to show the data
        data=data_Height*1e9;
        titleData=sprintf('Height (measured) channel (%s - %s)',textTypeData,imageType);
        nameFig=sprintf('resultA%s_%s_1_HeightChannel_%s',stepProcess,textTypeData,imageType);
        labelBar=sprintf('Height (nm)');
        showData(idxMon,SeeMe,data,titleData,folderSaveFig,nameFig,'normalized',norm,'labelBar',labelBar);
        % Lateral Deflection Trace
        data=data_LD_trace;
        titleData=sprintf('Lateral Deflection Trace channel (%s - %s)',textTypeData,imageType);
        nameFig=sprintf('resultA%s_%s_2_LDChannel_trace_%s',stepProcess,textTypeData,imageType);
        labelBar='Voltage [V]';
        showData(idxMon,SeeMe,data,titleData,folderSaveFig,nameFig,'normalized',norm,'labelBar',labelBar);
        % Lateral Deflection ReTrace
        data=data_LD_retrace;
        titleData=sprintf('Lateral Deflection Retrace channel (%s - %s)',textTypeData,imageType);
        nameFig=sprintf('resultA%s_%s_3_LDChannel_retrace_%s',stepProcess,textTypeData,imageType);
        showData(idxMon,SeeMe,data,titleData,folderSaveFig,nameFig,'normalized',norm,'labelBar',labelBar);
        % Vertical Deflection trace
        data=data_VD_trace*1e9;
        titleData=sprintf('Vertical Deflection trace channel (%s - %s)',textTypeData,imageType);
        nameFig=sprintf('resultA%s_%s_4_VDChannel_trace_%s',stepProcess,textTypeData,imageType);
        labelBar='Force [nN]';
        showData(idxMon,SeeMe,data,titleData,folderSaveFig,nameFig,'normalized',norm,'labelBar',labelBar);
        % Vertical Deflection Retrace
        data=data_VD_retrace*1e9;
        titleData=sprintf('Vertical Deflection retrace channel (%s - %s)',textTypeData,imageType);
        nameFig=sprintf('resultA%s_%s_5_VDChannel_retrace_%s',stepProcess,textTypeData,imageType);
        showData(idxMon,SeeMe,data,titleData,folderSaveFig,nameFig,'normalized',norm,'labelBar',labelBar);          
        
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
                setpoints=flip(setpoints); numSetpoints=length(setpoints); 
                setN=cell(1,numSetpoints); avgN=cell(1,numSetpoints); h=cell(1,numSetpoints);
                for i=1:numSetpoints
                    % plot lines of setpoint
                    setN{i}=xline(axes1,setpoints(i)*1e9,'LineWidth',4,'DisplayName',sprintf('setpoint section %d',i),'Color',colors{i});
                end
                vertForceAVG=zeros(1,numSetpoints);
                for i=1:numSetpoints
                    % in case of more files of single section scans, we know prior the size of single
                    % sections other than how much was the setpoint
                    if  ~isempty(metadata)
                        sizeSingleSection=metadata.y_scan_pixels(i); % already expressed in nanoNewton
                    else
                    % in case of single file, then divide the image in sections according to the number of used setpoint.
                    % IMPORTANT: this method is not accurate because when you change the setpoint manually, it is very
                    % likely that the "new" section has not same size as well as the previous one
                        sizeSingleSection=round(size(data,2)/numSetpoints);
                    end
                    % extract the vertical force data. Although this step could be made before the assembly, I
                    % found optimal put here so it can be made even in case of single entire scan
                    verticalForceSingleSection= data(:,(i-1)*sizeSingleSection+1:i*sizeSingleSection);
                    % exclude 99.9 percentile and 0.1
                    th=prctile(verticalForceSingleSection(:),99.9);
                    verticalForceSingleSection(verticalForceSingleSection>th)=NaN;
                    th=prctile(verticalForceSingleSection(:),0.1);
                    verticalForceSingleSection(verticalForceSingleSection<th)=NaN;
                    vertForceAVG(i)=mean(mean(verticalForceSingleSection),'omitnan');
                    avgN{i}=xline(axes1,vertForceAVG(i),'--','LineWidth',2,'DisplayName',sprintf('avg vertical force section %d',i),'Color',colors{i});
                    h{i}=histogram(axes1,verticalForceSingleSection,200,'DisplayName',sprintf('raw vertical force section %d',i),'FaceColor',colors{i});
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
                percentile=99.9;
                % prepare the data
                H_BK=data_Height(AFM_height_IO==0);
                H_FR=data_Height(AFM_height_IO==1);    
                thresholdBK = prctile(H_BK(:), percentile);
                thresholdPDA = prctile(H_FR(:), percentile);
                % outliers removal
                H_BK(H_BK >= thresholdBK) = NaN; 
                H_FR(H_FR >= thresholdPDA) = NaN; 
                H_BK = H_BK(~isnan(H_BK))*1e9;
                H_FR = H_FR(~isnan(H_FR))*1e9;
                edgesBK=min(H_BK):1:max(H_BK);
                edgesPDA=min(H_FR):1:max(H_FR);
                hold on    
                histogram(H_BK,edgesBK,'DisplayName','Distribution height','Normalization','percentage');
                histogram(H_FR,edgesPDA,'DisplayName','Distribution height','Normalization','percentage');
                legend({'Background','Foreground'},'FontSize',15)
                xlabel(sprintf('Feature height (nm)'),'FontSize',15), ylabel('Percentage %','FontSize',15), grid minor, grid on
                title(sprintf('Distribution PostProcessed Height (Percentile %d°)',percentile),'FontSize',20)
                objInSecondMonitor(f_heightDistribution,idxMon);     
                saveFigures_FigAndTiff(f_heightDistribution,folderSaveFig,'resultA2_end_6_OptHeightDistribution_FR_BK')
                % Since now there is the assembled mask
                titleData='Final Binary AFM IO Image';
                nameFig='resultA2_end_7_mask';
                showData(idxMon,SeeMe,AFM_height_IO,titleData,folderSaveFig,nameFig,'binary',true);
         
            end
        end
    end
end   