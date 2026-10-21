function out = applyAttack(img, attackType, attackCfg, seed)
% APPLYATTACK  Applies ONE noise attack to the watermarked image. No toolbox.
%
% PIPELINE:  STEP 6 (attacks) - always AFTER embedding: the noise goes on
%            the watermarked image, never on the original cover.
%
%   out = applyAttack(img, attackType, attackCfg, seed)
%
% INPUTS
%   img        : uint8 watermarked image
%   attackType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%   attackCfg  : struct with gaussVar, saltPepperDensity, speckleVar
%                (see defaultAttackSettings; only the needed field is read)
%   seed       : optional. Same seed -> same noise. The caller's random
%                state is restored afterwards (BFO/PSO are not disturbed).
%
% THE FOUR ATTACKS (the paper's list)
%   gaussian    J = I + n,         n ~ Normal(0, variance), I scaled to 0..1
%   shot        Poisson noise: brighter pixels get more noise,
%               approximated by  J = I + sqrt(I) * randn
%   saltpepper  a fraction "density" of pixels becomes 0 (pepper) or 255 (salt)
%   speckle     J = I + n .* I,    n uniform with the given variance
%               (multiplicative, like radar/ultrasound noise)

    attackType = lower(char(attackType));
    if strcmp(attackType, 'none')
        out = img;
        return;
    end

    if nargin >= 4 && ~isempty(seed)
        saved   = rng;
        restore = onCleanup(@() rng(saved));   %#ok<NASGU>
        rng(seed);
    end

    switch attackType
        case 'gaussian',   out = gaussianNoise(img, attackCfg.gaussVar);
        case 'shot',       out = shotNoise(img);
        case 'saltpepper', out = saltPepperNoise(img, attackCfg.saltPepperDensity);
        case 'speckle',    out = speckleNoise(img, attackCfg.speckleVar);
        otherwise
            error('applyAttack:badType', 'Unknown attack type "%s".', attackType);
    end
end

% =========================================================================
function out = gaussianNoise(img, variance)
    I = double(img) / 255;
    J = I + sqrt(variance) * randn(size(I));
    out = uint8(min(max(J, 0), 1) * 255);
end

function out = shotNoise(img)
% A Poisson variable with a large mean behaves almost like a Gaussian whose
% variance equals the mean, hence I + sqrt(I) * randn.
    I = double(img);
    J = I + sqrt(max(I, 0)) .* randn(size(I));
    out = uint8(min(max(round(J), 0), 255));
end

function out = saltPepperNoise(img, density)
    J = double(img);
    u = rand(size(J));
    J(u < density/2) = 0;                       % pepper
    J(u >= density/2 & u < density) = 255;      % salt
    out = uint8(J);
end

function out = speckleNoise(img, variance)
    I = double(img);
    n = sqrt(12 * variance) * (rand(size(I)) - 0.5);   % uniform, given variance
    J = I + n .* I;
    out = uint8(min(max(round(J), 0), 255));
end
