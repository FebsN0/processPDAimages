function [output, Greg] = dftregistration(buf1ft,buf2ft,usfac)
% DFTREGISTRATION Register two images (translation only) using DFT phase correlation. (Guizar et al. 2008)
% Inputs:
%   buf1ft, buf2ft: Fourier transforms of the two images.
%   usfac: upsampling factor (e.g. 100 for subpixel accuracy). ==> it controls how precisely the translation between two images is computed in subpixel units.
%               usfac = 1 → integer-pixel accuracy
%               usfac = 100 → 0.01 pixel accuracy (very high precision, but slower)
% Output:
%   output: [error, diffphase, net_row_shift, net_col_shift]
%   Greg: registered version of buf2ft

%%%% IMPORTANT NOTE: the two image must be made with the same
%%%% characteristics. Example: image1 and image2 are both TRITIC or both
%%%% BF. The algorithm fails if you give one TRITIC and one BF. This
%%%% because are made with different bit format.
% The Fourier cross-correlation (used inside dftregistration) assumes roughly comparable energy in both images.
    if nargin < 3
        usfac = 1;
    end    
    [nr, nc] = size(buf1ft);
    CCmax = 0;    
    if usfac == 0
        % Simple error and phase difference computation
        error = sqrt(sum(abs(buf1ft(:) - buf2ft(:)).^2)) / sum(abs(buf1ft(:)).^2);
        diffphase = 0;
        output = [error, diffphase, 0, 0];
        Greg = buf2ft;
        return;
    elseif usfac == 1
        % Cross-correlation and peak
        CC = ifft2(buf1ft .* conj(buf2ft));
        [~, loc1] = max(CC(:));
        [rloc, cloc] = ind2sub(size(CC), loc1);
        CCmax = CC(rloc, cloc);
        rloc = rloc - 1;
        cloc = cloc - 1;
        if rloc > nr/2
            rloc = rloc - nr;
        end
        if cloc > nc/2
            cloc = cloc - nc;
        end
        row_shift = rloc;
        col_shift = cloc;
    elseif usfac > 1
        % Whole-pixel shift (first step)
        CC = ifft2(buf1ft .* conj(buf2ft));
        [~, loc1] = max(CC(:));
        [rloc, cloc] = ind2sub(size(CC), loc1);
        rloc = rloc - 1;
        cloc = cloc - 1;
        if rloc > nr/2, rloc = rloc - nr; end
        if cloc > nc/2, cloc = cloc - nc; end
    
        % Refine by matrix multiply DFT about neighborhood of the peak
        dftshift = ceil(usfac * 1.5) / 2;
        CCup = dftups(buf2ft .* conj(buf1ft), ceil(usfac * 1.5), ceil(usfac * 1.5), usfac, ...
                      -round(rloc * usfac) + dftshift, -round(cloc * usfac) + dftshift);
        CCup = abs(CCup);
        [~, loc1] = max(CCup(:));
        [rloc, cloc] = ind2sub(size(CCup), loc1);
        rloc = rloc - dftshift - 1;
        cloc = cloc - dftshift - 1;
        row_shift = rloc / usfac;
        col_shift = cloc / usfac;
    end
    
    diffphase = angle(CCmax);
    error = 1.0 - CCmax .* conj(CCmax) / (sum(abs(buf1ft(:)).^2) * sum(abs(buf2ft(:)).^2));
    if nargout==2
        Greg = buf2ft .* exp(1i * 2 * pi * (-row_shift * (0:(nr - 1)) / nr).' - 1i * 2 * pi * col_shift * (0:(nc - 1)) / nc);
    end
    output = [error, diffphase, row_shift, col_shift];
    end
    
    % Helper subfunction
    function out = dftups(in, nor, noc, usfac, roff, coff)
    [nr, nc] = size(in);
    kernc = exp((-1i * 2 * pi / (nc * usfac)) * (ifftshift(0:nc-1) - floor(nc / 2))' * (0:noc-1 - coff));
    kernr = exp((-1i * 2 * pi / (nr * usfac)) * (0:nor-1 - roff)' * (ifftshift(0:nr-1) - floor(nr / 2)));
    out = kernr * in * kernc;
end
