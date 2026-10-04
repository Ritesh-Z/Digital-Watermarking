function out = manual_sharpen(img, amount)
% MANUAL_SHARPEN  Unsharp masking: x + amount * (x - blur(x)).
% One of the base paper's six attacks. No toolbox needed.
    if nargin < 2, amount = 1.0; end
    x = double(img);
    out = uint8(min(max(round(x + amount * (x - double(manual_gaussian_blur(img, 1.0)))), 0), 255));
end
