function watermarkingApp()
% WATERMARKINGAPP  Graphical interface for the hybrid DWT-DCT-SVD
% watermarking project (BFO and PBFO), after Yildiz, Ustunsoy, Sayan (2024).
%
% Normally you start it with main.m. Windows, in the order they appear:
%   1. selectWindow     upload the cover image and the watermark image, Submit
%                       (closes when the embedding is done)
%   2. embedWindow      watermarked image + its PSNR; pick a noise from the
%                       drop-down and press OK to see the noised image on the
%                       right; "Extract watermark" opens window 3 (this window
%                       stays open)
%   3. extractWindow    given watermark next to the extracted watermark, with
%                       the NC value (0 to 1); "Show results / comparison"
%                       opens window 4 and leaves this one open
%   4. tablesWindow     results: original, watermarked, noised watermarked image,
%                       original and extracted watermark (with PSNR and NC), plus
%                       the metric tables for all five stages
% Only window 1 closes by itself; every other window stays open until the
% user closes it.
%
% All windows and their helper functions are in this one file (local
% functions). The processing itself is embedAllStages.m and
% attackAndExtract.m in the utils folder. The result shown everywhere is the
% primary one, DWT-DCT-SVD-PBFO (the last of the five stages).
% Needs MATLAB R2018a or newer (uifigure, uiaxes, uiprogressdlg). No toolbox.

    addpath(genpath(projectRoot()));
    if verLessThan('matlab', '9.4')
        error('watermarkingApp:oldMatlab', ...
              'This GUI needs MATLAB R2018a or newer (it uses uifigure and uiprogressdlg).');
    end
    selectWindow();
end

% =====================================================================
function root = projectRoot()
% Folder that holds main.m (this file lives in <root>/gui).
    root = fileparts(fileparts(mfilename('fullpath')));
end

function d = imagesDir()
% Start the file pickers in the images folder when it exists.
    d = fullfile(projectRoot(), 'images');
    if isfolder(d)
        d = [d filesep];
    else
        d = '';
    end
end

function d = resultsDir()
% Save dialogs start in the results folder when it exists.
    d = fullfile(projectRoot(), 'results');
    if ~isfolder(d)
        d = pwd;
    end
end

% =====================================================================
function fig = selectWindow()
% Window 1: the user browses for the cover image and the watermark image,
% sees previews, and presses Submit. Submit runs the BFO/PBFO search and the
% embedding (with a progress dialog), opens window 2 (embedWindow) and then
% closes this window.
%
%   fig = selectWindow()   returns the figure handle.

    imgSize = 256;       % cover is resized to imgSize x imgSize (original project setting)

    % State shared by the callbacks below
    coverGray = [];   coverPath = '';
    wmRaw = [];       wmPath = '';
    Wprep = [];

    % ------------------------------------------------------------- layout
    scr = get(0, 'ScreenSize');
    figW = 920;  figH = 600;
    fig = uifigure('Name', 'Hybrid DWT-DCT-SVD Watermarking (BFO / PBFO) - 1. Upload images', ...
                   'Position', [max(1, (scr(3) - figW) / 2), max(1, (scr(4) - figH) / 2), figW, figH], ...
                   'Resize', 'off');

    uilabel(fig, 'Text', 'Hybrid DWT-DCT-SVD Image Watermarking with BFO and PSO', ...
            'Position', [20 552 880 36], 'FontSize', 20, 'FontWeight', 'bold');

    % --- Panel 1: cover image
    pCover = uipanel(fig, 'Title', '1. Original (cover) image', 'FontWeight', 'bold', ...
                     'Position', [20 80 430 460]);
    uibutton(pCover, 'push', 'Text', 'Browse...', 'Position', [15 400 110 28], ...
             'ButtonPushedFcn', @onBrowseCover);
    lblCover = uilabel(pCover, 'Text', 'No image selected', 'Position', [135 400 280 28]);
    axCover = uiaxes(pCover, 'Position', [30 90 370 300]);
    lblCoverInfo = uilabel(pCover, 'Text', '', 'Position', [15 10 400 70], ...
                           'WordWrap', 'on', 'VerticalAlignment', 'top');
    guiShow(axCover, [], 'Cover image preview');

    % --- Panel 2: watermark image
    pWm = uipanel(fig, 'Title', '2. Watermark image (logo)', 'FontWeight', 'bold', ...
                  'Position', [470 80 430 460]);
    uibutton(pWm, 'push', 'Text', 'Browse...', 'Position', [15 400 110 28], ...
             'ButtonPushedFcn', @onBrowseWatermark);
    lblWm = uilabel(pWm, 'Text', 'No image selected', 'Position', [135 400 280 28]);
    axWmIn  = uiaxes(pWm, 'Position', [15 205 195 185]);
    axWmOut = uiaxes(pWm, 'Position', [220 205 195 185]);
    guiShow(axWmIn,  [], 'Selected watermark');
    guiShow(axWmOut, [], 'Prepared watermark');
    chkBin = uicheckbox(pWm, 'Text', 'Convert to black/white (Otsu threshold)', 'Value', true, ...
                        'Position', [15 172 400 22], 'ValueChangedFcn', @onWmOption);
    chkInv = uicheckbox(pWm, 'Text', 'Invert (tick if the logo is dark on a light background)', ...
                        'Value', false, 'Position', [15 146 410 22], 'ValueChangedFcn', @onWmOption);
    uilabel(pWm, 'Text', 'Maximum watermark size (pixels):', 'Position', [15 116 215 22]);
    edtMax = uieditfield(pWm, 'numeric', 'Value', 32, 'Limits', [8 64], ...
                         'RoundFractionalValues', 'on', 'Position', [235 116 70 22], ...
                         'ValueChangedFcn', @onWmOption);
    lblWmInfo = uilabel(pWm, 'Text', '', 'Position', [15 8 405 100], ...
                        'WordWrap', 'on', 'VerticalAlignment', 'top');

    % --- Bottom bar
    lblStatus = uilabel(fig, 'Text', 'Upload the cover image and the watermark image, then press Submit.', ...
                        'Position', [20 18 650 44], 'WordWrap', 'on');
    btnSubmit = uibutton(fig, 'push', 'Text', 'Submit', 'FontWeight', 'bold', ...
                         'Position', [690 20 140 40], 'ButtonPushedFcn', @onSubmit);
    uibutton(fig, 'push', 'Text', 'Exit', 'Position', [840 20 60 40], ...
             'ButtonPushedFcn', @(~, ~) delete(fig));

    % ---------------------------------------------------------- callbacks
    function onBrowseCover(~, ~)
        [f, p] = uigetfile(imageFilter(), 'Upload the original (cover) image', imagesDir());
        figure(fig);
        if isequal(f, 0)
            setStatus('Cover image selection was cancelled.', false);
            return;
        end
        fullPath = fullfile(p, f);
        try
            raw = loadImage(fullPath);
            [gray, info] = prepareCover(raw, imgSize);
        catch ME
            uialert(fig, ME.message, 'Cannot use this cover image');
            setStatus(['Cover image not loaded: ' ME.message], true);
            return;
        end
        coverGray = gray;
        coverPath = fullPath;
        lblCover.Text = f;
        lblCover.Tooltip = fullPath;
        guiShow(axCover, raw, 'Selected cover image');
        if info.wasRGB
            kind = 'RGB';
        else
            kind = 'Grayscale';
        end
        lblCoverInfo.Text = sprintf(['%s image, %d x %d pixels. It is converted to a %d x %d ' ...
                                     'grayscale image for the watermarking.'], ...
                                    kind, info.originalSize(1), info.originalSize(2), imgSize, imgSize);
        setStatus('Cover image loaded.', false);
    end

    function onBrowseWatermark(~, ~)
        [f, p] = uigetfile(imageFilter(), 'Upload the watermark image (logo)', imagesDir());
        figure(fig);
        if isequal(f, 0)
            setStatus('Watermark selection was cancelled.', false);
            return;
        end
        fullPath = fullfile(p, f);
        try
            raw = loadImage(fullPath);
        catch ME
            uialert(fig, ME.message, 'Cannot use this watermark image');
            setStatus(['Watermark image not loaded: ' ME.message], true);
            return;
        end
        wmRaw = raw;
        wmPath = fullPath;
        lblWm.Text = f;
        lblWm.Tooltip = fullPath;

        % Pre-set "Invert" so that the logo (the minority colour) becomes the
        % embedded part (value 1). The user can still change it.
        try
            Wtest = prepareWatermark(wmRaw, edtMax.Value, chkBin.Value, false);
            chkInv.Value = mean(Wtest(:)) > 0.5;
        catch
            chkInv.Value = false;
        end
        refreshWatermark();
    end

    function onWmOption(~, ~)
        if ~isempty(wmRaw)
            refreshWatermark();
        end
    end

    function refreshWatermark()
        Wprep = [];
        guiShow(axWmIn, wmRaw, 'Selected watermark');
        try
            [W, info] = prepareWatermark(wmRaw, edtMax.Value, chkBin.Value, chkInv.Value);
        catch ME
            guiShow(axWmOut, [], 'Prepared watermark');
            lblWmInfo.FontColor = [0.75 0 0];
            lblWmInfo.Text = ME.message;
            setStatus(['Watermark not usable: ' ME.message], true);
            return;
        end
        Wprep = W;
        guiShow(axWmOut, W, sprintf('Prepared watermark (%d x %d)', info.size(1), info.size(2)));
        lblWmInfo.FontColor = [0 0 0];
        if info.binary
            mode = 'black/white';
        else
            mode = 'gray levels';
        end
        lblWmInfo.Text = sprintf(['Original %d x %d pixels, prepared as %d x %d (%s). White pixels ' ...
                                  '(value 1) are the part that is embedded: %.0f%% of the pixels.'], ...
                                 info.originalSize(1), info.originalSize(2), info.size(1), info.size(2), ...
                                 mode, 100 * mean(W(:)));
        setStatus('Watermark image loaded.', false);
    end

    function onSubmit(~, ~)
        if isempty(coverGray)
            uialert(fig, 'Please upload the original (cover) image first.', 'Missing input');
            return;
        end
        if isempty(wmRaw)
            uialert(fig, 'Please upload the watermark image first.', 'Missing input');
            return;
        end
        if isempty(Wprep)
            uialert(fig, ['The watermark image cannot be used as it is. Choose another image ' ...
                          'or change the black/white / invert options.'], 'Watermark not usable');
            return;
        end
        btnSubmit.Enable = 'off';
        dlg = uiprogressdlg(fig, 'Title', 'Embedding the watermark', ...
                            'Message', 'Starting...', 'Indeterminate', 'on', 'Cancelable', 'on');
        cleaner = onCleanup(@() releaseUi(dlg, btnSubmit));  %#ok<NASGU>
        opts = struct('statusFcn', @(msg) updateProgress(dlg, msg));
        setStatus('Working... the BFO/PBFO search can take a minute or two.', false);
        try
            emb = embedAllStages(coverGray, Wprep, opts);
        catch ME
            releaseUi(dlg, btnSubmit);
            if strcmp(ME.identifier, 'embedAllStages:cancelled')
                setStatus('The run was cancelled.', false);
            else
                uialert(fig, ME.message, 'Processing failed');
                setStatus(['Processing failed: ' ME.message], true);
            end
            return;
        end
        emb.coverPath = coverPath;
        emb.watermarkPath = wmPath;
        releaseUi(dlg, btnSubmit);
        try
            embedWindow(emb);
        catch ME
            uialert(fig, ME.message, 'Could not show the watermarked image');
            setStatus(['Could not show the watermarked image: ' ME.message], true);
            return;
        end
        delete(fig);      % window 2 is open, window 1 is done
    end

    function setStatus(msg, isError)
        if ~isvalid(fig)
            return;
        end
        lblStatus.Text = msg;
        if isError
            lblStatus.FontColor = [0.75 0 0];
        else
            lblStatus.FontColor = [0 0 0];
        end
    end
end

% ---------------------------------------------------------------------
function filt = imageFilter()
    filt = {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', ...
            'Image files (*.png, *.jpg, *.jpeg, *.bmp, *.tif, *.tiff)'; ...
            '*.*', 'All files'};
end

function cancelNow = updateProgress(dlg, msg)
% Called by embedAllStages with status text; returns true if the user
% pressed Cancel in the progress dialog.
    cancelNow = false;
    if isvalid(dlg)
        dlg.Message = msg;
        drawnow;
        cancelNow = dlg.CancelRequested;
    end
end

function releaseUi(dlg, btn)
% Closes the progress dialog and re-enables the Submit button (safe to
% call more than once).
    if isvalid(dlg)
        close(dlg);
    end
    if isvalid(btn)
        btn.Enable = 'on';
    end
end


% =====================================================================
function fig = embedWindow(emb)
% Window 2: the watermarked image with its PSNR on the left. A drop-down and
% an OK button apply a noise to it; the noised image appears on the right.
% "Extract watermark" opens window 3 and leaves this window open, so another
% noise can be tried (each Extract opens its own window 3, titled with the noise).

    S = numel(emb.stageNames);                  % primary result = DWT-DCT-SVD-PBFO
    items       = {'None', 'Gaussian Noise', 'Shot (Poisson) Noise', 'Salt-and-Pepper Noise', 'Speckle Noise'};
    types       = {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'};
    noiseCfg    = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
    res = [];                                   % result of the last OK press

    if isfield(emb, 'coverPath') && ~isempty(emb.coverPath)
        [~, baseName] = fileparts(emb.coverPath);
    else
        baseName = 'image';
    end

    scr = get(0, 'ScreenSize');
    figW = 1060;  figH = 650;
    fig = uifigure('Name', 'Hybrid DWT-DCT-SVD Watermarking - 2. Watermarked image', ...
                   'Position', [max(1, (scr(3) - figW) / 2), max(1, (scr(4) - figH) / 2), figW, figH], ...
                   'Resize', 'off');

    uilabel(fig, 'Text', 'Watermarked image (DWT-DCT-SVD-PBFO)', ...
            'Position', [20 608 700 32], 'FontSize', 20, 'FontWeight', 'bold');

    % --- left: watermarked image + PSNR
    pL = uipanel(fig, 'Title', 'Watermarked image', 'FontWeight', 'bold', 'Position', [20 130 500 465]);
    axWm = uiaxes(pL, 'Position', [20 70 460 365]);
    guiShow(axWm, emb.wmImgs{S}, '');
    uilabel(pL, 'Position', [20 25 460 34], 'FontSize', 18, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'Text', sprintf('PSNR = %s dB', fmtNum(emb.psnr(S), '%.2f')));

    % --- right: noised watermarked image
    pR = uipanel(fig, 'Title', 'Noised watermarked image', 'FontWeight', 'bold', 'Position', [540 130 500 465]);
    axNoisy = uiaxes(pR, 'Position', [20 70 460 365]);
    guiShow(axNoisy, [], '');
    lblNoisy = uilabel(pR, 'Position', [20 20 460 44], 'WordWrap', 'on', 'HorizontalAlignment', 'center', ...
                       'Text', 'Choose a noise below and press OK.');

    % --- bottom bar
    uilabel(fig, 'Text', 'Noise:', 'FontWeight', 'bold', 'Position', [20 82 50 22]);
    dd = uidropdown(fig, 'Items', items, 'Value', 'None', 'Position', [75 80 260 26], ...
                    'ValueChangedFcn', @onNoiseChanged);
    uibutton(fig, 'push', 'Text', 'OK', 'FontWeight', 'bold', 'Position', [345 77 80 32], ...
             'ButtonPushedFcn', @onOK);
    btnExtract = uibutton(fig, 'push', 'Text', 'Extract watermark  >', 'FontWeight', 'bold', ...
                          'Position', [820 74 220 38], 'Enable', 'off', 'ButtonPushedFcn', @onExtract);
    uibutton(fig, 'push', 'Text', 'Save watermarked image', 'Position', [20 20 190 30], ...
             'ButtonPushedFcn', @(~, ~) saveImageFile(fig, emb.wmImgs{S}, ...
                                  [baseName '_watermarked.png'], inputPaths(emb)));
    uibutton(fig, 'push', 'Text', 'Save noised image', 'Position', [220 20 160 30], ...
             'ButtonPushedFcn', @onSaveNoisy);
    uilabel(fig, 'Text', 'Save as PNG, BMP or TIFF. JPEG compression would damage the watermark.', ...
            'Position', [395 14 420 42], 'WordWrap', 'on');
    uibutton(fig, 'push', 'Text', 'Exit', 'Position', [950 20 90 30], 'ButtonPushedFcn', @(~, ~) delete(fig));

    % ---------------------------------------------------------- callbacks
    function onNoiseChanged(~, ~)
        % The picture on the right belongs to the noise that was applied, so
        % it is cleared until OK is pressed for the new choice.
        res = [];
        btnExtract.Enable = 'off';
        guiShow(axNoisy, [], '');
        lblNoisy.Text = 'Press OK to apply the selected noise.';
    end

    function onOK(~, ~)
        idx = find(strcmp(items, dd.Value), 1);
        try
            r = attackAndExtract(emb, types{idx}, noiseCfg);
        catch ME
            uialert(fig, ME.message, 'Could not apply the noise');
            return;
        end
        res = r;
        guiShow(axNoisy, r.finalImgs{S}, '');
        if strcmp(r.noiseType, 'none')
            lblNoisy.Text = 'No noise applied: this is the clean watermarked image.';
        else
            lblNoisy.Text = sprintf('%s noise (%s). PSNR against the watermarked image: %s dB.', ...
                                    r.noiseLabel, r.noiseParamText, fmtNum(r.noisePsnr(S), '%.2f'));
        end
        btnExtract.Enable = 'on';
    end

    function onExtract(~, ~)
        if isempty(res)
            return;
        end
        extractWindow(res);             % this window stays open
    end

    function onSaveNoisy(~, ~)
        if isempty(res)
            uialert(fig, 'Choose a noise and press OK first.', 'Nothing to save');
            return;
        end
        saveImageFile(fig, res.finalImgs{S}, [baseName '_noised.png'], inputPaths(emb));
    end
end

% ---------------------------------------------------------------------
function p = inputPaths(emb)
% The user's input files (so that saving never overwrites them).
    p = {};
    if isfield(emb, 'coverPath'),     p{end + 1} = emb.coverPath;     end
    if isfield(emb, 'watermarkPath'), p{end + 1} = emb.watermarkPath; end
end

function saveImageFile(parentFig, img, defName, inputs)
% Save dialog for an image. Refuses to overwrite the user's own input files
% and warns about JPEG.
    filt = {'*.png', 'PNG image (*.png)'; '*.bmp', 'BMP image (*.bmp)'; ...
            '*.tif', 'TIFF image (*.tif)'; '*.jpg', 'JPEG image (*.jpg) - lossy, not recommended'};
    [f, p] = uiputfile(filt, 'Save image', fullfile(resultsDir(), defName));
    figure(parentFig);
    if isequal(f, 0)
        return;
    end
    target = fullfile(p, f);
    if any(strcmpi(target, inputs))
        uialert(parentFig, 'That is one of your input files. Please choose a different file name.', ...
                'Not saved');
        return;
    end
    try
        imwrite(img, target);
    catch ME
        uialert(parentFig, ME.message, 'Saving failed');
        return;
    end
    [~, ~, ext] = fileparts(target);
    if any(strcmpi(ext, {'.jpg', '.jpeg'}))
        uialert(parentFig, ['Saved, but JPEG compression changes the pixel values and will damage ' ...
                            'the hidden watermark. Use PNG, BMP or TIFF to keep it extractable.'], ...
                'Saved (with a warning)', 'Icon', 'warning');
    else
        uialert(parentFig, ['Saved to ' target], 'Saved', 'Icon', 'success');
    end
end


% =====================================================================
function fig = extractWindow(res)
% Window 3: the given watermark next to the watermark extracted from the
% (noised) watermarked image, with the NC value between 0 and 1.
% "Show results / comparison" opens window 4 and leaves this window open.

    S = numel(res.stageNames);                  % primary result = DWT-DCT-SVD-PBFO

    % NC is the normalised cross-correlation (1 = identical). By its definition
    % it can only dip below 0 when the extraction has completely failed, so
    % the value is limited to the range 0..1 for display.
    nc = min(max(res.ncc(S), 0), 1);

    scr = get(0, 'ScreenSize');
    figW = 900;  figH = 600;
    fig = uifigure('Name', ['Hybrid DWT-DCT-SVD Watermarking - 3. Extracted watermark (' res.noiseLabel ' noise)'], ...
                   'Position', [max(1, (scr(3) - figW) / 2 + 40), max(1, (scr(4) - figH) / 2 - 30), figW, figH], ...
                   'Resize', 'off');

    uilabel(fig, 'Text', 'Watermark extraction', 'Position', [20 556 600 32], ...
            'FontSize', 20, 'FontWeight', 'bold');
    if strcmp(res.noiseType, 'none')
        noiseText = 'Extracted from the clean watermarked image (no noise).';
    else
        noiseText = sprintf('Extracted from the watermarked image with %s noise (%s).', ...
                            res.noiseLabel, res.noiseParamText);
    end
    uilabel(fig, 'Text', noiseText, 'Position', [20 528 860 22]);

    pGiven = uipanel(fig, 'Title', 'Given watermark', 'FontWeight', 'bold', 'Position', [20 170 420 350]);
    axGiven = uiaxes(pGiven, 'Position', [15 15 390 310]);
    guiShow(axGiven, res.W, sprintf('%d x %d', size(res.W, 1), size(res.W, 2)));

    pExt = uipanel(fig, 'Title', 'Extracted watermark', 'FontWeight', 'bold', 'Position', [460 170 420 350]);
    axExt = uiaxes(pExt, 'Position', [15 15 390 310]);
    We = res.extImgs{S};
    if res.isBinary
        shown = double(We > 0.5);
    else
        shown = min(max(We, 0), 1);
    end
    guiShow(axExt, shown, sprintf('%d x %d', size(We, 1), size(We, 2)));

    uilabel(fig, 'Text', sprintf('NC = %.4f', nc), 'Position', [20 95 860 56], ...
            'FontSize', 34, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
    uilabel(fig, 'Text', 'Normalised cross-correlation between the given and the extracted watermark (1 = identical, 0 = no similarity)', ...
            'Position', [20 70 860 22], 'HorizontalAlignment', 'center');

    uibutton(fig, 'push', 'Text', 'Show results / comparison', 'FontWeight', 'bold', ...
             'Position', [20 18 240 38], 'ButtonPushedFcn', @(~, ~) tablesWindow(res));
    uibutton(fig, 'push', 'Text', 'Close', 'Position', [790 18 90 38], 'ButtonPushedFcn', @(~, ~) delete(fig));
end


% =====================================================================
function fig = tablesWindow(res)
% Window 4: the results. Top row: original image, watermarked image, noised
% watermarked image, original watermark and extracted watermark, each with
% its PSNR / NC value. Below: the comparison tables of all five stages.
% Opened by the button in window 3; window 3 stays open.

    S = numel(res.stageNames);                  % primary result = DWT-DCT-SVD-PBFO

    scr = get(0, 'ScreenSize');
    figW = 960;  figH = 880;
    fig = uifigure('Name', 'Hybrid DWT-DCT-SVD Watermarking - 4. Results / comparison', ...
                   'Position', [max(1, (scr(3) - figW) / 2 + 40), max(1, (scr(4) - figH) / 2 - 20), figW, figH], ...
                   'Scrollable', 'on');

    uilabel(fig, 'Text', 'Results / comparison', ...
            'Position', [20 838 900 32], 'FontSize', 20, 'FontWeight', 'bold');

    % --- Images with their PSNR / NC values (primary result = last stage)
    nc = min(max(res.ncc(S), 0), 1);
    We = res.extImgs{S};
    if res.isBinary
        shownWe = double(We > 0.5);
    else
        shownWe = min(max(We, 0), 1);
    end
    if strcmp(res.noiseType, 'none')
        noisyCap = 'No noise applied (same as the watermarked image)';
        noisyTtl = 'Watermarked + noise (none)';
    else
        noisyCap = sprintf('%s noise (%s)\nPSNR = %s dB', res.noiseLabel, res.noiseParamText, ...
                           fmtNum(res.noisePsnr(S), '%.2f'));
        noisyTtl = 'Watermarked + noise';
    end

    imgs = {res.cover, res.wmImgs{S}, res.finalImgs{S}, res.W, shownWe};
    ttls = {'Original image', 'Watermarked image', noisyTtl, 'Original watermark', 'Extracted watermark'};
    caps = {sprintf('%d x %d', size(res.cover, 1), size(res.cover, 2)), ...
            sprintf('PSNR = %s dB', fmtNum(res.psnr(S), '%.2f')), ...
            noisyCap, ...
            sprintf('%d x %d', size(res.W, 1), size(res.W, 2)), ...
            sprintf('NC = %.4f', nc)};
    for k = 1:5
        x = 20 + (k - 1) * 184;
        ax = uiaxes(fig, 'Position', [x 640 176 176]);
        guiShow(ax, imgs{k}, ttls{k});
        uilabel(fig, 'Text', caps{k}, 'Position', [x 585 176 50], 'WordWrap', 'on', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                'FontWeight', 'bold', 'FontSize', 12);
    end

    % --- Table 1: embedding quality
    uilabel(fig, 'Text', 'Table 1. Embedding quality (original cover vs clean watermarked image)', ...
            'Position', [20 548 900 22], 'FontWeight', 'bold');
    uitable(fig, 'Data', embeddingTable(res), ...
            'ColumnName', {'Stage', 'Alpha', 'PSNR (dB)', 'SSIM', 'Image Fidelity'}, 'RowName', {}, ...
            'ColumnWidth', {200, 100, 150, 150, 150}, 'Position', [20 398 900 145]);

    % --- Table 2: recovery and noise damage
    if strcmp(res.noiseType, 'none')
        t2 = 'Table 2. Watermark recovery (no noise)';
    else
        t2 = sprintf('Table 2. Watermark recovery and noise damage (%s noise, %s)', res.noiseLabel, res.noiseParamText);
    end
    uilabel(fig, 'Text', t2, 'Position', [20 366 900 22], 'FontWeight', 'bold');
    uitable(fig, 'Data', recoveryTable(res), ...
            'ColumnName', {'Stage', 'NC', 'BER', 'Noise PSNR (dB)', 'Noise SSIM'}, 'RowName', {}, ...
            'ColumnWidth', {200, 100, 150, 150, 150}, 'Position', [20 216 900 145]);

    uilabel(fig, 'Position', [20 55 900 150], 'WordWrap', 'on', 'VerticalAlignment', 'top', 'Text', ...
        ['The images and the last row of each table, DWT-DCT-SVD-PBFO, are the primary result shown in the previous windows. ' ...
         'PSNR under the watermarked image, SSIM and Image Fidelity compare the ORIGINAL cover with the CLEAN watermarked image (quality of ' ...
         'the embedding). Image Fidelity follows the project definition (paper eq. 19): IF = 1 - sum(I.*I'') / ' ...
         'sum(I.^2); values close to 0 mean the images are very similar (it can be slightly negative). ' ...
         'NC and BER compare the given watermark with the watermark extracted from the final output (the clean ' ...
         'image if no noise was chosen, otherwise the noised image); NC closer to 1 and lower BER are better, ' ...
         'and BER is only defined for a black/white watermark. Noise PSNR and Noise SSIM compare each clean ' ...
         'watermarked image with its noised version, so they measure the damage done by the noise, not by the ' ...
         'embedding. "n/a" = not defined, "Inf" = identical images.']);

    uibutton(fig, 'push', 'Text', 'Close', 'Position', [830 15 90 34], 'ButtonPushedFcn', @(~, ~) delete(fig));
end

% ---------------------------------------------------------------------
function data = embeddingTable(res)
% One row per stage, all values as text so that "Inf" and "n/a" display well.
    nS = numel(res.stageNames);
    data = cell(nS, 5);
    for s = 1:nS
        data(s, :) = {res.stageNames{s}, fmtNum(res.alphas(s), '%.2f'), fmtNum(res.psnr(s), '%.2f'), ...
                      fmtNum(res.ssim(s), '%.4f'), fmtNum(res.IF(s), '%.3e')};
    end
end

function data = recoveryTable(res)
    nS = numel(res.stageNames);
    data = cell(nS, 5);
    for s = 1:nS
        nc = min(max(res.ncc(s), 0), 1);          % same 0..1 range as window 3
        data(s, :) = {res.stageNames{s}, fmtNum(nc, '%.4f'), fmtNum(100 * res.ber(s), '%.2f %%'), ...
                      fmtNum(res.noisePsnr(s), '%.2f'), fmtNum(res.noiseSsim(s), '%.4f')};
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


% =====================================================================
function guiShow(ax, img, ttl)
% HY_GUI_SHOW  Shows an image in a uiaxes (core MATLAB only, no imshow).
%
%   guiShow(ax, img, ttl)
%
%   img : uint8 gray or RGB image; a logical matrix; or a double matrix with
%         values between 0 and 1. [] clears the axes.
%   ttl : title, a char vector or a cell array of lines (optional)

    cla(ax);
    ax.XTick = [];
    ax.YTick = [];
    ax.Box = 'on';

    if ~isempty(img)
        if isa(img, 'uint8')
            u = img;
        elseif islogical(img)
            u = uint8(img) * 255;
        else
            u = uint8(round(255 * min(max(double(img), 0), 1)));
        end
        if ndims(u) == 2
            u = cat(3, u, u, u);
        end
        image(ax, u);
        [h, w, ~] = size(u);
        ax.XLim = [0.5 w + 0.5];
        ax.YLim = [0.5 h + 0.5];
        ax.YDir = 'reverse';
        ax.DataAspectRatio = [1 1 1];
        ax.XTick = [];
        ax.YTick = [];
    end

    if nargin >= 3
        title(ax, ttl, 'FontSize', 10);
    end
end
