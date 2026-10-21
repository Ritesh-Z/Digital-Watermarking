function f = hy_objective(alpha, cover, W, noiseCfg, seed, qualityWeight)
% HY_OBJECTIVE  The function BFO tries to minimise (paper equation 13):
%
%       Fobj = 1 / (NCC1 + NCC2 + NCC3 + NCC4)
%
% where NCC1..NCC4 are the watermark similarity scores after Gaussian, shot,
% salt and pepper and speckle noise. A smaller value means the watermark
% survives all four noises better. Uses the full DWT-DCT-SVD pipeline.
%
%   alpha         : embedding strength being tried
%   seed          : fixed noise seed so the same alpha always gives the same cost
%   qualityWeight : 0 follows the paper exactly. A value above 0 adds a penalty
%                   when the watermarked image drops below 50 dB PSNR, which
%                   stops the search from simply choosing the strongest alpha.

    [wm, key] = hy_embed(cover, W, alpha, 3);
    atk = hy_attacks(wm, seed, noiseCfg);

    total = 0;
    for i = 1:4
        We = hy_extract(atk{i}, key, size(W));
        total = total + hy_ncc(W, We);
    end
    f = 1 / max(total, 1e-6);

    if qualityWeight > 0
        p = hy_image_metrics(cover, wm);
        f = f + qualityWeight * max(50 - p, 0) / 50;
    end
end
