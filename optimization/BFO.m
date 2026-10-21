function [bestPos, bestCost, evals] = BFO(costFcn, lo, hi, cfg)
% HY_BFO  Bacterial Foraging Optimization for ONE parameter (here: alpha).
% Written by hand, no toolbox. It follows the four stages in the paper:
% chemotaxis (tumble and swim), reproduction, elimination-dispersal.
% The swarming term is left out: with a single parameter it adds nothing.
%
%   [bestPos, bestCost, evals] = BFO(costFcn, lo, hi, cfg)
%
%   costFcn : handle, cost = costFcn(position). Lower is better.
%   lo, hi  : search limits for the parameter
%   cfg     : struct with
%       N    number of bacteria (made even)
%       nc   chemotactic steps per reproduction round
%       ns   maximum swim length
%       nre  reproduction rounds
%       ned  elimination-dispersal rounds
%       Ped  probability that a bacterium is dispersed
%       step chemotactic step size  <- this is what PSO tunes in stage 5
%
%   evals   : how many times costFcn was called (the slow part)

    N = 2 * floor(cfg.N / 2);
    evals = 0;

    pos = lo + (hi - lo) * rand(1, N);
    cost = zeros(1, N);
    for i = 1:N
        cost(i) = costFcn(pos(i));
        evals = evals + 1;
    end
    [bestCost, ib] = min(cost);
    bestPos = pos(ib);

    for l = 1:cfg.ned
        for k = 1:cfg.nre
            health = zeros(1, N);

            for j = 1:cfg.nc
                for i = 1:N
                    Jlast = cost(i);

                    % Tumble: with one parameter the new direction is +1 or -1
                    dirn = 2 * (rand > 0.5) - 1;
                    pos(i) = min(max(pos(i) + cfg.step * dirn, lo), hi);
                    cost(i) = costFcn(pos(i));
                    evals = evals + 1;
                    if cost(i) < bestCost
                        bestCost = cost(i);
                        bestPos = pos(i);
                    end

                    % Swim: keep going the same way while it keeps improving
                    m = 0;
                    while m < cfg.ns && cost(i) < Jlast
                        Jlast = cost(i);
                        pos(i) = min(max(pos(i) + cfg.step * dirn, lo), hi);
                        cost(i) = costFcn(pos(i));
                        evals = evals + 1;
                        if cost(i) < bestCost
                            bestCost = cost(i);
                            bestPos = pos(i);
                        end
                        m = m + 1;
                    end

                    health(i) = health(i) + cost(i);
                end
            end

            % Reproduction: the healthier half splits in two, the other half dies
            [~, order] = sort(health);
            keep = order(1:N/2);
            pos = [pos(keep), pos(keep)];
            cost = [cost(keep), cost(keep)];
        end

        % Elimination-dispersal: some bacteria are moved to random places
        for i = 1:N
            if rand < cfg.Ped
                pos(i) = lo + (hi - lo) * rand;
                cost(i) = costFcn(pos(i));
                evals = evals + 1;
                if cost(i) < bestCost
                    bestCost = cost(i);
                    bestPos = pos(i);
                end
            end
        end
    end
end
