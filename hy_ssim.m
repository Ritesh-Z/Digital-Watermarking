function s = hy_ssim(a, b)
% HY_SSIM  Structural Similarity index between two grayscale images.
% Toolbox-free version of the standard method of Wang et al. (2004):
% 11x11 Gaussian window (sigma 1.5), K1 = 0.01, K2 = 0.03, 8-bit range.
% 1 means identical. The result is the mean of the local SSIM map.
% Returns NaN for images smaller than the 11 x 11 window.

    if ~isequal(size(a), size(b))
        error('hy_ssim:sizeMismatch', 'The two images must have the same size.');
    end
    if min(size(a)) < 11
        s = NaN;                 % the 11 x 11 window does not fit: SSIM undefined
        return;
    end
    a = double(a);
    b = double(b);

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
