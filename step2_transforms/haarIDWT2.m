function img = haarIDWT2(LL, LH, HL, HH)
% HAARIDWT2  Inverse of haarDWT2: four sub-bands -> full-size image.
%            Written by hand - idwt2 would need the Wavelet Toolbox.
%
% PIPELINE:  STEP 2 (transforms) - last transform of embedding (rebuilds the
%            watermarked image).
%
%   img = haarIDWT2(LL, LH, HL, HH)
%
% From  s = (a + b)/sqrt(2)  and  d = (a - b)/sqrt(2)  we get back
%       a = (s + d)/sqrt(2)  and  b = (s - d)/sqrt(2).
% The two passes of haarDWT2 are undone in reverse order (rows, then columns).

    [r, c] = size(LL);

    % Undo pass 2 (rows)
    Lc = zeros(2 * r, c);
    Lc(1:2:end, :) = (LL + LH) / sqrt(2);
    Lc(2:2:end, :) = (LL - LH) / sqrt(2);

    Hc = zeros(2 * r, c);
    Hc(1:2:end, :) = (HL + HH) / sqrt(2);
    Hc(2:2:end, :) = (HL - HH) / sqrt(2);

    % Undo pass 1 (columns)
    img = zeros(2 * r, 2 * c);
    img(:, 1:2:end) = (Lc + Hc) / sqrt(2);
    img(:, 2:2:end) = (Lc - Hc) / sqrt(2);
end
