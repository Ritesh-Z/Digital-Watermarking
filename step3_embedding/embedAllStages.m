function emb = embedAllStages(cover, W, opts)
% EMBEDALLSTAGES  Runs the whole EMBEDDING part: finds alpha with BFO and
% PBFO, then embeds the logo with all five methods so they can be compared.
%
% PIPELINE:  STEP 3 (embedding) - the "Embed" button of the GUI calls this.
%            No attack is applied here. Extraction (step 5) and attack tests
%            (step 6) come afterwards.
%
%   emb = embedAllStages(cover, W, opts)
%
% INPUTS
%   cover : uint8 grayscale image, even size        (from prepareCoverImage)
%   W     : watermark matrix, values 0..1           (from prepareWatermarkLogo)
%   opts  : optional struct; any setting in section 1 below can be overridden.
%           opts.statusFcn = @(msg) cancelRequested  is called with a progress
%           text; return true to cancel (error id 'embedAllStages:cancelled').
%
% THE FIVE STAGES (the last one is the project's main result)
%   1  DWT                embedStage1_DWT          alpha = 30 (fixed)
%   2  DWT-DCT            embedStage2_DWT_DCT      alpha = 30 (fixed)
%   3  DWT-DCT-SVD        embedStage3_DWT_DCT_SVD  alpha = 30 (fixed)
%   4  DWT-DCT-SVD-BFO    embedStage3_DWT_DCT_SVD  alpha found by BFO
%   5  DWT-DCT-SVD-PBFO   embedStage3_DWT_DCT_SVD  alpha found by PBFO (BFO + PSO)
%
% OUTPUT  emb (struct)
%   cover, W, isBinary         the inputs
%   stageNames, alphas         per stage
%   psnr, ssim, IF             embedding quality per stage (cover vs watermarked)
%   wmImgs, keys               watermarked image and extraction key per stage
%   alphaBFO, alphaPBFO, bestStep, costBFO, costPBFO,
%   evalsBFO, evalsPBFO, timeBFO, timePBFO      details of the alpha search
%   settings                   the settings that were used (section 1)

    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    % ================= 1. SETTINGS =======================================
    cfg = struct();
    cfg.alphaFixed    = 30;          % alpha of stages 1-3
    cfg.alphaRange    = [5 100];     % BFO / PBFO search range for alpha
    cfg.minPSNR       = 42;          % quality limit for the alpha search in dB (0 = paper exact eq. 13)
    cfg.trainSeed     = 7;           % noise seed used inside the fitness function
    cfg.testSeed      = 99;          % noise seed used for the attack tests
    cfg.optSeed       = 5;           % random seed of the optimisers
    cfg.bfoCfg        = struct('N',6,'nc',5,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
    cfg.bfoCfgFast    = struct('N',4,'nc',3,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
    cfg.psoCfg        = struct('nParticles',4,'iters',3,'w',0.6,'c1',1.5,'c2',1.5);
    cfg.stepRange     = [1 30];      % PSO search range for BFO's step size
    cfg.statusFcn     = @(msg) false;
    optNames = fieldnames(opts);
    for i = 1:numel(optNames)
        cfg.(optNames{i}) = opts.(optNames{i});
    end
    trainAttackCfg = defaultAttackSettings();

    % ================= 2. CHECK THE INPUTS ===============================
    if ~isa(cover, 'uint8') || ~ismatrix(cover)
        error('embedAllStages:badCover', 'The cover image must be a uint8 grayscale image.');
    end
    if ~(isnumeric(W) || islogical(W)) || ~ismatrix(W) || isempty(W) || any(~isfinite(double(W(:))))
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

    % ================= 3. FIND ALPHA (BFO, then PBFO) ====================
    lo = cfg.alphaRange(1);
    hi = cfg.alphaRange(2);
    evalCount = 0;
    phase = '';

    % SPEED-UPS (the result is exactly the same):
    %  - pre:   DWT, DCT and SVD of the cover and the logo do not depend on
    %           alpha, so they are computed ONCE instead of in every evaluation
    %  - cache: the search often tries the same alpha again (the edges of the
    %           range, the same start points in every PSO trial); a value that
    %           was already scored is taken from the cache
    pre   = analyseCoverAndLogo(cover, W);
    cache = containers.Map('KeyType', 'char', 'ValueType', 'double');
    nCached = 0;

    setPhase('BFO: searching for the best embedding strength alpha');
    tic;
    rng(cfg.optSeed);
    [alphaBFO, costBFO, evalsBFO] = optimizerBFO(@countedFitness, lo, hi, cfg.bfoCfg);
    timeBFO = toc;

    pcfg = struct('bfoCfg', cfg.bfoCfg, 'bfoCfgFast', cfg.bfoCfgFast, 'psoCfg', cfg.psoCfg, ...
                  'stepRange', cfg.stepRange, 'seed', cfg.optSeed, 'onPhase', @setPhase);
    tic;
    [alphaPBFO, costPBFO, pinfo] = optimizerPBFO(@countedFitness, lo, hi, pcfg);
    timePBFO = toc;

    % ================= 4. EMBED WITH ALL FIVE STAGES =====================
    stageNames  = {'DWT', 'DWT-DCT', 'DWT-DCT-SVD', 'DWT-DCT-SVD-BFO', 'DWT-DCT-SVD-PBFO'};
    stageMethod = [1 2 3 3 3];
    alphas      = [cfg.alphaFixed cfg.alphaFixed cfg.alphaFixed alphaBFO alphaPBFO];
    nS = numel(stageNames);

    psnrAll = zeros(1, nS);
    ssimAll = zeros(1, nS);
    ifAll   = zeros(1, nS);
    wmImgs  = cell(1, nS);
    keys    = cell(1, nS);

    for s = 1:nS
        report(sprintf('Embedding, stage %d of %d: %s', s, nS, stageNames{s}));
        switch stageMethod(s)
            case 1,    [wmImg, key] = embedStage1_DWT(cover, W, alphas(s));
            case 2,    [wmImg, key] = embedStage2_DWT_DCT(cover, W, alphas(s));
            otherwise, [wmImg, key] = embedStage3_DWT_DCT_SVD(cover, W, alphas(s), pre);
        end
        q = calculateMetrics(cover, wmImg);
        psnrAll(s) = q.psnr;
        ssimAll(s) = q.ssim;
        ifAll(s)   = q.IF;
        wmImgs{s}  = wmImg;
        keys{s}    = key;
    end

    % ================= 5. COLLECT THE RESULTS ============================
    emb = struct();
    emb.cover      = cover;       emb.W        = W;          emb.isBinary = isBinary;
    emb.stageNames = stageNames;  emb.alphas   = alphas;
    emb.psnr       = psnrAll;     emb.ssim     = ssimAll;    emb.IF       = ifAll;
    emb.wmImgs     = wmImgs;      emb.keys     = keys;
    emb.alphaBFO   = alphaBFO;    emb.alphaPBFO = alphaPBFO; emb.bestStep = pinfo.bestStep;
    emb.costBFO    = costBFO;     emb.costPBFO = costPBFO;
    emb.evalsBFO   = evalsBFO;    emb.evalsPBFO = pinfo.evals;
    emb.timeBFO    = timeBFO;     emb.timePBFO = timePBFO;
    emb.settings   = rmfield(cfg, 'statusFcn');
    emb.testSeed   = cfg.testSeed;
    emb.isColour   = false;          % addColourToStages switches this on

    % ---------------- nested helpers (they share the variables above) ----
    function f = countedFitness(a)
        id = sprintf('%.15g', a);
        if isKey(cache, id)                  % this alpha was scored before
            f = cache(id);
            nCached = nCached + 1;
            return;
        end
        evalCount = evalCount + 1;
        f = fitnessFunction(a, cover, W, trainAttackCfg, cfg.trainSeed, cfg.minPSNR, pre);
        cache(id) = f;
        if evalCount == 1 || mod(evalCount, 5) == 0
            report(sprintf('%s  (%d new alpha tests, %d repeats answered from memory)', phase, evalCount, nCached));
        end
    end

    function setPhase(msg)
        phase = msg;
        evalCount = 0;          % new = computed, nCached = answered from the cache
        nCached = 0;
        report(phase);
    end

    function report(msg)
        if cfg.statusFcn(msg)
            error('embedAllStages:cancelled', 'Cancelled by the user.');
        end
    end
end
