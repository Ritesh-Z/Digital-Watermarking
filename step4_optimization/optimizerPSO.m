function [bestX, bestCost] = optimizerPSO(costFcn, lo, hi, cfg)
% OPTIMIZERPSO  Particle Swarm Optimization for ONE parameter. Written by hand.
%
% PIPELINE:  STEP 4 (optimisation). Used only inside optimizerPBFO, where it
%            tunes BFO's step size (each "position" is a step size and its
%            cost is the result of a small BFO run).
%
%   [bestX, bestCost] = optimizerPSO(costFcn, lo, hi, cfg)
%
% IDEA - a flock of birds: every particle remembers its own best position
% (pbest) and knows the best position of the whole swarm (gbest), and is
% pulled towards both.
%
% UPDATE RULE (paper eq. 14 and 15)
%   v = w*v + c1*rand*(pbest - x) + c2*rand*(gbest - x)
%   x = x + v
%
%   cfg : nParticles, iters, w (inertia), c1 (own best), c2 (swarm best)

    nP   = cfg.nParticles;
    x    = lo + (hi - lo) * rand(nP, 1);     % random start positions
    v    = zeros(nP, 1);
    vmax = 0.2 * (hi - lo);                  % speed limit

    pbest     = x;
    pbestCost = zeros(nP, 1);
    for i = 1:nP
        pbestCost(i) = costFcn(x(i));
    end
    [bestCost, ib] = min(pbestCost);
    bestX = pbest(ib);                       % gbest

    for t = 1:cfg.iters
        for i = 1:nP
            % velocity and position update
            v(i) = cfg.w * v(i) ...
                 + cfg.c1 * rand * (pbest(i) - x(i)) ...
                 + cfg.c2 * rand * (bestX    - x(i));
            v(i) = min(max(v(i), -vmax), vmax);
            x(i) = min(max(x(i) + v(i), lo), hi);

            % remember the best positions
            c = costFcn(x(i));
            if c < pbestCost(i)
                pbestCost(i) = c;
                pbest(i)     = x(i);
            end
            if c < bestCost
                bestCost = c;
                bestX    = x(i);
            end
        end
    end
end
