function [psnrVal, ifVal, ssimVal] = hy_image_metrics(original, other)
% HY_IMAGE_METRICS  PSNR, Image Fidelity and SSIM between two images.
%
%   psnrVal : peak signal to noise ratio in dB (paper equations 16 and 17)
%   ifVal   : image fidelity, written exactly like the paper's equation (19):
%             IF = 1 - sum(I .* I') / sum(I .^ 2)
%             Values very close to 0 mean the two images are very similar
%             (it can be slightly negative when the second image is brighter).
%             This is NOT the 'classic' IF where 1 means identical.
%             NaN if the original image is completely black.
%   ssimVal : structural similarity (see hy_ssim), 1 means identical

    if ~isequal(size(original), size(other))
        error('hy_image_metrics:sizeMismatch', 'The two images must have the same size.');
    end
    a = double(original);
    b = double(other);

    mse = mean((a(:) - b(:)).^2);
    if mse == 0
        psnrVal = Inf;
    else
        psnrVal = 10 * log10(255^2 / mse);
    end

    denom = sum(a(:).^2);
    if denom == 0
        ifVal = NaN;                 % undefined for an all-black original
    else
        ifVal = 1 - sum(a(:) .* b(:)) / denom;
    end

    if nargout >= 3
        ssimVal = hy_ssim(original, other);
    end
end
