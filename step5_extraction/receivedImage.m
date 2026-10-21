function [Y, shown] = receivedImage(emb, s, img)
% RECEIVEDIMAGE  The image the extraction works on, for stage s.
%
% PIPELINE:  STEP 5 (extraction) - first step, before extractWatermark.
%
%   [Y, shown] = receivedImage(emb, s)        clean watermarked image
%   [Y, shown] = receivedImage(emb, s, img)   a given (e.g. attacked) image
%
%   gray mode   : Y = the watermarked gray image itself
%   colour mode : the colour watermarked image is split again with
%                 rgbToYCbCr and only its brightness Y is used - the logo
%                 was hidden in Y, Cb and Cr carry no watermark.
%
%   Y     : what extractWatermark gets
%   shown : the image a person would see (colour in colour mode)

    colour = isfield(emb, 'isColour') && emb.isColour;
    if nargin < 3
        if colour
            img = emb.wmRGB{s};
        else
            img = emb.wmImgs{s};
        end
    end
    shown = img;
    if colour
        Y = rgbToYCbCr(img);          % double, not rounded: no extra loss
    else
        Y = img;
    end
end
