function img = manual_idwt2_haar(LL, LH, HL, HH)
% MANUAL_IDWT2_HAAR  Inverse of manual_dwt2_haar - reconstructs the
% full-size image from its four Haar sub-bands. No toolbox needed
% (idwt2 is a Wavelet Toolbox function).
%
%   img = manual_idwt2_haar(LL, LH, HL, HH)

    [r, c] = size(LL);

    % Undo pass 2 (rows)
    Lc = zeros(r*2, c);
    Lc(1:2:end,:) = (LL + LH) / sqrt(2);
    Lc(2:2:end,:) = (LL - LH) / sqrt(2);

    Hc = zeros(r*2, c);
    Hc(1:2:end,:) = (HL + HH) / sqrt(2);
    Hc(2:2:end,:) = (HL - HH) / sqrt(2);

    % Undo pass 1 (columns)
    img = zeros(r*2, c*2);
    img(:,1:2:end) = (Lc + Hc) / sqrt(2);
    img(:,2:2:end) = (Lc - Hc) / sqrt(2);
end
