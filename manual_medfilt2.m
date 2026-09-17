function out = manual_medfilt2(img, winSize)
% MANUAL_MEDFILT2  Simple sliding-window median filter with
% replicate-edge padding. No toolbox needed.
    imgD = double(img);
    [rows, cols] = size(imgD);
    pad = floor(winSize/2);

    padded = zeros(rows+2*pad, cols+2*pad);
    padded(pad+1:pad+rows, pad+1:pad+cols) = imgD;
    padded(1:pad, pad+1:pad+cols) = repmat(imgD(1,:), pad, 1);
    padded(pad+rows+1:end, pad+1:pad+cols) = repmat(imgD(end,:), pad, 1);
    padded(:, 1:pad) = repmat(padded(:, pad+1), 1, pad);
    padded(:, pad+cols+1:end) = repmat(padded(:, pad+cols), 1, pad);

    out = zeros(rows, cols);
    for r = 1:rows
        for c = 1:cols
            window = padded(r:r+winSize-1, c:c+winSize-1);
            out(r,c) = median(window(:));
        end
    end
    out = uint8(out);
end
