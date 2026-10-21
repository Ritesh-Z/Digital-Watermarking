function [wmImg, key, trace] = embedStage3_DWT_DCT_SVD(cover, W, alpha, pre)
% EMBEDSTAGE3_DWT_DCT_SVD  Method 3 of 3: the full hybrid DWT-DCT-SVD method.
%                          (Stages 4 and 5 use this too, with alpha from BFO/PBFO.)
%
% PIPELINE:  STEP 3 (embedding). Called by embedAllStages for stages 3, 4, 5
%            and by fitnessFunction during the alpha search.
%
%   [wmImg, key, trace] = embedStage3_DWT_DCT_SVD(cover, W, alpha)
%   [wmImg, key, trace] = embedStage3_DWT_DCT_SVD(cover, W, alpha, pre)
%
% ALGORITHM
%   1. DWT    cover  -> LL, LH, HL, HH            (use the HH band)
%   2. DCT    D  = DCT(HH)
%   3. SVD    D  = U  * S  * V'     s  = diag(S)  cover's singular values
%             W  = Uw * Sw * Vw'    sw = diag(Sw) logo's singular values
%   4. EMBED  s_new(1:k) = s(1:k) + alpha * sw(1:k)
%             (k = number of non-zero singular values of the logo; a 0/1
%              logo has only a few, the zero ones would only add noise)
%   5. REBUILD  D_new  = U * diag(s_new) * V'     (inverse SVD)
%               HH_new = inverse DCT(D_new)
%               image  = inverse DWT(LL, LH, HL, HH_new)
%
%   Steps 1-3 do not depend on alpha. They are done by analyseCoverAndLogo;
%   pass its result as "pre" to skip them (the alpha search does this, which
%   makes it much faster - the result is exactly the same).
%
% WHY SVD?  Singular values change very little when an image is slightly
% changed (noise, filtering), so a watermark hidden in them survives attacks.
%
% OUTPUTS
%   wmImg : watermarked image (uint8)
%   key   : what extractWatermark needs (non-blind, as in the paper):
%           s (original singular values), Uw, Vw (logo's singular vectors), alpha
%   trace : every intermediate result, so the GUI can SHOW each step

    % ---- 1.-3. DWT, DCT, SVD (or reuse them)
    if nargin < 4 || isempty(pre)
        pre = analyseCoverAndLogo(cover, W);
    end
    k = pre.k;
    s = pre.s;

    % ---- 4. Embed: add the logo's singular values to the cover's
    sNew      = s;
    sNew(1:k) = s(1:k) + alpha * pre.sw(1:k);

    % ---- 5. Rebuild: inverse SVD -> inverse DCT -> inverse DWT
    Dnew  = pre.U * diag(sNew) * pre.V';
    HHnew = pre.Tr' * Dnew * pre.Tc;
    wmImg = rebuildFromBands(pre.LL, pre.LH, pre.HL, HHnew);

    % ---- Extraction key
    key = struct('stage', 3, 'alpha', alpha, 'imgSize', pre.imgSize);
    key.s  = s(1:k);
    key.Uw = pre.Uw(:, 1:k);
    key.Vw = pre.Vw(:, 1:k);

    % ---- Intermediate values (for the step-by-step view in the GUI)
    if nargout > 2
        trace = struct('LL', pre.LL, 'LH', pre.LH, 'HL', pre.HL, 'HH', pre.HH, 'D', pre.D, ...
                       's', s, 'sw', pre.sw, 'k', k, 'sNew', sNew, ...
                       'Dnew', Dnew, 'HHnew', HHnew, 'alpha', alpha);
    end
end
