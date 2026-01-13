function varargout = A2_feature_sortAndAssemblySections(allData,otherParameters,flag_processSingleSection,varargin)
% First part is sorting in function of the y-position of the sections
% Second part is assembling the sections
    
    p=inputParser(); 
    argName = 'frictionMain';          defaultVal = true;              addParameter(p,argName,defaultVal, @(x) (islogical(x) || (isnumeric(x) && ismember(x,[0 1]))));
    parse(p,varargin{:});
    frictionMain=p.Results.frictionMain;
  
    numFiles=length(allData);
    % check the origin offset information and properly sort data and
    % metadata. In theory, the sections are already ordered, but further
    % check always better! Note: each line of struct is
    % data-metadata-filename of specific section!
    y_OriginAllScans=[otherParameters.y_OriginAllScans];   
    [~,idx]=sort(y_OriginAllScans);
    allDataOrdered=allData(idx);

    % before assembly the data, adjust the metadata of the final assembly.
    % Copy the metadata of the first section and modify some fields
    metaDataAssembled= allDataOrdered(1).metadata;
    % adjust the metaData, in particular:
    %       y_Origin
    %       y_scan_length
    %       y_scan_pixels
    %       Baseline_V
    %       Baseline_N
    %       SetP_V
    %       SetP_m
    %       SetP_N
    %       (eventually) frictionCoeff_Used
    % the others don't change. 
    % since it is ordered, the first element already contains the true y_Origin        
    % in case of y lenght, just sum single y lenght of each section to have entire scan size
    y_scan_lengthAllScans = arrayfun(@(s) s.metadata.y_scan_length_m, allDataOrdered);      
    % allDataOrdered is a struct array
    % Each element has a field .metadata
    % .metadata itself is another struct (not an array).
    % ==>
    % y_scan_lengthAllScans=[allDataOrdered.metadata.y_scan_length_m]
    % ===== FAILS because [struct.struct.field] ===> which it can't flatten automatically.
    metaDataAssembled.y_scan_length_m= sum(y_scan_lengthAllScans);
    % in case of y pixel, keep the pixel value of each section. This information is valuable especially for
    % friction experiment method 1 which it needs to separate the section depending on setpoint
    metaDataAssembled.y_scan_pixels = arrayfun(@(s) s.metadata.y_scan_pixels, allDataOrdered);
    % in case of setpoints and baseline, create an array if more sections. For newton values, round a little a bit the values
    metaDataAssembled.SetP_V= arrayfun(@(s) s.metadata.SetP_V, allDataOrdered);
    metaDataAssembled.SetP_N=round(arrayfun(@(s) s.metadata.SetP_N, allDataOrdered),9);
    metaDataAssembled.Baseline_V=arrayfun(@(s) s.metadata.Baseline_V, allDataOrdered);
    metaDataAssembled.Baseline_N=round(arrayfun(@(s) s.metadata.Baseline_N, allDataOrdered),12);
    % in case of processing single sections before assembly, additional field in the data (friction used for each section)
    if ismember("frictionCoeff_Used",fieldnames(metaDataAssembled))
        metaDataAssembled.frictionCoeff_Used=arrayfun(@(s) s.metadata.frictionCoeff_Used, allDataOrdered);
    end
    clear y_scan_lengthAllScans y_OriginAllScans idx 

    if frictionMain
        varargout{1}=assemblyDataFromFrictionMain(allDataOrdered,metaDataAssembled);       
    else
        % Init vars where store the assembled sections by copying common data fields.
        % Copy just the first row (The data will be overwritten later during assembly):
        %   Channel_name
        %   Trace_type
        %   AFM data
        wantedFields = {'Channel_name','Trace_type'};
        tmp=allDataOrdered(1).AFMImage_Raw;
        dataAssembled = rmfield(tmp, setdiff(fieldnames(tmp), wantedFields));
        [dataAssembled.AFM_images_0_raw]=deal(zeros(0,1));   
        [dataAssembled.AFM_images_1_original]=deal(zeros(0,1));
        if flag_processSingleSection
            [dataAssembled.AFM_images_2_PostProcessed]=deal(zeros(0,1));        
        end
            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%% ASSEMBLY BY CONCATENATION %%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Then, for each iteration, in case of AFM image (5 channels), take all those channel
        % init the var where store the concatenated sections of pre and post processed sections        
        assembledMask=assemblyMask(metaData,dataMask);
        
        % start the assembly of the AFM images. For convenience, it is better take the i-th channel and then assembly all the sections of that
        % specific channel    
        for i=1:size(dataAssembled,2)
            % for each channel, init the var containing the concatenated data
            concatenatedData_Raw_afm_image=zeros(xpix, ypix_total);
            concatenatedData_AFM_image_START=zeros(xpix, ypix_total);
            if flag_processSingleSection
                concatenatedData_AFM_image_END=zeros(xpix, ypix_total);        
            end
            colStart = 1;
            % start the assembly of the i-th channel
            for j=numFiles:-1:1
                % extract the struct AFM data
                tmp=allDataOrdered(j).AFMImage_Raw(i);
                tmp_raw=flip(rot90(tmp.Raw_afm_image,-1));
                tmp_start=flip(rot90(tmp.AFM_image,-1));
                if flag_processSingleSection
                    tmp=allDataOrdered(j).AFMImage_PostProcess(i);
                    tmp_end=tmp.AFM_images_2_PostProcessed;
                end
                yLen=size(tmp_end,2); colEnd = colStart + yLen-1;
                % concatenate
                concatenatedData_Raw_afm_image(:,colStart:colEnd)=tmp_raw;
                concatenatedData_AFM_image_START(:,colStart:colEnd)=tmp_start;
                if flag_processSingleSection
                    concatenatedData_AFM_image_END(:,colStart:colEnd)=tmp_end;
                end
                colStart = colEnd+1;
            end
            % now the data has been concatenated. Store in the final var
            dataAssembled(i).AFM_images_0_raw=concatenatedData_Raw_afm_image;
            dataAssembled(i).AFM_images_1_original=concatenatedData_AFM_image_START;
            if flag_processSingleSection
                dataAssembled(i).AFM_images_2_PostProcessed=concatenatedData_AFM_image_END;
            end
        end
    end
    varargout{1}=dataAssembled;
    varargout{2}=concatenatedMask;
    varargout{3}=metaDataAssembled;
end

function assembledMask=assemblyMask(metaData,allData)
% assembly the mask. Since the size can be big, preallocate    
        xpix = metaData.x_scan_pixels;
        ypix_total = sum(metaData.y_scan_pixels);
        assembledMask=zeros(xpix, ypix_total);
        colStart = 1;
        for j=numFiles:-1:1
            tmp1=allData(j).AFMmask_heightIO;
            yLen=size(tmp1,2);        
            colEnd = colStart + yLen-1;
            assembledMask(:,colStart:colEnd)=tmp1;
            colStart = colEnd+1;
        end
end

function allDataAssembled=assemblyDataFromFrictionMain(allData,metaData)
    assembledMask=assemblyMask(metaData,allData);
    allDataAssembled.mask=assembledMask;
    % Init vars where store the assembled sections
    assembledForceRaw=zeros
    [dataAssembled.AFM_images_0_raw]=deal(zeros(0,1));   
    [dataAssembled.AFM_images_1_original]=deal(zeros(0,1));
    if flag_processSingleSection
        [dataAssembled.AFM_images_2_PostProcessed]=deal(zeros(0,1));        
    end
end