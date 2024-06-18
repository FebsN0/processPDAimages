% Function to remove unnecessary AFM channels and leave only LD, VD and height TRACE. No RETRACE because of HOVER MODE!
%
% Author updates: Altieri F.
% University of Tokyo
% 
% Last update 17.June.2024
% 
% 
% INPUT: OUTPUT of A1_open_JPK (single struct data)

function [Selected_AFM_data]=A2_CleanUpData2_AFM(arg)
    %if empty
    if ~nargin
        error('Missing Input')
    elseif nargin==1
        Selected_AFM_data=[];
        %check if they are struct with the specific fields
        if isstruct(arg)
           % Check if the struct has exactly the specific fields and 10 rows
           fieldNames=fieldnames(arg);
           for j=1:length(fieldnames(arg))
               if ~((strcmpi(fieldNames{j},'Channel_name') || strcmpi(fieldNames{j},'Trace_type') || ...
                   strcmpi(fieldNames{j},'Raw_afm_image') || strcmpi(fieldNames{j},'Scale_factor') || ...
                   strcmpi(fieldNames{j},'Offset') || strcmpi(fieldNames{j},'AFM_image')) && size(arg, 2) == 10)
                   error('Invalid Input!');
               end
           end
           %find only those rows of interest (trace, latDefle, Height and vertDefle)
           traceMask=strcmpi({arg.Trace_type},'trace');
           channelMask=strcmpi({arg.Channel_name},'Height (measured)') | strcmpi({arg.Channel_name},'Lateral Deflection') | strcmpi({arg.Channel_name},'Vertical Deflection');
           defMask= traceMask & channelMask;
           Selected_AFM_data = arg(defMask);
        else
           error('Invalid Input!');
        end
    else
        error('Too many Input!');
    end
end