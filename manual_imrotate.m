function out = manual_imrotate(img, angleDeg)
% MANUAL_IMROTATE  Rotate an image about its centre by angleDeg degrees
% (counter-clockwise), bilinear interpolation, same output size, black
% fill. No Image Processing Toolbox needed (imrotate is a toolbox function);
% interp2 and meshgrid are base MATLAB.
    imgD = double(img);
    [H, W] = size(imgD);
    [X, Y] = meshgrid(1:W, 1:H);
    cx = (W + 1) / 2;  cy = (H + 1) / 2;
    t = angleDeg * pi / 180;
    % inverse mapping: for each output pixel, where did it come from?
    xs =  cos(t) * (X - cx) - sin(t) * (Y - cy) + cx;
    ys =  sin(t) * (X - cx) + cos(t) * (Y - cy) + cy;
    out = interp2(X, Y, imgD, xs, ys, 'linear', 0);
    if isa(img, 'uint8')
        out = uint8(min(max(round(out), 0), 255));
    end
end
