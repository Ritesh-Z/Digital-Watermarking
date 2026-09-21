function [psnrVal, corrVal] = calculate_metrics_svd(original, watermarked, wmOriginal, wmExtracted)
% CALCULATE_METRICS_SVD  Evaluation metrics for SVD-based watermarking.
% Unlike the DCT/DWT projects, the SVD watermark is a full grayscale
% image (not a 0/1 bit pattern), so instead of NC/BER on bits, we use
% the Pearson correlation coefficient between the original and
% extracted watermark images - the standard metric in SVD watermarking
% papers. 1.0 = perfect match, 0 = no relation, negative = inverted.
%
%   [psnrVal, corrVal] = calculate_metrics_svd(original, watermarked, wmOriginal, wmExtracted)
%
%   psnrVal : Peak Signal-to-Noise Ratio (dB) between cover and
%             watermarked image -> measures IMPERCEPTIBILITY
%   corrVal : correlation coefficient between original and extracted
%             watermark images -> measures extraction ACCURACY

    orig = double(original);
    wm = double(watermarked);
    mse = mean((orig(:) - wm(:)).^2);
    if mse == 0
        psnrVal = Inf;
    else
        psnrVal = 10 * log10(255^2 / mse);
    end

    a = double(wmOriginal);
    b = double(wmExtracted);
    a = a - mean(a(:));
    b = b - mean(b(:));
    denom = sqrt(sum(a(:).^2) * sum(b(:).^2));
    if denom == 0
        corrVal = 0;
    else
        corrVal = sum(a(:) .* b(:)) / denom;
    end
end
