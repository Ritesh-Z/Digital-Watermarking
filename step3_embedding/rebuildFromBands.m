function wmImg = rebuildFromBands(LL, LH, HL, HHnew)
% REBUILDFROMBANDS  Last step shared by all three embedding methods.
%
% PIPELINE:  STEP 3 (embedding), part 3 of 3:
%            splitCoverIntoBands -> change HH -> [rebuildFromBands]
%
%   wmImg = rebuildFromBands(LL, LH, HL, HHnew)
%
% Inverse Haar DWT with the MODIFIED HH band, then round and clip to a
% normal 8-bit image (0..255). The rounding is the only loss in the method.

    img   = haarIDWT2(LL, LH, HL, HHnew);
    wmImg = uint8(min(max(round(img), 0), 255));
end
