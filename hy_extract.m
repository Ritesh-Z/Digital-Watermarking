function Wext = hy_extract(img, key, wmSize)
% HY_EXTRACT  Recovers the watermark from a (possibly noisy) watermarked
% image, using the key returned by hy_embed. Non-blind, like the paper.
%
%   Wext = hy_extract(img, key, wmSize)
%
%   img    : watermarked (or attacked) image
%   key    : struct from hy_embed (contains stage and alpha too)
%   wmSize : [rows cols] of the watermark that was embedded (size(W)), any size
%
%   Wext   : recovered watermark, real numbers (close to 0 and 1 when the
%            extraction is good). Threshold at 0.5 to display it as black/white.

    if isfield(key, 'imgSize') && ~isequal(size(img), key.imgSize)
        error('hy_extract:sizeMismatch', ...
              'The image size (%d x %d) differs from the size used for embedding (%d x %d).', ...
              size(img, 1), size(img, 2), key.imgSize(1), key.imgSize(2));
    end

    [~, ~, ~, HH] = manual_dwt2_haar(double(img));
    [r, c] = size(HH);
    wr = wmSize(1);
    wc = wmSize(2);
    if wr > r || wc > c
        error('hy_extract:watermarkTooLarge', ...
              'The watermark size (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end
    alpha = key.alpha;

    switch key.stage
        case 1
            d = (HH - key.HH) / alpha;
            Wext = d(1:wr, 1:wc);

        case 2
            D = hy_dct_matrix(r) * HH * hy_dct_matrix(c)';
            d = (D - key.D) / alpha;
            Wext = d(1:wr, 1:wc);

        case 3
            D = hy_dct_matrix(r) * HH * hy_dct_matrix(c)';
            s = svd(D);
            k = length(key.s);
            swe = (s(1:k) - key.s) / alpha;      % the paper's S3 = (S* - S) / alpha
            Wext = key.Uw * diag(swe) * key.Vw'; % the paper's W* = Uw * S3 * Vw'

        otherwise
            error('key.stage must be 1, 2 or 3');
    end
end
