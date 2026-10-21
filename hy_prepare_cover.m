function [cover, info] = hy_prepare_cover(img, imgSize)
% HY_PREPARE_COVER  Turns the user's cover image into what the watermarking
% code needs: a uint8 grayscale image of imgSize x imgSize (even).
%
%   [cover, info] = hy_prepare_cover(img, imgSize)
%
%   img     : uint8 grayscale (M x N) or RGB (M x N x 3) image
%   imgSize : side length after resizing (default 256, as in the original
%             project; the paper uses 512, which is slower). Made even.
%
% RGB is converted with manual_rgb2gray and the image is resized with
% manual_imresize (nearest neighbour), exactly like the original script.
% Note: a non-square image is stretched to a square, as before.

    if nargin < 2 || isempty(imgSize)
        imgSize = 256;
    end
    if ~(isnumeric(img) || islogical(img)) || isempty(img) || ~any(ndims(img) == [2 3])
        error('hy_prepare_cover:badImage', 'The cover image is not a valid grayscale or RGB image.');
    end
    imgSize = 2 * round(imgSize / 2);          % the Haar DWT needs even sizes
    if imgSize < 64
        error('hy_prepare_cover:tooSmall', 'The cover image size must be at least 64.');
    end

    info = struct('originalSize', [size(img, 1) size(img, 2)], 'wasRGB', false);

    if ndims(img) == 3
        if size(img, 3) ~= 3
            error('hy_prepare_cover:badChannels', 'The cover image must have 1 or 3 colour channels.');
        end
        gray = manual_rgb2gray(uint8(img));
        info.wasRGB = true;
    else
        gray = img;
    end
    if ~isa(gray, 'uint8')
        gray = uint8(min(max(round(double(gray)), 0), 255));
    end

    cover = uint8(manual_imresize(gray, [imgSize imgSize]));
end
