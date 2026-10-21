function f = fitnessFunction(alpha, cover, W, attackCfg, seed, minPSNR, pre)
% FITNESSFUNCTION  "How good is this alpha?"  Lower = better.
%                  This is what BFO and PBFO try to minimise.
%
% PIPELINE:  STEP 4 (optimisation) - called many times by optimizerBFO /
%            optimizerPBFO (through embedAllStages).
%
%   f = fitnessFunction(alpha, cover, W, attackCfg, seed, minPSNR)
%   f = fitnessFunction(alpha, cover, W, attackCfg, seed, minPSNR, pre)
%
% PAPER EQUATION 13 (robustness)
%       F(alpha) = 1 / (NC_gaussian + NC_shot + NC_saltpepper + NC_speckle)
%
%   For the given alpha:
%     1. embed the logo with the full DWT-DCT-SVD method
%     2. attack the watermarked image with each of the 4 noises
%     3. extract the logo from each attacked image
%     4. NC = similarity of extracted vs original logo (1 = perfect)
%   A higher total NC -> a smaller F -> the logo survives the attacks better.
%
% QUALITY LIMIT (image quality, added to the paper's formula)
%   Eq. 13 alone always prefers a STRONGER alpha (more robust), which makes
%   the watermark more visible (lower PSNR). With minPSNR > 0 every dB the
%   watermarked image falls below minPSNR adds a large penalty:
%       F = F + (minPSNR - PSNR)        when PSNR < minPSNR
%   so the search finds the MOST ROBUST alpha that still keeps
%   PSNR >= minPSNR. minPSNR = 0 is exactly the paper's eq. 13.
%
% INPUTS
%   attackCfg : noise strengths (see defaultAttackSettings)
%   seed      : fixed noise seed, so the same alpha always gives the same F
%   minPSNR   : quality limit in dB (0 = no limit, paper exact)
%   pre       : optional result of analyseCoverAndLogo(cover, W) - the parts
%               that do not depend on alpha, computed once (faster, same result)

    if nargin < 6, minPSNR = 0;  end
    if nargin < 7, pre = [];     end

    [wmImg, key] = embedStage3_DWT_DCT_SVD(cover, W, alpha, pre);

    % ---- robustness: paper eq. 13
    attacks = {'gaussian', 'shot', 'saltpepper', 'speckle'};
    totalNC = 0;
    for i = 1:numel(attacks)
        attacked = applyAttack(wmImg, attacks{i}, attackCfg, seed);
        We = extractWatermark(attacked, key, size(W));
        m  = calculateMetrics([], [], W, We);
        totalNC = totalNC + m.ncc;
    end
    f = 1 / max(totalNC, 1e-6);

    % ---- quality limit
    if minPSNR > 0
        q = calculateMetrics(cover, wmImg, [], [], false);
        if q.psnr < minPSNR
            f = f + (minPSNR - q.psnr);
        end
    end
end
