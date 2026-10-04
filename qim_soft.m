function s = qim_soft(c, step, d)
% QIM_SOFT  Soft QIM read-out in [-1, 1]: +1 exactly on an odd step
% (bit 1), -1 exactly on an even step (bit 0), ~0 half-way between
% (an unreliable copy). Used for soft-decision voting.
    s = -cos(pi * (c - d) ./ step);
end
