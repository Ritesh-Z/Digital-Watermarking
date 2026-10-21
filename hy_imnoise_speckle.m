function out = hy_imnoise_speckle(img, variance)
% HY_IMNOISE_SPECKLE  Multiplicative speckle noise, same model as
% imnoise(I, 'speckle', v):   J = I + n .* I
% where n is uniform random noise with mean 0 and the given variance.

    imgD = double(img);
    n = sqrt(12 * variance) * (rand(size(imgD)) - 0.5);
    noisy = imgD + n .* imgD;
    out = uint8(min(max(round(noisy), 0), 255));
end
