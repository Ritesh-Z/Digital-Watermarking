function [LL, LH, HL, HH] = manual_dwt2_haar(img)
% MANUAL_DWT2_HAAR  Single-level 2D Haar wavelet decomposition, written
% by hand (no Wavelet Toolbox needed - dwt2 is a toolbox function).
%
%   [LL, LH, HL, HH] = manual_dwt2_haar(img)
%
%   img : grayscale image, dimensions must be even in both directions
%
%   LL : approximation sub-band (low freq both directions) - most of
%        the image's energy lives here, this is a shrunk version of img
%   LH : horizontal-detail sub-band
%   HL : vertical-detail sub-band   <- this is what we embed into
%   HH : diagonal-detail sub-band (high freq both directions, mostly noise/edges)
%
%   Each output is exactly half the width and half the height of img.

    img = double(img);

    % Pass 1: transform across columns (pair up adjacent columns)
    Lc = (img(:,1:2:end) + img(:,2:2:end)) / sqrt(2);
    Hc = (img(:,1:2:end) - img(:,2:2:end)) / sqrt(2);

    % Pass 2: transform across rows of the results above (pair up adjacent rows)
    LL = (Lc(1:2:end,:) + Lc(2:2:end,:)) / sqrt(2);
    LH = (Lc(1:2:end,:) - Lc(2:2:end,:)) / sqrt(2);
    HL = (Hc(1:2:end,:) + Hc(2:2:end,:)) / sqrt(2);
    HH = (Hc(1:2:end,:) - Hc(2:2:end,:)) / sqrt(2);
end
