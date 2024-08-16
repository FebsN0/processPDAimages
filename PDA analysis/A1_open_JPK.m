        % varargout = return any number of output arguments
function [varargout]=A1_open_JPK(varargin)

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
% 
% Last update 17.June.2024


%%%%%%%%%%%%%%%%%%% UPDATES %%%%%%%%%%%%%%%%%%%%%
% it actually process only .jpk and .jpk-force files.
% if the input file is .jpk ==> retrieve metadata and img information
% if the input file is .jpk-force ==> not sure what exactly is. 

    % in case of code error, the waitbar won't be removed. So the following command force its closure
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    flag_manual_select=1;
    valid_extensions={'.jpk';'.jpk-force';'.jpk-force-map'};
    valid_extensions_getfile={'*.jpk';'*.jpk-force';'*.jpk-force-map'};

    %if open_JPK is run with an input file
    if(~isempty(varargin))
        if(isfile(varargin{1,1}))
            [~,~,extension]=fileparts(varargin{1,1});                   %returns the path name, file name, and extension for the specified file
            if(any(strcmp(extension,valid_extensions)))                 %verify if extension of input file is valid
                complete_path_to_afm_file=varargin{1,1};
                flag_manual_select=0;
            else
                clearvars extension
            end
        end
    end

    %if open_JPK is run without an input file ==> UIGETFILE
    while(flag_manual_select==1)
        [afm_file_name,AFM_file_path,afm_file_index]=uigetfile(valid_extensions_getfile,'Choose AFM File');
        complete_path_to_afm_file=sprintf('%c%c',AFM_file_path,afm_file_name);
        %check the extension of uploaded file
        [~,~,extension]=fileparts(complete_path_to_afm_file);
        if(afm_file_index==0)
            error('No File Selected')
        else
            if(any(strcmp(extension,valid_extensions)))
                fprintf('\n\nDetails of storage location:\n %s\n',sprintf('%c%c',AFM_file_path,afm_file_name))
                flag_manual_select=0;
            else
                clearvars afm_file_name AFM_file_path afm_file_index complete_path_to_afm_file extension
                waitfor(warndlg({'Accepted file formats limited to:','*.jpk','*.jpk-force','*.jpk-force-map (currently not supported)'},'Warning'));
            end
        end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%--------------- PROCESS .JPK IMAGE DATA ---------------%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if(strcmp(extension,valid_extensions{1,1}))
        if(~isempty(varargin))
            file_info=imfinfo(varargin{1,1});
        else
            %returns a structure whose fields contain information about an image in a graphics file, filename.
            % #row indicate #pics contained in the .jpk file
            file_info=imfinfo(complete_path_to_afm_file);
        end
        number_of_images=numel(file_info);
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
    
        for i=1:number_of_images
            
            if(i==1) %the first row of file_info contains metadata information
                %update the wait bar dialog box
                waitbar(i/number_of_images,wb,sprintf('Metadata of Image'));
                %UnknownTags is another struct which contains several information
                % Find such info by finding the index of a specific ID
                Type=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32816)).Value);              %scan mode (ie. contact or ac mode)
                x_Origin=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32832)).Value);          %origin axis
                y_Origin=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32833)).Value);
                x_scan_length=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32834)).Value);     %size of the image (ie 50um)
                y_scan_length=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32835)).Value);
                x_scan_pixels=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32838)).Value);     %resolution (512)
                y_scan_pixels=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32839)).Value);
                scanangle=rad2deg(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32836)).Value);  %direction of scanning
    
                if(strcmp(Type,'contact'))
                    % the 32830 ID contains further information in string format
                    % ==> split and extract specific info into cell array
                    flag_data=strsplit(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32830)).Value)';
                    % Apply function to each cell in cell array
                    %   - [@function to apply], targetCellArray ==> in this case check if the flag_data
                    %       contains information regarding i- and p- gain and take the index where it locates     
                    flag=find(~cellfun(@isempty,strfind(flag_data,'setpoint-feedback-settings.i-gain')));
                    % conver to number
                    I_Gain=cellfun(@str2double, flag_data(flag+2,1));
                    flag=find(~cellfun(@isempty,strfind(flag_data,'setpoint-feedback-settings.p-gain')));
                    P_Gain=cellfun(@str2double, flag_data(flag+2,1));
                    % ID 33028 contains LinearScaling in meter (distance)
                    % ID 32980 contains LinearScaling in volts (volts)
                    % vertical sensitivity (m/V)
                    Vertical_Sn=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33028)).Value)/(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32980)).Value);
                    % ID 33076 contains LinearScaling in newton (Force)
                    % ID 33028 contains LinearScaling in meter (distance)
                    % vertical stiffness (N/m)
                    Vertical_kn=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33076)).Value)/(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33028)).Value);
                    %calculate Alpha. 14.75 is from linear fitting of the Ortuso and Sugihara work about wedge method calibration
                    Alpha=Vertical_Sn*Vertical_kn*14.75; % For further detail please refer to aforementioned publication
    
                    if(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32820)).Value==1)
                        Baseline_Raw=((file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32819)).Value-file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32821)).Value)-file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32980)).Value);
                        Bline_adjust='Yes';
                    else
                        Baseline_Raw=((file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32819)).Value)-file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32980)).Value);
                        Bline_adjust='No';
                    end
                    
                    SetP_V=Baseline_Raw;
                    Raw=(Baseline_Raw-(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32981)).Value))/(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32980)).Value); % Setpoint in Volts [V]
                    SetP_m=(Raw)*(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33028)).Value)+(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33029)).Value); % Setpoint in meters [m]
                    SetP_N=(Raw)*(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33076)).Value)+(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33077)).Value); % Setpoint in force [N]
                    
                    % save every important information from Metadata
                    Details_Img=struct(...
                        'Type', Type,...
                        'x_Origin', x_Origin,...
                        'y_Origin', y_Origin,...
                        'Scanangle', scanangle,...
                        'x_scan_length', x_scan_length,...
                        'y_scan_length', y_scan_length,...
                        'x_scan_pixels', x_scan_pixels,...
                        'y_scan_pixels', y_scan_pixels,...
                        'I_Gain', I_Gain,...
                        'P_Gain', P_Gain,...
                        'Baseline_V', Baseline_Raw,...
                        'Baseline_N', nan,...
                        'SetP_V', SetP_V,...
                        'SetP_m', SetP_m,...
                        'SetP_N', SetP_N,...
                        'Vertical_Sn', Vertical_Sn,...
                        'Vertical_kn', Vertical_kn,...
                        'Alpha', Alpha);
                    
                elseif(strcmp(Type,'ac'))
                    
                    I_Gain=abs((file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32818)).Value));
                    
                    Reference_Amplitude=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32821)).Value);
                    Set_Amplitude=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32822)).Value);
                    Oscillation_Freq=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32823)).Value);
                    Reference_Phase_shift=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32824)).Value);
                    Scan_Rate=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32841)).Value);
                    
                    Vertical_Sn=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33028)).Value)/(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32980)).Value);
                    Vertical_kn=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33076)).Value)/(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==33028)).Value);
                    
                    Details_Img=struct(...
                        'Type', Type,...
                        'x_Origin', x_Origin,...
                        'y_Origin', y_Origin,...
                        'Scanangle', scanangle,...
                        'x_scan_length', x_scan_length,...
                        'y_scan_length', y_scan_length,...
                        'x_scan_pixels', x_scan_pixels,...
                        'y_scan_pixels', y_scan_pixels,...
                        'I_Gain', I_Gain,...
                        'Reference_Amp', Reference_Amplitude,...
                        'Set_Amplitude', Set_Amplitude,...
                        'Oscillation_Freq', Oscillation_Freq,...
                        'Regerence_Ph_Shift', Reference_Phase_shift,...
                        'Scan_Rate', Scan_Rate,...
                        'Vertical_Sn', Vertical_Sn,...
                        'Vertical_kn', Vertical_kn);
                    
                else
                    error('Code not valid for type of AFM imaging...')
                end
                
                
            else
                % start processing the data
                waitbar(i/number_of_images,wb,sprintf('Loading Channel %.0f of %.0f',i,number_of_images));
                
                % extract the name of the channel
                Channel_Name=(file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32850)).Value);
                % extract and put in cell array more details
                strsp=(strsplit((file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32851)).Value)))';
                % check if the scan is retrace or trace and make a flag
                for k=1:size(strsp,1)
                    if(strcmp(strsp{k,1},'retrace')==1)
                        if(strcmp(strsp{k+2,1},'true'))
                            trace_type_flag='ReTrace';
                        else
                            trace_type_flag='Trace';
                        end
                        break
                    end
                end
                
                % in order to take the z values matrix of each image, take the
                % coefficients to fix the z values
                type_of_ch=file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32897)).Value;
                               
                if(strcmp(type_of_ch,'nominal')||(strcmp(type_of_ch,'voltsamplitude')))
                    m_ID=33028;
                    off_ID=33029;
                elseif ((strcmp(type_of_ch,'force'))||(strcmp(type_of_ch,'calibrated'))||(strcmp(type_of_ch,'distanceamplitude')))
                    m_ID=33076;
                    off_ID=33077;
                elseif(strcmp(type_of_ch,'volts'))
                    typpe_of_ch_det=file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==32848)).Value;
                    if(strcmp(typpe_of_ch_det,'capacitiveSensorXPosition'))||(strcmp(typpe_of_ch_det,'servoDacY'))||(strcmp(typpe_of_ch_det,'servoDacX'))||(strcmp(typpe_of_ch_det,'capacitiveSensorYPosition'))
                        m_ID=33028;
                        off_ID=33029;
                    else
                        m_ID=32980;
                        off_ID=32981;
                    end
                else
                    m_ID=32980;
                    off_ID=32981;
                end  
                multiplyer=file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==m_ID)).Value;
                offset=file_info(i).UnknownTags(find([file_info(i).UnknownTags.ID]==off_ID)).Value;
                %extract image data (Z values) with imgread
                if(~strcmp(Channel_Name,'Vertical Deflection'))
                    afm_image=((double(imread(complete_path_to_afm_file,i))*multiplyer))+offset;
                else
                    if(strcmp(Bline_adjust,'No'))
                        afm_image=((double(imread(complete_path_to_afm_file,i))*multiplyer))+offset;
                    else
                        Details_Img.Baseline_N=(Baseline_Raw*multiplyer)+offset;
                        afm_image=((double(imread(complete_path_to_afm_file,i))*multiplyer))+offset;
                    end
                end
                
                %organize the all the important data into a struct var
                Image(i-1)=struct(...
                    'Channel_name',...
                    Channel_Name,...
                    'Signal_type',...
                    type_of_ch,...
                    'Trace_type',...
                    trace_type_flag,...
                    'Raw_afm_image',...
                    imread(complete_path_to_afm_file,i),...
                    'Scale_factor',...
                    multiplyer,...
                    'Offset',...
                    offset,...
                    'AFM_image',...
                    afm_image); %#ok<AGROW>
            end
            
            %if cancel is clicked, stop and delete dialog
            if(exist('wb','var'))
                if getappdata(wb,'canceling')
                    delete (wb)
                    break
                end
            end
        end
        delete (wb)
        [~,index] = sortrows({Image.Channel_name}.'); Image = Image(index); clear index
        % save the output image data. NOTE: the data is already expressed in the correct unit.
        % I.E. lateral deflection data is expressed in Volt
        varargout{1}=Image;
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
        
        j=1;f=0;g=1;Conversion_Set_Id=0;Encoder_Id=0;
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