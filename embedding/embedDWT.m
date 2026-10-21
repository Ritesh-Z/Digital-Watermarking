function [wmImg, key] = embedDWT(cover, W, alpha)
% EMBEDDWT  Stage 1: DWT only.
% Adds alpha * watermark straight onto the HH (diagonal detail) band of a
% one-level Haar DWT, then goes back with the inverse DWT.
%
%   [wmImg, key] = embedDWT(cover, W, alpha)
%
%   cover : grayscale cover image (uint8), even size
%   W     : watermark, values 0..1, small enough to fit in the HH band
%   alpha : embedding strength (the paper's scaling factor)
%
%   wmImg : watermarked image (uint8)
%   key   : what extractWatermark needs later. The method is non-blind, so
%           the key holds the original HH band.

    [LL, LH, HL, HH, Wpad] = splitCover(cover, W);

    key = struct('stage', 1, 'alpha', alpha, 'imgSize', size(cover));
    key.HH = HH;

    HHm = HH + alpha * Wpad;

    wmImg = joinCover(LL, LH, HL, HHm);
end
