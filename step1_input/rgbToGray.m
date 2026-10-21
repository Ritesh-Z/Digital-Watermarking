function gray = rgbToGray(rgbImg)
% RGBTOGRAY  RGB colour image -> grayscale (uint8). No toolbox needed.
%
% PIPELINE:  STEP 1 (input) - used by prepareCoverImage and prepareWatermarkLogo.
%
%   gray = rgbToGray(rgbImg)
%
% Uses the standard luminance weights (ITU-R BT.601, the same ones that
% rgb2gray uses):   Y = 0.2989 R + 0.5870 G + 0.1140 B
% Green gets the biggest weight because the human eye is most sensitive to it.

    rgbImg = double(rgbImg);
    gray = uint8(0.2989 * rgbImg(:, :, 1) + 0.5870 * rgbImg(:, :, 2) + 0.1140 * rgbImg(:, :, 3));
end
