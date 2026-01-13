function varargout = A1_openANDprepareAFMdata(varargin)
    %%%% prepare the directories where to store the data and figures. Then open .jpk files and prepare them. If there are more
    %%%% files than one, re-organize in cell array
        
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)    
    %init instance of inputParser
    p=inputParser();
    argName = 'filePath';                   defaultVal = '';        addParameter(p,argName,defaultVal, @(x) ischar(x));
    argName = 'frictionData';               defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,varargin{:});
    if isempty(p.Results.filePath)
        filePath=pwd;
    else
        filePath=p.Results.filePath;
    end
    % select the files from the specific experiment, sample and scan
    if strcmp(p.Results.frictionData,'Yes')
        [fileNameSections, filePathData] = uigetfile({'*.jpk'},'Select the .jpk AFM image to extract background friction coefficient',filePath,'MultiSelect', 'on');
    else
        [fileNameSections, filePathData] = uigetfile({'*.jpk'},'Select a .jpk AFM image',filePath,'MultiSelect', 'on');       
    end
    clear filePath
    if isequal(fileNameSections,0)
        error('No File Selected');
    else
        if iscell(fileNameSections)
            numFiles = length(fileNameSections);
        else
            numFiles = 1; % if only one file, filename is a string
            % note: single scan image suppose they are entire scan, which is not recommended to use because of
            % unupdated baseline which will be used to correct vertical deflection data
        end
    end

    %%% establish the name of >>>> nameSaveFigFolder <<<< to save the useful figures into a directory    
        % adjust name folder depending of which type of data is processing (HVon ==> normal, HVoff ==> friction)
    if ~strcmp(p.Results.frictionData,'Yes')       
        nameDir='Results Processing AFM and fluorescence images';    
        if numFiles>1
            nameDir=sprintf("%s - Assembled",nameDir);        
        else
            [~,nameDir]=sprintf("%s - %s",nameDir,fileparts(fileNameSections));
        end       
        % define the entire path of the directory where to save all figures
        [upperFolder,~,~]=fileparts(fileparts(filePathData));
        SaveFigFolder = fullfile(upperFolder,nameDir);
        % check if dir already exists
        if exist(SaveFigFolder, 'dir')
            question= sprintf('Directory already exists and it may already contain previous results.\nDo you want to overwrite it or create new directory?');
            options= {'Overwrite the existing dir','Create a new dir'};
            if getValidAnswer(question,'',options) == 1
                rmdir(SaveFigFolder, 's');
            else
                % create new directory with different name
                nameSaveFigFolder = inputdlg('Enter the name new folder','',[1 80]);
                SaveFigFolder = fullfile(upperFolder,nameSaveFigFolder{1});
            end
        end
        mkdir(SaveFigFolder);
        clear question options argName defaultVal upperFolder nameSaveFigFolder nameDir varargin
        varargout{3}=SaveFigFolder;
    end   
    % init OUTPUT vars
    allData=struct();
    otherParameters=struct();
    % init vars that will be used only in this function
    x_scan_lengthAllScans=zeros(1,numFiles);
    x_scan_pixelsAllScans=zeros(1,numFiles);
    alphaAllScans=zeros(1,numFiles);
    setpointN=zeros(1,numFiles);
    
    prevV_flag=false;
    answAnomalyVertParameters=1;
    % start to extract data from each file/section
    for i=1:numFiles        
        if numFiles>1
            fprintf('Extracting the file %d over %d\n',i,numFiles)            
            fullName=fullfile(filePathData,fileNameSections{i});
        else
            % if only one file, the var is not a cell
            fullName=fullfile(filePathData,fileNameSections);
        end      
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_feature_Open_JPK(fullName);
        % for unknown reasons, some jpk file have wrong and unreasonable vertical calibrations. So it is better to check the metadata!        
        vSn=metaData.Vertical_Sn;
        vKn=metaData.Vertical_kn;
        % the other sections must have all the same vertical parameters, therefore, store and check for each section
        if i==1, fprintf('\tVertical_Sn: %d\n\tVertical_kn: %d\n',vSn,vKn), end
        % check anomaly presence (still don't know why sometimes it occurs. It's very rare but check anyway!)
        if vSn > 1e-6 || vKn > 0.9
            question=sprintf(['Anomaly in the vertical parameters!\n' ...
                '\tVertical_Sn: %d\n\tVertical_kn: %d\n'],vSn,vKn);
            options={'Keep the current vertical parameters',...
                'Enter manually the corrected values (or automatically take from the previous section if already entered)'};
            answAnomalyVertParameters= getValidAnswer(question,'',options,2);
        end
        % if the correction choice is selected. The var is initially empty
        if answAnomalyVertParameters==2
            % enter the new vertical parameters for the first section. From the second section, it takes these values
            % automatically
            if ~prevV_flag
                vertParameters=zeros(2,1);
                question ={'Enter the sensitivity kn [m/V]:','Enter the spring constant Sn [nN/m]:'};
                while true
                    vertParameters = str2double(inputdlg(question,'Setting parameters for the alignment',[1 80]));
                    if any(isnan(vertParameters)), questdlg('Invalid input! Please enter a numeric value','','OK','OK');
                    else, break
                    end
                end
                prevV_flag=true;
            end
            % correct the metadata and the anomaly correction flag for the i-th section (auto correction)
            metaData.Vertical_kn=vertParameters(1);
            metaData.Vertical_Sn=vertParameters(2)*1e-9;
            factor=metaData.Vertical_kn*metaData.Vertical_Sn; 
            metaData.Alpha=factor*14.75;
            metaData.SetP_N=metaData.SetP_V*factor;
            metaData.Baseline_N=metaData.Baseline_V*factor;
            metaData.AnomalyCorrected=true;
        end

        %%%% after doing a lot of investigations, it was discovered that the (measured) vertical force 
        %%%% is actually not correct because it exclude the baseline correction (even if during the experiment was enabled
        %%%% by default), therefore vertical deflection is exactly what the detector reads, excluding the baseline correction.
        %%%% So baseline correction needs to be applied also in (measured) vertical deflection         
        % find the Vertical Deflection channel of the data
        for j=1:length(data)
            if strcmp(data(j).Channel_name,'Vertical Deflection')
                % in case of the anomaly of vertical parameters, use the vertical deflection in volt rather
                % than force and convert with the corrected values. First double check if the average of
                % meaured vertical force is numerically exaggerated. What we can be sure is that the volt data is
                % more trustful than newton
                if strcmp(data(j).Signal_type,'Force_N') & prevV_flag
                    Data_VD_forceAnomaly=data(j).AFM_image;
                    avgData_VD_forceAnomaly=mean(Data_VD_forceAnomaly(:));
                    question=sprintf(['Since the anomaly occurred, double-check the vertical deflection expressed in newton.\n' ...
                        'Averaged vertical deflection = %.2f\n' ...
                        'Convert the vertical deflection from Volt into Newton using the corrected vertical parameters?'],avgData_VD_forceAnomaly);
                    if getValidAnswer(question,'',{'yes','no'})
                        corr_data_VD_force = data(j).AFM_image*factor;
                        data(j).AFM_image = corr_data_VD_force;
                    end
                end

                % if the vertical deflection is expressed in volts, then convert into force
                % (first versions of experimentPlanner didnt allowed working in newton units as setpoint)
                if strcmp(data(j).Signal_type,'Volt_V')
                    fprintf('\t Original Vertical Deflection in Volts ==> converted to Force unit\n')
                    raw_data_VD_volt=data(j).AFM_image;
                    raw_data_VD_force = raw_data_VD_volt*metaData.Vertical_kn*metaData.Vertical_Sn;     % F (N) = V (V) * Sn (m/V) * Kn (N/m)       
                    data(j).AFM_image = raw_data_VD_force;
                    data(j).Signal_type = 'Force_N';
                end
                %%%%%%%%%%%%%%%%%%% 
                % ADJUST THE RAW VERTICAL FORCE WITH THE BASELINE
                %%%%%%%%%%%%%%%
                data(j).AFM_image = data(j).AFM_image - metaData.Baseline_N;
            end
        end
        
        % extract the setpoint information from metadata. In case of single scan in which setpoint
        % has changed manually (which is technically wrong), then put manually
        if numFiles> 1
            setpointN(i)=metaData.SetP_N;
        else            
            % extract the applied setpoint of each section as average of fast lines. Also, extract the idx of
            % each section
            data_VD_trace=  data(strcmp([data.Channel_name],'Vertical Deflection') & strcmp([data.Trace_type],'ReTrace')).AFM_image;
            [setpointN,idxSet]=unique(round(mean(data_VD_trace,2),9),'stable'); %expressed in nanoNewton. Dont sort
            % store the setpoint
            metaData.SetP_N=setpointN;
            % store the position and size of each found sections. They will be likely not regular
            yScanPixel=zeros(1,length(idxSet));
            for j=1:length(idxSet)-1
                yScanPixel(j)=idxSet(j+1)-idxSet(j);
            end
            yScanPixel(end)=size(data_VD_trace,2)-idxSet(end);
            metaData.y_scan_pixels=yScanPixel;
            clear v_num question v valueDefault
        end
               
        % remove not useful channels before processing. Not show the figures. It will be done later
        filtData=A1_feature_CleanOrPrepFiguresRawData(data,'cleanOnly',true);
        
        % store the data in a big struct var       
        if numFiles>1
            allData(i).filenameSection=fileNameSections{i};
        else
            % if only one file, the var is not a cell
            allData(i).filenameSection=fileNameSections;
        end   
        allData(i).metadata=metaData;
        allData(i).setpointN=setpointN(i);
        allData(i).AFMImage_Raw=filtData;
        varargout{1}=allData;
        %%%%%% Extract important parameters from metadata to check the integrity of the data %%%%%%
        % y slow direction (rows) | x fast direction (columns)
        % these parameters will be used just before the assembling, so just storing
        otherParameters(i).y_OriginAllScans=metaData.y_Origin_m;
        otherParameters(i).y_scan_lengthAllScans=metaData.y_scan_length_m;
        otherParameters(i).y_scan_pixelsAllScans=metaData.y_scan_pixels;
        otherParameters(i).SetP_V_AllScans=metaData.SetP_V;
        otherParameters(i).SetP_N_AllScans=metaData.SetP_N;   
        otherParameters(i).Baseline_V_AllScans=metaData.Baseline_V;
        otherParameters(i).Baseline_N_AllScans=metaData.Baseline_N;
        varargout{2}=otherParameters;
        % save other parameters (alpha, x_lengt and x_pixels) that will be used for additional
        % checks just after the end of file extraction. They are already stored in metadata in allData var       
        % if different x_length ==> no sense! slow fast scan lines should be equally long
        % if different x_pixels ==> as before, but also matrix error concatenation!
        % if different alpha    ==> it means that different vertical calibrations are performed,
        %                           which it is done % when a new experiment is started, but not
        %                           when different sections from the single experiment are done                 
        alphaAllScans(i)=metaData.Alpha;     
        x_scan_lengthAllScans(i)=metaData.x_scan_length_m;
        x_scan_pixelsAllScans(i)=metaData.x_scan_pixels;
    end    
    clear answAnomalyVertParameters data fileNameSections filePathData i j metaData numFiles p prevV_flag setpointN vKn vSn fullName filtData
          
    %%%% DATA INTEGRITY CHECK AMONG THE DIFFERENT SECTIONS %%%%
    % error check: each section must be geometrically the same in term of length and pixels!
    % x direction = fast direction. Y direction may be not exactly the same, especially the last section
    if ~all(alphaAllScans == alphaAllScans(1)) || ...
       ~all(x_scan_lengthAllScans == x_scan_lengthAllScans(1)) || ...
       ~all(x_scan_pixelsAllScans == x_scan_pixelsAllScans(1))        
        error(sprintf('ERROR: the x length/pixel and/or alpha calibration factor (thus vertical parameters) of some sections are not the same!!\n\tCheck the uploaded data!!'))
    end
    % Further checks: the total scan area should be a square in term of um and pixels
    y_scan_totalLength_m= sum([otherParameters.y_scan_lengthAllScans]); 
    ratioLength=x_scan_lengthAllScans(1)/y_scan_totalLength_m;
    if round(ratioLength,4) ~= 1.0
        warning('\n\ttratioLengthXY: %.2f\nX length is not the same as well as the Y length!!',ratioLength)
    end
    clear alphaAllScans ratioLength x_scan_lengthAllScans y_scan_totalLength_m x_scan_pixelsAllScans
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)    
end


