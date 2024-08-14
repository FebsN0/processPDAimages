% Function to remove unnecessary AFM channels and leave only LD, VD and height TRACE. No RETRACE because of HOVER MODE!
%
% Author updates: Altieri F.
% University of Tokyo
% 
% Last update 26.June.2024
% 
% 
% INPUT: OUTPUT of A1_open_JPK (single struct data)

function [Selected_AFM_data]=A2_CleanUpData2_AFM(data,secondMonitorMain,newFolder)
%check if they are struct with the specific fields
    if isstruct(data)
        % Check if the struct has exactly the specific fields and 10 rows
        fieldNames=fieldnames(data);
        for j=1:length(fieldnames(data))
            if ~((strcmpi(fieldNames{j},'Channel_name') || strcmpi(fieldNames{j},'Trace_type') || ...
                strcmpi(fieldNames{j},'Raw_afm_image') || strcmpi(fieldNames{j},'Scale_factor') || ...
                strcmpi(fieldNames{j},'Offset') || strcmpi(fieldNames{j},'AFM_image')) && size(data, 2) == 10)
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

        raw_data_Height=    Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Height (measured)')).AFM_image;
        raw_data_LD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        raw_data_LD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Lateral Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        raw_data_VD_trace=  Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'Trace')).AFM_image;
        raw_data_VD_retrace=Selected_AFM_data(strcmp({Selected_AFM_data.Channel_name},'Vertical Deflection') & strcmp({Selected_AFM_data.Trace_type},'ReTrace')).AFM_image;
        
        f1=figure;
        imagesc(raw_data_Height)
        colormap parula, title('Raw data Height (measured) channel','FontSize',17),
        c = colorbar; c.Label.String = ''; c.Label.FontSize=15;
        ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f1); end
        saveas(f1,sprintf('%s/resultA2_1_RawHeightChannel.tif',newFolder))
        
        f2=figure;
        imagesc(raw_data_LD_trace)
        colormap parula, title('Raw data Lateral Deflection Trace channel','FontSize',17),
        c = colorbar; c.Label.String = ''; c.Label.FontSize=15;
        ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f2); end
        saveas(f2,sprintf('%s/resultA2_2_RawLDChannel_trace.tif',newFolder))

        f3=figure;
        imagesc(raw_data_LD_retrace)
        colormap parula, title('Raw data Lateral Deflection Retrace channel','FontSize',17),
        c = colorbar; c.Label.String = ''; c.Label.FontSize=15;
        ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f3); end
        saveas(f3,sprintf('%s/resultA2_3_RawLDChannel_retrace.tif',newFolder))

        f4=figure;
        imagesc(raw_data_VD_trace)
        colormap parula, title('Raw data Vertical Deflection trace channel','FontSize',17),
        c = colorbar; c.Label.String = ''; c.Label.FontSize=15;
        ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f4); end
        saveas(f4,sprintf('%s/resultA2_4_RawVDChannel_trace.tif',newFolder))

        f5=figure;
        imagesc(raw_data_VD_retrace)
        colormap parula, title('Raw data Vertical Deflection retrace channel','FontSize',17),
        c = colorbar; c.Label.String = ''; c.Label.FontSize=15;
        ylabel('slow scan line direction','FontSize',12), xlabel('fast scan line direction','FontSize',12)
        if ~isempty(secondMonitorMain),objInSecondMonitor(secondMonitorMain,f5); end
        saveas(f5,sprintf('%s/resultA2_5_RawVDChannel_retrace.tif',newFolder))
    else
       error('Invalid Input!');
    end
end