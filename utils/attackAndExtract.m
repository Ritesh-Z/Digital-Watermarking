function res = attackAndExtract(emb, noiseType, noiseCfg)
% ATTACKANDEXTRACT  Step 2 of the processing: applies ONE noise to the
% watermarked image of every stage, extracts the watermark from the noisy
% images and collects the metrics. Fast (no optimisation), so the GUI can
% call it every time the user picks a noise.
%
%   res = attackAndExtract(emb, noiseType, noiseCfg)
%
%   emb       : struct from embedAllStages
%   noiseType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%               'none' = extract from the clean watermarked image.
%   noiseCfg  : optional struct (gaussVar, saltPepperDensity, speckleVar);
%               missing fields use the project defaults.
%
% res = everything in emb, plus: noiseType, noiseLabel, noiseParamText,
% ncc, ber (recovery per stage), noisePsnr, noiseSsim (clean vs noisy, NaN
% for 'none'), finalImgs (noisy watermarked image per stage), extImgs
% (extracted watermark per stage).

    noiseType = lower(char(noiseType));
    if ~any(strcmp(noiseType, {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'}))
        error('attackAndExtract:badNoise', 'Unknown noise type "%s".', noiseType);
    end

    cfgN = defaultNoise();
    if nargin >= 3 && ~isempty(noiseCfg)
        f = fieldnames(noiseCfg);
        for k = 1:numel(f)
            cfgN.(f{k}) = noiseCfg.(f{k});
        end
    end

    nS = numel(emb.stageNames);
    hasNoise = ~strcmp(noiseType, 'none');

    nccAll    = zeros(1, nS);
    berAll    = NaN(1, nS);
    noisePsnr = NaN(1, nS);
    noiseSsim = NaN(1, nS);
    finalImgs = cell(1, nS);
    extImgs   = cell(1, nS);

    for s = 1:nS
        wmImg = emb.wmImgs{s};

        % The noise goes on the WATERMARKED image (never on the cover)
        finalImg = applyNoise(wmImg, noiseType, cfgN, emb.testSeed);

        We = extractWatermark(finalImg, emb.keys{s}, size(emb.W));
        r = calculateMetrics([], [], emb.W, We);
        nccAll(s) = r.ncc;
        berAll(s) = r.ber;
        if hasNoise
            nz = calculateMetrics(wmImg, finalImg);
            noisePsnr(s) = nz.psnr;
            noiseSsim(s) = nz.ssim;
        end
        finalImgs{s} = finalImg;
        extImgs{s}   = We;
    end

    switch noiseType
        case 'gaussian',   noiseLabel = 'Gaussian';        paramText = sprintf('variance %.4g', cfgN.gaussVar);
        case 'shot',       noiseLabel = 'Shot (Poisson)';  paramText = 'signal-dependent';
        case 'saltpepper', noiseLabel = 'Salt-and-Pepper'; paramText = sprintf('density %.4g', cfgN.saltPepperDensity);
        case 'speckle',    noiseLabel = 'Speckle';         paramText = sprintf('variance %.4g', cfgN.speckleVar);
        otherwise,         noiseLabel = 'None';            paramText = '';
    end

    res = emb;
    res.noiseType = noiseType;   res.noiseLabel = noiseLabel;   res.noiseParamText = paramText;
    res.ncc = nccAll;            res.ber = berAll;
    res.noisePsnr = noisePsnr;   res.noiseSsim = noiseSsim;
    res.finalImgs = finalImgs;   res.extImgs = extImgs;
end

function n = defaultNoise()
% The noise levels used in the project and in the paper.
    n = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
end
