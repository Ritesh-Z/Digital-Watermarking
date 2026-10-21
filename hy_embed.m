function [wmImg, key] = hy_embed(cover, W, alpha, stage)
% HY_EMBED  Embeds a watermark into the HH (diagonal detail) band of a
% Haar DWT, following the stages of Yildiz, Ustunsoy and Sayan (2024).
%
%   [wmImg, key] = hy_embed(cover, W, alpha, stage)
%
%   cover : grayscale cover image (uint8), even size
%   W     : watermark, a matrix of values between 0 and 1 of ANY size that
%           fits inside the HH band (size(cover)/2). The paper uses 17x9;
%           the GUI passes the size of the user's own watermark.
%   alpha : embedding strength (the paper's "scaling factor" / "gain")
%   stage : 1 = DWT only
%           2 = DWT + DCT
%           3 = DWT + DCT + SVD
%
%   wmImg : watermarked image (uint8)
%   key   : everything needed to extract later. The paper's method is
%           NON-BLIND, so extraction needs the original image's data
%           (and for stage 3 the watermark's own SVD matrices).
%
% What each stage does to the HH band:
%   stage 1: add alpha*W straight onto the HH coefficients
%   stage 2: take the DCT of HH, add alpha*W onto the DCT coefficients,
%            then go back with the inverse DCT
%   stage 3: take the DCT of HH, do an SVD of that, add alpha times the
%            watermark's singular values onto the largest singular values
%            of HH, then rebuild (inverse SVD, inverse DCT)
% After that the inverse DWT gives the watermarked image.

    if ndims(cover) ~= 2
        error('hy_embed:coverNotGray', 'The cover image must be a 2-D grayscale image.');
    end
    if mod(size(cover, 1), 2) ~= 0 || mod(size(cover, 2), 2) ~= 0
        error('hy_embed:oddSize', 'The cover image must have an even width and height (Haar DWT).');
    end

    A = double(cover);
    [LL, LH, HL, HH] = manual_dwt2_haar(A);
    [r, c] = size(HH);
    W = double(W);
    [wr, wc] = size(W);
    if ndims(W) ~= 2 || isempty(W) || any(~isfinite(W(:)))
        error('hy_embed:badWatermark', 'The watermark must be a non-empty 2-D matrix of finite numbers.');
    end
    if wr > r || wc > c
        error('hy_embed:watermarkTooLarge', ...
              'The watermark (%d x %d) does not fit in the HH band (%d x %d).', wr, wc, r, c);
    end

    % Put the small watermark in the top-left corner of a matrix the size of HH
    Wpad = zeros(r, c);
    Wpad(1:wr, 1:wc) = W;

    Tr = hy_dct_matrix(r);
    Tc = hy_dct_matrix(c);

    key = struct('stage', stage, 'alpha', alpha);
    key.imgSize = size(cover);   % lets hy_extract catch a wrong-sized image

    switch stage
        case 1
            key.HH = HH;
            HHm = HH + alpha * Wpad;

        case 2
            D = Tr * HH * Tc';
            key.D = D;
            HHm = Tr' * (D + alpha * Wpad) * Tc;

        case 3
            D = Tr * HH * Tc';
            [U, S, V] = svd(D);
            s = diag(S);

            % SVD of the watermark. A 0/1 pattern like "VIT" has only a few
            % non-zero singular values, so only those carry information.
            [Uw, Sw, Vw] = svd(W, 'econ');
            sw = diag(Sw);
            k = sum(sw > 1e-8 * sw(1));

            s2 = s;
            s2(1:k) = s(1:k) + alpha * sw(1:k);
            Dm = U * diag(s2) * V';
            HHm = Tr' * Dm * Tc;

            key.s  = s(1:k);        % original singular values of HH (the key)
            key.Uw = Uw(:, 1:k);    % watermark's left vectors
            key.Vw = Vw(:, 1:k);    % watermark's right vectors

        otherwise
            error('stage must be 1, 2 or 3');
    end

    wm = manual_idwt2_haar(LL, LH, HL, HHm);
    wmImg = uint8(min(max(round(wm), 0), 255));
end
