% Function to remove unnecessary AFM channels and leave only LD, VD and height TRACE. No RETRACE because of HOVER MODE!
%
% Author updates: Altieri F.
% University of Tokyo
% 
% Last update 26.June.2024
% 
% 
% INPUT: OUTPUT of A1_open_JPK (single struct data)

function [Selected_AFM_data]=A2_CleanUpData2_AFM(data,secondMonitorMain,newFolder,varargin)
%check if they are struct with the specific fields
    if isstruct(data)
        % Check if the struct has exactly the specific fields and 10 rows
        fieldNames=fieldnames(data);
        for j=1:length(fieldnames(data))
            if ~((strcmpi(fieldNames{j},'Channel_name') || strcmpi(fieldNames{j},'Trace_type') ||  strcmpi(fieldNames{j},'Signal_type') || ...
                strcmpi(fieldNames{j},'Raw_afm_image') || strcmpi(fieldNames{j},'Scale_factor') || ...
                strcmpi(fieldNames{j},'Offset') || strcmpi(fieldNames{j},'AFM_image')) && size(data, 2) == 10)
                error('Invalid Input!');
            end
        end

        %init instance of inputParser
        p=inputParser();    
        argName = 'Silent';     defaultVal = 'Yes';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
        % validate and parse the inputs
        parse(p,varargin{:});
    
        clearvars argName defaultVal     
        if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end



    %find only those rows of interest (trace: latDefle, Height and vertDefle, retrace: latDefle, vertDefle)
        traceMask=strcmpi({data.Trace_type},'trace');
        channelMask1= strcmpi({data.Channel_name},'Height (measured)');
        channelMask2= strcmpi({data.Channel_name},'Vertical Deflection');
        channelMask3= strcmpi({data.Channel_name},'Lateral Deflection');
        defMask= (traceMask & channelMask1) | channelMask2 | channelMask3;
        Selected_AFM_data = data(defMask);

        raw_data_Height=    Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Height (measured)')).AFM_image;
        raw_data_LD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        raw_data_LD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        raw_data_VD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        raw_data_VD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        

        data=raw_data_Height*1e6;
        titleData='Raw data Height (measured) channel';
        labelBar=sprintf('height (\x03bcm)');
        nameFig=sprintf('%s/resultA2_1_RawHeightChannel.tif',newFolder);
        showData(secondMonitorMain,SeeMe,1,data,titleData,labelBar,nameFig)

        data=raw_data_LD_trace;
        titleData='Raw data Lateral Deflection Trace channel';
        labelBar='Voltage [V]';
        nameFig=sprintf('%s/resultA2_2_RawLDChannel_trace.tif',newFolder);
        showData(secondMonitorMain,SeeMe,2,data,titleData,labelBar,nameFig)

        data=raw_data_LD_retrace;
        titleData='Raw data Lateral Deflection Retrace channel';
        nameFig=sprintf('%s/resultA2_3_RawLDChannel_retrace.tif',newFolder);
        showData(secondMonitorMain,SeeMe,3,data,titleData,labelBar,nameFig)

        data=raw_data_VD_trace*1e9;
        titleData='Raw data Vertical Deflection trace channel';
        labelBar='Force [nN]';
        nameFig=sprintf('%s/resultA2_4_RawVDChannel_trace.tif',newFolder);
        showData(secondMonitorMain,SeeMe,4,data,titleData,labelBar,nameFig)
 

        data=raw_data_VD_retrace*1e9;
        titleData='Raw data Vertical Deflection retrace channel';
        nameFig=sprintf('%s/resultA2_5_RawVDChannel_retrace.tif',newFolder);
        showData(secondMonitorMain,SeeMe,5,data,titleData,labelBar,nameFig)

    else
       error('Invalid Input!');
    end
end
