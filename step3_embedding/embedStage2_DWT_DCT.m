function [wmImg, key] = embedStage2_DWT_DCT(cover, W, alpha)
% EMBEDSTAGE2_DWT_DCT  Method 2 of 3: DWT, then DCT.
%
% PIPELINE:  STEP 3 (embedding). Called by embedAllStages for stage 2.
%
%   [wmImg, key] = embedStage2_DWT_DCT(cover, W, alpha)
%
% ALGORITHM
%   1. cover --DWT--> LL, LH, HL, HH
%   2. D      = DCT(HH)
%   3. D_new  = D + alpha * W
%   4. HH_new = inverse DCT(D_new)
%   5. LL, LH, HL, HH_new --inverse DWT--> watermarked image
%
% Same inputs/outputs as embedStage1_DWT. The key holds the original D.

    [LL, LH, HL, HH, Wpad] = splitCoverIntoBands(cover, W);
    [r, c] = size(HH);
    Tr = dctMatrix(r);
    Tc = dctMatrix(c);

    D     = Tr * HH * Tc';                  % forward DCT
    Dnew  = D + alpha * Wpad;               % add the watermark
    HHnew = Tr' * Dnew * Tc;                % inverse DCT

    wmImg = rebuildFromBands(LL, LH, HL, HHnew);
    key   = struct('stage', 2, 'alpha', alpha, 'imgSize', size(cover), 'D', D);
end
