function [bestX, bestCost] = hy_pso(costFcn, lo, hi, cfg)
% HY_PSO  Particle Swarm Optimization for ONE parameter, written by hand.
% In the paper PSO sets the best position of BFO's chemotactic parameter,
% so here costFcn runs a small BFO search for a given step size and returns
% the best cost that BFO found.
%
%   [bestX, bestCost] = hy_pso(costFcn, lo, hi, cfg)
%
%   cfg : struct with
%       nParticles  number of particles
%       iters       number of iterations
%       w           inertia weight
%       c1, c2      acceleration coefficients (own best, swarm best)
%
% Update rule (paper equations 14 and 15, written in the standard form):
%   v = w*v + c1*rand*(pbest - x) + c2*rand*(gbest - x)
%   x = x + v

    nP = cfg.nParticles;
    x = lo + (hi - lo) * rand(nP, 1);
    v = zeros(nP, 1);
    vmax = 0.2 * (hi - lo);

    pbest = x;
    pbestCost = zeros(nP, 1);
    for i = 1:nP
        pbestCost(i) = costFcn(x(i));
    end
    [bestCost, ib] = min(pbestCost);
    bestX = pbest(ib);

    for t = 1:cfg.iters
        for i = 1:nP
            v(i) = cfg.w * v(i) ...
                 + cfg.c1 * rand * (pbest(i) - x(i)) ...
                 + cfg.c2 * rand * (bestX - x(i));
            v(i) = min(max(v(i), -vmax), vmax);
            x(i) = min(max(x(i) + v(i), lo), hi);

            c = costFcn(x(i));
            if c < pbestCost(i)
                pbestCost(i) = c;
                pbest(i) = x(i);
            end
            if c < bestCost
                bestCost = c;
                bestX = x(i);
            end
        end
    end
end
