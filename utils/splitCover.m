function [LL, LH, HL, HH, Wpad] = splitCover(cover, W)
% SPLITCOVER  First step shared by every embedding stage: checks the inputs,
% splits the cover with a one-level Haar DWT and puts the small watermark
% into the top-left corner of a matrix the size of the HH band.
%
%   [LL, LH, HL, HH, Wpad] = splitCover(cover, W)
%
%   cover : grayscale image (uint8), even width and height
%   W     : watermark, values between 0 and 1, any size that fits inside HH
%           (size(cover)/2). The paper uses 17x9.
%   Wpad  : zeros(size(HH)) with W in its top-left corner

    if ndims(cover) ~= 2
        error('splitCover:coverNotGray', 'The cover image must be a 2-D grayscale image.');
    end
    if mod(size(cover, 1), 2) ~= 0 || mod(size(cover, 2), 2) ~= 0
        error('splitCover:oddSize', 'The cover image must have an even width and height (Haar DWT).');
    end
    W = double(W);
    if ndims(W) ~= 2 || isempty(W) || any(~isfinite(W(:)))
        error('splitCover:badWatermark', 'The watermark must be a non-empty 2-D matrix of finite numbers.');
    end

    [LL, LH, HL, HH] = dwt2Haar(double(cover));
    [r, c] = size(HH);
    [wr, wc] = size(W);
    if wr > r || wc > c
        error('splitCover:watermarkTooLarge', ...
              'The watermark (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end

    Wpad = zeros(r, c);
    Wpad(1:wr, 1:wc) = W;
end
