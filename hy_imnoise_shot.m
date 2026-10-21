function out = hy_imnoise_shot(img)
% HY_IMNOISE_SHOT  Shot (Poisson) noise without any toolbox.
%
% imnoise(I, 'poisson') treats every uint8 pixel value as the mean of a
% Poisson random number. A Poisson variable with a large mean behaves almost
% like a Gaussian whose variance equals the mean, so we use
%       I + sqrt(I) * randn
% which needs no Statistics Toolbox.

    imgD = double(img);
    noisy = imgD + sqrt(max(imgD, 0)) .* randn(size(imgD));
    out = uint8(min(max(round(noisy), 0), 255));
end
