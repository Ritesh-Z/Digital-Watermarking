function fig = hy_plot_comparison(res)
% HY_PLOT_COMPARISON  One figure with six separate charts that compare the
% five watermarking stages (each metric has its own axis, because the
% metrics have different units and scales):
%
%   A  PSNR  (original cover vs clean watermarked image)      higher = better
%   B  SSIM  (original cover vs clean watermarked image)      closer to 1 = better
%   C  Image Fidelity, project/paper eq. (19)                 closer to 0 = more similar
%   D  NCC   (input watermark vs extracted watermark)         higher = better
%   E  PSNR  (clean watermarked vs noisy watermarked image)   noise damage
%   F  SSIM  (clean watermarked vs noisy watermarked image)   noise damage
%
% D uses the noise chosen by the user. E and F exist only when a noise was
% chosen. A PSNR of Inf (identical images) is drawn as a capped bar labelled
% "Inf".

    names = res.stageNames;
    scr = get(0, 'ScreenSize');
    figW = min(1250, scr(3) - 60);
    figH = min(720, scr(4) - 100);
    fig = figure('Name', 'Comparison of the five watermarking stages', 'NumberTitle', 'off', ...
                 'Color', 'w', 'Position', [max(1, (scr(3) - figW) / 2 + 30), ...
                                            max(1, (scr(4) - figH) / 2 - 20), figW, figH]);

    colX = [0.06 0.375 0.69];
    rowY = [0.58 0.14];
    wA = 0.27;
    hA = 0.30;

    % --- A: PSNR of the embedding
    ax = subplot('Position', [colX(1) rowY(1) wA hA]);
    drawBars(ax, res.psnr, names, 'A. Embedding quality: PSNR', 'PSNR (dB)', '%.2f', []);

    % --- B: SSIM of the embedding (axis zoomed, see label)
    ax = subplot('Position', [colX(2) rowY(1) wA hA]);
    lowLim = 0;
    fin = res.ssim(isfinite(res.ssim));
    if ~isempty(fin)
        lowLim = max(0, floor((min(fin) - 0.01) * 100) / 100);
    end
    drawBars(ax, res.ssim, names, 'B. Embedding quality: SSIM', ...
             sprintf('SSIM (axis starts at %.2f)', lowLim), '%.4f', [lowLim 1.02]);

    % --- C: Image Fidelity
    ax = subplot('Position', [colX(3) rowY(1) wA hA]);
    drawBars(ax, res.IF, names, 'C. Image Fidelity (closer to 0 = more similar)', ...
             'IF = 1 - sum(I.*I'')/sum(I.^2)', '%.2e', []);

    % --- D: NCC after the selected noise
    ax = subplot('Position', [colX(1) rowY(2) wA hA]);
    if strcmp(res.noiseType, 'none')
        ttlD = 'D. Watermark recovery: NCC (no noise)';
    else
        ttlD = sprintf('D. Watermark recovery: NCC (%s noise)', res.noiseLabel);
    end
    drawBars(ax, res.ncc, names, ttlD, 'NCC', '%.4f', [0 1.12]);

    % --- E, F: damage caused by the noise
    ax = subplot('Position', [colX(2) rowY(2) wA hA]);
    if strcmp(res.noiseType, 'none')
        emptyPanel(ax, 'E. Noise damage: PSNR');
    else
        drawBars(ax, res.noisePsnr, names, 'E. Noise damage: PSNR (clean vs noisy)', 'PSNR (dB)', '%.2f', []);
    end
    ax = subplot('Position', [colX(3) rowY(2) wA hA]);
    if strcmp(res.noiseType, 'none')
        emptyPanel(ax, 'F. Noise damage: SSIM');
    else
        fin = res.noiseSsim(isfinite(res.noiseSsim));
        lowN = 0;
        if ~isempty(fin)
            lowN = max(0, floor((min(fin) - 0.02) * 20) / 20);
        end
        drawBars(ax, res.noiseSsim, names, 'F. Noise damage: SSIM (clean vs noisy)', ...
                 sprintf('SSIM (axis starts at %.2f)', lowN), '%.4f', [lowN 1.02]);
    end

    if strcmp(res.noiseType, 'none')
        head = 'Comparison of the five watermarking stages - no noise';
    else
        head = sprintf('Comparison of the five watermarking stages - %s noise (%s)', ...
                       res.noiseLabel, res.noiseParamText);
    end
    annotation(fig, 'textbox', [0 0.935 1 0.055], 'String', head, 'EdgeColor', 'none', ...
               'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);
    annotation(fig, 'textbox', [0 0.005 1 0.04], 'EdgeColor', 'none', ...
               'String', 'The orange bar is the primary result (DWT-DCT-SVD-PBFO). Alpha = embedding strength.', ...
               'HorizontalAlignment', 'center', 'FontSize', 9);
end

% ---------------------------------------------------------------------
function drawBars(ax, vals, names, ttl, ylab, fmt, yLimits)
% Bar chart with value labels. Inf is drawn as a capped bar, NaN as no bar.
    nS = numel(vals);
    plotVals = vals(:)';
    fin = plotVals(isfinite(plotVals));
    if isempty(fin)
        capVal = 100;
    else
        capVal = max(abs(fin)) * 1.1;
        if capVal == 0
            capVal = 1;
        end
    end
    plotVals(isinf(plotVals)) = capVal;

    b = bar(ax, 1:nS, plotVals, 0.6);
    b.FaceColor = 'flat';
    cd = repmat([0.45 0.62 0.80], nS, 1);
    cd(nS, :) = [0.85 0.35 0.10];
    b.CData = cd;

    if isempty(yLimits)
        shown = plotVals(isfinite(plotVals));
        lo = min([0, shown]);
        hi = max([0, shown]);
        if hi == lo
            hi = lo + 1;
        end
        span = hi - lo;
        if lo < 0
            lo = lo - 0.15 * span;
        end
        yLimits = [lo, hi + 0.18 * span];
    end
    ylim(ax, yLimits);
    xlim(ax, [0.4 nS + 0.6]);

    for i = 1:nS
        if isnan(vals(i))
            label = 'n/a';
            y = max(yLimits(1), 0);
        elseif isinf(vals(i))
            label = 'Inf';
            y = plotVals(i);
        else
            label = sprintf(fmt, vals(i));
            y = plotVals(i);
        end
        if y < 0
            va = 'top';
        else
            va = 'bottom';
        end
        text(i, y, label, 'Parent', ax, 'HorizontalAlignment', 'center', ...
             'VerticalAlignment', va, 'FontSize', 8);
    end

    set(ax, 'XTick', 1:nS, 'XTickLabel', names, 'XTickLabelRotation', 25, 'FontSize', 8);
    ylabel(ax, ylab, 'FontSize', 9);
    title(ax, ttl, 'FontSize', 10);
    grid(ax, 'on');
    box(ax, 'on');
end

function emptyPanel(ax, ttl)
    set(ax, 'XTick', [], 'YTick', [], 'XLim', [0 1], 'YLim', [0 1]);
    box(ax, 'on');
    text(0.5, 0.5, 'No noise selected', 'Parent', ax, 'HorizontalAlignment', 'center', ...
         'FontSize', 10, 'Color', [0.4 0.4 0.4]);
    title(ax, ttl, 'FontSize', 10);
end
