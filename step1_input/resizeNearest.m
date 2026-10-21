function out = resizeNearest(img, outSize)
% RESIZENEAREST  Nearest-neighbour resize of a 2-D image. No toolbox needed.
%
% PIPELINE:  STEP 1 (input) - used by prepareCoverImage.
%
%   out = resizeNearest(img, [rows cols])
%
% Every output pixel simply copies the closest input pixel. Simple and fast;
% the output is double, the caller converts it back to uint8.

    img = double(img);
    [inRows, inCols] = size(img);
    rIdx = round(linspace(1, inRows, outSize(1)));
    cIdx = round(linspace(1, inCols, outSize(2)));
    out  = img(max(rIdx, 1), max(cIdx, 1));
end
