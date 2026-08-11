function data_filtered = remove_Edges_Outlier(data,data_mask,pix,segmentProcess,outlierRemovalMethod) 
%%%%%%%% OUTLIER REMOVAL FOR THE GIVEN FAST SCAN LINE %%%%%%%%
% Delete edges data by searching non-zero data area (segmentLineDataFilt) and put NaN in both edges of the segment
% INPUT:    - data: if segmentProcess=1/2, single fast scan line. If segmentProcess=3, section (matrix)
%           - data_mask: since the data has been previously cleared, there may be areas that can be confused as edges.
%                        Therefore, instead of using directly the data, use the mask to identify the 0/1 changes as true BK/FR changes, therefore, true edges
%           - pix: number of pixels to be removed at both edges of a segment.
%           - segmentProcess: how to process the segments before outlier removal:
%               1: outliers over Single Segments
%               2: outliers over a Connected Segment (assembled single segment, corrisponding with a single fast scan line)
%               3: outliers over entire section (heavy method, sometime too aggressive) 
%           - outlierRemovalMethod: Detect and replace outliers in the line (segment|connectedSegment|connectedAllSegments) with NaN in 3 possible ways:
%               1: do nothing. Dont remove outliers. They may be already removed by pixel reduction.
%               2: remove 0.5 and 99.5 percentile (NOTE: since single segments already contains few elements, no good to use percentile threshold method)
%               3: MAD findmethod is default: Outliers are defined as elements more than three scaled MAD from the median (robust
%                % when there are lot of data, but sometime aggressive and not suitable when BK contains "more" type of BK           
% NOTE: when outlierRemovalMethod=1, segmentProcess doesnt really matter
%
% OUTPUT:   - line_filtered : line without edges and outliers.
%                             Note: the output/filtered line has same size as the input line
% for each element:
%   1) if ~= 0 ==> DETECTION NEW SEGMENT 
%           ==> update StartPos
%           ==> find the end of the segment (first zero value)
%           ==> build the segment and remove outliers
%           ==> skip to end+1 element which is zero and detect a new segment
%   2) if == 0 ==> nothing happens, skip to next iteration    

% check the type of the provided data
    if ((segmentProcess==1 || segmentProcess==2) && ~isvector(data)) || (segmentProcess==3 && isvector(data))
        error("The type of the data does not match with the type of segment. If you want to use ConnectedSegment (segmentProcess=2) over entire section/matrix, you need to provide single fast scan line")
    end
    
    % transform the section into vector
    % NOTE: vectors are technically matrices in MATLAB (ismatrix(v)==true), so we
    % explicitly test ~isvector(data) here to distinguish "section" (segmentProcess==3)
    % from "single fast scan line" (segmentProcess==1/2) inputs.
    if ~isvector(data)
        data_vector=reshape(data,[],1);
        mask_vector=reshape(data_mask,[],1);
        % track the border of each fast scan line so also the borders will be subjected to removal
        idxBorders=1:size(data,1):length(data_vector);
        idxCurrentFastLine=1;
    else
        data_vector=data;
        mask_vector=data_mask;
    end

    % init
    SegPosList_StartPos = [];
    SegPosList_EndPos = [];
    ConnectedSegment = [];
    Cnt = 1;
    data_filtered_vector = data_vector;
    processSingleSegment=true; i=1;
    while processSingleSegment
    % DETECTION NEW SEGMENT AS BACKGROUND
        if mask_vector(i) == 0
            StartPos = i;   
            % find the idx of the only first zero element from startpos idx. Then the result is the idx of the nonzero
            % element just before the previously found idx of zero element
            EndPos=StartPos+find(mask_vector(StartPos:end)==1,1)-2;
            % the previous operation will return NaN when the last element is non-zero, thus manage it
            if isempty(EndPos)
                EndPos=length(mask_vector);
                processSingleSegment=false;                
            end
            % in case of section, to avoid that the right border of i-th line is merged with the left border of i+1-th line and interpreted as segment,
            % additional check. If so, treat them separately as two segment
            if segmentProcess==3 && idxCurrentFastLine<=length(idxBorders)
                if StartPos<idxBorders(idxCurrentFastLine) && EndPos>idxBorders(idxCurrentFastLine)
                    EndPos=idxBorders(idxCurrentFastLine)-1;
                elseif any(StartPos==idxBorders)
                    idxCurrentFastLine=idxCurrentFastLine+1;
                end
            end            
            % Extract the segment from the data (note: it is BACKGROUND data)
            Segment = data_vector(StartPos:EndPos);
            % if the length of segment is less than 4, it is very likely to be a random artefact. 
            % Also, not really realiable when filloutliers is used because few sample
            % remove such values and put 0
            if length(Segment)<4
                data_filtered_vector(StartPos:EndPos) = nan;
            else
                % save the indexes of start and end segment
                SegPosList_StartPos(Cnt) = StartPos;                    %#ok<AGROW>
                SegPosList_EndPos(Cnt) = EndPos;                        %#ok<AGROW>
                Cnt = Cnt + 1;
                % if first iteration, do nothing and use as reference
                if pix > 0
                    % if the half-segment is longer than pix window, then reset first and last part with size = pix
                    % in order to remove edges in both sides (the tip encounters the edges of a single PDA crystal 
                    % twice: trace and in retrace)
                    if ceil(length(Segment)/2) >=pix
                        Segment(1:pix) = nan;                
                        Segment(end-pix+1:end) = nan;
                    else
                    % if the segment is shorter, then reset entire segment
                        Segment(:) = nan;
                    end
                end                
                % PROCESS THE SEGMENT (Detect and replace outliers in data with NaN) - see applyOutlierRemoval() below
                if segmentProcess == 1
                    Segment = applyOutlierRemoval(Segment, outlierRemovalMethod);
                    data_filtered_vector(StartPos:EndPos) = Segment;
                else
                % method 2 or 3: attach the current segment to the previous found one to build a single large connected segment
                    ConnectedSegment = [ConnectedSegment; Segment];          %#ok<AGROW>
                end   
            end
            % skip to find the next segment
            i=EndPos+1;
        else
            % if the last element=1, break the while loop 
            if i>=length(mask_vector)
                break
            end    
            % if the element=1 (FR), do nothing and move to the next element           
            if segmentProcess==3 && (any(i==(idxBorders)))
                idxCurrentFastLine=idxCurrentFastLine+1;
            end
            i=i+1;
        end
    end
    % Process one large connected segment. Note that if mode = 2 or 3, connected segment lacks of resetted edges of the previous part.
    % Here, ConnectedSegment is just the concatenation of each nonFiltered segments previously found.
    % in this way, the function filloutliers has more data to process so the result should be more consistent.
    if segmentProcess == 2 || segmentProcess == 3
        ConnectedSegment = applyOutlierRemoval(ConnectedSegment, outlierRemovalMethod);
        % substitute the pieces of connectedSegment with the corresponding part of original fast scan line
        Cnt2 = 1;
        for i=1:length(SegPosList_StartPos)
            % coincide with the number of elements of original segment
            Len = SegPosList_EndPos(i) - SegPosList_StartPos(i) +1;
            data_filtered_vector(SegPosList_StartPos(i):SegPosList_EndPos(i)) = ConnectedSegment(Cnt2:Cnt2+Len-1);
            % start with the next segment
            Cnt2 = Cnt2 + Len;  
        end
    end
    % in case of section data, restore the size
    if ~isvector(data)
        data_filtered=reshape(data_filtered_vector,size(data));
    else
        data_filtered=data_filtered_vector;
    end
end

function seg = applyOutlierRemoval(seg, outlierRemovalMethod)
% Detect and replace outliers in seg with NaN, per outlierRemovalMethod:
%   1: do nothing (already handled by pixel-edge removal upstream)
%   2: remove values outside the 0.5-99.5 percentile range
%   3: MAD method (default filloutliers) - elements more than three scaled
%      MAD from the median
    switch outlierRemovalMethod
        case 2
            seg = filloutliers(seg, nan, 'percentiles', [0.5 99.5]);
        case 3
            seg = filloutliers(seg, nan);
        % case 1 (or anything else): leave seg unchanged
    end
end