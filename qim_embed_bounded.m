function c = qim_embed_bounded(c, bits, step, d, lo, hi)
% QIM_EMBED_BOUNDED  QIM that respects how far each value may move.
% Every level with the right parity encodes the bit, so besides the
% nearest one we may use the next one up or down (q +- 2). For each slot
% pick the closest level whose change lies in [lo, hi]; if none fits, the
% one that overshoots least. Avoids losing bits where pixels would clip.
    base = qim_embed(c, bits, step, d);
    cands = [base; base - 2*step; base + 2*step];      % 3 x n
    delta = cands - c;
    over = max(lo - delta, 0) + max(delta - hi, 0);    % 0 when feasible
    cost = over * 1e6 + abs(delta);
    [~, k] = min(cost, [], 1);
    c = cands(sub2ind(size(cands), k, 1:numel(c)));
end
