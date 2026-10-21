function pre = analyseCoverAndLogo(cover, W)
% ANALYSECOVERANDLOGO  Steps 1-3 of the DWT-DCT-SVD embedding: everything
% that does NOT depend on the strength alpha.
%
% PIPELINE:  STEP 3 (embedding). Used by embedStage3_DWT_DCT_SVD. The alpha
%            search (BFO / PBFO) tries over a thousand values of alpha on the
%            SAME cover and logo, so it computes this ONCE and reuses it -
%            only steps 4-5 (add alpha * sw, rebuild) are repeated.
%
%   pre = analyseCoverAndLogo(cover, W)
%
%   1. DWT    cover -> LL, LH, HL, HH
%   2. DCT    D = T * HH * T'
%   3. SVD    D = U * S * V'      (cover)    s  = diag(S)
%             W = Uw * Sw * Vw'   (logo)     sw = diag(Sw),  k = rank of the logo
%
% pre holds all of these plus the DCT matrices Tr, Tc and the image size.

    [LL, LH, HL, HH] = splitCoverIntoBands(cover, W);
    W = double(W);

    [r, c] = size(HH);
    Tr = dctMatrix(r);
    Tc = dctMatrix(c);
    D  = Tr * HH * Tc';

    [U, S, V]    = svd(D);
    [Uw, Sw, Vw] = svd(W, 'econ');
    sw = diag(Sw);

    pre = struct('LL', LL, 'LH', LH, 'HL', HL, 'HH', HH, 'Tr', Tr, 'Tc', Tc, 'D', D, ...
                 'U', U, 's', diag(S), 'V', V, 'Uw', Uw, 'sw', sw, 'Vw', Vw, ...
                 'k', sum(sw > 1e-8 * sw(1)), 'imgSize', size(cover));
end
