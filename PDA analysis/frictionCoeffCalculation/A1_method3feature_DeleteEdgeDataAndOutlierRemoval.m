function LineDataFilt = A5_method3feature_DeleteEdgeDataAndOutlierRemoval(LineData, pix, fOutlierRemoval)
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
    %   1) if it's nonzero ==> DETECTION NEW SEGMENT 
    %           ==> update StartPos
    %           ==> find the end of the segment
    %           ==> build the segment and remove outliers
    %           ==> skip to end+1 element which is zero and detect a new segment
    %   2) if it's == zero ==> nothing happens, skip to next iteration
    
    processSingleSegment=true; i=1;
    while processSingleSegment
        % DETECTION NEW SEGMENT
        if LineData(i) ~= 0
            StartPos = i;
            EndPos=StartPos+find(LineData(StartPos:end)==0,1)-2;
            % if the last element of the last segment is nonzero, then EndPos = NaN
            if isempty(EndPos)
                EndPos=length(LineData);
                processSingleSegment=false;
            end
            % PROCESS THE SEGMENT
            Segment = LineData(StartPos:EndPos);
            
            if pix > 0
                % if the segment is longer than window, then reset first and last part with size = pix
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

            if fOutlierRemoval == 1
                % Detect and replace outliers in data with 0. Median findmethod is default
                % outliers are defined as elements more than three scaled MAD from the median
                Segment = filloutliers(Segment, 0);
            end
            % Replace segment
            LineDataFilt(StartPos:EndPos) = Segment;

            % Make one large connected segment
            SegPosList_StartPos(Cnt) = StartPos;
            SegPosList_EndPos(Cnt) = EndPos;
            ConnectedSegment = [ConnectedSegment Segment];
            Cnt = Cnt + 1;
            % skip to find the next segment
            i=EndPos+1;
        else
            i=i+1;
            % the element is zero, so if it is the last element, break the while loop 
            if i==length(LineData), break, end
        end
    end
    
    % Calculate one large connected segment. Note that if mode = 2, connected segment lacks of resetted edges
    % of the previous part.
    % Here, ConnectedSegment is just the concatenation of each nonFiltered segment previously found .
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
