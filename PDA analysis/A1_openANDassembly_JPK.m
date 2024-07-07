function [dataOrdered,metaDataOrdered,filePathData] = A1_openANDassembly_JPK
    %%%% the funtion open .jpk files. If there are more files than one, then assembly togheter before process
    %%%% them
    %%%% IMPORTANT NOTE: the sum area of any section must be a square
    %%% EXAMPLES
    %%% 1) total area: 50x50 um2 and 1024x1024 pixels and if 4 sections are performed (each with a different
    %%%     setpoint)   ==> 50x10 um2 and 1024x256 pixels !!
    %%% 2) total area: 40x40 um2 and 512x512 pixels and if 8 sections are performed (each with a different
    %%%     setpoint)   ==> 40x10 um2 and 512x64 pixels !!

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

    if numFiles > 1
        question= sprintf('More .jpk files are uploaded. Are they from the same experiment which only setpoint is changed?');
        options= {'Yes','No'};
        if getValidAnswer(question,'',options) ~= 1
            error('Restart again and select only one .jpk file if the more uploaded .jpk are from different experiment')
        end
    end
    clear question options
    % init variables
    allScansImage=cell(1,numFiles);
    allScansMetadata=cell(1,numFiles);
    y_OriginAllScans=zeros(1,numFiles);
    y_scan_lengthAllScans=zeros(1,numFiles);
    y_scan_pixelsAllScans=zeros(1,numFiles);
    x_scan_lengthAllScans=zeros(1,numFiles);
    x_scan_pixelsAllScans=zeros(1,numFiles);
    alphaAllScans=zeros(1,numFiles);
    % EXTRACT ALL DATA
    for i=1:numFiles
        if numFiles==1      %if only one file, the var is not a cell
            fullName=fullfile(filePathData,fileName);
        else
            fullName=fullfile(filePathData,fileName{i});
        end
        % open jpk, it returns the AFM file, the details (position of tip, IGain, Pgain, Sn, Kn and
        % calculates alpha, based on the pub), it returns the location of the file.
        [data,metaData]=A1_open_JPK(fullName);
        allScansImage{i}=data;
        allScansMetadata{i}=metaData;
        % y slow direction BUT once it is in MATLAB it is the x axis
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
        error(sprintf('ERROR: the x lengths and/or alpha calibration factor of some sections are not the same!!\n\tCheck the uploaded data!!'))
    end
    % check the offset information and properly sort
    [~,idx]=sort(y_OriginAllScans);
    allScansImageOrdered=allScansImage(idx);
    allScansMetadataOrdered=allScansMetadata(idx);
    clear allScansMetadata allScansImage metadata data
    
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
        error(sprintf('ERROR: the x lengths and/or x pixels is not the same as well as the y length and/or y pixels!!'))
    end

    clear y_scan_pixelsAllScans y_scan_lengthAllScans y_OriginAllScans
    % copy common data:
    %   Channel_name
    %   Trace_type
    %   Scale_factor
    %   Offset
    dataOrdered=allScansImageOrdered{1};
    %init vars
    % ASSEMBLY BY CONCATENATION
    for i=1:size(dataOrdered,2)
        concatenatedData_Raw_afm_image=[];
        concatenatedData_AFM_image=[];
        for j=1:numFiles
            %dubbio su dim concatenazione
            concatenatedData_Raw_afm_image  = cat(2,concatenatedData_Raw_afm_image,allScansImageOrdered{j}(i).Raw_afm_image);
            concatenatedData_AFM_image      = cat(2,concatenatedData_AFM_image,allScansImageOrdered{j}(i).AFM_image);
        end
        dataOrdered(i).Raw_afm_image= concatenatedData_Raw_afm_image;
        dataOrdered(i).AFM_image=concatenatedData_AFM_image;
    end
end