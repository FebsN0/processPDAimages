        % varargout = return any number of output arguments
function [varargout]=A1_open_JPK(pathJpk,varargin)

    
% the python file is assumed to be in a directory called "PythonCodes". Find it to a max distance of 4 upper
% folders
    % Maximum levels to search
    maxLevels = 4; originalPos=pwd; found=false;
    for i=1:maxLevels
        if isfolder(fullfile(pwd, 'PythonCodes'))
            found=true;
            break
        else
            cd ..        
        end            
    end
    if ~found
        error('PythonCodes directory not found. Please, put the directory close to "PDA analysis" folder or move to the proper position')
    else
        % Construct the path to the Python file       
        pythonFile = fullfile(pwd, 'PythonCodes', 'JPKScanTiffTags.py');
        % return to original position
        cd(originalPos)
    end
% This function opens .JPK image files and .JPK-force curves.
% It is also able to import a number of parameters relative to the hile.
%
% Image:
% [Image,Details of the image (metadata), path_to_file]=open_JPK(Path_to_File)
%
% Force Curve:
% [Force Curve]=open_JPK(Path_to_File);
%
% In case a JPK Nanowizard AFM is used and an image is imported, in combination with the following
% micromash [https://www.spmtips.com/] tips HQ:CSC38/Cr-Au or HQ:CSC37/Cr-Au, the SW also calibrates
% for lateral force microscopy. For further information on this functionality please turn to the
% following scientific article:
%
% Ortuso, Roberto D., Kaori Sugihara.
% "Detailed Study on the Failure of the Wedge Calibration Method at Nanonewton Setpoints for Friction Force Microscopy."
% The Journal of Physical Chemistry C 122.21 (2018): 11464-11474.
%
% Author: Dr. Ortuso, R.D.
% Univeristy of Geneva
%
%
% Author updates: Altieri F.
% University of Tokyo
% Important implementation: using python to extract metadata
% run on Command Window "pyversion". If it return nothing, python may be not installed or you dont have the
% rignt version. Check on the website https://www.mathworks.com/support/requirements/python-compatibility.html
% 


%%%%%%%%%%%%%%%%%%% UPDATES %%%%%%%%%%%%%%%%%%%%%
% it actually process only .jpk and .jpk-force files.
% if the input file is .jpk ==> retrieve metadata and img information
% if the input file is .jpk-force ==> not sure what exactly is. 

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    valid_extensions={'.jpk';'.jpk-force';'.jpk-force-map'};
    valid_extensions_getfile={'*.jpk';'*.jpk-force';'*.jpk-force-map'};
    
    p = inputParser;
    % if pathfile is entered, verify if extension of input file is valid
    addOptional(p, 'pathJpk', [], @(x) isempty(x) || (ischar(x) && endsWith(x, valid_extensions, 'IgnoreCase', true)));
    addParameter(p, 'metadataExtractionOnly', 'no', @(x) ischar(x) && any(strcmpi(x, {'yes', 'no'})));
    parse(p, pathJpk, varargin{:});
    
    if strcmpi(p.Results.metadataExtractionOnly,'Yes')
        flagOnlyMetadata = 1;
    else
        flagOnlyMetadata = 0;
    end

    %if open_JPK is run with an input file
    if p.Results.pathJpk
        complete_path_to_afm_file=p.Results.pathJpk;
    %if open_JPK is run without an input file ==> UIGETFILE
    else
        [afm_file_name,AFM_file_path,afm_file_index]=uigetfile(valid_extensions_getfile,'Choose AFM File');
        if(afm_file_index==0)
            error('No File Selected')
        else
            complete_path_to_afm_file=sprintf('%c%c',AFM_file_path,afm_file_name);
            %check the extension of uploaded file
            if ~endsWith(complete_path_to_afm_file, valid_extensions, 'IgnoreCase', true)
                error('Invalid format file')
            end
        end
    end
    [~,~,extension]=fileparts(complete_path_to_afm_file);
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%--------------- PROCESS .JPK IMAGE DATA ---------------%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if(strcmp(extension,valid_extensions{1,1}))
        %returns a structure whose fields contain information about an image in a graphics file, filename.
        % #row indicate #pics contained in the .jpk file
        file_info=imfinfo(complete_path_to_afm_file);
        
        number_of_images=numel(file_info);

        if ~flagOnlyMetadata
            % Create or update wait bar dialog box. INPUT are:
            %   - fractionalNumber* first call is zero
            %   - text to appear ==> in this case 0 is the start
            %   - CreateCancelBtn ==> Cancel button callback
            %   - 'setappdata(gcbf,''canceling'',1)' ==> When a user clicks the Cancel button MATLAB sets the
            %       'canceling' flag, to 1 (true) in the figure application data (appdata).
            %       NOTE: when cancel is clicked, the dialog box stop run but it
            %       doesn't close automatically. So the code tests for that value within the for loop
            %       and exits the loop if the flag value is 1.
            wb=waitbar(0/number_of_images,sprintf('Loading Channel %.0f of %.0f',0,number_of_images),...
                'CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
            % set the logical flag in cancel situation to false. When cancel is
            % clicked, then it becomes true
            setappdata(wb,'canceling',0);
        end

        for i=1:number_of_images
            if ~flagOnlyMetadata
                %update the wait bar dialog box
                waitbar(i/number_of_images,wb,sprintf('Loading Channel %.0f of %.0f',i,number_of_images));
            end

            if i==1
            % execute python file to extract metadata when i=1 ==> metadata stored in page 0 of the tiff file

                % REASON: The previous A1_open_JPK.m version uses fixed tag ID’s to read the available calibration slots!
                % like 
                % """
                % Type=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32816)).Value); 
                % """
                % However, Joerg Barner from JPK support said that it is dangerous use this approach because there is no guaranty
                % that all slots are available (depending on available calibration) or the slots are given always in the same order
        
                % For example, the Tag 32896 is the number of available slots reported after that line (give a look
                % into file_info to better understand) like ['raw','volts', 'distance','force'].
                % A potential problem is that there is the risk that are not in the same order. For example, it can be
                % like ['volts','force','raw','distance'] INSTEAD of the order previously reported
        
                % you need to read all of them, then you need to find the right slots (slot-name) ‘volts’, ‘distance’
                % and ‘force’ to compute the vertical calibration parameters
                % Used the python script instead of tifffile MATLAB library because it doesn't properly find HEX tag
                % IDs. Also, the original python code has been kindly provided by Joerg, assuring accurate results.
                % proper updates are made: the original version extract only metadata. The new version extract and
                % properly convert the data for each channel type
                % convert python dictionary object into matlab dictionary. To access matlab dictionary, use metadata("nameKey")            
                metadata = dictionary(pyrunfile(sprintf("%s '%s' %d'",pythonFile,complete_path_to_afm_file,i),"metadata")); 
                % for pixels it require more handling than other parameters
                x_scan_pixels= metadata("x_scan_pixels"); x_scan_pixels=double(x_scan_pixels{1});
                y_scan_pixels= metadata("y_scan_pixels"); y_scan_pixels=double(y_scan_pixels{1});
                % scan mode (ie. contact or ac mode)
                Type=string(metadata("FeedbackMode"));
                % vertical sensitivity (m/V)
                Vertical_Sn=cell2mat(metadata("sensitivity_m_V"));
                % vertical stiffness (N/m)
                Vertical_kn=cell2mat(metadata("springConstant_N_m"));
                %calculate Alpha. 14.75 is from linear fitting of the Ortuso and Sugihara work about wedge method calibration
                Alpha=Vertical_Sn*Vertical_kn*14.75; % For further detail please refer to aforementioned publication
                % save every important information from Metadata. Same for AC and Contact mode

                Details_Img=struct( ...
                    'Type', Type,...
                    'Scan_Rate_Hz',     cell2mat(metadata("scan_rate")),...
                    'x_Origin_m',       cell2mat(metadata("x_Origin")),...
                    'y_Origin_m',       cell2mat(metadata("y_Origin")),...
                    'Scanangle_deg',    rad2deg(cell2mat(metadata("scanangle"))),...
                    'x_scan_length_m',  cell2mat(metadata("x_scan_length")),...
                    'y_scan_length_m',  cell2mat(metadata("y_scan_length")),...
                    'x_scan_pixels',    x_scan_pixels,...
                    'y_scan_pixels',    y_scan_pixels,...
                    'Vertical_Sn',      Vertical_Sn,...
                    'Vertical_kn',      Vertical_kn,...
                    'Alpha',            Alpha,...
                    'P_Gain',           cell2mat(metadata("P_Gain")),...
                    'I_Gain',           cell2mat(metadata("I_Gain")));
                % same properties are unique for some scanning modes, but the following are specific.
                if strcmp(Type,'contact')
                    % Activated Baseline correction allow to correct the setpoint according on the value of measured
                    % vertical deflection at the approaching moment (unavoidable presence of interaction
                    % between the tip and the sample). Here there is no check if correction was enabled, because it is
                    % already processed in the python script. So, if correction was disabled, baselineVolts = 0     
                    absoluteSetpoint_V      = cell2mat(metadata("AbsoluteSetpoint"));
                    baseline_V              = cell2mat(metadata("BaselineV"));
                    EffectiveSetpoint_V     = absoluteSetpoint_V - baseline_V;
                    % baseline and setpoint in Newton
                    baseline_N              = cell2mat(metadata("BaselineForce_N")); absoluteSetpoint_N = cell2mat(metadata("absoluteSetpointForce_N"));
                    EffectiveSetpoint_N     = absoluteSetpoint_N - baseline_N;
                    % save the data
                    Details_Img.baselineAdjust  = cell2mat(metadata("BaselineAdjust"));
                    Details_Img.Baseline_V      = baseline_V;
                    Details_Img.Baseline_N      = baseline_N;
                    Details_Img.SetP_V          = EffectiveSetpoint_V;
                    Details_Img.SetP_N          = EffectiveSetpoint_N;
                % in case of AC-mode
                else       
                    Details_Img.Reference_Amp       = cell2mat(metadata("Reference_Amplitude"));
                    Details_Img.Set_Amplitude       = cell2mat(metadata("Set_Amplitude"));
                    Details_Img.Oscillation_Freq    = cell2mat(metadata("Oscillation_Freq"));
                    Details_Img.Regerence_Ph_Shift  = cell2mat(metadata("Reference_Phase_shift"));
                end
                if flagOnlyMetadata
                    break
                end
            % extract data from each channel
            else
                % start processing the data
                dataChannel = dictionary(pyrunfile(sprintf("%s '%s' %d'",pythonFile,complete_path_to_afm_file,i),"dataChannel")); 
                multiplyer  = cell2mat(dataChannel("multiplier"));
                offset      = cell2mat(dataChannel("offset"));
                %extract image data (Z values) with imread and properly scale 
                afm_image=((double(imread(complete_path_to_afm_file,i))*multiplyer))+offset;
                %organize the all the important data into a struct var
                Image(i-1)=struct(...
                    'Channel_name',     string(dataChannel("Channel_Name")), ...
                    'Trace_type',       string(dataChannel("trace_type_flag")),...
                    'Raw_afm_image',    imread(complete_path_to_afm_file,i),...
                    'Scale_factor',     multiplyer,...
                    'Offset',           offset,...
                    'Signal_type',      string(dataChannel("type_of_ch")),...
                    'AFM_image',        afm_image);
            end
            
            %if cancel is clicked during the data extraction, stop and delete dialog
            if(exist('wb','var'))
                if getappdata(wb,'canceling')
                    delete(wb)
                    error('Stopped the data extraction')
                end
            end
        end
        
        if(exist('wb','var'))
            delete(wb)
        end
        
        if ~flagOnlyMetadata
            % re organize the struct in alphabetic order. Transform 1x10 cell array into 1x10 string array and
            % transpose otherwise sortrows doesnt correctly read
            [~,index]=sortrows(string({Image.Channel_name})');
            Image = Image(index); clear index
            % save the output image data. NOTE: the data is already expressed in the correct unit.
            % I.E. lateral deflection data is expressed in Volt
            varargout{1}=Image;
        else
            varargout{1}=[];
        end
        % save the output metadata
        varargout{2}=Details_Img;
        % save the pathname where the image was processed
        if(exist('AFM_file_path','var'))
            varargout{3}=AFM_file_path;
        else
            varargout{3}=complete_path_to_afm_file;
        end
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%----------- PROCESS .JPK-FORCE FORCE CURVE DATA -----------%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Never modified but it is my goal to fix it
    elseif(strcmp(extension,valid_extensions{2,1}))
        %create directory where the force-curve data locates if doesnt exist 
        [FilePath,FileName,~]=fileparts(complete_path_to_afm_file);
        FullDirPath=fullfile(FilePath,'ForceCurvesMatalabExtracted');
        if ~exist(FullDirPath, 'dir')
           mkdir(FullDirPath)
        end
        % extract the force-curve metadata into subfolder of ForceCurvesMatalabExtracted Directory.
        % the unzip operation creates: segments, shared-data and header.properties
        unzip(complete_path_to_afm_file,sprintf('%s\\%s',FullDirPath,FileName))
        InfoDir=dir(sprintf('%s\\%s',FullDirPath,FileName));
        
        % every metadata information is in header.properties file inside share-data dir
        index_header=find(strcmp({InfoDir.name},'shared-data')==1);
        % location file
        header_location=fullfile(InfoDir(index_header).folder,InfoDir(index_header).name,'header.properties');
        fid=fopen(header_location);
        header_metadata_raw=textscan(fid,'%s');
        header_metadata_raw=header_metadata_raw{1,1};
        fclose(fid);
        
        j=1;f=0;Conversion_Set_Id=0;Encoder_Id=0;
        for i=1:size(header_metadata_raw,1)
            %exclude some rows which doesnt have = delimiter
            % this part aims to re-organize metadata in cell matrix
            % example:
            % i) lcd-info.0.conversion-set.conversion.volts.defined=false
            % ==> lcd-info | 0 | conversion-set | conversion | volts | defined | false
            
            %exclude rows which doesnt have = delimiter
            temp=strsplit(header_metadata_raw{i,1},'=');
            if(size(temp,2)==2)
                
                %split every row by . delimiter
                temp_2=strsplit(temp{1,1},'.');
                for z=1:size(temp_2,2)+1
                    if(z<=size(temp_2,2))
                        % take the i-information between '.'
                        header_metadata_split{j,z}=temp_2{1,z};
                    end
                    if(z==size(temp_2,2)+1)
                        % take the last information after '='
                        header_metadata_split{j,z}=temp{1,2};
                    end
                end
                % if 4 and over points
                if(size(temp_2,2)>=4)
                    %if the j-row and third column contains 'channel' and 'name' ==> take the name of the channel
                    %and create nested empty struct in .Encoded
                    % it saves imp information regarding Height | vDeflection | hDeflection | error | measuredHeight
                    if(strcmp(header_metadata_split{j,3},'channel')) && (strcmp(header_metadata_split{j,4},'name'))
                        f=f+1;
                        FC_Data(f).Channel_name=header_metadata_split{j,5};
                        FC_Data(f).Encoded.Offset=[];
                        FC_Data(f).Encoded.Multiplier=[];
                    end
                end
    
                if(size(temp_2,2)==5)
                    if(strcmp(header_metadata_split{j,3},'encoder'))&&(strcmp(header_metadata_split{j,4},'scaling'))&&(strcmp(header_metadata_split{j,5},'style'))&&(strcmp(temp{1,2},'offsetmultiplier'))
                        Encoder_Id=1;
                        Flag_Encoder_Id=j;
                    end
                end
    
                if(size(temp_2,2)==7)
                    if(strcmp(header_metadata_split{j,3},'conversion-set'))&&(strcmp(header_metadata_split{j,4},'conversion'))&&(strcmp(temp{1,2},'offsetmultiplier'))
                        Conversion_Set_Id=1;
                        Flag_Conversion_Set_Id=j;
                    end
                end
                % extract further metadata in a nested struct with the name from raw metadata (header_metadata_split{j-2,5})
                % example nominal, calibrated, distance, force
                if((Conversion_Set_Id==1)&&(Flag_Conversion_Set_Id+4==j))
                    FC_Data(f).(header_metadata_split{j-2,5}).Offset=str2double(header_metadata_split{j-3,8});
                    FC_Data(f).(header_metadata_split{j-2,5}).Multiplier=str2double(header_metadata_split{j-2,8});
                    FC_Data(f).(header_metadata_split{j-2,5}).Unit=header_metadata_split{j,9};
                    Conversion_Set_Id=0;
                end
                if((Encoder_Id==1)&&(Flag_Encoder_Id+4==j))
                    %save in the empty nested struct the information of encoding
                    FC_Data(f).Encoded.Offset=str2double(header_metadata_split{j-3,6});
                    FC_Data(f).Encoded.Multiplier=str2double(header_metadata_split{j-2,6});
                    FC_Data(f).Encoded.Unit=header_metadata_split{j,7};
                    Encoder_Id=0;
                end
                j=j+1;
            end
        end
    
        [~,index] = sortrows({FC_Data.Channel_name}.'); FC_Data = FC_Data(index); clear index
        z=1;
        % lists files and folders in the segment folder. Exclude those that have no number as name file
        % 0 = extend
        % 1 = retract
        InfoDir_Segments=dir(sprintf('%s\\%s\\%s',FullDirPath,FileName,'segments'));
        for i=1:size(InfoDir_Segments,1)
            if(~isnan(str2double(InfoDir_Segments(i).name)))
                folderToEval(1,z)=i;
                z=z+1;
            end
        end
        Channel_Name_Imprint_Raw=sprintf('%s_%s','Data','Raw');
        Channel_Name_Imprint_Encoded=sprintf('%s_%s','Data','Encoded');
        F_Names_FC_Data=fieldnames(FC_Data);
        %for each dir inside segment:
        for i=1:size(folderToEval,2)
            % save raw header.properties data
            Info_location=fullfile(FullDirPath,FileName,'segments',InfoDir_Segments(folderToEval(1,i)).name,'segment-header.properties');
            fid=fopen(Info_location);
            segment_metadata_raw=textscan(fid,'%s');
            fclose(fid);
            % check the style mode (retract o extend) 
            for j=1:size(segment_metadata_raw{1,1},1)
                temp=strsplit(segment_metadata_raw{1,1}{j,1},'=');
                if(size(temp,2)==2)&&(strcmp(temp{1,1},'force-segment-header.settings.style'))
                    Data_Type=temp{1,2};
                break
                end
            end
    
            % lists files and folders in the segment\<i>\channels folder. Exclude those that are not .dat files
            Temp_InfoDir_Segments=dir(sprintf('%s\\%s\\%s\\%s\\%s\\*.dat',FullDirPath,FileName,'segments',InfoDir_Segments(folderToEval(1,i)).name,'channels'));
            [~,index1] = sortrows({Temp_InfoDir_Segments.name}.'); Temp_InfoDir_Segments = Temp_InfoDir_Segments(index1); clear index1
            
            if(size(Temp_InfoDir_Segments,1)~=size(FC_Data,2))
                error('Something went wrong!! Different data sets')
            end
            for j=1:size(Temp_InfoDir_Segments,1)
                %take the name of the file inside i-dir segment\<i>\channels and Read data from binary file (.dat)
                File_OfInterest=sprintf('%s\\%s\\%s\\%s\\%s\\%s',FullDirPath,FileName,'segments',InfoDir_Segments(folderToEval(1,i)).name,'channels',Temp_InfoDir_Segments(j).name);
                fid=fopen(File_OfInterest);
                %extract data (raw)
                flag_temp=fread(fid,'int32');
                fclose(fid);
                %check if names of metadata from header.properties is the same as well as the file in i-dir segment\<i>\channels folder
                temp=strsplit(Temp_InfoDir_Segments(j).name,'.');
                if(~strcmp(FC_Data(j).Channel_name,temp{1,1}))
                    error('Something went wrong!!')
                end
                % add another Fields depending on mode (extend or retract) and add 2 struct
                %   - Data_Raw
                %   - Data_Encoded
                % NOTE
                % error channel = all zero
                FC_Data(j).(Data_Type).(Channel_Name_Imprint_Raw) = flag_temp;
                FC_Data(j).(Data_Type).(Channel_Name_Imprint_Encoded)=flag_temp*(FC_Data(j).Encoded.Multiplier)+(FC_Data(j).Encoded.Offset);
                
                % from 3 to 6 (nominal to force fields)
                for w=3:size(F_Names_FC_Data,1)
                    % if empty, skip. Otherwise add another field of w-field in FC_Data fields
                    %   and add the data: Data_Encoded*Multiplier+Offset
                    % Multiplier and Offset are from FC_Data corrispective field
                    % EXAMPLE: FC_field(3).nominal.Multiplier and FC_field(3).nominal.Offset to the FC_Data(3).extend.Data_Encoded
                    if(~isempty(FC_Data(j).(F_Names_FC_Data{w,1})))
                        Channel_Name_Imprint_Calibrated=sprintf('%s_%s','Data',F_Names_FC_Data{w,1});
                        FC_Data(j).(Data_Type).(Channel_Name_Imprint_Calibrated)=(FC_Data(j).(Data_Type).(Channel_Name_Imprint_Encoded))*(FC_Data(j).(F_Names_FC_Data{w,1}).Multiplier)+(FC_Data(j).(F_Names_FC_Data{w,1}).Offset);
                    end
                end

            end
            clear segment_metadata_raw Temp_InfoDir_Segments
        end
        % OUTPUT data of force curves
        varargout{1}=FC_Data;    
    end    
    if(exist('wb','var'))
        delete (wb)
    end

end