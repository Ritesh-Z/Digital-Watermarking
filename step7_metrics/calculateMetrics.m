function m = calculateMetrics(original, other, W, We, wantSSIM)
% CALCULATEMETRICS  All quality / robustness scores of the project in one place.
%
% PIPELINE:  STEP 7 (metrics). Used after embedding, extraction and attacks.
%
%   m = calculateMetrics(original, other, W, We)
%   m = calculateMetrics(original, other)                image scores only
%   m = calculateMetrics([], [], W, We)                  logo scores only
%   m = calculateMetrics(original, other, W, We, false)  skip SSIM (faster)
%
%   original, other : two images of the same size (e.g. cover and watermarked)
%   W, We           : original logo and extracted logo
%
% IMAGE vs IMAGE  ("is the watermark invisible?")
%   psnr  Peak Signal-to-Noise Ratio, dB      PSNR = 10 log10(255^2 / MSE)
%         Higher = better. > 40 dB is invisible to the eye. Inf = identical.
%   ssim  Structural Similarity, 1 = identical (Wang et al. 2004)
%   IF    Image Fidelity as written in the paper (eq. 19):
%         IF = 1 - sum(I .* I') / sum(I .^ 2). Close to 0 = very similar
%         (can be slightly negative; NOT the classic IF where 1 = identical).
%
% LOGO vs LOGO  ("did the watermark survive?")
%   ncc   Normalised Cross-Correlation, 1 = perfect copy
%         NC = sum(W .* We) / sqrt(sum(W.^2) * sum(We.^2))
%   ber   Bit Error Rate (fraction of wrong pixels after threshold 0.5);
%         only for a black/white logo
%
% Fields not computed are NaN.

    if nargin < 3, W = [];  end
    if nargin < 4, We = []; end
    if nargin < 5, wantSSIM = true; end

    m = struct('psnr', NaN, 'ssim', NaN, 'IF', NaN, 'ncc', NaN, 'ber', NaN);

    % ---- image vs image
    if ~isempty(original) && ~isempty(other)
        if ~isequal(size(original), size(other))
            error('calculateMetrics:sizeMismatch', 'The two images must have the same size.');
        end
        a = double(original);
        b = double(other);

        mse = mean((a(:) - b(:)) .^ 2);
        if mse == 0
            m.psnr = Inf;
        else
            m.psnr = 10 * log10(255^2 / mse);
        end

        energy = sum(a(:) .^ 2);
        if energy ~= 0
            m.IF = 1 - sum(a(:) .* b(:)) / energy;
        end

        if wantSSIM
            m.ssim = ssimIndex(a, b);
        end
    end

    % ---- logo vs logo
    if ~isempty(W) && ~isempty(We)
        w  = double(W(:));
        we = double(We(:));
        d  = sqrt(sum(w .^ 2) * sum(we .^ 2));
        if d == 0
            m.ncc = 0;
        else
            m.ncc = sum(w .* we) / d;
        end
        if all(w == 0 | w == 1)
            m.ber = mean((we > 0.5) ~= (w > 0.5));
        end
    end
end

% =========================================================================
function s = ssimIndex(a, b)
% Toolbox-free SSIM: 11x11 Gaussian window (sigma 1.5), K1 = 0.01,
% K2 = 0.03, 8-bit range. Returns the mean of the local SSIM map
% (NaN if the image is smaller than the window). Colour images: the mean
% of the SSIM of the three channels.
    if size(a, 3) > 1
        s = mean(arrayfun(@(ch) ssimIndex(a(:, :, ch), b(:, :, ch)), 1:size(a, 3)));
        return;
    end
    if min(size(a, 1), size(a, 2)) < 11
        s = NaN;
        return;
    end
    L  = 255;
    C1 = (0.01 * L)^2;
    C2 = (0.03 * L)^2;

    [x, y] = meshgrid(-5:5, -5:5);
    g = exp(-(x.^2 + y.^2) / (2 * 1.5^2));
    g = g / sum(g(:));

    mu_a  = conv2(a, g, 'valid');
    mu_b  = conv2(b, g, 'valid');
    mu_aa = mu_a .^ 2;
    mu_bb = mu_b .^ 2;
    mu_ab = mu_a .* mu_b;

    sig_aa = conv2(a .* a, g, 'valid') - mu_aa;
    sig_bb = conv2(b .* b, g, 'valid') - mu_bb;
    sig_ab = conv2(a .* b, g, 'valid') - mu_ab;

    ssimMap = ((2 * mu_ab + C1) .* (2 * sig_ab + C2)) ./ ...
              ((mu_aa + mu_bb + C1) .* (sig_aa + sig_bb + C2));
    s = mean(ssimMap(:));
end
