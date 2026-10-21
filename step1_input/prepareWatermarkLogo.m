function [W, info] = prepareWatermarkLogo(img, maxDim, doBinarize, doInvert)
% PREPAREWATERMARKLOGO  User's logo image -> small 0/1 matrix W (the watermark).
%
% PIPELINE:  STEP 1 (input).  loadImageFile -> [prepareWatermarkLogo] -> embedding
%
%   [W, info] = prepareWatermarkLogo(img, maxDim, doBinarize, doInvert)
%
% INPUTS
%   img        : uint8 grayscale or RGB logo
%   maxDim     : longer side of W in pixels (default 32). Bigger logos are
%                shrunk with area averaging; smaller ones keep their size.
%                Bigger W = more detail, but a lower PSNR.
%   doBinarize : true (default) -> black/white with Otsu's threshold
%                false          -> keep the gray levels, scaled to 0..1
%   doInvert   : true -> W = 1 - W. The value 1 is the "ink" that gets
%                embedded, so tick this for a DARK logo on a LIGHT background.
%
% OUTPUTS
%   W    : matrix with values 0..1 (this is what is hidden in the cover)
%   info : struct with size, originalSize, threshold, binary, inverted
%
% STEPS
%   1. RGB -> gray
%   2. shrink so the longer side is at most maxDim
%   3. Otsu threshold -> 0/1   (or keep gray levels)
%   4. optional invert
%   5. refuse a flat result (one colour = nothing to embed)

    if nargin < 2 || isempty(maxDim),     maxDim = 32;       end
    if nargin < 3 || isempty(doBinarize), doBinarize = true; end
    if nargin < 4 || isempty(doInvert),   doInvert = false;  end
    if ~(isnumeric(maxDim) && isscalar(maxDim) && isfinite(maxDim) && maxDim >= 4)
        error('prepareWatermarkLogo:badMaxDim', 'The maximum watermark size must be a number of at least 4.');
    end
    if ~(isnumeric(img) || islogical(img)) || isempty(img) || ~any(ndims(img) == [2 3])
        error('prepareWatermarkLogo:badImage', 'The watermark is not a valid grayscale or RGB image.');
    end

    % ---- 1. Colour -> gray
    if ndims(img) == 3
        if size(img, 3) ~= 3
            error('prepareWatermarkLogo:badChannels', 'The watermark must have 1 or 3 colour channels.');
        end
        g = rgbToGray(uint8(img));
    else
        g = img;
    end
    g = double(g);

    % ---- 2. Shrink
    [h, w] = size(g);
    scale = min(1, maxDim / max(h, w));
    nr = max(1, round(h * scale));
    nc = max(1, round(w * scale));
    if nr ~= h || nc ~= w
        g = areaResize(g, nr, nc);
    end
    g = min(max(round(g), 0), 255);

    % ---- 3. Black/white (or gray)
    if doBinarize
        thr = otsuThreshold(g);
        W = double(g > thr);                % bright pixels -> 1
    else
        thr = NaN;
        W = g / 255;
    end

    % ---- 4. Invert
    if doInvert
        W = 1 - W;
    end

    % ---- 5. Must have a pattern
    if max(W(:)) - min(W(:)) < 1e-9
        error('prepareWatermarkLogo:flat', ...
              ['The watermark has no visible pattern (it is one flat colour after ' ...
               'processing). Choose another image, or change the black/white option.']);
    end

    info = struct('size', [nr nc], 'originalSize', [h w], 'threshold', thr, ...
                  'binary', logical(doBinarize), 'inverted', logical(doInvert));
end

% =========================================================================
function out = areaResize(img, nr, nc)
% Area-averaging resize written as two matrix products: every output pixel
% is the average of the input pixels it covers.
    out = areaWeights(size(img, 1), nr) * img * areaWeights(size(img, 2), nc)';
end

function M = areaWeights(nIn, nOut)
% Row i of M holds how much of each input sample falls into output sample i.
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

function t = otsuThreshold(g)
% Otsu's method: try every threshold 0..255 and keep the one that makes the
% two classes (dark / bright) as different as possible (max between-class
% variance). Pixels with value > t are "bright".
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
