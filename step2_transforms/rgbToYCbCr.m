function [Y, Cb, Cr] = rgbToYCbCr(rgb)
% RGBTOYCBCR  Colour image -> brightness (Y) + two colour channels (Cb, Cr).
%             Written by hand (rgb2ycbcr would need a toolbox).
%
% PIPELINE:  STEP 2 (transforms) - only used when "Keep colour" is ticked.
%            Embedding: the logo is hidden in Y only; Cb and Cr are kept.
%            Extraction: Y is taken back out of the colour image.
%            Undo it with yCbCrToRgb.
%
%   [Y, Cb, Cr] = rgbToYCbCr(rgb)
%
%   rgb : M x N x 3 image (uint8 or double 0..255)
%   Y   : brightness, 0..255 (double)  - this is exactly the grayscale image,
%         so the paper's gray-level method runs on it unchanged
%   Cb  : blue-difference colour channel, centred on 128 (double)
%   Cr  : red-difference colour channel, centred on 128 (double)
%
% Full-range ITU-R BT.601 (the JPEG version):
%   Y  =       0.299    R + 0.587    G + 0.114    B
%   Cb = 128 - 0.168736 R - 0.331264 G + 0.5      B
%   Cr = 128 + 0.5      R - 0.418688 G - 0.081312 B

    rgb = double(rgb);
    R = rgb(:, :, 1);
    G = rgb(:, :, 2);
    B = rgb(:, :, 3);

    Y  =       0.299    * R + 0.587    * G + 0.114    * B;
    Cb = 128 - 0.168736 * R - 0.331264 * G + 0.5      * B;
    Cr = 128 + 0.5      * R - 0.418688 * G - 0.081312 * B;
end
