function watermarked = proposed_watermark_embed(cover, watermarkBits, alpha, key)
% PROPOSED_WATERMARK_EMBED  Proposed blind triple-carrier watermarking.
% (MATLAB port of python/wmark/schemes.py -> HybridQIMScheme.)
%
%   watermarked = proposed_watermark_embed(cover, watermarkBits, alpha, key)
%
%   cover         : grayscale uint8 image, both sides a multiple of 8
%   watermarkBits : 1xN vector of 0/1 bits (e.g. a 32x32 logo -> N = 1024)
%   alpha         : strength (default in the demos: 28, about 41 dB PSNR)
%   key           : secret integer. The SAME key is needed to extract.
%
% Every 8x8 block carries three independent copies of each bit:
%   1) DC (block brightness): dithered QIM, clip-aware water-filling.
%      Survives noise, JPEG, blur, median, rotation.
%      (DC of the 4x4 DCT of the Haar LL band = sum of the 8x8 block / 8,
%      so this is the paper's DWT -> DCT front end done in one step.)
%   2) Low-frequency pair D(3,2)-D(2,3): dithered QIM on the DIFFERENCE.
%      Bounded change; a brightness drift (e.g. clipped noise) cancels out.
%   3) Mid-frequency pair D(4,3) vs D(3,4): order rule (Block DCT's rule).
%      Scale-invariant, so it survives sharpening / contrast changes.
% DCT basis functions are orthogonal, so the three carriers do not
% interfere. Bits are scrambled and spread with the key; no original image
% is needed to extract (blind).

    P = proposed_params();
    host = double(cover);
    [H, W] = size(host);
    nb = (H/8) * (W/8);
    bits = wm_scramble(watermarkBits(:)', key + 2);
    n = numel(bits);

    % ---------------- carrier 1: DC with clip-aware water-filling
    B = img_to_blocks(host, 8);                  % 64 x nb
    dc = sum(B, 1) / 8;
    [s1, w1] = wm_layout(n, nb, key);
    down = B(:, s1);                             % how far each pixel can go down
    up = 255 - B(:, s1);                         % ... and up, before clipping
    lo = -sum(down, 1) / 8 * 0.97;               % DC change of D needs pixel-sum change 8*D
    hi = sum(up, 1) / 8 * 0.97;
    target = qim_embed_bounded(dc(s1), bits(w1), alpha, wm_dither(key + 1, numel(s1), alpha), lo, hi);
    target = dc(s1) + P.dcLambda * (target - dc(s1));   % distortion-compensated QIM
    need = 8 * (target - dc(s1));
    % water-filling: same change t for every pixel, capped by its head-room,
    % with t chosen (bisection) so the block's total change equals "need"
    tLo = -256 * ones(1, numel(s1));
    tHi = 256 * ones(1, numel(s1));
    for it = 1:40
        t = (tLo + tHi) / 2;
        total = sum(min(max(t, -down), up), 1);
        low = total < need;
        tLo(low) = t(low);
        tHi(~low) = t(~low);
    end
    t = (tLo + tHi) / 2;
    B(:, s1) = B(:, s1) + min(max(t, -down), up);
    host = blocks_to_img(B, 8, H, W);

    % ---------------- carriers 2 and 3 in the 8x8 DCT domain
    T = manual_dct_matrix(8);
    B = img_to_blocks(host, 8);
    D = zeros(8, 8, nb);
    for k = 1:nb
        D(:, :, k) = T * reshape(B(:, k), 8, 8) * T';
    end
    i1 = sub2ind([8 8], P.low1(1), P.low1(2));  i2 = sub2ind([8 8], P.low2(1), P.low2(2));
    m1 = sub2ind([8 8], P.mid1(1), P.mid1(2));  m2 = sub2ind([8 8], P.mid2(1), P.mid2(2));
    Df = reshape(D, 64, nb);

    % carrier 2: QIM on the low-pair difference
    [s2, w2] = wm_layout(n, nb, key + P.pairKey);
    step = P.pairRatio * alpha;
    c1 = Df(i1, s2);  c2 = Df(i2, s2);
    d = c1 - c2;
    dNew = qim_embed(d, bits(w2), step, wm_dither(key + P.pairKey + 1, numel(s2), step));
    Df(i1, s2) = c1 + (dNew - d) / 2;
    Df(i2, s2) = c2 - (dNew - d) / 2;

    % carrier 3: order of the mid pair, with margin m
    [s3, w3] = wm_layout(n, nb, key + P.midKey);
    m = P.midRatio * alpha;
    e1 = Df(m1, s3);  e2 = Df(m2, s3);  g = e1 - e2;
    b3 = bits(w3);
    need3 = (b3 == 1 & g < m) | (b3 == 0 & g > -m);
    tgt = m * (2 * b3 - 1);
    delta = zeros(size(g));
    delta(need3) = (tgt(need3) - g(need3)) / 2;
    Df(m1, s3) = e1 + delta;
    Df(m2, s3) = e2 - delta;

    D = reshape(Df, 8, 8, nb);
    for k = 1:nb
        B(:, k) = reshape(T' * D(:, :, k) * T, 64, 1);
    end
    watermarked = uint8(min(max(round(blocks_to_img(B, 8, H, W)), 0), 255));
end
