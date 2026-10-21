function hy_gui_show(ax, img, ttl)
% HY_GUI_SHOW  Shows an image in a uiaxes (core MATLAB only, no imshow).
%
%   hy_gui_show(ax, img, ttl)
%
%   img : uint8 gray or RGB image; a logical matrix; or a double matrix with
%         values between 0 and 1. [] clears the axes.
%   ttl : title, a char vector or a cell array of lines (optional)

    cla(ax);
    ax.XTick = [];
    ax.YTick = [];
    ax.Box = 'on';

    if ~isempty(img)
        if isa(img, 'uint8')
            u = img;
        elseif islogical(img)
            u = uint8(img) * 255;
        else
            u = uint8(round(255 * min(max(double(img), 0), 1)));
        end
        if ndims(u) == 2
            u = cat(3, u, u, u);
        end
        image(ax, u);
        [h, w, ~] = size(u);
        ax.XLim = [0.5 w + 0.5];
        ax.YLim = [0.5 h + 0.5];
        ax.YDir = 'reverse';
        ax.DataAspectRatio = [1 1 1];
        ax.XTick = [];
        ax.YTick = [];
    end

    if nargin >= 3
        title(ax, ttl, 'FontSize', 10);
    end
end
