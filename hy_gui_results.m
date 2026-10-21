function fig = hy_gui_results(res)
% HY_GUI_RESULTS  Third window: previews, metrics table, save buttons.
% Also opens the comparison charts (hy_plot_comparison).
%
%   fig = hy_gui_results(res)   res comes from hy_run_pipeline (the caller may
%                               add res.coverPath and res.watermarkPath so that
%                               the input files are never overwritten).
%
% The previews show one stage at a time (default: the primary result,
% DWT-DCT-SVD-PBFO). The table lists all five stages.

    nS = numel(res.stageNames);
    stageIdx = nS;                                   % PBFO = primary result
    shortNames = {'DWT', 'DWT_DCT', 'DWT_DCT_SVD', 'BFO', 'PBFO'};
    isNone = strcmp(res.noiseType, 'none');

    if isfield(res, 'coverPath') && ~isempty(res.coverPath)
        [~, baseName] = fileparts(res.coverPath);
    else
        baseName = 'image';
    end

    % ------------------------------------------------------------- layout
    scr = get(0, 'ScreenSize');
    figW = 1040;  figH = 720;
    fig = uifigure('Name', 'Hybrid DWT-DCT-SVD Watermarking - 3. Results', ...
                   'Position', [max(1, (scr(3) - figW) / 2 - 30), max(1, (scr(4) - figH) / 2 + 20), figW, figH]);

    uilabel(fig, 'Text', 'Results (primary result: DWT-DCT-SVD-PBFO)', ...
            'Position', [20 682 700 30], 'FontSize', 18, 'FontWeight', 'bold');
    uilabel(fig, 'Text', 'Stage shown:', 'Position', [20 648 90 22]);
    ddStage = uidropdown(fig, 'Items', res.stageNames, 'Value', res.stageNames{stageIdx}, ...
                         'Position', [110 646 230 26], 'ValueChangedFcn', @onStage);
    if isNone
        noiseText = 'Noise: None. The watermark was extracted from the clean watermarked image.';
    else
        noiseText = sprintf('Noise: %s (%s). The watermark was extracted from the noisy watermarked image.', ...
                            res.noiseLabel, res.noiseParamText);
    end
    uilabel(fig, 'Text', noiseText, 'Position', [360 646 660 26]);

    tabs = uitabgroup(fig, 'Position', [10 60 1020 575]);

    % --- Tab 1: images (3 columns x 2 rows)
    tabImg = uitab(tabs, 'Title', 'Images');
    colX = [15 350 685];
    rowY = [285 15];
    axCover = uiaxes(tabImg, 'Position', [colX(1) rowY(1) 320 255]);
    axWm    = uiaxes(tabImg, 'Position', [colX(2) rowY(1) 320 255]);
    axClean = uiaxes(tabImg, 'Position', [colX(3) rowY(1) 320 255]);
    axFinal = uiaxes(tabImg, 'Position', [colX(1) rowY(2) 320 255]);
    axExt   = uiaxes(tabImg, 'Position', [colX(2) rowY(2) 320 255]);
    axDiff  = uiaxes(tabImg, 'Position', [colX(3) rowY(2) 320 255]);

    % --- Tab 2: metrics table
    tabTbl = uitab(tabs, 'Title', 'Metrics table');
    colNames = {'Stage', 'Alpha', 'PSNR (dB)', 'SSIM', 'Image Fidelity', 'NCC', 'BER', ...
                'Noise PSNR (dB)', 'Noise SSIM'};
    uitable(tabTbl, 'Data', buildTable(res), 'ColumnName', colNames, 'RowName', {}, ...
            'ColumnWidth', {160, 60, 85, 80, 105, 80, 80, 115, 100}, ...
            'Position', [10 165 995 370]);
    uilabel(tabTbl, 'Position', [10 5 995 150], 'WordWrap', 'on', 'VerticalAlignment', 'top', 'Text', ...
        ['PSNR, SSIM and Image Fidelity compare the ORIGINAL cover with the CLEAN watermarked image ' ...
         '(quality of the embedding). Image Fidelity follows the project definition (paper eq. 19): ' ...
         'IF = 1 - sum(I.*I'') / sum(I.^2); values close to 0 mean the images are very similar ' ...
         '(it can be slightly negative). NCC and BER compare the input watermark with the watermark ' ...
         'extracted from the final output (clean image if no noise was chosen, otherwise the noisy ' ...
         'image); higher NCC and lower BER are better, and BER is only defined for a black/white ' ...
         'watermark. Noise PSNR and Noise SSIM compare each clean watermarked image with its noisy ' ...
         'version, so they measure the damage done by the noise, not by the embedding. ' ...
         '"n/a" = not defined, "Inf" = identical images.']);

    % --- Buttons
    uibutton(fig, 'push', 'Text', 'Save clean watermarked image', 'Position', [20 15 220 34], ...
             'ButtonPushedFcn', @(~, ~) saveImage('clean'));
    uibutton(fig, 'push', 'Text', 'Save final output image', 'Position', [250 15 200 34], ...
             'ButtonPushedFcn', @(~, ~) saveImage('final'));
    uibutton(fig, 'push', 'Text', 'Show comparison charts', 'Position', [460 15 190 34], ...
             'ButtonPushedFcn', @(~, ~) hy_plot_comparison(res));
    uilabel(fig, 'Text', 'Save as PNG, BMP or TIFF. JPEG compression would damage the watermark.', ...
            'Position', [665 8 260 46], 'WordWrap', 'on');
    uibutton(fig, 'push', 'Text', 'Close', 'Position', [950 15 80 34], ...
             'ButtonPushedFcn', @(~, ~) delete(fig));

    refreshImages();
    hy_plot_comparison(res);

    % ---------------------------------------------------------- callbacks
    function onStage(~, ~)
        stageIdx = find(strcmp(res.stageNames, ddStage.Value), 1);
        refreshImages();
    end

    function refreshImages()
        s = stageIdx;
        hy_gui_show(axCover, res.cover, {'Original cover image', ...
                    sprintf('grayscale, %d x %d', size(res.cover, 1), size(res.cover, 2))});
        hy_gui_show(axWm, res.W, {'Input watermark', ...
                    sprintf('%d x %d, white = embedded', size(res.W, 1), size(res.W, 2))});
        hy_gui_show(axClean, res.wmImgs{s}, {'Clean watermarked image', res.stageNames{s}});

        if isNone
            finalTitle = {'Final output = clean watermarked image', '(no noise applied)'};
        else
            finalTitle = {'Final output (watermarked + noise)', ...
                          sprintf('%s noise, %s', res.noiseLabel, res.noiseParamText)};
        end
        hy_gui_show(axFinal, res.finalImgs{s}, finalTitle);

        We = res.extImgs{s};
        if res.isBinary
            shown = double(We > 0.5);
        else
            shown = min(max(We, 0), 1);
        end
        hy_gui_show(axExt, shown, {'Extracted watermark', ...
                    sprintf('%s, NCC = %.4f', res.stageNames{s}, res.ncc(s))});

        d = abs(double(res.wmImgs{s}) - double(res.cover));
        dMax = max(d(:));
        if dMax == 0
            hy_gui_show(axDiff, zeros(size(d)), {'Difference image', 'cover and watermarked are identical'});
        else
            hy_gui_show(axDiff, d / dMax, {'Difference image', ...
                        sprintf('cover vs clean watermarked (amplified x%.0f)', 255 / dMax)});
        end
    end

    function saveImage(kind)
        % Reads stageIdx when the button is pressed, so it always saves the
        % stage that is currently shown.
        if strcmp(kind, 'clean')
            img = res.wmImgs{stageIdx};
        else
            img = res.finalImgs{stageIdx};
        end
        filt = {'*.png', 'PNG image (*.png)'; '*.bmp', 'BMP image (*.bmp)'; ...
                '*.tif', 'TIFF image (*.tif)'; '*.jpg', 'JPEG image (*.jpg) - lossy, not recommended'};
        defName = sprintf('%s_%s_%s.png', baseName, kind, shortNames{stageIdx});
        [f, p] = uiputfile(filt, 'Save image', defName);
        figure(fig);
        if isequal(f, 0)
            return;
        end
        target = fullfile(p, f);
        inputs = {};
        if isfield(res, 'coverPath'),     inputs{end + 1} = res.coverPath;     end %#ok<AGROW>
        if isfield(res, 'watermarkPath'), inputs{end + 1} = res.watermarkPath; end %#ok<AGROW>
        if any(strcmpi(target, inputs))
            uialert(fig, 'That is one of your input files. Please choose a different file name.', ...
                    'Not saved');
            return;
        end
        try
            imwrite(img, target);
        catch ME
            uialert(fig, ME.message, 'Saving failed');
            return;
        end
        [~, ~, ext] = fileparts(target);
        if any(strcmpi(ext, {'.jpg', '.jpeg'}))
            uialert(fig, ['Saved, but JPEG compression changes the pixel values and will damage ' ...
                          'the hidden watermark. Use PNG, BMP or TIFF to keep it extractable.'], ...
                    'Saved (with a warning)', 'Icon', 'warning');
        else
            uialert(fig, ['Saved to ' target], 'Saved', 'Icon', 'success');
        end
    end
end

% ---------------------------------------------------------------------
function data = buildTable(res)
% One row per stage, all values as text so that "Inf" and "n/a" display well.
    nS = numel(res.stageNames);
    data = cell(nS, 9);
    for s = 1:nS
        data(s, :) = {res.stageNames{s}, fmtNum(res.alphas(s), '%.2f'), fmtNum(res.psnr(s), '%.2f'), ...
                      fmtNum(res.ssim(s), '%.4f'), fmtNum(res.IF(s), '%.3e'), fmtNum(res.ncc(s), '%.4f'), ...
                      fmtNum(100 * res.ber(s), '%.2f %%'), fmtNum(res.noisePsnr(s), '%.2f'), ...
                      fmtNum(res.noiseSsim(s), '%.4f')};
    end
end

function s = fmtNum(x, fmt)
    if isnan(x)
        s = 'n/a';
    elseif isinf(x)
        if x > 0
            s = 'Inf';
        else
            s = '-Inf';
        end
    else
        s = sprintf(fmt, x);
    end
end
