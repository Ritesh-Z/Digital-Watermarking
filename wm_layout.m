function [slots, bitOf] = wm_layout(nBits, nSlots, key)
% WM_LAYOUT  Keyed spreading + redundancy (port of python/wmark/spread.py).
% Each of the nBits watermark bits is written "reps" times at secret,
% key-chosen slot positions. reps is capped at 7 and kept ODD so a
% majority vote can never tie.
%
%   slots : 1 x (reps*nBits) slot indices (1-based)
%   bitOf : 1 x (reps*nBits) which watermark bit each slot carries
    if nSlots < nBits
        error('watermark needs %d slots but the image only has %d', nBits, nSlots);
    end
    reps = min(7, floor(nSlots / nBits));
    if mod(reps, 2) == 0
        reps = reps - 1;
    end
    bitOf = repmat(1:nBits, 1, reps);
    s = RandStream('mt19937ar', 'Seed', key);
    slots = randperm(s, nSlots, numel(bitOf));
end
