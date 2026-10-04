function extractedW = hybrid_paper_extract(watermarkedImg, Sc, Uw, Vw, alpha, band)
% HYBRID_PAPER_EXTRACT  Non-blind extraction for hybrid_paper_embed
% (the paper's extraction algorithm): recompute the DC matrix C* of the
% (possibly attacked) image, S3 = (S* - Sc) / alpha, W* = Uw * S3 * Vw'.
%
% Known weakness (shown in main_security_test.m): because Uw and Vw carry
% the watermark's structure, someone using THEIR OWN Uw, Vw "extracts"
% their own logo from the owner's image - the ownership-ambiguity flaw of
% SVD watermarking (Zhang & Li, 2005).
    if nargin < 6, band = 'HH'; end
    [LL, LH, HL, HH] = manual_dwt2_haar(watermarkedImg);
    bands = {LL, LH, HL, HH};
    X = bands{strcmp({'LL', 'LH', 'HL', 'HH'}, band)};
    [h, w] = size(X);
    T = manual_dct_matrix(4);
    Bk = img_to_blocks(X, 4);
    dcs = zeros(1, size(Bk, 2));
    for k = 1:size(Bk, 2)
        D = T * reshape(Bk(:, k), 4, 4) * T';
        dcs(k) = D(1, 1);
    end
    C = reshape(dcs, h/4, w/4);
    S = svd(C);
    S3 = diag((S - diag(Sc)) / alpha);
    extractedW = uint8(min(max(round(Uw * S3 * Vw'), 0), 255));
end
