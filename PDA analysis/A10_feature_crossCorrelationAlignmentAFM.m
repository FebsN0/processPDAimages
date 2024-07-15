function varargout = A10_feature_crossCorrelationAlignmentAFM(BF_IO,AFM_IO,varargin)
    % init
    varargout=cell(9,1);
        % 1 = max_c_it_OI;  % 2 = imax;
        % 3 = final_time;
        % 4 = xbegin;       % 5 = xend;
        % 6 = ybegin;       % 7 = yend;
        % 8 =AFM_padded;

    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'BF_IO');
    addRequired(p,'AFM_IO_original')
       
    argName = 'runFFT';
    defaultVal = true;
    addParameter(p,argName,defaultVal,@(x) islogical(x));
    argName = 'runAlignAFM';
    defaultVal = true;
    addParameter(p,argName,defaultVal,@(x) islogical(x));
    argName = 'idxCCMax';
    defaultVal = [];
    addParameter(p,argName,defaultVal);

    parse(p,BF_IO,AFM_IO,varargin{:});
    

    % fprintf(['Results of optional input:\n' ...
    %     '\trunFFT:\t\t\t\t%s\n'      ...
    %     '\trunAlignAFM:\t\t\t%s\n'
    %     ],string(p.Results.runFFT),string(p.Results.runAlignAFM))
    % 

    if p.Results.runFFT
        % calc the time required to run a cross-correlation
        before=datetime('now');
        cross_correlation=xcorr2_fft(BF_IO,AFM_IO);
        final_time=minus(datetime('now'),before);
        % find the max value in the 2D matrix. Such value represent the point in which the two images are mostly
        % correlated (i.e. almost aligned).
        % cross_correlation(:) becomes a single array with any element, therefore find the idx x max value in 1D array
        [max_c_it_OI, imax] = max(abs(cross_correlation(:)));       
        % output
        varargout{1}= max_c_it_OI;
        varargout{2}= imax;
        varargout{3}= size(cross_correlation);
        varargout{4}= final_time;
    end

    if p.Results.runAlignAFM
        % case in which imax is brought from the extern, for example when runAlignAFM is true
        % whereas runFFT is false
        if ~isempty(p.Results.idxCCMax) && ~p.Results.runFFT
            imax=p.Results.idxCCMax;
        elseif ~p.Results.runFFT && isempty(p.Results.idxCCMax)
            error('Operation non permitted. Check better the input')
        end
        % convert the idx of 1D array into idx of 2D matrix
        [ypeak, xpeak] = ind2sub(size(cross_correlation),imax);    
        % The idx's point of view is from BF_Mic_Image_IO ==> therefore the AFM image has to moved
        corr_offset = [(xpeak-size(AFM_IO,2)) (ypeak-size(AFM_IO,1))];

        xoffset = corr_offset(1);                    % idx from the left of BF matric
        yoffset = corr_offset(2);                    % idx from the top of BF matrix
        % In the worst case scenario, the top and left edges of the AFM image coincide with those of the BF image.
        % It is very unlikely that the AFM image goes outside the BF image because of experimental design.
        if(xoffset>0), xbegin = round(xoffset); else, xbegin = 1; end
        xend   = xbegin+size(AFM_IO,2)-1;
        if(yoffset>0), ybegin = round(yoffset); else, ybegin = 1; end
        yend   = ybegin+size(AFM_IO,1)-1;
        % create a zero-element matrix with the same cropped BF sizes and place the AFM image based at those idxs (i.e.
        % offset) which represent the most aligned position
        AFM_padded=(zeros(size(BF_IO)));
        AFM_padded(ybegin:yend,xbegin:xend) = AFM_IO;
        % save the output
        varargout{2}= imax;
        varargout{5}= xbegin;
        varargout{6}= xend;
        varargout{7}= ybegin;
        varargout{8}= yend;
        varargout{9}=AFM_padded;
    end
end