function [wmImg, key] = embedDWTDCT(cover, W, alpha)
% EMBEDDWTDCT  Stage 2: DWT, then DCT.
% Takes the DCT of the HH band, adds alpha * watermark onto the DCT values,
% goes back with the inverse DCT and then the inverse DWT.
%
%   [wmImg, key] = embedDWTDCT(cover, W, alpha)
%
% Inputs and outputs are the same as in embedDWT. The key holds the
% original DCT values of the HH band.

    [LL, LH, HL, HH, Wpad] = splitCover(cover, W);
    [r, c] = size(HH);
    Tr = dctMatrix(r);
    Tc = dctMatrix(c);

    key = struct('stage', 2, 'alpha', alpha, 'imgSize', size(cover));

    D = Tr * HH * Tc';            % DCT of the HH band
    key.D = D;

    HHm = Tr' * (D + alpha * Wpad) * Tc;   % add the watermark, inverse DCT

    wmImg = joinCover(LL, LH, HL, HHm);
end
