function out = manual_imresize(img, outSize)
% MANUAL_IMRESIZE  Nearest-neighbor resize - simple, robust, no toolbox
% needed. Works for 2D grayscale/logical images.
    img = double(img);
    [inRows, inCols] = size(img);
    outRows = outSize(1); outCols = outSize(2);
    rIdx = round(linspace(1, inRows, outRows));
    cIdx = round(linspace(1, inCols, outCols));
    rIdx(rIdx < 1) = 1; cIdx(cIdx < 1) = 1;
    out = img(rIdx, cIdx);
end
