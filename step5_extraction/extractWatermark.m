function [Wext, trace] = extractWatermark(img, key, wmSize)
% EXTRACTWATERMARK  Gets the logo back out of a watermarked (or attacked) image.
%
% PIPELINE:  STEP 5 (extraction). Used by the GUI's "Extract" step, by the
%            attack tests (step 6) and by fitnessFunction (step 4).
%
%   [Wext, trace] = extractWatermark(img, key, wmSize)
%
% INPUTS
%   img    : watermarked image (clean or attacked), uint8
%   key    : struct returned by the embedding function (holds stage + alpha)
%   wmSize : [rows cols] of the embedded logo, i.e. size(W)
% OUTPUTS
%   Wext   : recovered logo (real numbers; close to 0/1 when it works -
%            threshold at 0.5 to display it as black/white)
%   trace  : intermediate results, so the GUI can SHOW each step
%
% NON-BLIND: the key holds information about the ORIGINAL cover (as in the
% paper), so the original image itself is not needed.
%
% ALGORITHM (it is the embedding run backwards)
%   Method 1 - DWT          HH* = DWT(img)          W* = (HH* - HH) / alpha
%   Method 2 - DWT-DCT      D*  = DCT(HH*)          W* = (D*  - D ) / alpha
%   Method 3 - DWT-DCT-SVD  D*  = DCT(HH*)
%                           s*  = singular values of D*
%                           sw* = (s* - s) / alpha       <- undo  s_new = s + alpha*sw
%                           W*  = Uw * diag(sw*) * Vw'   <- rebuild the logo

    if isfield(key, 'imgSize') && ~isequal(size(img), key.imgSize)
        error('extractWatermark:sizeMismatch', ...
              'The image size (%d x %d) differs from the size used for embedding (%d x %d).', ...
              size(img, 1), size(img, 2), key.imgSize(1), key.imgSize(2));
    end

    % ---- 1. DWT of the received image -> HH* band
    [~, ~, ~, HH] = haarDWT2(double(img));
    [r, c] = size(HH);
    wr = wmSize(1);
    wc = wmSize(2);
    if wr > r || wc > c
        error('extractWatermark:watermarkTooLarge', ...
              'The watermark size (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end
    alpha = key.alpha;
    trace = struct('HH', HH, 'D', [], 's', [], 'swe', []);

    switch key.stage
        case 1  % ---- DWT only
            d    = (HH - key.HH) / alpha;
            Wext = d(1:wr, 1:wc);

        case 2  % ---- DWT-DCT
            D    = dctMatrix(r) * HH * dctMatrix(c)';
            d    = (D - key.D) / alpha;
            Wext = d(1:wr, 1:wc);
            trace.D = D;

        case 3  % ---- DWT-DCT-SVD
            D    = dctMatrix(r) * HH * dctMatrix(c)';     % 2. DCT
            s    = svd(D);                                % 3. SVD
            k    = length(key.s);
            swe  = (s(1:k) - key.s) / alpha;              % 4. logo's singular values
            Wext = key.Uw * diag(swe) * key.Vw';          % 5. rebuild the logo
            trace.D   = D;
            trace.s   = s;
            trace.swe = swe;

        otherwise
            error('extractWatermark:badStage', 'key.stage must be 1, 2 or 3.');
    end
end
