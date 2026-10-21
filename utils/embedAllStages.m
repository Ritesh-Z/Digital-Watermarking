function emb = embedAllStages(cover, W, opts)
% EMBEDALLSTAGES  Step 1 of the processing: finds alpha with BFO and PBFO and
% embeds the watermark in the cover with all five stages. No noise is applied
% here; that is attackAndExtract (step 2), so the user can look at the clean
% watermarked image first and choose the noise afterwards.
%
%   emb = embedAllStages(cover, W, opts)
%
%   cover : uint8 grayscale image, even size (see prepareCover)
%   W     : watermark matrix, values 0..1 (see prepareWatermark)
%   opts  : optional struct. Any default below can be overridden, e.g.
%             opts.statusFcn  @(msg) cancelRequested  - called with a status
%                             text during the slow BFO/PBFO search; return
%                             true to cancel (error id embedAllStages:cancelled)
%
% The five stages:
%   1 DWT (embedDWT)   2 DWT-DCT (embedDWTDCT)   3 DWT-DCT-SVD (embedDWTDCT_SVD)
%   4 stage 3 with alpha from BFO     5 stage 3 with alpha from PBFO (primary)
%
% The BFO and PBFO searches use the paper's objective (local function
% objective below), which tests all four noises internally at the paper's
% default levels.
%
% emb holds: cover, W, isBinary, stageNames, alphas, psnr, ssim, IF (embedding
% quality per stage, cover vs clean watermarked image), wmImgs (clean
% watermarked image per stage), keys (extraction keys per stage), testSeed,
% alphaBFO, alphaPBFO, bestStep, costBFO, costPBFO, evalsBFO, evalsPBFO,
% timeBFO, timePBFO.

    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    % ---- Settings
    cfg = struct();
    cfg.alphaFixed    = 30;
    cfg.alphaRange    = [5 100];
    cfg.qualityWeight = 0;       % 0 = paper exact. Try 0.1 to also reward image quality
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
    trainNoiseCfg = defaultNoise();    % what BFO/PBFO always train on

    % ---- Check the inputs
    if ~isa(cover, 'uint8') || ndims(cover) ~= 2
        error('embedAllStages:badCover', 'The cover image must be a uint8 grayscale image.');
    end
    if ~(isnumeric(W) || islogical(W)) || ndims(W) ~= 2 || isempty(W) || any(~isfinite(double(W(:))))
        error('embedAllStages:badWatermark', 'The watermark must be a non-empty 2-D numeric matrix.');
    end
    W = double(W);
    if max(W(:)) == min(W(:))
        error('embedAllStages:flatWatermark', 'The watermark is one flat colour; there is nothing to embed.');
    end
    half = size(cover) / 2;
    if size(W, 1) > half(1) || size(W, 2) > half(2)
        error('embedAllStages:watermarkTooLarge', ...
              'The watermark (%d x %d) is too large for this cover image (maximum %d x %d).', ...
              size(W, 1), size(W, 2), half(1), half(2));
    end
    isBinary = all(W(:) == 0 | W(:) == 1);

    % ---- Find alpha with BFO and with PBFO
    lo = cfg.alphaRange(1);
    hi = cfg.alphaRange(2);
    evalCount = 0;
    phase = '';
    objFcn = @countedObjective;

    setPhase('BFO: searching for the embedding strength');
    tic;
    rng(cfg.optSeed);
    [alphaBFO, costBFO, evalsBFO] = BFO(objFcn, lo, hi, cfg.bfoCfg);
    tBFO = toc;

    pcfg = struct('bfoCfg', cfg.bfoCfg, 'bfoCfgFast', cfg.bfoCfgFast, 'psoCfg', cfg.psoCfg, ...
                  'stepRange', cfg.stepRange, 'seed', cfg.optSeed, 'onPhase', @setPhase);
    tic;
    [alphaPBFO, costPBFO, pinfo] = PBFO(objFcn, lo, hi, pcfg);
    tPBFO = toc;
    bestStep = pinfo.bestStep;
    evalsPBFO = pinfo.evals;

    % ---- Embed with the five stages (clean images only)
    stageNames = {'DWT', 'DWT-DCT', 'DWT-DCT-SVD', 'DWT-DCT-SVD-BFO', 'DWT-DCT-SVD-PBFO'};
    stageType  = [1 2 3 3 3];
    alphas     = [cfg.alphaFixed cfg.alphaFixed cfg.alphaFixed alphaBFO alphaPBFO];
    nS = numel(stageNames);

    psnrAll = zeros(1, nS);
    ssimAll = zeros(1, nS);
    ifAll   = zeros(1, nS);
    wmImgs  = cell(1, nS);
    keys    = cell(1, nS);

    for s = 1:nS
        report(sprintf('Embedding, stage %d of %d: %s', s, nS, stageNames{s}));
        [wmImg, key] = embedStage(cover, W, alphas(s), stageType(s));
        q = calculateMetrics(cover, wmImg);
        psnrAll(s) = q.psnr;
        ifAll(s)   = q.IF;
        ssimAll(s) = q.ssim;
        wmImgs{s}  = wmImg;
        keys{s}    = key;
    end

    % ---- Collect everything
    emb = struct();
    emb.cover = cover;           emb.W = W;               emb.isBinary = isBinary;
    emb.stageNames = stageNames; emb.alphas = alphas;
    emb.psnr = psnrAll;          emb.ssim = ssimAll;      emb.IF = ifAll;
    emb.wmImgs = wmImgs;         emb.keys = keys;         emb.testSeed = cfg.testSeed;
    emb.alphaBFO = alphaBFO;     emb.alphaPBFO = alphaPBFO;
    emb.bestStep = bestStep;     emb.costBFO = costBFO;   emb.costPBFO = costPBFO;
    emb.evalsBFO = evalsBFO;     emb.evalsPBFO = evalsPBFO;
    emb.timeBFO = tBFO;          emb.timePBFO = tPBFO;

    % ---------------- nested helpers (share the variables above) -------------
    function f = countedObjective(a)
        % The paper's objective, with a progress counter around it.
        evalCount = evalCount + 1;
        f = objective(a, cover, W, trainNoiseCfg, cfg.trainSeed, cfg.qualityWeight);
        if evalCount == 1 || mod(evalCount, 5) == 0
            report(sprintf('%s  (%d evaluations)', phase, evalCount));
        end
    end

    function setPhase(msg)
        phase = msg;
        evalCount = 0;
        report(phase);
    end

    function report(msg)
        if cfg.statusFcn(msg)
            error('embedAllStages:cancelled', 'Cancelled by the user.');
        end
    end
end

function [wmImg, key] = embedStage(cover, W, alpha, stageType)
% Picks the embedding function for a stage number (1, 2 or 3).
    switch stageType
        case 1
            [wmImg, key] = embedDWT(cover, W, alpha);
        case 2
            [wmImg, key] = embedDWTDCT(cover, W, alpha);
        otherwise
            [wmImg, key] = embedDWTDCT_SVD(cover, W, alpha);
    end
end

function f = objective(alpha, cover, W, noiseCfg, seed, qualityWeight)
% The function BFO tries to minimise (paper equation 13):
%
%       Fobj = 1 / (NCC1 + NCC2 + NCC3 + NCC4)
%
% NCC1..NCC4 are the watermark similarity scores after Gaussian, shot,
% salt and pepper and speckle noise. A smaller value means the watermark
% survives all four noises better. Uses the full DWT-DCT-SVD stage.
%
%   seed          : fixed noise seed so the same alpha always gives the same cost
%   qualityWeight : 0 follows the paper exactly. A value above 0 adds a penalty
%                   when the watermarked image drops below 50 dB PSNR, which
%                   stops the search from simply choosing the strongest alpha.
    [wm, key] = embedDWTDCT_SVD(cover, W, alpha);
    noises = {'gaussian', 'shot', 'saltpepper', 'speckle'};

    total = 0;
    for i = 1:4
        noisy = applyNoise(wm, noises{i}, noiseCfg, seed);
        We = extractWatermark(noisy, key, size(W));
        m = calculateMetrics([], [], W, We);
        total = total + m.ncc;
    end
    f = 1 / max(total, 1e-6);

    if qualityWeight > 0
        q = calculateMetrics(cover, wm, [], [], false);
        f = f + qualityWeight * max(50 - q.psnr, 0) / 50;
    end
end

function n = defaultNoise()
% The noise levels used in the project and in the paper.
    n = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
end
