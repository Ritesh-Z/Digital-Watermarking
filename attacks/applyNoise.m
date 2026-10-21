function out = applyNoise(img, noiseType, noiseCfg, seed)
% APPLYNOISE  Applies ONE noise to an image. No toolbox needed.
%
%   out = applyNoise(img, noiseType, noiseCfg, seed)
%
%   img       : uint8 image (usually the watermarked image)
%   noiseType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%   noiseCfg  : struct with gaussVar, saltPepperDensity, speckleVar
%               (only the field for the chosen noise is read)
%   seed      : optional random seed. The same seed always gives the same
%               noise. The caller's random generator state is restored
%               afterwards, so this does not disturb BFO and PSO.
%
% 'none' returns the image untouched.
%
% The four noises (the paper's list):
%   gaussian    zero-mean Gaussian noise, image scaled to 0..1 (like imnoise)
%   shot        Poisson noise, approximated by I + sqrt(I) * randn
%   saltpepper  a fraction 'density' of pixels set to 0 or 255
%   speckle     multiplicative noise, J = I + n .* I, n uniform with the
%               given variance

    noiseType = lower(char(noiseType));
    if strcmp(noiseType, 'none')
        out = img;
        return;
    end

    if nargin >= 4 && ~isempty(seed)
        saved = rng;
        restore = onCleanup(@() rng(saved));   %#ok<NASGU>
        rng(seed);
    end

    switch noiseType
        case 'gaussian'
            out = gaussianNoise(img, noiseCfg.gaussVar);
        case 'shot'
            out = shotNoise(img);
        case 'saltpepper'
            out = saltPepperNoise(img, noiseCfg.saltPepperDensity);
        case 'speckle'
            out = speckleNoise(img, noiseCfg.speckleVar);
        otherwise
            error('applyNoise:badType', 'Unknown noise type "%s".', noiseType);
    end
end

function out = gaussianNoise(img, variance)
    imgD = double(img) / 255;
    noise = sqrt(variance) * randn(size(imgD));
    noisy = min(max(imgD + noise, 0), 1);
    out = uint8(noisy * 255);
end

function out = shotNoise(img)
% imnoise(I, 'poisson') treats every pixel value as the mean of a Poisson
% random number. A Poisson variable with a large mean behaves almost like a
% Gaussian whose variance equals the mean, so I + sqrt(I) * randn is used.
    imgD = double(img);
    noisy = imgD + sqrt(max(imgD, 0)) .* randn(size(imgD));
    out = uint8(min(max(round(noisy), 0), 255));
end

function out = saltPepperNoise(img, density)
    imgD = double(img);
    mask = rand(size(imgD));
    imgD(mask < density/2) = 0;
    imgD(mask >= density/2 & mask < density) = 255;
    out = uint8(imgD);
end

function out = speckleNoise(img, variance)
    imgD = double(img);
    n = sqrt(12 * variance) * (rand(size(imgD)) - 0.5);
    noisy = imgD + n .* imgD;
    out = uint8(min(max(round(noisy), 0), 255));
end
