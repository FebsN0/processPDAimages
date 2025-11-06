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
    argName = 'setpointsList';  defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'idxMon';         defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'newFolder';      defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'cleanOnly';      defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'Silent';         defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'imageType';      defaultVal = 'Entire';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'Normalization';  defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'sectionSize';    defaultVal = [];        addParameter(p,argName,defaultVal);
    argName = 'metadata';       defaultVal = [];        addParameter(p,argName,defaultVal);
    % validate and parse the inputs
    parse(p,data,varargin{:});

    clearvars argName defaultVal

    if(strcmp(p.Results.cleanOnly,'Yes'))
        cleanOnly=1;
    else
        cleanOnly=0;
        if(strcmp(p.Results.Silent,'Yes'));     SeeMe=0; else, SeeMe=1; end                    
        imageTyp=p.Results.imageType;
        if p.Results.Normalization; norm=1; else, norm=0; end
        setpoints=p.Results.setpointsList;
        idxMon=p.Results.idxMon;
        newFolder=p.Results.newFolder;        
    end
    
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
        data_VD_trace=  data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'Trace')).AFM_image;
        data_Height=    data(strcmp([data.Channel_name],'Height (measured)')).AFM_image;
        data_LD_trace=  data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'Trace')).AFM_image;
        data_LD_retrace=data(strcmp([data.Channel_name],'Lateral Deflection') & strcmp([data.Trace_type],'ReTrace')).AFM_image;
        data_VD_retrace=data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'ReTrace')).AFM_image;
        % rotate so the image is aligned with BF\fluorescence images        
        data_Height= flip(rot90(data_Height),2);
        data_LD_trace= flip(rot90(data_LD_trace),2);
        data_LD_retrace=flip(rot90(data_LD_retrace),2);
        data_VD_trace= flip(rot90(data_VD_trace),2);
        data_VD_retrace=flip(rot90(data_VD_retrace),2);
        % start to show the data
        data=data_Height*1e9;
        titleData=sprintf('Height (measured) channel (Raw - %s)',imageTyp);
        idimg=2;
        nameFig=sprintf('resultA2_%d_HeightChannel_%s',idimg,imageTyp);
        labelBar=sprintf('height (nm)');
        showData(idxMon,SeeMe,1,data,norm,titleData,labelBar,newFolder,nameFig)
        % Lateral Deflection Trace
        data=data_LD_trace;
        titleData=sprintf('Lateral Deflection Trace channel (Raw - %s)',imageTyp);
        nameFig=sprintf('resultA2_3_Raw_LDChannel_trace_%s',imageTyp);
        labelBar='Voltage [V]';
        showData(idxMon,SeeMe,2,data,norm,titleData,labelBar,newFolder,nameFig)
        % Lateral Deflection ReTrace
        data=data_LD_retrace;
        titleData=sprintf('Lateral Deflection Retrace channel (Raw - %s)',imageTyp);
        nameFig=sprintf('resultA2_4_Raw_LDChannel_retrace_%s',imageTyp);
        showData(idxMon,SeeMe,3,data,norm,titleData,labelBar,newFolder,nameFig)
        % Vertical Deflection trace
        data=data_VD_trace*1e9;
        titleData=sprintf('Vertical Deflection trace channel (Raw - %s)',imageTyp);
        nameFig=sprintf('resultA2_5_Raw_VDChannel_trace_%s',imageTyp);
        labelBar='Force [nN]';
        showData(idxMon,SeeMe,4,data,norm,titleData,labelBar,newFolder,nameFig)
        % Vertical Deflection Retrace
        data=data_VD_retrace*1e9;
        titleData=sprintf('Vertical Deflection retrace channel (Raw - %s)',imageTyp);
        nameFig=sprintf('resultA2_6_Raw_VDChannel_retrace_%s',imageTyp);
        showData(idxMon,SeeMe,5,data,norm,titleData,labelBar,newFolder,nameFig)           
        
        %%%%% perform the following step ONLY after assembly %%%%%
        if ~strcmp(imageTyp,"SingleSection")
            % show distribution of vertical forces (data_VD_trace). If good, it should coincide approximately with the setpoint
            data=data_VD_trace*1e9;
            colors={"#0072BD","#D95319","#EDB120","#7E2F8E","#77AC30","#4DBEEE","#A2142F",'k','#FF00FF','#00FF00'};
            if SeeMe
                f0=figure('Visible','on');
            else
                f0=figure('Visible','off');
            end
            axes1 = axes('Parent',f0);
            hold(axes1,'on');
            % EXTRACT ALL DATA
            % why flip? because the data has previously been flipped to coindide with the Fluorescence imaging. So
            % needed to flip also the setpoint vector (left high - right low)
            setpoints=flip(setpoints); numSetpoints=length(setpoints); 
            setN=cell(1,numSetpoints); avgN=cell(1,numSetpoints); h=cell(1,numSetpoints);
            for i=1:numSetpoints
                % plot lines of setpoint
                setN{i}=xline(setpoints(i)*1e9,'LineWidth',4,'DisplayName',sprintf('setpoint section %d',i),'Color',colors{i});
            end
            vertForceAVG=zeros(1,numSetpoints);
            for i=1:numSetpoints
                % in case of more files of single section scans, we know prior the size of single
                % sections other than how much was the setpoint
                if ~isempty(p.Results.sectionSize)
                    sizeSingleSection=p.Results.sectionSize(i); % already expressed in nanoNewton
                else
                % in case of single file, then divide the image in sections according to the number of used setpoint.
                % IMPORTANT: this method is not accurate because when you change the setpoint manually, it is very
                % likely that the "new" section has not same size as well as the previous one
                    sizeSingleSection=round(size(data,2)/numSetpoints);
                end
                % extract the vertical force data. Although this step could be made before the assembly, I
                % found optimal put here so it can be made even in case of single entire scan
                verticalForceSingleSection= data(:,(i-1)*sizeSingleSection+1:i*sizeSingleSection);
                vertForceAVG(i)=mean(mean(verticalForceSingleSection));
                avgN{i}=xline(vertForceAVG(i),'--','LineWidth',2,'DisplayName',sprintf('avg vertical force section %d',i),'Color',colors{i});
                h{i}=histogram(verticalForceSingleSection,400,'DisplayName',sprintf('raw vertical force section %d',i),'FaceColor',colors{i});
            end
            legend1 = legend('FontSize',15);
            set(legend1,'Location','bestoutside');
            title('Distribution Raw Vertical Forces','FontSize',18), xlabel('Force [nN]','FontSize',15)
            objInSecondMonitor(f0,idxMon);
            saveas(f0,sprintf('%s/tiffImages/resultA2_1_distributionVerticalForces.tif',newFolder))
            saveas(f0,sprintf('%s/figImages/resultA2_1_distributionVerticalForces',newFolder))
            vertForceAVG=unique(round(vertForceAVG));
            if length(vertForceAVG)~=numSetpoints
                warndlg('Number of rounded vertical forces is less than number of setpoint!')
            end
            close(f0)
            % plot the baseline trend
            if ~isempty(p.Results.metadata)
                metadata=p.Results.metadata;
                totTimeScan = (metadata.x_scan_pixels/metadata.Scan_Rate_Hz)/60;
                totTimeSection = totTimeScan/numSetpoints;
                if SeeMe
                    f1=figure('Visible','on');
                else
                    f1=figure('Visible','off');
                end
                % we dont have the baseline info at the end of the scan. It is saved only in the baseline.txt file
                arrayTime=0:totTimeSection:totTimeScan-totTimeSection;
                baselineN=metadata.Baseline_N*1e9;
                if length(baselineN) > 1
                    if abs(baselineN(2) - baselineN(1)) > 10 
                        warning('\n\tThe baseline of the first section varies by more than 10nN from the first one!!\n\tThe current scan is not really realiable... ')
                    end
                    plot(arrayTime,metadata.Baseline_N*1e9,'-*','LineWidth',2,'MarkerSize',15,'MarkerEdgeColor','red')
                    title('Baseline Trend among the sections','FontSize',18)
                    ylabel('Baseline shift [nN]','FontSize',15), xlabel('Time [min]','FontSize',15), grid on, grid minor
                    objInSecondMonitor(f1,idxMon);
                    saveas(f1,sprintf('%s/tiffImages/resultA2_0_baselineTrend.tif',newFolder))
                    saveas(f1,sprintf('%s/figImages/resultA2_0_baselineTrend',newFolder))
                else
                    warning('\n\tPlotting the baseline trend is not possible because only one baseline value is stored in the metadata (Scan = Section)')
                end
                close(f1)
            end
        end
    end
end
