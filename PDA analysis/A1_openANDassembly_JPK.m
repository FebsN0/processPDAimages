function varargout = A1_openANDassembly_JPK(secondMonitorMain,varargin)
    %%%% the funtion open .jpk files. If there are more files than one, then assembly togheter before process
    %%%% them
    %%%% IMPORTANT NOTE: the sum area of any section must be a square
    %%% EXAMPLES
    %%% 1) total area: 50x50 um2 and 1024x1024 pixels and if 4 sections are performed (each with a different
    %%%     setpoint)   ==> 50x10 um2 and 1024x256 pixels !!
    %%% 2) total area: 40x40 um2 and 512x512 pixels and if 8 sections are performed (each with a different
    %%%     setpoint)   ==> 40x10 um2 and 512x64 pixels !!
    allWaitBars = findall(0,'type','figure','tag','TMWWaitbar');
    delete(allWaitBars)
    
    %init instance of inputParser

    p=inputParser();
    argName = 'Silent';                 defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'saveFig';                defaultVal = 'Yes';     addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'Normalization';          defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    argName = 'filePath';               defaultVal = '';        addParameter(p,argName,defaultVal, @(x) ischar(x));
    argName = 'backgroundOnly';         defaultVal = 'No';      addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,varargin{:});
    silent=p.Results.Silent;
    saveFig=p.Results.saveFig;
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

    if isequal(fileName,0)
        error('No File Selected');
    else
        if iscell(fileName)
            numFiles = length(fileName);
        else
            numFiles = 1; % if only one file, filename is a string
        end
    end

    % save the useful figures into a directory. Not in the case of sections to save time.
    % in case of sections, only the assembled version will be saved

    if strcmp(p.Results.backgroundOnly,'Yes') && numFiles~=1
        [upperFolder,~,~]=fileparts(fileparts(filePathData));
        newFolder = fullfile(upperFolder, 'Results Processing AFM-background only');
    elseif strcmp(p.Results.backgroundOnly,'Yes') && numFiles==1
        [~,nameFile,~]=fileparts(fileName);
        newFolder = fullfile(filePathData, sprintf('Results Processing AFM-background only _ %s',nameFile));
    else % in case normal scans
        if numFiles==1
        [~,nameFile]=fileparts(fileName);
        else
            nameFile='Entire Section';
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


    flag_processSignleSections=false;
    if numFiles > 1
        question= sprintf('Process single sections before assembling (usually no)?');
        options= {'Yes','No'};
        if getValidAnswer(question,'',options,2) == 1
            flag_processSignleSections=true;
        end
        imgTyp = 'Assembled';
    else
        %if only one file, the var is not a cell
        fullName=fullfile(filePathData,fileName);
        imgTyp = 'Entire';
    end

    clear question options argName defaultVal
    % init variables
    allScansImageSTART=cell(1,numFiles);
    if flag_processSignleSections
        allScansImageEND=cell(1,numFiles);
        allScans_AFM_HeightIO=cell(1,numFiles);
    end
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
            fullName=fullfile(filePathData,fileName{i});
        end
        if i==1, accuracy=''; end
       
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_open_JPK(fullName);
        % for unknown reasons, some jpk file have wrong and unreasonable vertical calibrations.
        % so it is better to check the metadata!
        
        vSn=metaData.Vertical_Sn;
        vKn=metaData.Vertical_kn;
        % the other sections have all the same vertical parameters
        if i==1, fprintf('\tVertical_Sn: %d\n\tVertical_kn: %d\n',vSn,vKn), end

        if vSn > 1e-6 || vKn > 0.9
            question=sprintf(['Anomaly in the vertical parameters!\n' ...
                '\tVertical_Sn: %d\n\tVertical_kn: %d\n'],vSn,vKn);
            options={'Keep the current vertical parameters',...
                'Enter manually the corrected values (or automatically take from the previous section if already entered)'};
            answ= getValidAnswer(question,'',options,2);
        end

        if answ==2
            % for the first section. From the second use the same vertical parameters without asking
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
            % correct the metadata and the anomaly correction flag
            metaData.Vertical_kn=vertParameters(1);
            metaData.Vertical_Sn=vertParameters(2)*1e-9;
            factor=metaData.Vertical_kn*metaData.Vertical_Sn; 
            metaData.Alpha=factor*14.75;
            metaData.SetP_N=metaData.SetP_V*factor;
            metaData.Baseline_N=metaData.Baseline_V*factor;
            metaData.AnomalyCorrected=true;
        end


        % after doing a lot of investigations, it was discovered that the vertical force (measured)
        % is actually not correct because it exclude the baseline correction, therefore vertical deflection is
        % exactly what the detector reads, excluding the baseline correction. So baseline correction needs
        % to be applied also in vertical deflection         
        for j=1:length(data)
            if strcmp(data(j).Channel_name,'Vertical Deflection')
                % in case of the anomaly of vertical parameters, use the vertical deflection in volt rather
                % than force and convert with the corrected values. First double check if the average of
                % meaured vertical force is numerically exaggerated. What we can be sure is that the volt is
                % more trustful than newton
                if strcmp(data(j).Signal_type,'Force_N') & prevV_flag
                    Data_VD_forceAnomaly=data(j).AFM_image;
                    avgData_VD_forceAnomaly=mean(Data_VD_forceAnomaly(:));
                    question=sprintf(['Since the anomaly occurred, double-check the vertical deflection expressed in newton.\n' ...
                        'Averaged vertical deflection = %.2f\n' ...
                        'Convert the vertical deflection from Volt into Newton using the corrected vertical parameters?'],avgData_VD_forceAnomaly);
                    answ=getValidAnswer(question,'',{'yes','no'});
                    if answ==1
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
        % by default, setpoint start from 30 and increase by 20 nN
            valueDefault = {'30'}; j=1; setpointN = [];
            while true
                question = sprintf('Enter the used setpoint [nN] for the section %d. Click ''Cancel'' to terminate.',j);    
                v_num = str2double(inputdlg(question,'',[1 40],valueDefault));
                if isempty(v_num)
                    break
                elseif ~isnan(v_num)
                    setpointN = [setpointN, v_num]; %#ok<AGROW>
                    valueDefault= string(str2double(valueDefault)+20);
                else
                    uiwait(msgbox(sprintf('Invalid input! Please enter a numeric value or terminate. '),''));
                end
            end
            % express in Newton from nanoNewton
            setpointN=setpointN*1e-9;
            clear v_num question v valueDefault
        end
            
        % remove not useful information prior the process. Not show the figures. Later
        % setpoint array here is useless. putted to avoid error
        filtData=A2_CleanUpData2_AFM(data,setpointN,secondMonitorMain,newFolder,'cleanOnly','Yes');
        % save the sections before and after the processing
        allScansImageSTART{i}=filtData;
        allScansMetadata{i}=metaData;
        % in case the process of single section, dont save and show the single figures not save the post processed data of each section
        if flag_processSignleSections
            [AFM_HeightFittedMasked,AFM_height_IO,accuracy]=processData(filtData,secondMonitorMain,newFolder,accuracy,'Yes','No');
            allScansImageEND{i}=AFM_HeightFittedMasked;
            allScans_AFM_HeightIO{i}=AFM_height_IO;
            clear AFM_height_IO AFM_HeightFittedMasked
        end
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
        y_scan_pixelsAllScans(i)=allScansMetadata{i}.y_scan_pixels;
        x_scan_pixelsAllScans(i)=allScansMetadata{i}.x_scan_pixels;
        SetP_V_AllScans(i)=allScansMetadata{i}.SetP_V;
        SetP_N_AllScans(i)=allScansMetadata{i}.SetP_N;
        Baseline_V_AllScans(i)=allScansMetadata{i}.Baseline_V;
        Baseline_N_AllScans(i)=allScansMetadata{i}.Baseline_N;
    end

    % error check: each section must be geometrically the same in term of length and pixels!
    if ~all(alphaAllScans == alphaAllScans(1)) || ...
       ~all(y_scan_lengthAllScans == y_scan_lengthAllScans(1)) || ...
       ~all(x_scan_lengthAllScans == x_scan_lengthAllScans(1)) || ...
       ~all(y_scan_pixelsAllScans == y_scan_pixelsAllScans(1)) || ...
       ~all(x_scan_pixelsAllScans == x_scan_pixelsAllScans(1))        
        error(sprintf('ERROR: the x lengths and/or alpha calibration factor (thus vertical parameters) of some sections are not the same!!\n\tCheck the uploaded data!!'))
    end
    % check the offset information and properly sort
    [~,idx]=sort(y_OriginAllScans);
    allScansImageOrderedSTART=allScansImageSTART(idx);
    allScansMetadataOrdered=allScansMetadata(idx);
    % copy common data fields by copying just the first row (The data will be overwritten):
    %   Channel_name
    %   Trace_type
    %   AFM data
    dataOrderedSTART=allScansImageOrderedSTART{1};
    if flag_processSignleSections
        allScansImageOrderedEND=allScansImageEND(idx);
        allScans_AFM_HeightIO_ordered=allScans_AFM_HeightIO(idx);
        dataOrderedEND=allScansImageOrderedEND{1};
    end
 
    clear allScansMetadata allScansImageSTART allScansImageEND metaData data alphaAllScans x_scan_pixelsAllScans x_scan_lengthAllScans
    
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
    metaDataOrdered= allScansMetadataOrdered{1};
    metaDataOrdered.y_scan_length_m= sum(y_scan_lengthAllScans);
    metaDataOrdered.y_scan_pixels= sum(y_scan_pixelsAllScans);
    % in case of setpoints and baseline, create an array if different values in case of setpoint
    metaDataOrdered.SetP_V=unique(SetP_V_AllScans(idx));
    metaDataOrdered.SetP_N=unique(SetP_N_AllScans(idx));
    metaDataOrdered.Baseline_V=Baseline_V_AllScans(idx);
    metaDataOrdered.Baseline_N=Baseline_N_AllScans(idx);

    % Further checks: the total scan area should be a square in term of um and pixels
    ratioLength=round(metaDataOrdered.x_scan_length_m\metaDataOrdered.y_scan_length_m,2);
    ratioPixel=round(metaDataOrdered.x_scan_pixels\metaDataOrdered.y_scan_pixels,1);
    if ratioLength ~= 1 || ratioPixel ~= 1
        warning('\n\ttratioLengthXY: %.2f\n\tratioPixelXY %.2f\nX length/pixels is not the same as well as the Y length/pixels!!',ratioLength,ratioPixel)
    end
    clear y_scan_pixelsAllScans y_scan_lengthAllScans y_OriginAllScans ratioLength ratioPixel idx allScansMetadataOrdered j i

    if flag_processSignleSections
        concatenated_AFM_Height_IO = [];
    end
    % ASSEMBLY BY CONCATENATION
    for i=1:size(dataOrderedSTART,2)
        % assembly the pre processed single sections
        concatenatedData_Raw_afm_image=[];
        concatenatedData_AFM_image_START=[];
        % assembly the post processed single sections
        if flag_processSignleSections
            concatenatedData_AFM_image_END=[];
        end

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
            if flag_processSignleSections
                dataPOST=flip(rot90(allScansImageOrderedEND{j}(i).AFM_image));
                concatenatedData_AFM_image_END  = cat(1,concatenatedData_AFM_image_END,dataPOST);
                % no need to process iteratively in case of AFM Height IO image
                if i==1
                    dataIO=flip(rot90(allScans_AFM_HeightIO_ordered{j}));
                    concatenated_AFM_Height_IO  = cat(1,concatenated_AFM_Height_IO,dataIO);
                end
            end
        end

        dataOrderedSTART(i).Raw_afm_image= flip(concatenatedData_Raw_afm_image);
        dataOrderedSTART(i).AFM_image=flip(concatenatedData_AFM_image_START);
        if flag_processSignleSections
            dataOrderedEND(i).AFM_image   = flip(rot90(concatenatedData_AFM_image_END,-1));
        end
    end
    
    % show and save figures post assembly

    [vertForceAVG]=A2_CleanUpData2_AFM(dataOrderedSTART,setpointN,secondMonitorMain,newFolder,'metadata',metaDataOrdered,'imageType',imgTyp,'phaseProcess','Raw','Silent',silent,'SaveFig',saveFig,'Normalization',norm,'sectionSize',sizeSections);
    
    % show and save figures post assembly postProcessing
    if flag_processSignleSections
        A2_CleanUpData2_AFM(dataOrderedEND,secondMonitorMain,newFolder,'imageType',imgTyp,'phaseProcess','PostProcessed','Silent',silent,'SaveFig',saveFig,'Normalization',norm);
        AFM_HeightFittedMasked=dataOrderedEND;
        AFM_height_IO=rot90(concatenated_AFM_Height_IO,-1);
        
        if strcmp(silent,'No')
            f1=figure('Visible','on');
        else
            f1=figure('Visible','off');
        end
        imshow(AFM_height_IO); title('Baseline and foreground processed', 'FontSize',16), colormap parula
        colorbar('Ticks',[0 1],'TickLabels',{'Background','Foreground'},'FontSize',13)
        objInSecondMonitor(secondMonitorMain,f1);
        if strcmp(saveFig,'Yes')
            saveas(f1,sprintf('%s/resultA3_1_fittedHeightChannel_BaselineForeground_Assembled.tif',newFolder))
        end
    else       
        [AFM_HeightFittedMasked,AFM_height_IO,~]=processData(dataOrderedSTART,secondMonitorMain,newFolder,accuracy,silent,saveFig);
        % use this following line just to further check or to get the normalization in a second moment.
        A2_CleanUpData2_AFM(AFM_HeightFittedMasked,setpointN,secondMonitorMain,newFolder,'imageType',imgTyp,'phaseProcess','PostProcessed','Silent',silent,'SaveFig',saveFig,'Normalization','No');
    end

    varargout{1}=AFM_HeightFittedMasked;
    varargout{2}=AFM_height_IO;
    varargout{3}=metaDataOrdered;
    varargout{4}=newFolder;
    varargout{5}=setpointN;
    varargout{6}=vertForceAVG;
end


function [AFM_HeightFittedMasked,AFM_height_IO,accuracy]=processData(data,secondMonitorMain,newFolder,accuracy,silent,saveFig)
    [AFM_HeightFitted,AFM_height_IO,accuracy]=A3_El_AFM(data,secondMonitorMain,newFolder,'fitOrder',accuracy,'Silent',silent,'SaveFig',saveFig);
    % Using the AFM_height_IO, fit the background again, yielding a more accurate height image
    AFM_HeightFittedMasked=A4_El_AFM_masked(AFM_HeightFitted,AFM_height_IO,secondMonitorMain,newFolder,'Silent',silent,'SaveFig',saveFig);
end
