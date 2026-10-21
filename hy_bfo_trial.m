function bestCost = hy_bfo_trial(step, costFcn, lo, hi, bfoCfg, seed)
% HY_BFO_TRIAL  Runs one BFO search with a given chemotactic step size and
% returns the best cost it found. PSO calls this to judge each step size.
%
% The random generator is seeded so every step size is judged on equal terms,
% and the caller's generator state is restored afterwards (otherwise PSO's
% own random numbers would be reset every time).

    saved = rng;
    rng(seed);
    bfoCfg.step = step;
    [~, bestCost] = hy_bfo(costFcn, lo, hi, bfoCfg);
    rng(saved);
end
