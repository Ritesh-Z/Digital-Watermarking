function hy_show(img, ttl, range)
% HY_SHOW  Shows an image in the current axes using only core MATLAB
% (imagesc), so it does not depend on any toolbox.
%
%   hy_show(img, title, [lo hi])   the range is optional, e.g. [0 255]

    imagesc(img);
    if nargin >= 3 && ~isempty(range)
        caxis(range);
    end
    colormap(gray(256));
    axis image off;
    if nargin >= 2
        title(ttl, 'FontSize', 9);
    end
end
