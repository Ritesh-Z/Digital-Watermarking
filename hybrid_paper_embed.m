function [watermarked, Sc, Uw, Vw] = hybrid_paper_embed(cover, watermarkImg, alpha, band)
% HYBRID_PAPER_EMBED  Reproduction of the base paper's algorithm:
% Loke, Swami & Kulkarni, "Hybrid Digital Watermarking Using DWT, DCT and
% SVD for Robust Image Protection", IJES 2025.
% (MATLAB port of python/wmark/schemes.py -> HybridPaperScheme.)
%
%   [watermarked, Sc, Uw, Vw] = hybrid_paper_embed(cover, watermarkImg, alpha, band)
%
%   cover        : grayscale uint8 image, both sides a multiple of 8
%   watermarkImg : grayscale watermark of size (H/8) x (W/8)  (e.g. 64x64 for 512x512)
%   alpha        : strength, the paper sweeps 0.05 .. 1.0 (demo default 0.1)
%   band         : 'LL', 'LH', 'HL' or 'HH' (the paper reports results for HH)
%
%   Sc, Uw, Vw   : the KEY. Like classic SVD this scheme is NON-BLIND, so
%                  these must be saved to extract the watermark later.
%
% Steps (as in the paper):
%   1) Haar (db1) DWT of the cover
%   2) split the chosen band into 4x4 blocks and DCT each block
%   3) collect the DC coefficient of every block into a matrix C
%   4) C = Uc*Sc*Vc'  and  W = Uw*Sw*Vw'
%   5) Sc' = Sc + alpha*Sw,  C' = Uc*Sc'*Vc'
%   6) put C' back as the DC coefficients, inverse DCT, inverse DWT
    if nargin < 4, band = 'HH'; end
    [LL, LH, HL, HH] = manual_dwt2_haar(cover);
    bands = {LL, LH, HL, HH};
    idx = find(strcmp({'LL', 'LH', 'HL', 'HH'}, band));
    X = bands{idx};
    [h, w] = size(X);
    T = manual_dct_matrix(4);
    Bk = img_to_blocks(X, 4);                    % 16 x nBlocks
    nb = size(Bk, 2);
    D = zeros(16, nb);
    for k = 1:nb
        D(:, k) = reshape(T * reshape(Bk(:, k), 4, 4) * T', 16, 1);
    end
    C = reshape(D(1, :), h/4, w/4);              % DC matrix, one entry per block

    [Uc, Sc, Vc] = svd(C);
    [Uw, Sw, Vw] = svd(double(watermarkImg));
    C2 = Uc * (Sc + alpha * Sw) * Vc';

    D(1, :) = C2(:)';
    for k = 1:nb
        Bk(:, k) = reshape(T' * reshape(D(:, k), 4, 4) * T, 16, 1);
    end
    bands{idx} = blocks_to_img(Bk, 4, h, w);
    watermarked = manual_idwt2_haar(bands{1}, bands{2}, bands{3}, bands{4});
    watermarked = uint8(min(max(round(watermarked), 0), 255));
end
