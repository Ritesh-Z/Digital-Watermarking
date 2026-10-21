function fig = hy_gui_select()
% HY_GUI_SELECT  First window: the user browses for the cover image and the
% watermark image, sees previews, and presses Continue.
%
% Continue opens the noise popup (hy_gui_noise); Run there starts the
% watermarking (hy_run_pipeline) and opens the results window
% (hy_gui_results). This window stays open, so the same two images can be
% run again with a different noise. Closing it ends the program.
%
%   fig = hy_gui_select()   returns the figure handle.

    imgSize = 256;       % cover is resized to imgSize x imgSize (original project setting)

    % State shared by the callbacks below
    coverGray = [];   coverPath = '';
    wmRaw = [];       wmPath = '';
    Wprep = [];

    % ------------------------------------------------------------- layout
    scr = get(0, 'ScreenSize');
    figW = 920;  figH = 600;
    fig = uifigure('Name', 'Hybrid DWT-DCT-SVD Watermarking (BFO / PBFO) - 1. Select images', ...
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
    hy_gui_show(axCover, [], 'Cover image preview');

    % --- Panel 2: watermark image
    pWm = uipanel(fig, 'Title', '2. Watermark image (logo)', 'FontWeight', 'bold', ...
                  'Position', [470 80 430 460]);
    uibutton(pWm, 'push', 'Text', 'Browse...', 'Position', [15 400 110 28], ...
             'ButtonPushedFcn', @onBrowseWatermark);
    lblWm = uilabel(pWm, 'Text', 'No image selected', 'Position', [135 400 280 28]);
    axWmIn  = uiaxes(pWm, 'Position', [15 205 195 185]);
    axWmOut = uiaxes(pWm, 'Position', [220 205 195 185]);
    hy_gui_show(axWmIn,  [], 'Selected watermark');
    hy_gui_show(axWmOut, [], 'Prepared watermark');
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
    lblStatus = uilabel(fig, 'Text', 'Select the cover image and the watermark image, then press Continue.', ...
                        'Position', [20 18 650 44], 'WordWrap', 'on');
    btnContinue = uibutton(fig, 'push', 'Text', 'Continue  >', 'FontWeight', 'bold', ...
                           'Position', [690 20 140 40], 'ButtonPushedFcn', @onContinue);
    uibutton(fig, 'push', 'Text', 'Exit', 'Position', [840 20 60 40], ...
             'ButtonPushedFcn', @(~, ~) delete(fig));

    % ---------------------------------------------------------- callbacks
    function onBrowseCover(~, ~)
        [f, p] = uigetfile(imageFilter(), 'Select the original (cover) image');
        figure(fig);
        if isequal(f, 0)
            setStatus('Cover image selection was cancelled.', false);
            return;
        end
        fullPath = fullfile(p, f);
        try
            raw = hy_load_image(fullPath);
            [gray, info] = hy_prepare_cover(raw, imgSize);
        catch ME
            uialert(fig, ME.message, 'Cannot use this cover image');
            setStatus(['Cover image not loaded: ' ME.message], true);
            return;
        end
        coverGray = gray;
        coverPath = fullPath;
        lblCover.Text = f;
        lblCover.Tooltip = fullPath;
        hy_gui_show(axCover, raw, 'Selected cover image');
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
        [f, p] = uigetfile(imageFilter(), 'Select the watermark image (logo)');
        figure(fig);
        if isequal(f, 0)
            setStatus('Watermark selection was cancelled.', false);
            return;
        end
        fullPath = fullfile(p, f);
        try
            raw = hy_load_image(fullPath);
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
            Wtest = hy_prepare_watermark(wmRaw, edtMax.Value, chkBin.Value, false);
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
        hy_gui_show(axWmIn, wmRaw, 'Selected watermark');
        try
            [W, info] = hy_prepare_watermark(wmRaw, edtMax.Value, chkBin.Value, chkInv.Value);
        catch ME
            hy_gui_show(axWmOut, [], 'Prepared watermark');
            lblWmInfo.FontColor = [0.75 0 0];
            lblWmInfo.Text = ME.message;
            setStatus(['Watermark not usable: ' ME.message], true);
            return;
        end
        Wprep = W;
        hy_gui_show(axWmOut, W, sprintf('Prepared watermark (%d x %d)', info.size(1), info.size(2)));
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

    function onContinue(~, ~)
        if isempty(coverGray)
            uialert(fig, 'Please select the original (cover) image first.', 'Missing input');
            return;
        end
        if isempty(wmRaw)
            uialert(fig, 'Please select the watermark image first.', 'Missing input');
            return;
        end
        if isempty(Wprep)
            uialert(fig, ['The watermark image cannot be used as it is. Choose another image ' ...
                          'or change the black/white / invert options.'], 'Watermark not usable');
            return;
        end
        sel = hy_gui_noise(fig);
        if isempty(sel)
            setStatus('Noise selection cancelled. Press Continue to choose again.', false);
            return;
        end
        runPipeline(sel);
    end

    function runPipeline(sel)
        btnContinue.Enable = 'off';
        dlg = uiprogressdlg(fig, 'Title', 'Running the watermarking pipeline', ...
                            'Message', 'Starting...', 'Indeterminate', 'on', 'Cancelable', 'on');
        cleaner = onCleanup(@() releaseUi(dlg, btnContinue));  %#ok<NASGU>
        opts = struct('noiseCfg', sel.cfg, 'statusFcn', @(msg) updateProgress(dlg, msg));
        setStatus('Running... the BFO/PBFO search can take a minute or two.', false);
        try
            res = hy_run_pipeline(coverGray, Wprep, sel.type, opts);
        catch ME
            releaseUi(dlg, btnContinue);
            if strcmp(ME.identifier, 'hy_run_pipeline:cancelled')
                setStatus('The run was cancelled.', false);
            else
                uialert(fig, ME.message, 'Processing failed');
                setStatus(['Processing failed: ' ME.message], true);
            end
            return;
        end
        res.coverPath = coverPath;
        res.watermarkPath = wmPath;
        releaseUi(dlg, btnContinue);
        try
            hy_gui_results(res);
        catch ME
            uialert(fig, ME.message, 'Could not show the results');
            setStatus(['Could not show the results: ' ME.message], true);
            return;
        end
        setStatus(sprintf(['Done. The results are in the new window. To try another noise, ' ...
                           'press Continue again (noise: %s).'], sel.label), false);
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
% Called by hy_run_pipeline with status text; returns true if the user
% pressed Cancel in the progress dialog.
    cancelNow = false;
    if isvalid(dlg)
        dlg.Message = msg;
        drawnow;
        cancelNow = dlg.CancelRequested;
    end
end

function releaseUi(dlg, btn)
% Closes the progress dialog and re-enables the Continue button (safe to
% call more than once).
    if isvalid(dlg)
        close(dlg);
    end
    if isvalid(btn)
        btn.Enable = 'on';
    end
end
