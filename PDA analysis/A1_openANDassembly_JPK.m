function varargout = A1_openANDassembly_JPK(secondMonitorMain,varargin)
    %%%% the funtion open .jpk files. If there are more files than one, then assembly togheter before process
    %%%% them
    %%%% IMPORTANT NOTE: the sum area of any section must be a square
    %%% EXAMPLES
    %%% 1) total area: 50x50 um2 and 1024x1024 pixels and if 4 sections are performed (each with a different
    %%%     setpoint)   ==> 50x10 um2 and 1024x256 pixels !!
    %%% 2) total area: 40x40 um2 and 512x512 pixels and if 8 sections are performed (each with a different
    %%%     setpoint)   ==> 40x10 um2 and 512x64 pixels !!
    
    
    
    % OUTPUT:
    % 1) AFM_HeightFittedMasked     ==> contains all the channels but the Height Image data is adjusted
    % 2) AFM_height_IO              ==> Height Image data adjusted and then transformed into 0 (BK) and 1 (crystal) values 
    % 3) metaData
    % 4) newFolder;                 ==> path where the results and figures will be saved
    % 5) setpointN;
    
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    
    %init instance of inputParser
    p=inputParser();
    argName = 'Silent';                 defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'Normalization';          defaultVal = false;     addParameter(p,argName,defaultVal, @(x) islogical(x));
    argName = 'filePath';               defaultVal = '';        addParameter(p,argName,defaultVal, @(x) ischar(x));
    argName = 'backgroundOnly';         defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'FitOrder';               defaultVal = 'Low';     addOptional(p,argName,defaultVal, @(x) ismember(x,{'Low','Medium','High'}));
    % validate and parse the inputs
    parse(p,varargin{:});
    silent=p.Results.Silent;
    norm=p.Results.Normalization;
    if isempty(p.Results.filePath)
        filePath=pwd;
    else
        filePath=p.Results.filePath;
    end
    % select the files
    if strcmp(p.Results.backgroundOnly,'Yes')
        [fileName, filePathData] = uigetfile({'*.jpk'},'Select the .jpk AFM image to extract background friction coefficient',filePath,'MultiSelect', 'on');
    else
        [fileName, filePathData] = uigetfile({'*.jpk'},'Select a .jpk AFM image',filePath,'MultiSelect', 'on');       
    end
    accuracy=p.Results.FitOrder;

    if isequal(fileName,0)
        error('No File Selected');
    else
        if iscell(fileName)
            numFiles = length(fileName);
        else
            numFiles = 1; % if only one file, filename is a string
            % note: single scan image suppose they are entire scan, which is not recommended to use because of
            % unupdated baseline which will be used to correct vertical deflection data
        end
    end

    % save the useful figures into a directory
    if strcmp(p.Results.backgroundOnly,'Yes') && numFiles~=1
        [upperFolder,~,~]=fileparts(fileparts(filePathData));
        newFolder = fullfile(upperFolder, 'Results Processing AFM-background for friction coefficient');
    elseif strcmp(p.Results.backgroundOnly,'Yes') && numFiles==1
        [~,nameFile,~]=fileparts(fileName);
        newFolder = fullfile(filePathData, sprintf('Results Processing AFM-background for friction coefficient - %s',nameFile));
    else % in case normal scans
        if numFiles==1
            [~,nameFile]=fileparts(fileName);
        else
            nameFile='Entire Section Assembled';
        end
        [upperFolder,~,~]=fileparts(fileparts(filePathData));
        newFolder = fullfile(upperFolder, sprintf('Results Processing AFM and fluorescence images - %s',nameFile));
    end
    % check if dir already exists
    if exist(newFolder, 'dir')
        question= sprintf('Directory already exists and it may already contain previous results.\nDo you want to overwrite it or create new directory?');
        options= {'Overwrite the existing dir','Create a new dir'};
        if getValidAnswer(question,'',options) == 1
            rmdir(newFolder, 's');
            mkdir(newFolder);
        else
            % create new directory with different name
            nameFolder = inputdlg('Enter the name new folder','',[1 80]);
            newFolder = fullfile(upperFolder,nameFolder{1});
            mkdir(newFolder);
            clear nameFolder
        end
    else
        mkdir(newFolder);
    end

    clear question options argName defaultVal
    % init variables
    allScansImageSTART=cell(1,numFiles);
    allScansMetadata=cell(1,numFiles);
    y_OriginAllScans=zeros(1,numFiles);
    y_scan_lengthAllScans=zeros(1,numFiles);
    y_scan_pixelsAllScans=zeros(1,numFiles);
    x_scan_lengthAllScans=zeros(1,numFiles);
    x_scan_pixelsAllScans=zeros(1,numFiles);
    alphaAllScans=zeros(1,numFiles);
    setpointN=zeros(1,numFiles);
    SetP_V_AllScans=zeros(1,numFiles);
    SetP_N_AllScans=zeros(1,numFiles);
    Baseline_V_AllScans=zeros(1,numFiles);
    Baseline_N_AllScans=zeros(1,numFiles);
    
    prevV_flag=false;
    answ=[];
    for i=1:numFiles
        if numFiles>1
            fprintf('Processing the file %d over %d\n',i,numFiles)
            imgTyp = 'Assembled';
            fullName=fullfile(filePathData,fileName{i});
        else
            % if only one file, the var is not a cell
            fullName=fullfile(filePathData,fileName);
            imgTyp = 'Entire';
        end      
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_feature_Open_JPK(fullName);
        % for unknown reasons, some jpk file have wrong and unreasonable vertical calibrations.
        % so it is better to check the metadata!
        
        vSn=metaData.Vertical_Sn;
        vKn=metaData.Vertical_kn;
        % the other sections must have all the same vertical parameters
        if i==1, fprintf('\tVertical_Sn: %d\n\tVertical_kn: %d\n',vSn,vKn), end
        % check anomaly presence (still don't know why sometimes it occurs. It's very rare but check anyway!)
        if vSn > 1e-6 || vKn > 0.9
            question=sprintf(['Anomaly in the vertical parameters!\n' ...
                '\tVertical_Sn: %d\n\tVertical_kn: %d\n'],vSn,vKn);
            options={'Keep the current vertical parameters',...
                'Enter manually the corrected values (or automatically take from the previous section if already entered)'};
            answ= getValidAnswer(question,'',options,2);
        end
        % if the correction choice is selected
        if answ==2
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

        % after doing a lot of investigations, it was discovered that the (measured) vertical force 
        % is actually not correct because it exclude the baseline correction (even if during the experiment was enabled
        % by default), therefore vertical deflection is exactly what the detector reads, excluding the baseline correction.
        % So baseline correction needs to be applied also in (measured) vertical deflection         
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
            % PREVIOUS VERSION: MANUAL. ==> not necessary anymore since the issue about the shifted vertical force has been solved
            %{
            %use the only available setpoint in metadata of the section-scan file as default. Then increase by 20
            firstSetpoint=metaData.SetP_N*1e9;
            valueDefault = string(firstSetpoint); j=1; setpointN = [];
            while true
                question = sprintf('Enter the used setpoint [nN] for the section %d. Click ''Cancel'' to terminate.',j);    
                v_num = str2double(inputdlg(question,'',[1 40],valueDefault));
                if isempty(v_num)
                    break
                elseif ~isnan(v_num)
                    setpointN = [setpointN, v_num]; %#ok<AGROW>
                    valueDefault= string(v_num+20);
                else
                    uiwait(msgbox(sprintf('Invalid input! Please enter a numeric value or terminate. '),''));
                end
                j=j+1;
            end
            setpointN=setpointN*1e-9;
            %} 
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
            
        % remove not useful information prior the process. Not show the figures. Later
        % setpoint array here is useless. putted to avoid error
        filtData=A2_CleanUpData2_AFM(data,setpointN,secondMonitorMain,newFolder,'cleanOnly','Yes');
        % save the sections before and after the processing
        allScansImageSTART{i}=filtData;
        allScansMetadata{i}=metaData;

        % y slow direction (rows) | x fast direction (columns)
        % save alpha, x_lengt and x_pixels to check errors later
        % if different x_length ==> no sense! slow fast scan lines should be equally long
        % if different x_pixels ==> as before, but also matrix error concatenation!
        % if different alpha    ==> it means that different vertical calibrations are performed,
        %                           which it is done % when a new experiment is started, but not
        %                           when different sections from the single experiment are done  
        alphaAllScans(i)=allScansMetadata{i}.Alpha;     
        y_OriginAllScans(i)=allScansMetadata{i}.y_Origin_m;
        y_scan_lengthAllScans(i)=allScansMetadata{i}.y_scan_length_m;
        x_scan_lengthAllScans(i)=allScansMetadata{i}.x_scan_length_m;
        if numFiles==1
            y_scan_pixelsAllScans=allScansMetadata{i}.y_scan_pixels;
        else
            y_scan_pixelsAllScans(i)=allScansMetadata{i}.y_scan_pixels;
        end
        x_scan_pixelsAllScans(i)=allScansMetadata{i}.x_scan_pixels;
        SetP_V_AllScans(i)=allScansMetadata{i}.SetP_V;
        if numFiles==1
            SetP_N_AllScans=allScansMetadata{i}.SetP_N;
        else
            SetP_N_AllScans(i)=allScansMetadata{i}.SetP_N;
        end
        Baseline_V_AllScans(i)=allScansMetadata{i}.Baseline_V;
        Baseline_N_AllScans(i)=allScansMetadata{i}.Baseline_N;
    end

    % error check: each section must be geometrically the same in term of length and pixels!
    % x direction = fast direction. Y direction may be not exactly the same, especially the last section
    if ~all(alphaAllScans == alphaAllScans(1)) || ...
       ~all(x_scan_lengthAllScans == x_scan_lengthAllScans(1)) || ...
       ~all(x_scan_pixelsAllScans == x_scan_pixelsAllScans(1))        
        error(sprintf('ERROR: the x length/pixel and/or alpha calibration factor (thus vertical parameters) of some sections are not the same!!\n\tCheck the uploaded data!!'))
    end
    % check the origin offset information and properly sort data and metadata
    [~,idx]=sort(y_OriginAllScans);
    allScansImageOrderedSTART=allScansImageSTART(idx);
    allScansMetadataOrdered=allScansMetadata(idx);
    % copy common data fields by copying just the first row (The data will be overwritten):
    %   Channel_name
    %   Trace_type
    %   AFM data
    dataOrderedSTART=allScansImageOrderedSTART{1};
    clear allScansMetadata allScansImageSTART allScansImageEND metaData data alphaAllScans x_scan_pixelsAllScans x_scan_lengthAllScans
    metaDataOrdered= allScansMetadataOrdered{1};
    if numFiles>1
    % adjust the metaData, in particular:
    %       y_Origin
    %       y_scan_length
    %       y_scan_pixels
    %       Baseline_V
    %       Baseline_N
    %       SetP_V
    %       SetP_m
    %       SetP_N
    % the others don't change. 
    % since it is ordered, the first element already contains the true y_Origin        
        % in case of y lenght, just sum single y lenght of each section to have entire scan size
        metaDataOrdered.y_scan_length_m= sum(y_scan_lengthAllScans);
        % in case of y pixel, keep the pixel value of each section. This information is valuable especially for
        % friction experiment method 1 which it needs to separate the section depending on setpoint
        metaDataOrdered.y_scan_pixels= y_scan_pixelsAllScans(idx);
        % in case of setpoints and baseline, create an array if more sections. For newton values, round a little a bit the values
        metaDataOrdered.SetP_V=SetP_V_AllScans(idx);
        metaDataOrdered.SetP_N=round(SetP_N_AllScans(idx),9);
        metaDataOrdered.Baseline_V=Baseline_V_AllScans(idx);
        metaDataOrdered.Baseline_N=round(Baseline_N_AllScans(idx),12);
    end
    % Further checks: the total scan area should be a square in term of um and pixels
    ratioLength=metaDataOrdered.x_scan_length_m\metaDataOrdered.y_scan_length_m;
    if round(ratioLength,4) ~= 1.0
        warning('\n\ttratioLengthXY: %.2f\nX length is not the same as well as the Y length!!',ratioLength)
    end
    clear y_scan_pixelsAllScans y_scan_lengthAllScans y_OriginAllScans ratioLength ratioPixel idx allScansMetadataOrdered j i

    % ASSEMBLY BY CONCATENATION
    for i=1:size(dataOrderedSTART,2)
        % assembly the pre processed single sections
        concatenatedData_Raw_afm_image=[];
        concatenatedData_AFM_image_START=[];

        for j=numFiles:-1:1            
            dataRAW=flip(allScansImageOrderedSTART{j}(i).Raw_afm_image);
            concatenatedData_Raw_afm_image      = cat(1,concatenatedData_Raw_afm_image,dataRAW);
            dataIMAGE=flip(allScansImageOrderedSTART{j}(i).AFM_image);
            concatenatedData_AFM_image_START    = cat(1,concatenatedData_AFM_image_START,dataIMAGE);
            if numFiles>1
                sizeSections(j)=size(dataRAW,1);
            else
                sizeSections=[];
            end
        end

        dataOrderedSTART(i).Raw_afm_image= flip(concatenatedData_Raw_afm_image);
        dataOrderedSTART(i).AFM_image=flip(concatenatedData_AFM_image_START);
    end
    
    % show and save figures post assembly
    A2_CleanUpData2_AFM(dataOrderedSTART,setpointN,secondMonitorMain,newFolder,'metadata',metaDataOrdered,'imageType',imgTyp,'Silent',silent,'Normalization',norm,'sectionSize',sizeSections);
    % process the data (A3 and A4 to create optimized and 0\1 height images
    [AFM_HeightFittedMasked,AFM_height_IO,~]=processData(dataOrderedSTART,secondMonitorMain,newFolder,accuracy,silent);
    % save the outputs
    varargout{1}=AFM_HeightFittedMasked;
    varargout{2}=AFM_height_IO;
    varargout{3}=metaDataOrdered;
    varargout{4}=newFolder;
    varargout{5}=setpointN;
end

function [AFM_HeightFittedMasked,AFM_height_IO,accuracy]=processData(data,secondMonitorMain,newFolder,accuracy,silent)
    iterationMain=1;
    while true
        [AFM_HeightFitted,AFM_height_IO]=A3_El_AFM(data,iterationMain,secondMonitorMain,newFolder,'fitOrder',accuracy,'Silent',silent);
        % Using the AFM_height_IO, fit the background again, yielding a more accurate height image by using the
        % 0\1 height image
        [AFM_HeightFittedMasked,AFM_height_IO]=A4_El_AFM_masked(AFM_HeightFitted,AFM_height_IO,iterationMain,secondMonitorMain,newFolder,'Silent',silent);
        % ask if re-run the process to obtain better AFM height image 0/1
        if ~getValidAnswer('Run again A3 and A4 to create better optimized mask and height AFM image?','',{'y','n'},2)
            break
        else
            iterationMain=iterationMain+1;
            data=AFM_HeightFittedMasked;
        end
    end
end