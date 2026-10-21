function [bestAlpha, bestCost, info] = optimizerPBFO(costFcn, lo, hi, cfg)
% OPTIMIZERPBFO  PSO-tuned Bacterial Foraging Optimization (the paper's PBFO).
%
% PIPELINE:  STEP 4 (optimisation). Gives the alpha of stage 5, the main result.
%
%   [bestAlpha, bestCost, info] = optimizerPBFO(costFcn, lo, hi, cfg)
%
% IDEA
%   BFO works well or badly depending on its step size. So:
%     phase 1  PSO searches for a good BFO step size
%              (each candidate step is judged by running a small BFO)
%     phase 2  BFO runs once more with that tuned step size -> alpha
%
% INPUTS
%   costFcn : cost = costFcn(alpha), lower is better (fitnessFunction)
%   lo, hi  : search limits for alpha
%   cfg     : bfoCfg      settings of the final BFO run
%             bfoCfgFast  smaller BFO used while PSO judges step sizes
%             psoCfg      PSO settings
%             stepRange   [lo hi] for the BFO step size
%             seed        random seed (same answer every run)
%             onPhase     optional handle, called with a text before each phase
% OUTPUT
%   info : bestStep (step size found by PSO), evals (cost calls of phase 2)

    % ---- phase 1: PSO tunes the BFO step size
    notify('PBFO phase 1: PSO is tuning the BFO step size (slowest part)');
    rng(cfg.seed);
    trialFcn = @(st) bfoTrial(st, costFcn, lo, hi, cfg.bfoCfgFast, cfg.seed);
    bestStep = optimizerPSO(trialFcn, cfg.stepRange(1), cfg.stepRange(2), cfg.psoCfg);

    % ---- phase 2: BFO with the tuned step size
    notify('PBFO phase 2: BFO search with the tuned step size');
    tuned = cfg.bfoCfg;
    tuned.step = bestStep;
    rng(cfg.seed);
    [bestAlpha, bestCost, evals] = optimizerBFO(costFcn, lo, hi, tuned);

    info = struct('bestStep', bestStep, 'evals', evals);

    function notify(msg)
        if isfield(cfg, 'onPhase') && ~isempty(cfg.onPhase)
            cfg.onPhase(msg);
        end
    end
end

% =========================================================================
function bestCost = bfoTrial(step, costFcn, lo, hi, bfoCfg, seed)
% One small BFO run with the given step size; returns the best cost found.
% Seeded so every step size is judged on equal terms; the caller's random
% state is restored afterwards so PSO's own random numbers are not reset.
    saved = rng;
    rng(seed);
    bfoCfg.step = step;
    [~, bestCost] = optimizerBFO(costFcn, lo, hi, bfoCfg);
    rng(saved);
end
