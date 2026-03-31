function varargout = A2_feature_sortAndAssemblySections(allData,otherParameters,flag_processSingleSection,modeScan)
% First part is sorting in function of the y-position of the sections
% Second part is assembling the sections
    numFiles=length(allData);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% ORDER THE DATA IN FUNCTION OF Y ORIGIN POSITION %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % check the origin offset information and properly sort data and metadata. In theory, the sections are already ordered, but further
    % check always better! Note: each line of struct is data-metadata-filename of specific section!
    y_OriginAllScans=[otherParameters.y_OriginAllScans];   
    [~,idx]=sort(y_OriginAllScans);
    allDataOrdered=allData(idx);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% ADJUST THE METADATA %%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % before assembly the data, adjust the metadata of the final assembly.
    % Copy the metadata of the first section and modify some fields (identical among all sections)
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
    % since it is ordered, the first element already contains the true y_Origin        
    % in case of y lenght, just sum single y lenght of each section to have entire scan size
    y_scan_lengthAllScans = arrayfun(@(s) s.metadata.y_scan_length_m, allDataOrdered);      
    metaDataAssembled.y_scan_length_m= sum(y_scan_lengthAllScans);
    % count number of pixels
    xpix_total = metaDataAssembled.x_scan_pixels;
    % in case of y pixel, keep the pixel value of each section instead of sum. This information is valuable especially for
    % friction experiment method 1 which it needs to separate the section depending on setpoint and in A1_feature_CleanOrPrepFiguresRawData to create VF distribution.
    y_scan_pixels_info= arrayfun(@(s) s.metadata.y_scan_pixels, allDataOrdered,'UniformOutput',false);
    ypix_total=0;
    ypix_idx_allSec=zeros(2,numFiles);
    for i=1:numFiles    
        ypix_length=y_scan_pixels_info{i}(2);
        ypix_start = ypix_total + 1;
        ypix_end = ypix_start+ypix_length-1;
        ypix_idx_allSec(:,i) = [ypix_start; ypix_end];
        ypix_total=ypix_total+ypix_length;
    end
    clear ypix_end ypix_start ypix_length
    % store the start-end idxs of any section
    metaDataAssembled.y_scan_pixels = ypix_idx_allSec;   
    % in case of setpoints and baseline, create an array if more sections. For newton values, round a little a bit the values
    metaDataAssembled.SetP_V= arrayfun(@(s) s.metadata.SetP_V, allDataOrdered);
    vals=arrayfun(@(s) s.metadata.SetP_N, allDataOrdered,'UniformOutput',false);
    % Flatten cell content into a numeric vector
    if isscalar(vals)           % case: {Nx1 double}
        vals = vals{1};
    else        
        vals = cell2mat(vals);  % case: {1x1 double, 1x1 double, ...}
    end
    metaDataAssembled.SetP_N=round(vals,9);
    metaDataAssembled.Baseline_V=arrayfun(@(s) s.metadata.Baseline_V, allDataOrdered);
    metaDataAssembled.Baseline_N=round(arrayfun(@(s) s.metadata.Baseline_N, allDataOrdered),12);
    % in case of processing single sections before assembly, additional field in the data (friction used for each section)
    if ismember("frictionCoeff_Used",fieldnames(metaDataAssembled))
        metaDataAssembled.frictionCoeff_Used=arrayfun(@(s) s.metadata.frictionCoeff_Used, allDataOrdered);
    end
    clear y_scan_lengthAllScans y_OriginAllScans idx    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%% PREPARE THE DATA AS: RAW - ORIGINAL (preprocessing) - POST_PROCESSED %%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Init vars where store the assembled sections by copying common data fields.
    % Copy just the first row (The data will be overwritten later during assembly):
    %   Channel_name
    %   Trace_type
    %   AFM data
    wantedFields = {'Channel_name','Trace_type'};
    tmp=allDataOrdered(1).AFMImage_Raw;
    dataAssembled = rmfield(tmp, setdiff(fieldnames(tmp), wantedFields));
    if ~flag_processSingleSection
        [dataAssembled.Raw_afm_image]=deal(zeros(0,1));   
        [dataAssembled.AFM_image]=deal(zeros(0,1));
    else
        [dataAssembled.AFM_images_0_raw]=deal(zeros(0,1));   
        [dataAssembled.AFM_images_1_original]=deal(zeros(0,1));
        if ~strcmp(modeScan,"frictionScan") % friction data does not contain lateral processing
            [dataAssembled.AFM_images_2_PostProcessed]=deal(zeros(0,1));       
        end
        [dataAssembled.AFMmask_heightIO]=deal(zeros(0,1));  
        % in case of already processed single section, the masks of each section are already ready to be assembled. Metadata is required
        % to build a zero matrix with final size
    end            
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%% ASSEMBLY BY CONCATENATION %%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % For each iteration/section, in case of AFM image (5 channels), take all those channel init the var where store the concatenated sections of pre and
    % post (if any) processed sections. For convenience, it is better take the i-th channel and then assembly all the sections of that specific channel    
    for th_channel=1:size(dataAssembled,2)
        % for each channel, init the var containing the concatenated data
        concatenatedData_Raw_afm_image=zeros(xpix_total, ypix_total);
        concatenatedData_AFM_image_START=zeros(xpix_total, ypix_total);
        if flag_processSingleSection
            concatenatedData_AFM_image_END=zeros(xpix_total, ypix_total);
            % manage the mask only once
            if th_channel==1
                concatenatedMask=zeros(xpix_total, ypix_total);
            end
        end
        colStart = 1;
        % start the assembly of the i-th channel
        for th_section=numFiles:-1:1
            % extract the struct AFM data. Not processed data has no flipped adjusted sections
            if ~flag_processSingleSection   
                tmp=allDataOrdered(th_section).AFMImage_Raw(th_channel);
                tmp_raw=flip(rot90(tmp.Raw_afm_image,-1));
                tmp_start=flip(rot90(tmp.AFM_image,-1));
            else
                tmp=allDataOrdered(th_section).AFMImage_PostProcess(th_channel);
                tmp_raw=tmp.AFM_images_0_raw;
                tmp_start=tmp.AFM_images_1_original;
                tmp_end=tmp.AFM_images_2_PostProcessed;
                % manage the mask only once
                if th_channel==1
                    tmp_mask=allDataOrdered(th_section).AFMmask_heightIO;                    
                end
            end
            yLen=size(tmp_start,2);
            colEnd = colStart + yLen-1;
            % concatenate
            concatenatedData_Raw_afm_image(:,colStart:colEnd)=tmp_raw;
            concatenatedData_AFM_image_START(:,colStart:colEnd)=tmp_start;
            if flag_processSingleSection
                concatenatedData_AFM_image_END(:,colStart:colEnd)=tmp_end;
                % manage the mask only once
                if th_channel==1
                    concatenatedMask(:,colStart:colEnd)=tmp_mask;
                end
            end
            colStart = colEnd+1;
        end
        % now the data has been concatenated. Store in the final var
        if ~flag_processSingleSection
            [dataAssembled(th_channel).Raw_afm_image]=concatenatedData_Raw_afm_image; 
            [dataAssembled(th_channel).AFM_image]=concatenatedData_AFM_image_START;
        else
            dataAssembled(th_channel).AFM_images_0_raw=concatenatedData_Raw_afm_image;
            dataAssembled(th_channel).AFM_images_1_original=concatenatedData_AFM_image_START;
            if flag_processSingleSection
                dataAssembled(th_channel).AFM_images_2_PostProcessed=concatenatedData_AFM_image_END;
                % manage the mask only once
                if th_channel==1
                    dataAssembled.AFMmask_heightIO=concatenatedMask;
                end
            end    
        end
    end
    varargout{1}=dataAssembled;    
    varargout{2}=metaDataAssembled;
end
