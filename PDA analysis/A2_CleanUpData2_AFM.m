% Function to remove unnecessary AFM channels and leave only LD, VD and height TRACE. No RETRACE because of HOVER MODE!
%
% Author updates: Altieri F.
% University of Tokyo
% 
% Last update 26.August.2024
% 
% 
% INPUT: OUTPUT of A1_open_JPK (single struct data)

function [Selected_AFM_data,varargout]=A2_CleanUpData2_AFM(data,setpoints,secondMonitorMain,newFolder,varargin)
           
    %init instance of inputParser
    p=inputParser();
    addRequired(p, 'data', @(x) isstruct(x));
    argName = 'Silent';         defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'phaseProcess';   defaultVal = 'Raw';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'Raw','PostProcessed'}));
    argName = 'imageType';      defaultVal = 'Entire';  addParameter(p,argName,defaultVal, @(x) ismember(x,{'Entire','SingleSection','Assembled'}));
    argName = 'SaveFig';        defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'Normalization';  defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'sectionSize';    defaultVal = [];        addParameter(p,argName,defaultVal);

    % validate and parse the inputs
    parse(p,data,varargin{:});

    clearvars argName defaultVal     
    if(strcmp(p.Results.Silent,'Yes'));  SeeMe=0; else, SeeMe=1; end
    if(strcmp(p.Results.SaveFig,'Yes')); SavFg=1; else, SavFg=0; end
    phaseProc=p.Results.phaseProcess;
    if(strcmp(phaseProc,'Raw'));  step=2; else, step=4; end
    imageTyp=p.Results.imageType;
    if(strcmp(p.Results.Normalization,'Yes')); norm=1; else, norm=0; end
   
    % Check if the data struct has exactly the specific fields and 5 rows (removed not useful data)
    fieldNames=fieldnames(data);
    for j=1:length(fieldnames(data))
        if ~((strcmpi(fieldNames{j},'Channel_name') || strcmpi(fieldNames{j},'Trace_type') ||  strcmpi(fieldNames{j},'Signal_type') || ...
            strcmpi(fieldNames{j},'Raw_afm_image') || strcmpi(fieldNames{j},'Scale_factor') || ...
            strcmpi(fieldNames{j},'Offset') || strcmpi(fieldNames{j},'AFM_image')) && (size(data, 2) == 5 || size(data, 2) == 10))       % first call there are 10 fields. After only 5 are left
            error('Invalid Input!');
        end
    end

    %find only those rows of interest (trace: latDefle, Height and vertDefle, retrace: latDefle, vertDefle)
    traceMask=strcmpi({data.Trace_type},'trace');
    channelMask1= strcmpi({data.Channel_name},'Height (measured)');
    channelMask2= strcmpi({data.Channel_name},'Vertical Deflection');
    channelMask3= strcmpi({data.Channel_name},'Lateral Deflection');
    defMask= (traceMask & channelMask1) | channelMask2 | channelMask3;
    Selected_AFM_data = data(defMask);

    if SavFg
        data_Height=    Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Height (measured)')).AFM_image;
        data_LD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        data_LD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        data_VD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        data_VD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        % rotate
        if step==2
            data_Height= flip(rot90(data_Height),2);
            data_LD_trace= flip(rot90(data_LD_trace),2);
            data_LD_retrace=flip(rot90(data_LD_retrace),2);
            data_VD_trace= flip(rot90(data_VD_trace),2);
            data_VD_retrace=flip(rot90(data_VD_retrace),2);
        end

        data=data_Height*1e6;
        titleData=sprintf('%s - Height (measured) channel (%s)',phaseProc,imageTyp);
        nameFig=sprintf('%s/resultA%d_1_%s_HeightChannel_%s.tif',newFolder,step,phaseProc,imageTyp);
        labelBar=sprintf('height (\x03bcm)');
        showData(secondMonitorMain,SeeMe,1,data,norm,titleData,labelBar,nameFig)
        % no need to plot and save the others channels since they have not changed
        if step == 2
            data=data_LD_trace;
            titleData=sprintf('%s - Lateral Deflection Trace channel (%s)',phaseProc,imageTyp);
            nameFig=sprintf('%s/resultA%d_2_%s_LDChannel_trace_%s.tif',newFolder,step,phaseProc,imageTyp);
            labelBar='Voltage [V]';
            showData(secondMonitorMain,SeeMe,2,data,norm,titleData,labelBar,nameFig)
    
            data=data_LD_retrace;
            titleData=sprintf('%s - Lateral Deflection Retrace channel (%s)',phaseProc,imageTyp);
            nameFig=sprintf('%s/resultA%d_3_%s_LDChannel_retrace_%s.tif',newFolder,step,phaseProc,imageTyp);
            showData(secondMonitorMain,SeeMe,3,data,norm,titleData,labelBar,nameFig)
    
            data=data_VD_trace*1e9;
            titleData=sprintf('%s - Vertical Deflection trace channel (%s)',phaseProc,imageTyp);
            nameFig=sprintf('%s/resultA%d_4_%s_VDChannel_trace_%s.tif',newFolder,step,phaseProc,imageTyp);
            labelBar='Force [nN]';
            showData(secondMonitorMain,SeeMe,4,data,norm,titleData,labelBar,nameFig)
            
            % show distribution of vertical forces. Should coincide approximately with the setpoint
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
                % whereas in case of more files of single section scans, we know prior the size of single
                % sections other than how much was the setpoint
                if ~isempty(p.Results.sectionSize)
                    sizeSingleSection=p.Results.sectionSize(i); % already expressed in nanoNewton
                else
                % in case of single file, similar size are expected. Method not accurate
                    sizeSingleSection=round(size(data,2)/numSetpoints);
                end
                % extract the vertical force data. Although this step could be made before the assembly, I
                % found optimal put here so it can be made even in case of single entire scan
                verticalForceSingleSection= data(:,(i-1)*sizeSingleSection+1:i*sizeSingleSection);
                vertForceAVG(i)=mean(mean(verticalForceSingleSection));
                avgN{i}=xline(vertForceAVG(i),'--','LineWidth',2,'DisplayName',sprintf('avg vertical force section %d',i),'Color',colors{i});
                h{i}=histogram(verticalForceSingleSection,500,'DisplayName',sprintf('raw vertical force section %d',i),'FaceColor',colors{i});
            end
            legend1 = legend(axes1,'show');
            set(legend1,'Location','best');
            title('Distribution Raw Vertical Forces','FontSize',18), xlabel('Force [nN]','FontSize',15)
            objInSecondMonitor(secondMonitorMain,f0);
            saveas(f0,sprintf('%s/resultA2_5_distributionVerticalForces.tif',newFolder))
            vertForceAVG=unique(round(vertForceAVG));
            if length(vertForceAVG)~=numSetpoints
                warndlg('Number of rounded vertical forces is less than number of setpoint!')
            end
            varargout{1}=vertForceAVG*1e-9;     % convert nanoNewton into Newton

            data=data_VD_retrace*1e9;
            titleData=sprintf('%s - Vertical Deflection retrace channel (%s)',phaseProc,imageTyp);
            nameFig=sprintf('%s/resultA%d_6_%s_VDChannel_retrace_%s.tif',newFolder,step,phaseProc,imageTyp);
            showData(secondMonitorMain,SeeMe,5,data,norm,titleData,labelBar,nameFig)
        end
    end
end
