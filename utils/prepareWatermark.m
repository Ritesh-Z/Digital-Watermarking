function [W, info] = prepareWatermark(img, maxDim, doBinarize, doInvert)
% HY_PREPARE_WATERMARK  Turns the user's watermark/logo image into the
% numerical matrix W that the embedding functions expect (values 0..1, any size).
%
%   [W, info] = prepareWatermark(img, maxDim, doBinarize, doInvert)
%
%   img        : uint8 grayscale or RGB image
%   maxDim     : the longer side of W is at most this many pixels (default
%                32). Larger images are shrunk proportionally with area
%                averaging; smaller images are kept at their own size.
%                Bigger watermarks carry more detail but lower the PSNR.
%   doBinarize : true (default) -> black/white using Otsu's threshold
%                (computed here, no toolbox). false -> keep gray levels/255.
%   doInvert   : true -> W = 1 - W. The embedded "ink" is the value 1, so
%                tick this when the logo is dark on a light background.
%
%   info : struct with size, originalSize, threshold, binary, inverted
%
% Throws an error if the result is one flat colour (nothing to embed).

    if nargin < 2 || isempty(maxDim),     maxDim = 32;       end
    if nargin < 3 || isempty(doBinarize), doBinarize = true; end
    if nargin < 4 || isempty(doInvert),   doInvert = false;  end
    if ~(isnumeric(maxDim) && isscalar(maxDim) && isfinite(maxDim) && maxDim >= 4)
        error('prepareWatermark:badMaxDim', 'The maximum watermark size must be a number of at least 4.');
    end
    if ~(isnumeric(img) || islogical(img)) || isempty(img) || ~any(ndims(img) == [2 3])
        error('prepareWatermark:badImage', 'The watermark is not a valid grayscale or RGB image.');
    end

    if ndims(img) == 3
        if size(img, 3) ~= 3
            error('prepareWatermark:badChannels', 'The watermark must have 1 or 3 colour channels.');
        end
        g = rgbToGray(uint8(img));
    else
        g = img;
    end
    g = double(g);

    [h, w] = size(g);
    scale = min(1, maxDim / max(h, w));
    nr = max(1, round(h * scale));
    nc = max(1, round(w * scale));
    if nr ~= h || nc ~= w
        g = local_area_resize(g, nr, nc);
    end
    g = min(max(round(g), 0), 255);

    if doBinarize
        thr = local_otsu(g);
        W = double(g > thr);              % bright pixels -> 1
    else
        thr = NaN;
        W = g / 255;
    end
    if doInvert
        W = 1 - W;
    end

    if max(W(:)) - min(W(:)) < 1e-9
        error('prepareWatermark:flat', ...
              ['The watermark has no visible pattern (it is one flat colour after ' ...
               'processing). Choose another image, or change the black/white option.']);
    end

    info = struct('size', [nr nc], 'originalSize', [h w], 'threshold', thr, ...
                  'binary', logical(doBinarize), 'inverted', logical(doInvert));
end

function out = local_area_resize(img, nr, nc)
% Area-averaging resize as two matrix products (core MATLAB only).
    out = local_area_weights(size(img, 1), nr) * img * local_area_weights(size(img, 2), nc)';
end

function M = local_area_weights(nIn, nOut)
% Row i of M averages the input samples covered by output sample i.
    M = zeros(nOut, nIn);
    edges = linspace(0, nIn, nOut + 1);
    for i = 1:nOut
        a = edges(i);
        b = edges(i + 1);
        for j = (floor(a) + 1):min(ceil(b), nIn)
            M(i, j) = min(b, j) - max(a, j - 1);
        end
        M(i, :) = M(i, :) / sum(M(i, :));
    end
end

function t = local_otsu(g)
% Otsu's threshold for a gray image with integer values 0..255.
% Pixels with value > t belong to the bright class.
    counts = accumarray(g(:) + 1, 1, [256 1]);
    p  = counts / sum(counts);
    om = cumsum(p);                         % weight of the dark class
    mu = cumsum(p .* (0:255)');             % cumulative mean
    mt = mu(end);
    sb = (mt * om - mu) .^ 2 ./ (om .* (1 - om));   % between-class variance
    sb(~isfinite(sb)) = 0;
    [mx, idx] = max(sb);
    if mx <= 0
        t = 127.5;                          % flat image: any threshold will do
    else
        t = idx - 1;
    end
end
