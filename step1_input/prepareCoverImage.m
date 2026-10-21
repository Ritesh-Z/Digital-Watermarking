function [cover, info] = prepareCoverImage(img, imgSize, keepColour)
% PREPARECOVERIMAGE  User's cover photo -> square uint8 grayscale image
%                    (the image the watermark is hidden in).
%
% PIPELINE:  STEP 1 (input).  loadImageFile -> [prepareCoverImage] -> embedding
%
%   [cover, info] = prepareCoverImage(img, imgSize)
%   [cover, info] = prepareCoverImage(img, imgSize, keepColour)
%
% INPUTS
%   img        : uint8 grayscale (M x N) or RGB (M x N x 3) image
%   imgSize    : side length of the result (default 256; the paper uses 512,
%                which is slower). Rounded to an EVEN number because the
%                Haar DWT halves the image.
%   keepColour : false (default, as in the paper) -> plain grayscale cover.
%                true and the photo is RGB -> the colour is kept for later:
%                the cover is the brightness channel Y of YCbCr, and the
%                colour channels Cb, Cr are returned in info.
%
% OUTPUTS
%   cover : imgSize x imgSize uint8 gray image (in colour mode: Y)
%   info  : originalSize, wasRGB, colour (true in colour mode) and, in
%           colour mode, coverRGB (resized colour photo), Cb, Cr
%
% STEPS
%   gray mode   : 1. RGB -> gray (rgbToGray)   2. resize (resizeNearest)
%   colour mode : 1. resize R, G, B            2. RGB -> Y, Cb, Cr (rgbToYCbCr)
%   A non-square photo is stretched to a square.

    if nargin < 2 || isempty(imgSize),    imgSize = 256;      end
    if nargin < 3 || isempty(keepColour), keepColour = false; end
    if ~(isnumeric(img) || islogical(img)) || isempty(img) || ~any(ndims(img) == [2 3])
        error('prepareCoverImage:badImage', 'The cover image is not a valid grayscale or RGB image.');
    end
    imgSize = 2 * round(imgSize / 2);
    if imgSize < 64
        error('prepareCoverImage:tooSmall', 'The cover image size must be at least 64.');
    end
    if ndims(img) == 3 && size(img, 3) ~= 3
        error('prepareCoverImage:badChannels', 'The cover image must have 1 or 3 colour channels.');
    end

    info = struct('originalSize', [size(img, 1) size(img, 2)], 'wasRGB', ndims(img) == 3, ...
                  'colour', false);

    if keepColour && info.wasRGB
        % ---- colour mode: resize each channel, then split into Y, Cb, Cr
        small = zeros(imgSize, imgSize, 3);
        for ch = 1:3
            small(:, :, ch) = resizeNearest(img(:, :, ch), [imgSize imgSize]);
        end
        info.coverRGB = uint8(small);
        [Y, info.Cb, info.Cr] = rgbToYCbCr(info.coverRGB);
        cover = uint8(min(max(round(Y), 0), 255));
        info.colour = true;
        return;
    end

    % ---- gray mode (the paper): 1. colour -> gray
    if info.wasRGB
        gray = rgbToGray(uint8(img));
    else
        gray = img;
    end
    if ~isa(gray, 'uint8')
        gray = uint8(min(max(round(double(gray)), 0), 255));
    end

    % ---- 2. resize to imgSize x imgSize
    cover = uint8(resizeNearest(gray, [imgSize imgSize]));
end
