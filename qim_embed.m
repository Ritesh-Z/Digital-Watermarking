function c = qim_embed(c, bits, step, d)
% QIM_EMBED  Dithered odd/even quantisation index modulation (same rule as
% dwt_watermark_embed.m, plus a secret dither d): round (c - d) to a
% multiple of step; even index = bit 0, odd index = bit 1.
    c = c - d;
    q = round(c ./ step);
    wrong = mod(q, 2) ~= bits;
    up = (c - q .* step) >= 0;
    q(wrong & up) = q(wrong & up) + 1;
    q(wrong & ~up) = q(wrong & ~up) - 1;
    c = q .* step + d;
end
