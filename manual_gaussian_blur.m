function out = manual_gaussian_blur(img, sigma)
% MANUAL_GAUSSIAN_BLUR  Separable Gaussian blur with replicate padding.
% conv2 is base MATLAB, so no toolbox is needed (imgaussfilt is one).
    if nargin < 2, sigma = 1.0; end
    r = max(1, ceil(3 * sigma));
    k = exp(-0.5 * ((-r:r) / sigma).^2);
    k = k / sum(k);
    imgD = double(img);
    padded = [repmat(imgD(:, 1), 1, r), imgD, repmat(imgD(:, end), 1, r)];
    imgD = conv2(padded, k, 'valid');
    padded = [repmat(imgD(1, :), r, 1); imgD; repmat(imgD(end, :), r, 1)];
    out = uint8(min(max(round(conv2(padded, k', 'valid')), 0), 255));
end
