function [LL, LH, HL, HH] = haarDWT2(img)
% HAARDWT2  One-level 2-D Haar Discrete Wavelet Transform (forward).
%           Written by hand - dwt2 would need the Wavelet Toolbox.
%
% PIPELINE:  STEP 2 (transforms) - first transform of embedding AND extraction.
%            Undo it with haarIDWT2.
%
%   [LL, LH, HL, HH] = haarDWT2(img)
%
%   img : grayscale image, even height and width
%
% Each output is half the height and half the width of img:
%   LL : low/low   - approximation, a small copy of the image (most energy)
%   LH : low/high  - horizontal details
%   HL : high/low  - vertical details
%   HH : high/high - diagonal details (fine edges, texture)
%                    <- THE WATERMARK IS HIDDEN IN THIS BAND
%
% HOW IT WORKS
%   Take every pair of neighbouring pixels (a, b):
%       average part  (a + b) / sqrt(2)     "low"  (L)
%       difference    (a - b) / sqrt(2)     "high" (H)
%   Do this once across the columns and once across the rows -> 4 bands.
%   The 1/sqrt(2) keeps the transform orthonormal (energy is preserved).

    img = double(img);

    % Pass 1: pair up neighbouring COLUMNS
    Lc = (img(:, 1:2:end) + img(:, 2:2:end)) / sqrt(2);
    Hc = (img(:, 1:2:end) - img(:, 2:2:end)) / sqrt(2);

    % Pass 2: pair up neighbouring ROWS of the two results
    LL = (Lc(1:2:end, :) + Lc(2:2:end, :)) / sqrt(2);
    LH = (Lc(1:2:end, :) - Lc(2:2:end, :)) / sqrt(2);
    HL = (Hc(1:2:end, :) + Hc(2:2:end, :)) / sqrt(2);
    HH = (Hc(1:2:end, :) - Hc(2:2:end, :)) / sqrt(2);
end
