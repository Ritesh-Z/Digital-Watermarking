function [psnrVal, ncVal, berVal] = calculate_metrics(original, watermarked, wmBits, extractedBits)
% CALCULATE_METRICS  Computes standard evaluation metrics for a
% watermarking scheme. Uses a manual PSNR formula instead of the
% Image Processing Toolbox's psnr() function, so this needs no toolbox.
%
%   [psnrVal, ncVal, berVal] = calculate_metrics(original, watermarked, wmBits, extractedBits)
%
%   psnrVal : Peak Signal-to-Noise Ratio (dB) -> measures IMPERCEPTIBILITY
%   ncVal   : Normalized Correlation -> measures extraction ACCURACY (1 = perfect)
%   berVal  : Bit Error Rate -> fraction of watermark bits flipped (0 = perfect)

    % --- PSNR (manual) ---
    orig = double(original);
    wm = double(watermarked);
    mse = mean((orig(:) - wm(:)).^2);
    if mse == 0
        psnrVal = Inf;   % identical images
    else
        psnrVal = 10 * log10(255^2 / mse);
    end

    % --- Normalized Correlation (bipolar convention: 0/1 -> -1/+1) ---
    w  = 2*wmBits - 1;
    we = 2*extractedBits - 1;
    ncVal = sum(w .* we) / sqrt(sum(w.^2) * sum(we.^2));

    % --- Bit Error Rate ---
    berVal = sum(wmBits ~= extractedBits) / length(wmBits);
end
