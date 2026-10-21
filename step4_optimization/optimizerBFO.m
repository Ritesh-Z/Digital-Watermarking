function [bestPos, bestCost, evals] = optimizerBFO(costFcn, lo, hi, cfg)
% OPTIMIZERBFO  Bacterial Foraging Optimization for ONE parameter (alpha).
%               Written by hand, no toolbox.
%
% PIPELINE:  STEP 4 (optimisation). Used for stage 4 (BFO) and inside
%            optimizerPBFO for stage 5.
%
%   [bestPos, bestCost, evals] = optimizerBFO(costFcn, lo, hi, cfg)
%
% IDEA - E. coli bacteria looking for food:
%   each bacterium is one candidate alpha; "food" = low cost.
%
%   for each elimination-dispersal round  (ned)
%     for each reproduction round          (nre)
%       for each chemotactic step          (nc)
%         every bacterium:
%           TUMBLE : pick a random direction (+1 or -1) and take one step
%           SWIM   : keep stepping the same way while the cost improves
%                    (at most ns steps)
%       REPRODUCTION : the healthier half splits in two, the other half dies
%     ELIMINATION-DISPERSAL : with probability Ped a bacterium is moved to
%                             a random place (escapes local minima)
%   (The swarming term of the paper is left out: with one parameter it adds nothing.)
%
% INPUTS
%   costFcn : handle, cost = costFcn(position). Lower is better.
%   lo, hi  : search limits
%   cfg     : N (bacteria, made even), nc, ns, nre, ned, Ped,
%             step (chemotactic step size - PSO tunes this in PBFO)
% OUTPUTS
%   bestPos, bestCost : best alpha found and its cost
%   evals             : how many times costFcn was called (the slow part)

    N = 2 * floor(cfg.N / 2);
    evals    = 0;
    bestCost = Inf;      % evaluate() below keeps these two up to date
    bestPos  = NaN;

    % ---- random start
    pos  = lo + (hi - lo) * rand(1, N);
    cost = zeros(1, N);
    for i = 1:N
        cost(i) = evaluate(pos(i));
    end

    for l = 1:cfg.ned
        for r = 1:cfg.nre
            health = zeros(1, N);

            for j = 1:cfg.nc
                for i = 1:N
                    Jlast = cost(i);

                    % -- TUMBLE: with one parameter the direction is +1 or -1
                    dirn = 2 * (rand > 0.5) - 1;
                    pos(i)  = clamp(pos(i) + cfg.step * dirn);
                    cost(i) = evaluate(pos(i));

                    % -- SWIM: keep going while it keeps improving
                    m = 0;
                    while m < cfg.ns && cost(i) < Jlast
                        Jlast   = cost(i);
                        pos(i)  = clamp(pos(i) + cfg.step * dirn);
                        cost(i) = evaluate(pos(i));
                        m = m + 1;
                    end

                    health(i) = health(i) + cost(i);
                end
            end

            % -- REPRODUCTION: healthiest half (lowest total cost) is copied
            [~, order] = sort(health);
            keep = order(1:N/2);
            pos  = [pos(keep),  pos(keep)];
            cost = [cost(keep), cost(keep)];
        end

        % -- ELIMINATION-DISPERSAL
        for i = 1:N
            if rand < cfg.Ped
                pos(i)  = lo + (hi - lo) * rand;
                cost(i) = evaluate(pos(i));
            end
        end
    end

    % ---------------- nested helpers ----------------
    function c = evaluate(p)
        c = costFcn(p);
        evals = evals + 1;
        if c < bestCost
            bestCost = c;
            bestPos  = p;
        end
    end

    function p = clamp(p)
        p = min(max(p, lo), hi);
    end
end
