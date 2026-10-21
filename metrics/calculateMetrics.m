function m = calculateMetrics(original, other, W, We, wantSSIM)
% CALCULATEMETRICS  All the scores of the project in one place.
%
%   m = calculateMetrics(original, other, W, We)
%   m = calculateMetrics(original, other)        image scores only
%   m = calculateMetrics([], [], W, We)          watermark scores only
%   m = calculateMetrics(original, other, W, We, false)   skip SSIM (faster)
%
%   original, other : two images of the same size (for example the cover and
%                     the watermarked image)
%   W, We           : the input watermark and the extracted watermark
%
% Fields of m (NaN when not computed or not defined):
%   psnr  peak signal to noise ratio in dB (paper eq. 16 and 17), Inf if identical
%   ssim  structural similarity, 1 means identical
%   IF    image fidelity as written in the paper (eq. 19):
%         IF = 1 - sum(I .* I') / sum(I .^ 2). Close to 0 means very similar.
%         It can be slightly negative. It is NOT the "classic" IF where 1 is identical.
%   ncc   normalized cross correlation of W and We, 1 is perfect. The paper's
%         eq. 18 does not give values near 1 (its tables show about 0.004), so
%         this is the standard definition that the paper's own text describes.
%   ber   bit error rate, only for a black/white watermark (threshold 0.5)

    if nargin < 3, W = [];  end
    if nargin < 4, We = []; end
    if nargin < 5, wantSSIM = true; end

    m = struct('psnr', NaN, 'ssim', NaN, 'IF', NaN, 'ncc', NaN, 'ber', NaN);

    % ---- image against image
    if ~isempty(original) && ~isempty(other)
        if ~isequal(size(original), size(other))
            error('calculateMetrics:sizeMismatch', 'The two images must have the same size.');
        end
        a = double(original);
        b = double(other);

        mse = mean((a(:) - b(:)).^2);
        if mse == 0
            m.psnr = Inf;
        else
            m.psnr = 10 * log10(255^2 / mse);
        end

        denom = sum(a(:).^2);
        if denom ~= 0
            m.IF = 1 - sum(a(:) .* b(:)) / denom;
        end

        if wantSSIM
            m.ssim = ssimIndex(a, b);
        end
    end

    % ---- watermark against watermark
    if ~isempty(W) && ~isempty(We)
        w  = double(W(:));
        we = double(We(:));
        d = sqrt(sum(w.^2) * sum(we.^2));
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

function s = ssimIndex(a, b)
% Toolbox-free SSIM (Wang et al., 2004): 11x11 Gaussian window with sigma 1.5,
% K1 = 0.01, K2 = 0.03, 8-bit range. Mean of the local SSIM map.
% NaN for images smaller than the 11 x 11 window.
    if min(size(a)) < 11
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
