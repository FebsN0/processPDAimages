function LineData2 = A5_method3feature_DeleteEdgeDataAndOutlierRemoval(LineData, pix, fOutlierRemoval)
% Delete edge data.

% Mode of outlier removal:
% 0: No outlier removal.
% 1: Apply outlier removal to each segment after pixel reduction.
% 2: Apply outlier removal to one large connected segment after pixel reduction.
%

% Debug flag
fDebug = true;

if nargin < 3
    fOutlierRemoval = 0;
end

if fDebug
    %if fOutlierRemoval == 2
    %    figure(91);
    %    movegui('northeast');
    %end
    figure(90);
    clf;
    plot(LineData);
    %tmp = LineData;
    %tmp(tmp==0) = nan;
    %plot(tmp);
    ylim([0, 1e-7])
    title(['Pix = ' num2str(pix)]);
    hold on;
end

% Initialize connected one large segment
SegPosList_StartPos = [];
SegPosList_EndPos = [];
ConnectedSegment = [];
Cnt = 1;

LineData = LineData(:);
LineData2 = LineData;

% Search non-zero data area (segment) and put zero in edge of segment.
fInSegment = false;

% If the starting point is in-segment, startpos = 1.
if LineData(1) ~= 0
    fInSegment = true;
    StartPos = 1;
end

for i=1:length(LineData)-1
    
    if LineData(i) ~= 0
        if fInSegment == false
            % Start of the segment.
            fInSegment = true;
            StartPos = i;
        else
            % InSegment
        end
    else
        if fInSegment == false
            % OutSegment
        else
            % End of the segment.
            fInSegment = false;
            EndPos = i-1;

            % Delete data
            Segment = LineData(StartPos:EndPos);

            if pix>0
                if length(Segment)>=pix
                    Segment(1:pix) = 0;
                    Segment(end-pix+1:end) = 0;
                else
                    % pix is larger than length of Segment.
                    Segment(:) = 0;
                end
            else
                % if pix=0, no data delete.
            end
            
            if fOutlierRemoval == 1
                % Use outlier removal.
                Segment = filloutliers(Segment, 0);
            end

            % Replace segment
            LineData2(StartPos:EndPos) = Segment;
            
            
            % Make one large connected segment
            SegPosList_StartPos(Cnt) = StartPos;
            SegPosList_EndPos(Cnt) = EndPos;
            ConnectedSegment = [ConnectedSegment; Segment];
            Cnt = Cnt + 1;
        end
    end
end

% Process the last data
i = length(LineData);
if fInSegment == true
    % finalize the segment
    % The last data should be zero whether the data is zero or not.
    EndPos = i;

    % Delete data
    Segment = LineData(StartPos:EndPos);

    if pix>0
        if length(Segment)>=pix
            Segment(1:pix) = 0;
            Segment(end-pix+1:end) = 0;
        else
            % pix is larger than length of Segment.
            Segment(:) = 0;
        end
    else
        % if pix=0, no data delete.
    end

    if fOutlierRemoval == 1
        % Use outlier removal.
        Segment = filloutliers(Segment, 0);
    end

    % Replace segment
    LineData2(StartPos:EndPos) = Segment;
    
    % Make one large connected segment
    SegPosList_StartPos(Cnt) = StartPos;
    SegPosList_EndPos(Cnt) = EndPos;
    ConnectedSegment = [ConnectedSegment; Segment];
    Cnt = Cnt + 1;
end

% Calculate one large connected segment.
if fOutlierRemoval == 2
    ConnectedSegment2 = filloutliers(ConnectedSegment, 0);
    
    %if fDebug
    %    figure(91);
    %    clf;
    %    plot(ConnectedSegment);
    %    hold on;
    %    plot(ConnectedSegment2);    
    %end
    
    Cnt2 = 1;
    Num = length(SegPosList_StartPos);
    for i=1:Num
        Len = SegPosList_EndPos(i) - SegPosList_StartPos(i);
        LineData2(SegPosList_StartPos(i):SegPosList_EndPos(i)) ...
            = ConnectedSegment2(Cnt2:Cnt2+Len);
        Cnt2 = Cnt2 + Len + 1;  
    end
end

if fDebug
    figure(90);
    tmp = LineData2;
    tmp(tmp==0) = nan;
    plot(tmp, 'LineWidth', 3);
end
