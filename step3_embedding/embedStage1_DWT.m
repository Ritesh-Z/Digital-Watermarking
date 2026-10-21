function [wmImg, key] = embedStage1_DWT(cover, W, alpha)
% EMBEDSTAGE1_DWT  Method 1 of 3: DWT only (the simplest baseline).
%
% PIPELINE:  STEP 3 (embedding). Called by embedAllStages for stage 1.
%
%   [wmImg, key] = embedStage1_DWT(cover, W, alpha)
%
% ALGORITHM
%   1. cover --DWT--> LL, LH, HL, HH
%   2. HH_new = HH + alpha * W          (W padded to the size of HH)
%   3. LL, LH, HL, HH_new --inverse DWT--> watermarked image
%
% INPUTS   cover : uint8 grayscale, even size
%          W     : watermark, values 0..1, must fit in HH
%          alpha : embedding strength
% OUTPUTS  wmImg : watermarked image (uint8)
%          key   : what extractWatermark needs (non-blind: the original HH)

    [LL, LH, HL, HH, Wpad] = splitCoverIntoBands(cover, W);

    HHnew = HH + alpha * Wpad;

    wmImg = rebuildFromBands(LL, LH, HL, HHnew);
    key   = struct('stage', 1, 'alpha', alpha, 'imgSize', size(cover), 'HH', HH);
end
