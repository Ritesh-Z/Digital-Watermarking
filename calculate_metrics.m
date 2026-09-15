function [psnrVal, ncVal, berVal] = calculate_metrics(original, watermarked, wmBits, extractedBits)
% CALCULATE_METRICS  Computes standard evaluation metrics for a
% watermarking scheme.
%
%   [psnrVal, ncVal, berVal] = calculate_metrics(original, watermarked, wmBits, extractedBits)
%
%   original       : original cover image (uint8)
%   watermarked    : watermarked image (uint8)
%   wmBits         : original watermark bit vector
%   extractedBits  : extracted watermark bit vector
%
%   psnrVal : Peak Signal-to-Noise Ratio (dB) between original and
%             watermarked image -> measures IMPERCEPTIBILITY
%   ncVal   : Normalized Correlation between original and extracted
%             watermark -> measures ROBUSTNESS/accuracy (1 = perfect)
%   berVal  : Bit Error Rate -> fraction of watermark bits flipped
%             (0 = perfect extraction)

    % --- PSNR ---
    psnrVal = psnr(watermarked, original);

    % --- Normalized Correlation (bipolar convention: 0/1 -> -1/+1) ---
    w  = 2*wmBits - 1;
    we = 2*extractedBits - 1;
    ncVal = sum(w .* we) / sqrt(sum(w.^2) * sum(we.^2));

    % --- Bit Error Rate ---
    berVal = sum(wmBits ~= extractedBits) / length(wmBits);
end
