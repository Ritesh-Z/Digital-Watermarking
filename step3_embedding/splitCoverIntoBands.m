function [LL, LH, HL, HH, Wpad] = splitCoverIntoBands(cover, W)
% SPLITCOVERINTOBANDS  First step shared by all three embedding methods.
%
% PIPELINE:  STEP 3 (embedding), part 1 of 3:
%            [splitCoverIntoBands] -> change HH -> rebuildFromBands
%
%   [LL, LH, HL, HH, Wpad] = splitCoverIntoBands(cover, W)
%
% What it does
%   1. checks the inputs (gray, even size, W fits inside HH)
%   2. Haar DWT of the cover -> LL, LH, HL, HH
%   3. Wpad = zeros the size of HH with the small watermark W in the
%      top-left corner (stages 1 and 2 add Wpad directly)

    if ~ismatrix(cover)
        error('splitCoverIntoBands:coverNotGray', 'The cover image must be a 2-D grayscale image.');
    end
    if mod(size(cover, 1), 2) ~= 0 || mod(size(cover, 2), 2) ~= 0
        error('splitCoverIntoBands:oddSize', 'The cover image must have an even width and height (Haar DWT).');
    end
    W = double(W);
    if ~ismatrix(W) || isempty(W) || any(~isfinite(W(:)))
        error('splitCoverIntoBands:badWatermark', 'The watermark must be a non-empty 2-D matrix of finite numbers.');
    end

    [LL, LH, HL, HH] = haarDWT2(double(cover));

    [r, c]   = size(HH);
    [wr, wc] = size(W);
    if wr > r || wc > c
        error('splitCoverIntoBands:watermarkTooLarge', ...
              'The watermark (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end

    Wpad = zeros(r, c);
    Wpad(1:wr, 1:wc) = W;
end
