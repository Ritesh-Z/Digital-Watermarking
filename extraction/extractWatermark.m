function Wext = extractWatermark(img, key, wmSize)
% EXTRACTWATERMARK  Recovers the watermark from a (possibly noisy)
% watermarked image, using the key from embedDWT, embedDWTDCT or
% embedDWTDCT_SVD. Non-blind, like the paper.
%
%   Wext = extractWatermark(img, key, wmSize)
%
%   img    : watermarked (or attacked) image
%   key    : struct from the embedding function (holds stage and alpha too)
%   wmSize : [rows cols] of the watermark that was embedded, size(W)
%
%   Wext   : recovered watermark as real numbers, close to 0 and 1 when the
%            extraction is good. Threshold at 0.5 to show it as black/white.
%
% What it does for each stage (alpha is key.alpha):
%   1 DWT        (HH band - original HH) / alpha
%   2 DWT-DCT    (DCT of HH - original DCT) / alpha
%   3 DWT-DCT-SVD  swe = (singular values - original ones) / alpha,
%                  then Wext = Uw * diag(swe) * Vw'   (paper: S3 and W*)

    if isfield(key, 'imgSize') && ~isequal(size(img), key.imgSize)
        error('extractWatermark:sizeMismatch', ...
              'The image size (%d x %d) differs from the size used for embedding (%d x %d).', ...
              size(img, 1), size(img, 2), key.imgSize(1), key.imgSize(2));
    end

    [~, ~, ~, HH] = dwt2Haar(double(img));
    [r, c] = size(HH);
    wr = wmSize(1);
    wc = wmSize(2);
    if wr > r || wc > c
        error('extractWatermark:watermarkTooLarge', ...
              'The watermark size (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end
    alpha = key.alpha;

    switch key.stage
        case 1
            d = (HH - key.HH) / alpha;
            Wext = d(1:wr, 1:wc);

        case 2
            D = dctMatrix(r) * HH * dctMatrix(c)';
            d = (D - key.D) / alpha;
            Wext = d(1:wr, 1:wc);

        case 3
            D = dctMatrix(r) * HH * dctMatrix(c)';
            s = svd(D);
            k = length(key.s);
            swe = (s(1:k) - key.s) / alpha;
            Wext = key.Uw * diag(swe) * key.Vw';

        otherwise
            error('extractWatermark:badStage', 'key.stage must be 1, 2 or 3.');
    end
end
