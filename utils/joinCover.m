function wmImg = joinCover(LL, LH, HL, HH)
% JOINCOVER  Last step shared by every embedding stage: inverse Haar DWT,
% then round and clip to a normal 8-bit image.
%
%   wmImg = joinCover(LL, LH, HL, HH)

    wm = idwt2Haar(LL, LH, HL, HH);
    wmImg = uint8(min(max(round(wm), 0), 255));
end
