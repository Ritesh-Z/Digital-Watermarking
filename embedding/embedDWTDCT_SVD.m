function [wmImg, key] = embedDWTDCT_SVD(cover, W, alpha)
% EMBEDDWTDCT_SVD  Stage 3: DWT, then DCT, then SVD (the full hybrid method).
%
%   [wmImg, key] = embedDWTDCT_SVD(cover, W, alpha)
%
% Steps:
%   1. Haar DWT of the cover, take the HH band
%   2. DCT of the HH band
%   3. SVD of those DCT values:  D = U * S * V'
%   4. SVD of the watermark:     W = Uw * Sw * Vw'
%   5. Add alpha times the watermark's singular values onto the largest
%      singular values of the cover:   s2 = s + alpha * sw
%   6. Rebuild: inverse SVD, inverse DCT, inverse DWT
%
% Only the watermark's non-zero singular values are used (rank limited). A 0/1
% pattern like "VIT" has only a few, and the zero ones would only add noise.
%
% The key holds the cover's original singular values and the watermark's
% singular vectors (the method is non-blind, as in the paper).

    [LL, LH, HL, HH] = splitCover(cover, W);
    W = double(W);
    [r, c] = size(HH);
    Tr = dctMatrix(r);
    Tc = dctMatrix(c);

    key = struct('stage', 3, 'alpha', alpha, 'imgSize', size(cover));

    D = Tr * HH * Tc';
    [U, S, V] = svd(D);
    s = diag(S);

    [Uw, Sw, Vw] = svd(W, 'econ');
    sw = diag(Sw);
    k = sum(sw > 1e-8 * sw(1));

    s2 = s;
    s2(1:k) = s(1:k) + alpha * sw(1:k);
    Dm = U * diag(s2) * V';
    HHm = Tr' * Dm * Tc;

    key.s  = s(1:k);        % original singular values of the HH band
    key.Uw = Uw(:, 1:k);    % watermark's left vectors
    key.Vw = Vw(:, 1:k);    % watermark's right vectors

    wmImg = joinCover(LL, LH, HL, HHm);
end
