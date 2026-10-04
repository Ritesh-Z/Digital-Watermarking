function [extractedBits, angle] = proposed_watermark_extract(img, numBits, alpha, key, doResync)
% PROPOSED_WATERMARK_EXTRACT  Blind extraction for proposed_watermark_embed.
% (MATLAB port of python/wmark/schemes.py + engine.py re-sync.)
%
%   [extractedBits, angle] = proposed_watermark_extract(img, numBits, alpha, key)
%   [...] = proposed_watermark_extract(img, numBits, alpha, key, false)  % no rotation search
%
%   img      : (possibly attacked) grayscale watermarked image
%   numBits  : number of watermark bits (e.g. 1024)
%   alpha    : MUST equal the strength used when embedding
%   key      : MUST equal the key used when embedding
%   angle    : rotation (degrees) undone by blind re-synchronisation (0 if none)
%
% Decoder:
%   * soft votes from all three carriers, each carrier weighted by
%     confidence^2 = how strongly its own copies agree, so whichever carrier
%     survived the attack dominates;
%   * DC copies from blocks full of exactly clipped (0/255) pixels get less
%     say, because clipping biases block brightness;
%   * salt & pepper repair: only isolated 0/255 specks are median-filtered,
%     and that reading is kept only if the copies agree more;
%   * rotation: if the copies disagree, try angles and keep the one where
%     they agree most (no original image needed).
    if nargin < 5
        doResync = true;
    end
    host = double(img);
    angle = 0;
    if doResync && copy_agreement(host, numBits, alpha, key) < 0.9
        [host, angle] = resync(host, numBits, alpha, key);
    end

    [combined, conf] = decode(host, numBits, alpha, key);
    extreme = host <= 1 | host >= 254;
    impulse = false(size(host));
    if nnz(extreme) > numel(host) * 0.0005             % only then is the (slow) median worth it
        med = manual_medfilt2(host, 3);
        impulse = extreme & abs(host - double(med)) > 60;
    end
    if nnz(impulse) > numel(host) * 0.0005
        cleaned = host;
        cleaned(impulse) = double(med(impulse));
        [c2, conf2] = decode(cleaned, numBits, alpha, key);
        if conf2 > conf
            combined = c2;
        end
    end
    extractedBits = wm_scramble(double(combined' > 0), key + 2);
end

% ------------------------------------------------------------------------
function [soft1, w1, soft2, w2, soft3, w3] = soft_parts(host, n, alpha, key)
    P = proposed_params();
    [H, W] = size(host);
    nb = (H/8) * (W/8);
    B = img_to_blocks(host, 8);
    % carrier 1: DC, down-weighted where pixels are exactly clipped
    dc = sum(B, 1) / 8;
    clipFrac = mean(B <= 0.5 | B >= 254.5, 1);
    [s1, w1] = wm_layout(n, nb, key);
    soft1 = qim_soft(dc(s1), alpha, wm_dither(key + 1, numel(s1), alpha)) .* (1 - clipFrac(s1)).^2;
    % carriers 2 and 3 from the 8x8 DCT
    T = manual_dct_matrix(8);
    Df = zeros(64, nb);
    for k = 1:nb
        Df(:, k) = reshape(T * reshape(B(:, k), 8, 8) * T', 64, 1);
    end
    i1 = sub2ind([8 8], P.low1(1), P.low1(2));  i2 = sub2ind([8 8], P.low2(1), P.low2(2));
    m1 = sub2ind([8 8], P.mid1(1), P.mid1(2));  m2 = sub2ind([8 8], P.mid2(1), P.mid2(2));
    [s2, w2] = wm_layout(n, nb, key + P.pairKey);
    step = P.pairRatio * alpha;
    soft2 = qim_soft(Df(i1, s2) - Df(i2, s2), step, wm_dither(key + P.pairKey + 1, numel(s2), step));
    [s3, w3] = wm_layout(n, nb, key + P.midKey);
    soft3 = min(max((Df(m1, s3) - Df(m2, s3)) / max(P.midRatio * alpha, 1e-9), -1), 1);
end

function [combined, totalConf] = decode(host, n, alpha, key)
    [s1, w1, s2, w2, s3, w3] = soft_parts(host, n, alpha, key);
    combined = zeros(n, 1);
    totalConf = 0;
    parts = {s1, w1; s2, w2; s3, w3};
    for p = 1:3
        meanv = accumarray(parts{p, 2}', parts{p, 1}', [n 1]) ./ accumarray(parts{p, 2}', 1, [n 1]);
        c = mean(abs(meanv));
        combined = combined + meanv * c^2;
        totalConf = totalConf + c;
    end
end

function a = copy_agreement(host, n, alpha, key)
    % mean fraction of copies agreeing with each bit's majority (1 = unanimous)
    [s1, w1, s2, w2, s3, w3] = soft_parts(host, n, alpha, key);
    bits = [s1 s2 s3] > 0;
    which = [w1 w2 w3];
    ones_ = accumarray(which', double(bits'), [n 1]);
    total = accumarray(which', 1, [n 1]);
    a = mean(max(ones_, total - ones_) ./ total);
end

function [best, bestAngle] = resync(host, n, alpha, key)
    % coarse 1-degree search in [-8, 8], then 0.25 and 0.1 degree refinements
    best = host; bestAngle = 0; bestA = copy_agreement(host, n, alpha, key);
    grids = {-8:1:8, [-0.75 -0.5 -0.25 0.25 0.5 0.75], [-0.2 -0.1 0.1 0.2]};
    for g = 1:numel(grids)
        if g == 2 && bestAngle == 0
            break;                               % no rotation found
        end
        centre = bestAngle * (g > 1);
        for a = centre + grids{g}
            if a == 0, continue; end
            h = double(manual_imrotate(host, -a));
            ag = copy_agreement(h, n, alpha, key);
            if ag > bestA
                bestA = ag; best = h; bestAngle = a;
            end
        end
    end
end
