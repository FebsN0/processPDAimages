function [dataOrdered,concatenated_AFM_Height_IO,metaDataOrdered,filePathData,newFolder] = A1_openANDassembly_JPK(secondMonitorMain,varargin)
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
    argName = 'Silent';
    defaultVal = 'Yes';
    addParameter(p,argName,defaultVal, @(x) ismember(x,{'No','Yes'}));
    % validate and parse the inputs
    parse(p,varargin{:});
    if(strcmp(p.Results.Silent,'Yes')); SeeMe=0; else, SeeMe=1; end



    [fileName, filePathData] = uigetfile('*.jpk', 'Select a .jpk AFM image','MultiSelect', 'on');
    if isequal(fileName,0)
        error('No File Selected');
    else
        if iscell(fileName)
            numFiles = length(fileName);
        else
            numFiles = 1; % if only one file, filename is a string
        end
    end



    % save the useful figures into a directory
    newFolder = fullfile(filePathData, 'Results Processing AFM and fluorescence images');
    % check if dir already exists
    if exist(newFolder, 'dir')
        question= sprintf('Directory already exists and it may already contain results.\nDo you want to overwrite it or create new directory?');
        options= {'Overwrite the existing dir','Create a new dir'};
        if getValidAnswer(question,'',options) == 1
            rmdir(newFolder, 's');
            mkdir(newFolder);
        else
            nameFolder = inputdlg('Enter the name new folder','',[1 80]);
            newFolder = fullfile(filePathData,nameFolder{1});
            mkdir(newFolder);
            clear nameFolder
        end
    else
        mkdir(newFolder);
    end



    if numFiles > 1
        question= sprintf('More .jpk files are uploaded. Are they from the same experiment which only setpoint is changed?');
        options= {'Yes','No'};
        if getValidAnswer(question,'',options) ~= 1
            error('Restart again and select only one .jpk file if the more uploaded .jpk are from different experiment')
        end
        flagAFMSections=true;
    else
        %if only one file, the var is not a cell
        fullName=fullfile(filePathData,fileName);
        newSubFolder=newFolder;
        flagAFMSections=false;
    end

    clear question options
    % init variables
    allScansImage=cell(1,numFiles);
    allScans_AFM_HeightIO=cell(1,numFiles);
    allScansMetadata=cell(1,numFiles);
    y_OriginAllScans=zeros(1,numFiles);
    y_scan_lengthAllScans=zeros(1,numFiles);
    y_scan_pixelsAllScans=zeros(1,numFiles);
    x_scan_lengthAllScans=zeros(1,numFiles);
    x_scan_pixelsAllScans=zeros(1,numFiles);
    alphaAllScans=zeros(1,numFiles);
    % EXTRACT ALL DATA
    for i=1:numFiles
        fprintf('Processing file of the section %d\n',i)
        if flagAFMSections
            fullName=fullfile(filePathData,fileName{i});
            %save each section image in different subfolder, otherwise, overwritting
            newSubFolder=sprintf('%s\\section_%d',newFolder,i);
            mkdir(newSubFolder)
        end
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_open_JPK(fullName);
        
        % if the vertical deflection is expressed in volts, then convert into force
        for j=1:length(data)
            if strcmp(data(j).Channel_name,'Vertical Deflection') && strcmp(data(j).Signal_type,'volts')
                fprintf('\t Original Vertical Deflection in Volts ==> converted to Force unit\n')
                raw_data_VD_volt=data(j).AFM_image;
                % imagesc(raw_data_VD_volt), colormap parula, title('Raw data Vertical Deflection volt','FontSize',17), colorbar
                raw_data_VD_force = raw_data_VD_volt*metaData.Vertical_kn*metaData.Vertical_Sn;     % F (N) = V (V) * Sn (m/V) * Kn (N/m)
                % figure
                % imagesc(raw_data_VD_force), colormap parula, title('Raw data Vertical Deflection force','FontSize',17), colorbar
                % raw_data_VD_nanoforce = raw_data_VD_force*1e9;
                % figure
                % imagesc(raw_data_VD_nanoforce), colormap parula, title('Raw data Vertical Deflection nanoforce','FontSize',17), colorbar
                data(j).AFM_image = raw_data_VD_force;
                data(j).Signal_type = 'force';
            end
        end
        
        % Remove unnecessary channels to elaboration (necessary for memory save)
        filtData=A2_CleanUpData2_AFM(data,secondMonitorMain,newSubFolder);
        clear data
        
        if exist('accuracy','var') % after first AFM section, keep the same accuracy
            [AFM_HeightFitted,AFM_height_IO,accuracy]=A3_El_AFM(filtData,secondMonitorMain,newSubFolder,'fitOrder',accuracy);
        else
            [AFM_HeightFitted,AFM_height_IO,accuracy]=A3_El_AFM(filtData,secondMonitorMain,newSubFolder);
        end

        clear filtData
        % Using the AFM_height_IO, fit the background again, yielding a more accurate height image
        AFM_HeightFittedMasked=A4_El_AFM_masked(AFM_HeightFitted,AFM_height_IO,secondMonitorMain,newSubFolder,'Silent','Yes');
        clear AFM_HeightFitted
        
        allScansImage{i}=AFM_HeightFittedMasked;
        allScans_AFM_HeightIO{i}=AFM_height_IO;
        allScansMetadata{i}=metaData;
        % y slow direction (rows) | x fast direction (columns)
        y_OriginAllScans(i)=allScansMetadata{i}.y_Origin;
        y_scan_lengthAllScans(i)=allScansMetadata{i}.y_scan_length;
        x_scan_lengthAllScans(i)=allScansMetadata{i}.x_scan_length;
        y_scan_pixelsAllScans(i)=allScansMetadata{i}.y_scan_pixels;
        x_scan_pixelsAllScans(i)=allScansMetadata{i}.x_scan_pixels;
        % save x_length, x_pixels and alpha to check errors
        % if different x_length ==> no sense! slow fast scan lines should be equally long
        % if different x_pixels ==> as before, but also matrix error concatenation!
        % if different alpha ==> it means that different vertical calibrations are performed, which it is done
        % when a new experiment is started, but not when different sections from the single experiment are
        % done    
        alphaAllScans(i)=allScansMetadata{i}.Alpha;        
    end

    % quick error check: each section is geometrically the same in term of length and pixels!
    if  ~all(alphaAllScans == alphaAllScans(1)) || ...
        ~all(y_scan_lengthAllScans == y_scan_lengthAllScans(1)) || ...
        ~all(x_scan_lengthAllScans == x_scan_lengthAllScans(1)) || ...
        ~all(y_scan_pixelsAllScans == y_scan_pixelsAllScans(1)) || ...
        ~all(x_scan_pixelsAllScans == x_scan_pixelsAllScans(1)) 
        error(sprintf('ERROR: the x lengths and/or alpha calibration factor (thus vertical parameters) of some sections are not the same!!\n\tCheck the uploaded data!!'))
    end
    % check the offset information and properly sort
    [~,idx]=sort(y_OriginAllScans);
    allScansImageOrdered=allScansImage(idx);
    allScans_AFM_HeightIO_ordered=allScans_AFM_HeightIO(idx);
    allScansMetadataOrdered=allScansMetadata(idx);
    clear allScansMetadata allScansImage metaData data alphaAllScans x_scan_pixelsAllScans x_scan_lengthAllScans
    
    % adjust the metaData, in particular:
    %       y_Origin
    %       y_scan_length
    %       y_scan_pixels
    % assumption: ignoring the following values, since they are not used in the following parts
    %       Baseline_V
    %       Baseline_N
    %       SetP_V
    %       SetP_m
    %       SetP_N
    % the others don't change. 
    % since it is ordered, the first element already contains the true y_Origin
    metaDataOrdered= allScansMetadataOrdered{1};
    metaDataOrdered.y_scan_length= sum(y_scan_lengthAllScans);
    metaDataOrdered.y_scan_pixels= sum(y_scan_pixelsAllScans);

    % Further checks: the total scan area must be a square in term of um and pixels
    ratioLength=metaDataOrdered.x_scan_length\metaDataOrdered.y_scan_length;
    ratioPixel=metaDataOrdered.y_scan_pixels\metaDataOrdered.x_scan_pixels;
    if ratioLength ~= 1 || ratioPixel ~= 1
        warning('ratioLength: %. x lengths and/or x pixels is not the same as well as the y length and/or y pixels!!')
    end

    clear y_scan_pixelsAllScans y_scan_lengthAllScans y_OriginAllScans ratioLength ratioPixel idx allScansMetadataOrdered
    % copy common data fields:
    %   Channel_name
    %   Trace_type
    %   AFM data
    dataOrdered=allScansImageOrdered{1};
    %init vars
    % ASSEMBLY BY CONCATENATION
    concatenated_AFM_Height_IO = [];
    for i=1:size(dataOrdered,2)
        concatenatedData_AFM_image=[];
        for j=numFiles:-1:1
            concatenatedData_AFM_image      = cat(2,concatenatedData_AFM_image,allScansImageOrdered{j}(i).AFM_image);
            if i==1
                concatenated_AFM_Height_IO  = cat(2,concatenated_AFM_Height_IO,allScans_AFM_HeightIO_ordered{j});
            end
        end
        dataOrdered(i).AFM_image=concatenatedData_AFM_image;
    end
    
    % show the concatenated images
    if flagAFMSections
        
        data_Height=    dataOrdered(strcmp({dataOrdered.Channel_name},'Height (measured)')).AFM_image;
        data_LD_trace=  dataOrdered(strcmp({dataOrdered.Channel_name},'Lateral Deflection') & strcmp({dataOrdered.Trace_type},'Trace')).AFM_image;
        data_LD_retrace=dataOrdered(strcmp({dataOrdered.Channel_name},'Lateral Deflection') & strcmp({dataOrdered.Trace_type},'ReTrace')).AFM_image;
        data_VD_trace=  dataOrdered(strcmp({dataOrdered.Channel_name},'Vertical Deflection') & strcmp({dataOrdered.Trace_type},'Trace')).AFM_image;
        data_VD_retrace=dataOrdered(strcmp({dataOrdered.Channel_name},'Vertical Deflection') & strcmp({dataOrdered.Trace_type},'ReTrace')).AFM_image;

        titleData='Assembled Opt Fitted and masked Height channel';
        labelBar=sprintf('height (\x03bcm)');
        nameFig=sprintf('%s/resultA4_2_Assembled_OptFittedMasked_HeightChannel.tif',newFolder);
        showData(secondMonitorMain,true,1,data_Height*1e6,titleData,labelBar,nameFig)
    
        titleData='Assembled Height IO';
        labelBar='';
        nameFig=sprintf('%s/resultA4_3_Assembled_HeightIO.tif',newFolder);
        showData(secondMonitorMain,true,2,concatenated_AFM_Height_IO,titleData,labelBar,nameFig)

        titleData='Assembled Raw Lateral Deflection Trace channel';
        labelBar='Voltage [V]';
        nameFig=sprintf('%s/resultA4_4_Assembled_RawLDChannel_trace.tif',newFolder);
        showData(secondMonitorMain,true,3,data_LD_trace,titleData,labelBar,nameFig)
    
        titleData='Assembled Raw Lateral Deflection ReTrace channel';
        nameFig=sprintf('%s/resultA4_5_Assembled_RawLDChannel_Retrace.tif',newFolder);
        showData(secondMonitorMain,true,4,data_LD_retrace,titleData,labelBar,nameFig)

        titleData='Assembled Raw data Vertical Deflection trace channel';
        labelBar='Force [nN]';
        nameFig=sprintf('%s/resultA4_6_Assembled_RawVDChannel_trace.tif',newFolder);
        showData(secondMonitorMain,true,5,data_VD_trace*1e9,titleData,labelBar,nameFig)
 
        titleData='Assembled Raw data Vertical Deflection retrace channel';
        nameFig=sprintf('%s/resultA4_7_Assembled_RawVDChannel_retrace.tif',newFolder);
        showData(secondMonitorMain,true,6,data_VD_retrace*1e9,titleData,labelBar,nameFig)

        uiwait(msgbox('Click to continue'))
        close all
    end
end


