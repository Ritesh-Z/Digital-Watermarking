function img = insertTextSafe(img, txt)
% INSERTTEXTSAFE  Draws simple block text into a small binary canvas
% using only core graphics functions (figure/text/getframe), no
% Computer Vision Toolbox needed.
    fig = figure('Visible', 'off', 'Color', 'k', ...
                 'Units', 'pixels', 'Position', [0 0 size(img,2) size(img,1)]);
    ax = axes('Parent', fig, 'Position', [0 0 1 1], 'Color', 'k');
    text(ax, 0.5, 0.5, txt, 'Color', 'w', 'FontSize', size(img,1)*0.5, ...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'middle');
    axis(ax, 'off');
    frame = getframe(ax);
    close(fig);
    gray = manual_rgb2gray(frame.cdata);
    img = double(manual_imresize(gray, [size(img,1), size(img,2)]) > 128);
end
