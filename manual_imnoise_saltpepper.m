function out = manual_imnoise_saltpepper(img, density)
% MANUAL_IMNOISE_SALTPEPPER  Randomly sets a fraction 'density' of pixels
% to 0 or 255. No toolbox needed.
    imgD = double(img);
    mask = rand(size(imgD));
    imgD(mask < density/2) = 0;
    imgD(mask >= density/2 & mask < density) = 255;
    out = uint8(imgD);
end
