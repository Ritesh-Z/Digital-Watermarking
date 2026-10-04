function d = wm_dither(key, n, step)
% WM_DITHER  Secret per-slot offset in [-step, step) for dithered QIM.
% It shifts the quantisation grid by a key-dependent amount, so an image
% that was never watermarked (or a wrong key) decodes to random bits.
% The range must cover a full odd/even period (2*step).
    s = RandStream('mt19937ar', 'Seed', key);
    d = (rand(s, 1, n) * 2 - 1) * step;
end
