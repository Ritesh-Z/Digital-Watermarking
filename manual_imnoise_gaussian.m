function out = manual_imnoise_gaussian(img, variance)
% MANUAL_IMNOISE_GAUSSIAN  Adds zero-mean Gaussian noise, image treated
% on a [0,1] scale (matching imnoise's convention), no toolbox needed.
    imgD = double(img) / 255;
    noise = sqrt(variance) * randn(size(imgD));
    noisy = min(max(imgD + noise, 0), 1);
    out = uint8(noisy * 255);
end
