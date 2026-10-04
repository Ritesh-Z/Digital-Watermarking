function out = wm_scramble(bits, key)
% WM_SCRAMBLE  XOR the watermark bits with a key-derived random sequence.
% Logos are mostly one colour, so two unrelated logos still "correlate".
% Scrambling balances the bits; XOR is its own inverse, so the same call
% unscrambles at extraction.
    s = RandStream('mt19937ar', 'Seed', key);
    pn = randi(s, [0 1], size(bits));
    out = double(xor(bits ~= 0, pn ~= 0));
end
