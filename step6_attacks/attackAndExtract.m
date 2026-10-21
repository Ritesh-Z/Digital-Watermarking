function res = attackAndExtract(emb, attackType, attackCfg)
% ATTACKANDEXTRACT  Attack test: noise -> extraction -> scores, for all five stages.
%
% PIPELINE:  STEP 6 (attacks). Fast (no optimisation), so the GUI calls it
%            every time the user tests an attack.
%
%   res = attackAndExtract(emb, attackType, attackCfg)
%
% INPUTS
%   emb        : struct from embedAllStages
%   attackType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%                ('none' = extract from the clean watermarked image)
%   attackCfg  : optional struct (gaussVar, saltPepperDensity, speckleVar);
%                missing fields use defaultAttackSettings
%
% FOR EVERY STAGE
%   1. attacked = applyAttack(watermarked image)
%      (colour mode: the COLOUR watermarked image is attacked)
%   2. W*       = extractWatermark(attacked)
%      (colour mode: from the brightness Y of the attacked colour image,
%       see receivedImage)
%   3. NC, BER  = calculateMetrics(original logo, W*)
%   4. PSNR/SSIM of watermarked vs attacked (how much the attack damaged it)
%
% OUTPUT  res = everything in emb, plus
%   attackType, attackLabel, attackParamText   description of the attack
%   ncc, ber                 logo recovery per stage
%   attackPsnr, attackSsim   damage done by the attack per stage (NaN for 'none')
%   attackedImgs, extImgs    attacked image and extracted logo per stage

    attackType = lower(char(attackType));
    if ~any(strcmp(attackType, {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'}))
        error('attackAndExtract:badAttack', 'Unknown attack type "%s".', attackType);
    end

    cfg = defaultAttackSettings();
    if nargin >= 3 && ~isempty(attackCfg)
        f = fieldnames(attackCfg);
        for i = 1:numel(f)
            cfg.(f{i}) = attackCfg.(f{i});
        end
    end

    nS = numel(emb.stageNames);
    hasAttack = ~strcmp(attackType, 'none');

    nccAll       = zeros(1, nS);
    berAll       = NaN(1, nS);
    attackPsnr   = NaN(1, nS);
    attackSsim   = NaN(1, nS);
    attackedImgs = cell(1, nS);
    extImgs      = cell(1, nS);

    for s = 1:nS
        [~, wmImg] = receivedImage(emb, s);                              % gray or colour
        attacked = applyAttack(wmImg, attackType, cfg, emb.testSeed);      % 1
        Y        = receivedImage(emb, s, attacked);
        We       = extractWatermark(Y, emb.keys{s}, size(emb.W));         % 2
        r        = calculateMetrics([], [], emb.W, We);                  % 3
        nccAll(s) = r.ncc;
        berAll(s) = r.ber;
        if hasAttack                                                      % 4
            q = calculateMetrics(wmImg, attacked);
            attackPsnr(s) = q.psnr;
            attackSsim(s) = q.ssim;
        end
        attackedImgs{s} = attacked;
        extImgs{s}      = We;
    end

    [label, paramText] = describeAttack(attackType, cfg);

    res = emb;
    res.attackType   = attackType;
    res.attackLabel  = label;
    res.attackParamText = paramText;
    res.attackCfg    = cfg;
    res.ncc          = nccAll;
    res.ber          = berAll;
    res.attackPsnr   = attackPsnr;
    res.attackSsim   = attackSsim;
    res.attackedImgs = attackedImgs;
    res.extImgs      = extImgs;
end

% =========================================================================
function [label, paramText] = describeAttack(attackType, cfg)
    switch attackType
        case 'gaussian',   label = 'Gaussian noise';       paramText = sprintf('variance %.4g', cfg.gaussVar);
        case 'shot',       label = 'Shot (Poisson) noise'; paramText = 'signal-dependent';
        case 'saltpepper', label = 'Salt & pepper noise';  paramText = sprintf('density %.4g', cfg.saltPepperDensity);
        case 'speckle',    label = 'Speckle noise';        paramText = sprintf('variance %.4g', cfg.speckleVar);
        otherwise,         label = 'No attack';            paramText = '';
    end
end
