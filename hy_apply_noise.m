function out = hy_apply_noise(img, noiseType, noiseCfg, seed)
% HY_APPLY_NOISE  Applies ONE chosen noise to an image, using the project's
% existing noise functions (nothing is re-implemented here).
%
%   out = hy_apply_noise(img, noiseType, noiseCfg, seed)
%
%   noiseType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%   noiseCfg  : struct with gaussVar, saltPepperDensity, speckleVar
%   seed      : random seed, so the same seed always gives the same noise
%
% 'none' returns the image untouched. The caller's random generator state is
% restored afterwards (same habit as hy_attacks).

    noiseType = lower(char(noiseType));
    if strcmp(noiseType, 'none')
        out = img;
        return;
    end

    saved = rng;
    restore = onCleanup(@() rng(saved));   %#ok<NASGU>
    rng(seed);

    switch noiseType
        case 'gaussian'
            out = manual_imnoise_gaussian(img, noiseCfg.gaussVar);
        case 'shot'
            out = hy_imnoise_shot(img);
        case 'saltpepper'
            out = manual_imnoise_saltpepper(img, noiseCfg.saltPepperDensity);
        case 'speckle'
            out = hy_imnoise_speckle(img, noiseCfg.speckleVar);
        otherwise
            error('hy_apply_noise:badType', 'Unknown noise type "%s".', noiseType);
    end
end
