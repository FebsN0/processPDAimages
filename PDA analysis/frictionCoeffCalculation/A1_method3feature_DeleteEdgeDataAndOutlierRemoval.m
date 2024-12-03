function LineDataFilt = A1_method3feature_DeleteEdgeDataAndOutlierRemoval(LineData, pix, fOutlierRemoval)
% Delete edge data by searching non-zero data area (segment) and put zero in edge of segment (last part of the segment)
%
% INPUT:    1) single fast scan line (force, N)
%           2) dimension window filter
%           3) Mode of outlier removal:
%               0: No outlier removal.
%               1: Apply outlier removal to each segment after pixel reduction.
%               2: Apply outlier removal to one large connected segment after pixel reduction.

    % Initialize connected one large segment
    SegPosList_StartPos = [];
    SegPosList_EndPos = [];
    ConnectedSegment = [];
    Cnt = 1;
    LineDataFilt = LineData;

    % for each element
    %   1) if ~= 0 ==> DETECTION NEW SEGMENT 
    %           ==> update StartPos
    %           ==> find the end of the segment (first zero value)
    %           ==> build the segment and remove outliers
    %           ==> skip to end+1 element which is zero and detect a new segment
    %   2) if == 0 ==> nothing happens, skip to next iteration
    
    processSingleSegment=true; i=1;
    while processSingleSegment
        % DETECTION NEW SEGMENT
        if LineData(i) ~= 0
            StartPos = i;
            % find the idx of the only first zero element from startpos idx. Then the result is the idx of the nonzero
            % element just before the previously found idx of zero element
            EndPos=StartPos+find(LineData(StartPos:end)==0,1)-2;
            % the previous operation will return NaN when the last element is non-zero, thus manage it
            if isempty(EndPos)
                EndPos=length(LineData);
                processSingleSegment=false;
            end
            % Extract the segment (note: it is BACKGROUND data)
            Segment = LineData(StartPos:EndPos);

            % if the length of segment is less than 4, it is very likely to be a random artefact. 
            % Also, not really realiable when filloutliers is used because few sample
            % remove such values and put 0
            if length(Segment)<4
                LineDataFilt(StartPos:EndPos) = zeros(1,length(Segment));
            else
                % if first iteration, do nothing and use as reference
                if pix > 0
                    % if the half-segment is longer than pix window, then reset first and last part with size = pix
                    % in order to remove edges in both sides (the tip encounters the edges of a single PDA crystal 
                    % twice: trace and in retrace)
                    if ceil(length(Segment)/2) >=pix
                        Segment(1:pix) = 0;                
                        Segment(end-pix+1:end) = 0;
                    else
                    % if the segment is shorter, then reset entire segment
                        Segment(:) = 0;
                    end
                end
                
                % MANAGE THE SEGMENT WITH TWO METHODS
                % method 1: Detect and replace outliers in data with 0. Median findmethod is default
                % Outliers are defined as elements more than three scaled MAD from the median
                if fOutlierRemoval == 1
                    Segment = filloutliers(Segment, 0);
                    % Replace segment
                    LineDataFilt(StartPos:EndPos) = Segment;
                else
                % method 2: Find the i-th segment and attach to the previous found one to build a single large
                % connected segment        
                    SegPosList_StartPos(Cnt) = StartPos;                    %#ok<AGROW>
                    SegPosList_EndPos(Cnt) = EndPos;                        %#ok<AGROW>
                    ConnectedSegment = [ConnectedSegment Segment];          %#ok<AGROW>
                    Cnt = Cnt + 1;
                end   
            end
            % skip to find the next segment
            i=EndPos+1;
        else
            % if the element is zero, do nothing and move to the next element
            i=i+1;
            % if the last element is zero, break the while loop 
            if i==length(LineData), break, end            
        end
    end
    
    % Process one large connected segment. Note that if mode = 2, connected segment lacks of resetted edges
    % of the previous part.
    % Here, ConnectedSegment is just the concatenation of each nonFiltered segment previously found .
    % in this way, the function filloutliers has more data to process so the result should be more consistent
    if fOutlierRemoval == 2
        ConnectedSegment2 = filloutliers(ConnectedSegment, 0);
        % substitute the pieces of connectedSegment2 with the corresponding part of original fast scan line
        Cnt2 = 1;
        for i=1:length(SegPosList_StartPos)
            Len = SegPosList_EndPos(i) - SegPosList_StartPos(i);
            LineDataFilt(SegPosList_StartPos(i):SegPosList_EndPos(i)) = ConnectedSegment2(Cnt2:Cnt2+Len);
            Cnt2 = Cnt2 + Len + 1;  
        end
    end
end
