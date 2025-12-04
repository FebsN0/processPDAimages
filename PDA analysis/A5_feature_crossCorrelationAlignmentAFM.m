function varargout = A9_feature_crossCorrelationAlignmentAFM(fixed,moving,varargin)
% cross-correlation between the two images
% OUTPUT:       1 = max_c_it_OI; 
%               2 = [yoffset xoffset]
%               3 = [xbegin, xend, ybegin, yend]
%               4 = AFM_padded;

    % init
    varargout=cell(4,1);

    p=inputParser();    %init instance of inputParser
    % Add required parameters
    addRequired(p, 'fixed');
    addRequired(p,'moving')       
    argName = 'runFFT';         defaultVal = true;      addParameter(p,argName,defaultVal,@(x) islogical(x));
    argName = 'runAlignAFM';    defaultVal = true;      addParameter(p,argName,defaultVal,@(x) islogical(x));
    argName = 'offset';         defaultVal = [];        addParameter(p,argName,defaultVal);  
    parse(p,fixed,moving,varargin{:});
    
    if p.Results.runFFT
        % calc the time required to run a cross-correlation
        cross_correlation=xcorr2_fft(fixed,moving);
        % find the max value in the 2D matrix. Such value represent the point in which the two images are mostly
        % correlated (i.e. almost aligned).
        % cross_correlation(:) becomes a single array with any element, therefore find the idx x max value in 1D array
        [max_c_it_OI, imax] = max(abs(cross_correlation(:)));       
        size_OI=size(cross_correlation);
        % convert the idx of 1D array into idx of 2D matrix
        [ypeak, xpeak] = ind2sub(size_OI,imax);    
        % The idx's point of view is from BF_Mic_Image_IO ==> therefore the AFM image has to moved
        xoffset = (xpeak-size(moving,2));       % idx from the left of BF matric
        yoffset = (ypeak-size(moving,1));       % idx from the top of BF matrix            
        % output
        varargout{1}= max_c_it_OI;
        varargout{2}= [yoffset xoffset];
    end

    if p.Results.runAlignAFM
        % case in which imax is brought from the extern, for example when runAlignAFM is true
        % whereas runFFT is false
        if ~exist("xoffset",'var')
            if ~isempty(p.Results.offset) && ~p.Results.runFFT
                offset=p.Results.offset;
                yoffset=offset(1); xoffset=offset(2);
            elseif ~p.Results.offset && isempty(p.Results.sizeCCMax)
                error('Operation non permitted. Check better the input')
            end
        end
        % In the worst case scenario, the top and left edges of the AFM image coincide with those of the BF image.
        % It is very unlikely that the AFM image goes outside the BF image because of experimental design.
        % save the coordinates of AFM in the 2D space of BF
        if(xoffset>0), xbegin = round(xoffset); else, xbegin = 1; end
        xend   = xbegin+size(moving,2)-1;
        if(yoffset>0), ybegin = round(yoffset); else, ybegin = 1; end
        yend   = ybegin+size(moving,1)-1;
        % create a zero-element matrix with the same cropped BF sizes and place the AFM image based at those idxs (i.e.
        % offset) which represent the most aligned position
        AFM_padded=(zeros(size(fixed)));
        AFM_padded(ybegin:yend,xbegin:xend) = moving;
        % save the output
        varargout{3}= [xbegin, xend, ybegin, yend];
        varargout{4}=AFM_padded;
    end
end