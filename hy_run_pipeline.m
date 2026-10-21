function res = hy_run_pipeline(cover, W, noiseType, opts)
% HY_RUN_PIPELINE  Runs the five watermarking stages on the user's images and
% collects every metric. This is the processing part of the old
% main_demo_paper2.m script, with no GUI code in it. The algorithms are the
% original ones: hy_bfo, hy_pso, hy_bfo_trial, hy_objective, hy_embed,
% hy_extract, hy_image_metrics and hy_ncc are called exactly as before.
%
%   res = hy_run_pipeline(cover, W, noiseType, opts)
%
%   cover     : uint8 grayscale image, even size (see hy_prepare_cover)
%   W         : watermark matrix, values 0..1, any size that fits the HH band
%               (see hy_prepare_watermark)
%   noiseType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%               This one noise is applied to every stage's watermarked image
%               before extraction. 'none' = extract from the clean image.
%   opts      : optional struct. Any default below can be overridden, e.g.
%                 opts.noiseCfg   noise strengths for the FINAL noise
%                                 (fields gaussVar, saltPepperDensity, speckleVar)
%                 opts.statusFcn  @(msg) cancelRequested  - called with a status
%                                 text during the slow BFO/PBFO search; return
%                                 true to cancel (error id hy_run_pipeline:cancelled)
%
% The BFO and PBFO searches still use the project's original objective, which
% tests all four noises internally at the paper's default levels. That is
% independent of the single noise chosen for the final result.
%
% res holds: cover, W, isBinary, noiseType, noiseLabel, noiseParamText,
% stageNames, alphas, psnr, ssim, IF, ncc, ber (embedding quality and
% recovery per stage); noisePsnr, noiseSsim (clean vs noisy, NaN for 'none');
% wmImgs, finalImgs, extImgs (cell arrays, one entry per stage);
% alphaBFO, alphaPBFO, bestStep, costBFO, costPBFO, evalsBFO, evalsPBFO,
% timeBFO, timePBFO.

    if nargin < 4 || isempty(opts)
        opts = struct();
    end

    % ---- Settings: the same values as the original main_demo_paper2.m
    cfg = struct();
    cfg.alphaFixed    = 30;
    cfg.alphaRange    = [5 100];
    cfg.qualityWeight = 0;
    cfg.noiseCfg      = local_default_noise();
    cfg.trainSeed     = 7;
    cfg.testSeed      = 99;
    cfg.optSeed       = 5;
    cfg.bfoCfg        = struct('N',6,'nc',5,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
    cfg.bfoCfgFast    = struct('N',4,'nc',3,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
    cfg.psoCfg        = struct('nParticles',4,'iters',3,'w',0.6,'c1',1.5,'c2',1.5);
    cfg.stepRange     = [1 30];
    cfg.statusFcn     = @(msg) false;
    optNames = fieldnames(opts);
    for k = 1:numel(optNames)
        cfg.(optNames{k}) = opts.(optNames{k});
    end
    trainNoiseCfg = local_default_noise();    % what BFO/PBFO always train on

    % ---- Check the inputs
    noiseType = lower(char(noiseType));
    if ~any(strcmp(noiseType, {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'}))
        error('hy_run_pipeline:badNoise', 'Unknown noise type "%s".', noiseType);
    end
    if ~isa(cover, 'uint8') || ndims(cover) ~= 2
        error('hy_run_pipeline:badCover', 'The cover image must be a uint8 grayscale image.');
    end
    if ~(isnumeric(W) || islogical(W)) || ndims(W) ~= 2 || isempty(W) || any(~isfinite(double(W(:))))
        error('hy_run_pipeline:badWatermark', 'The watermark must be a non-empty 2-D numeric matrix.');
    end
    W = double(W);
    if max(W(:)) == min(W(:))
        error('hy_run_pipeline:flatWatermark', 'The watermark is one flat colour; there is nothing to embed.');
    end
    half = size(cover) / 2;
    if size(W, 1) > half(1) || size(W, 2) > half(2)
        error('hy_run_pipeline:watermarkTooLarge', ...
              'The watermark (%d x %d) is too large for this cover image (maximum %d x %d).', ...
              size(W, 1), size(W, 2), half(1), half(2));
    end
    isBinary = all(W(:) == 0 | W(:) == 1);

    % ---- Find alpha with BFO and with PBFO (original procedure)
    lo = cfg.alphaRange(1);
    hi = cfg.alphaRange(2);
    evalCount = 0;
    phase = '';
    objFcn = @countedObjective;

    phase = 'BFO: searching for the embedding strength';
    report(phase);
    tic;
    rng(cfg.optSeed);
    [alphaBFO, costBFO, evalsBFO] = hy_bfo(objFcn, lo, hi, cfg.bfoCfg);
    tBFO = toc;

    evalCount = 0;
    phase = 'PBFO: PSO is tuning the BFO step size (this is the slowest part)';
    report(phase);
    tic;
    trialFcn = @(st) hy_bfo_trial(st, objFcn, lo, hi, cfg.bfoCfgFast, cfg.optSeed);
    [bestStep, ~] = hy_pso(trialFcn, cfg.stepRange(1), cfg.stepRange(2), cfg.psoCfg);
    cfgTuned = cfg.bfoCfg;
    cfgTuned.step = bestStep;
    evalCount = 0;
    phase = 'PBFO: final search with the tuned step size';
    report(phase);
    rng(cfg.optSeed);
    [alphaPBFO, costPBFO, evalsPBFO] = hy_bfo(objFcn, lo, hi, cfgTuned);
    tPBFO = toc;

    % ---- Run the five stages with the one selected noise
    stageNames = {'DWT', 'DWT-DCT', 'DWT-DCT-SVD', 'DWT-DCT-SVD-BFO', 'DWT-DCT-SVD-PBFO'};
    stageType  = [1 2 3 3 3];
    alphas     = [cfg.alphaFixed cfg.alphaFixed cfg.alphaFixed alphaBFO alphaPBFO];
    nS = numel(stageNames);
    hasNoise = ~strcmp(noiseType, 'none');

    psnrAll   = zeros(1, nS);
    ssimAll   = zeros(1, nS);
    ifAll     = zeros(1, nS);
    nccAll    = zeros(1, nS);
    berAll    = NaN(1, nS);
    noisePsnr = NaN(1, nS);
    noiseSsim = NaN(1, nS);
    wmImgs    = cell(1, nS);
    finalImgs = cell(1, nS);
    extImgs   = cell(1, nS);

    for s = 1:nS
        report(sprintf('Embedding and extracting, stage %d of %d: %s', s, nS, stageNames{s}));

        [wmImg, key] = hy_embed(cover, W, alphas(s), stageType(s));
        [psnrAll(s), ifAll(s), ssimAll(s)] = hy_image_metrics(cover, wmImg);

        % The noise goes on the WATERMARKED image (never on the cover)
        finalImg = hy_apply_noise(wmImg, noiseType, cfg.noiseCfg, cfg.testSeed);

        We = hy_extract(finalImg, key, size(W));
        nccAll(s) = hy_ncc(W, We);
        if isBinary
            berAll(s) = mean((We(:) > 0.5) ~= (W(:) > 0.5));
        end
        if hasNoise
            [noisePsnr(s), ~, noiseSsim(s)] = hy_image_metrics(wmImg, finalImg);
        end

        wmImgs{s}    = wmImg;
        finalImgs{s} = finalImg;
        extImgs{s}   = We;
    end

    % ---- Collect everything
    switch noiseType
        case 'gaussian',   noiseLabel = 'Gaussian';        paramText = sprintf('variance %.4g', cfg.noiseCfg.gaussVar);
        case 'shot',       noiseLabel = 'Shot (Poisson)';  paramText = 'signal-dependent';
        case 'saltpepper', noiseLabel = 'Salt-and-Pepper'; paramText = sprintf('density %.4g', cfg.noiseCfg.saltPepperDensity);
        case 'speckle',    noiseLabel = 'Speckle';         paramText = sprintf('variance %.4g', cfg.noiseCfg.speckleVar);
        otherwise,         noiseLabel = 'None';            paramText = '';
    end

    res = struct();
    res.cover = cover;           res.W = W;               res.isBinary = isBinary;
    res.noiseType = noiseType;   res.noiseLabel = noiseLabel;   res.noiseParamText = paramText;
    res.stageNames = stageNames; res.alphas = alphas;
    res.psnr = psnrAll;  res.ssim = ssimAll;  res.IF = ifAll;
    res.ncc = nccAll;    res.ber = berAll;
    res.noisePsnr = noisePsnr;   res.noiseSsim = noiseSsim;
    res.wmImgs = wmImgs; res.finalImgs = finalImgs;       res.extImgs = extImgs;
    res.alphaBFO = alphaBFO;     res.alphaPBFO = alphaPBFO;
    res.bestStep = bestStep;     res.costBFO = costBFO;   res.costPBFO = costPBFO;
    res.evalsBFO = evalsBFO;     res.evalsPBFO = evalsPBFO;
    res.timeBFO = tBFO;          res.timePBFO = tPBFO;

    % ---------------- nested helpers (share the variables above) -------------
    function f = countedObjective(a)
        % The ORIGINAL objective, with a progress counter around it.
        evalCount = evalCount + 1;
        f = hy_objective(a, cover, W, trainNoiseCfg, cfg.trainSeed, cfg.qualityWeight);
        if evalCount == 1 || mod(evalCount, 5) == 0
            report(sprintf('%s  (%d evaluations)', phase, evalCount));
        end
    end

    function report(msg)
        if cfg.statusFcn(msg)
            error('hy_run_pipeline:cancelled', 'Cancelled by the user.');
        end
    end
end

function n = local_default_noise()
% The noise levels used in the original script and in the paper.
    n = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
end
