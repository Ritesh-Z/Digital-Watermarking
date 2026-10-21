function [bestAlpha, bestCost, info] = PBFO(costFcn, lo, hi, cfg)
% PBFO  PSO-tuned Bacterial Foraging Optimization (the paper's PBFO).
% BFO's chemotactic step size decides how well the search works, so PSO
% looks for a good step size, and then BFO runs once more with it.
%
%   [bestAlpha, bestCost, info] = PBFO(costFcn, lo, hi, cfg)
%
%   costFcn : handle, cost = costFcn(alpha). Lower is better.
%   lo, hi  : search limits for alpha
%   cfg     : struct with
%       bfoCfg      settings of the final BFO run (see BFO.m)
%       bfoCfgFast  smaller BFO settings used while PSO judges step sizes
%       psoCfg      PSO settings (see PSO.m)
%       stepRange   [lo hi] limits for the BFO step size
%       seed        random seed, so every run gives the same answer
%       onPhase     optional handle, called with a text before each phase
%
%   info    : struct with bestStep (step size PSO found) and evals (how many
%             times costFcn was called by the final BFO run)

    notify('PBFO: PSO is tuning the BFO step size (this is the slowest part)');
    rng(cfg.seed);
    trialFcn = @(st) bfoTrial(st, costFcn, lo, hi, cfg.bfoCfgFast, cfg.seed);
    [bestStep, ~] = PSO(trialFcn, cfg.stepRange(1), cfg.stepRange(2), cfg.psoCfg);

    tuned = cfg.bfoCfg;
    tuned.step = bestStep;

    notify('PBFO: final search with the tuned step size');
    rng(cfg.seed);
    [bestAlpha, bestCost, evals] = BFO(costFcn, lo, hi, tuned);

    info = struct('bestStep', bestStep, 'evals', evals);

    function notify(msg)
        if isfield(cfg, 'onPhase') && ~isempty(cfg.onPhase)
            cfg.onPhase(msg);
        end
    end
end

function bestCost = bfoTrial(step, costFcn, lo, hi, bfoCfg, seed)
% Runs one BFO search with the given step size and returns the best cost it
% found. PSO calls this to judge each step size. The generator is seeded so
% every step size is judged on equal terms, and the caller's generator state
% is restored (otherwise PSO's own random numbers would be reset each time).
    saved = rng;
    rng(seed);
    bfoCfg.step = step;
    [~, bestCost] = BFO(costFcn, lo, hi, bfoCfg);
    rng(saved);
end
