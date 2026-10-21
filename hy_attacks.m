function out = hy_attacks(img, seed, noiseCfg)
% HY_ATTACKS  Adds the four noise types used in the paper, one at a time,
% in the paper's order: Gaussian, shot, salt and pepper, speckle.
%
%   out = hy_attacks(img, seed, noiseCfg)
%
%   img      : uint8 image (usually the watermarked image)
%   seed     : random seed, so the same seed always gives the same noise
%   noiseCfg : struct with fields gaussVar, saltPepperDensity, speckleVar
%
%   out      : 1x4 cell array of noisy uint8 images
%
% The caller's random generator state is restored afterwards, so seeding the
% noise here does not disturb the random numbers used by BFO and PSO.

    saved = rng;
    rng(seed);

    out = cell(1, 4);
    out{1} = manual_imnoise_gaussian(img, noiseCfg.gaussVar);
    out{2} = hy_imnoise_shot(img);
    out{3} = manual_imnoise_saltpepper(img, noiseCfg.saltPepperDensity);
    out{4} = hy_imnoise_speckle(img, noiseCfg.speckleVar);

    rng(saved);
end
