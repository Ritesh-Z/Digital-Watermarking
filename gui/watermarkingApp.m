function watermarkingApp()
% WATERMARKINGAPP  Graphical interface for the hybrid DWT-DCT-SVD
% watermarking project (BFO and PBFO), after Yildiz, Ustunsoy, Sayan (2024).
%
% Start it with main.m. Everything happens in ONE window. The black rail on
% the left has six step buttons; a step can be opened as soon as it is
% unlocked, and the red "... >" button at the bottom of each page moves on:
%
%   1 UPLOAD   pick the cover image and the logo (watermark), then
%              "Embed the logo": BFO/PBFO search + embedding
%   2 EMBED    watermarked image + PSNR, and a step-by-step view of HOW the
%              logo was embedded (DWT -> DCT -> SVD -> alpha -> embed -> rebuild)
%   3 EXTRACT  given vs extracted logo + NC, and a step-by-step view of HOW
%              the extraction works
%   4 ATTACKS  choose a noise (Gaussian, shot, salt & pepper, speckle) and its
%              strength, OK: the noise is put on the WATERMARKED image and the
%              logo is extracted again
%   5 RESULTS  images + comparison tables of all five methods
%   6 WORKFLOW flowchart of the whole method (like Fig. 6 / 7 of the paper)
%              with the file behind every box, and all files in the order they run
%
% HOW THIS FILE IS ORGANISED
%   watermarkingApp      the window: left rail (step buttons), header art, page switching (goToPage)
%   buildUploadPage ...  one nested "build" function per page (layout + its buttons)
%   local functions      look and feel (colours), walkthrough viewer, the
%                        sub-step texts and drawings, small helpers
%
% The maths is NOT in this file - it calls the step folders
% (step1_input ... step7_metrics). Pages 2-4 show the main method,
% DWT-DCT-SVD-PBFO (the last of the five stages).
% Needs MATLAB R2018a or newer. No toolbox.

    addpath(genpath(projectRoot()));
    if verLessThan('matlab', '9.4')
        error('watermarkingApp:oldMatlab', 'This GUI needs MATLAB R2018a or newer (uifigure).');
    end

    % ================= APP STATE (shared by all pages) ====================
    emb   = [];         % result of embedAllStages (page 1 -> pages 2-5)
    trace = [];         % intermediate values of the PBFO embedding (page 2)
    curve = [];         % fitness curve F(alpha) (page 2)
    lastRes   = [];     % last attack test (page 4 -> page 5)
    attackCfg = defaultAttackSettings();
    S        = 5;       % index of the main method, DWT-DCT-SVD-PBFO
    unlocked = 1;       % highest step that may be opened
    current  = 1;
    NSTEPS   = 6;
    WORKFLOW = 6;       % this step can always be opened (no run needed)
    built    = false(1, NSTEPS);

    STEP_NAMES = {'UPLOAD', 'EMBED', 'EXTRACT', 'ATTACKS', 'RESULTS', 'WORKFLOW'};
    BIG_WORDS  = {'UPLOAD', 'EMBEDDING', 'EXTRACTION', 'ATTACKS', 'RESULTS', 'WORKFLOW'};
    SUBTITLES  = {'Choose the cover photo and the logo to hide', ...
                  'How the logo is hidden:  DWT  >  DCT  >  SVD  >  alpha by PBFO', ...
                  'How the logo is recovered from the watermarked image', ...
                  'Noise on the watermarked image - does the logo survive?', ...
                  'All five methods compared under every noise', ...
                  'The whole method on one page - and which file does what'};
    c = theme();

    % ================= WINDOW =============================================
    %   +------+------------------------------------------------------+
    %   |      |  HEADER ART  (title, shapes, giant red word)          |
    %   | RAIL +------------------------------------------------------+
    %   | (nav)|  PAGE 1..5  (only the current one is visible)         |
    %   +------+------------------------------------------------------+
    scr   = get(0, 'ScreenSize');
    figW  = 1200;  figH = 780;
    railW = 70;    headH = 124;
    pageW = figW - railW;
    pageH = figH - headH;
    fig = uifigure('Name', 'Watermark-inator - Hybrid DWT-DCT-SVD Watermarking (BFO / PBFO)', ...
                   'Position', [max(1, (scr(3) - figW) / 2), max(1, (scr(4) - figH) / 2), figW, figH], ...
                   'Resize', 'off');
    trySet(fig, 'Theme', 'light');            % stay light even if MATLAB is in dark mode
    fig.Color = c.bg;

    % ---- left rail: logo mark, step buttons, rotated name, badge
    rail = uipanel(fig, 'Position', [0 0 railW figH], 'BackgroundColor', c.rail, ...
                   'BorderType', 'none', 'Tag', 'themeHeader');
    uilabel(rail, 'Text', 'W.', 'Position', [0 715 railW 44], 'FontSize', 30, 'FontWeight', 'bold', ...
            'FontColor', [1 1 1], 'HorizontalAlignment', 'center');
    stepBtn = gobjects(1, NSTEPS);
    for k = 1:NSTEPS
        y = 640 - (k - 1) * 70;
        stepBtn(k) = uibutton(rail, 'push', 'Text', sprintf('%02d', k), 'Position', [10 y 50 50], ...
                              'FontSize', 16, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) goToPage(k));
        uilabel(rail, 'Text', STEP_NAMES{k}, 'Position', [0 y - 20 railW 16], 'FontSize', 9, ...
                'FontWeight', 'bold', 'FontColor', [0.62 0.62 0.64], 'HorizontalAlignment', 'center');
    end
    railArt(rail, railW);

    % ---- header art (redrawn for every page)
    head = uiaxes(fig, 'Position', [railW pageH pageW headH], 'Tag', 'themeHeader');
    prepareArtAxes(head, pageW, headH);

    % ---- pages
    page = gobjects(1, NSTEPS);
    for k = 1:NSTEPS
        page(k) = uipanel(fig, 'Position', [railW 0 pageW pageH], 'BorderType', 'none', ...
                          'BackgroundColor', c.bg, 'Visible', 'off', 'Tag', 'themePage');
    end

    buildUploadPage(page(1));
    built(1) = true;
    goToPage(1);

    % =====================================================================
    % NAVIGATION
    % =====================================================================
    function goToPage(k)
    % Shows page k (building it first when needed) and updates header + rail.
    % The WORKFLOW step (6) is always open; the others unlock one by one.
        if k > unlocked && k ~= WORKFLOW
            return;
        end
        try
            if k == 3 && ~built(3), buildExtractPage(page(3)); built(3) = true; end
            if k == 4 && ~built(4), buildAttackPage(page(4));   built(4) = true; end
            if k == 5,              buildResultsPage(page(5));  built(5) = true; end
            if k == 6 && ~built(6), buildWorkflowPage(page(6)); built(6) = true; end
        catch ME
            uialert(fig, ME.message, 'Could not open this step');
            return;
        end
        set(page, 'Visible', 'off');
        page(k).Visible = 'on';
        current = k;
        headerArt(head, pageW, headH, k, BIG_WORDS{k}, SUBTITLES{k});
        refreshStepButtons();
    end

    function refreshStepButtons()
    % Current step = red, unlocked steps = dark grey, locked steps = black.
        for i = 1:NSTEPS
            if i == current
                stepBtn(i).BackgroundColor = c.red;
                stepBtn(i).FontColor = [1 1 1];
            elseif i <= unlocked || i == WORKFLOW
                stepBtn(i).BackgroundColor = c.railOn;
                stepBtn(i).FontColor = [1 1 1];
            else
                stepBtn(i).BackgroundColor = c.railOff;
                stepBtn(i).FontColor = [0.42 0.42 0.44];
            end
            stepBtn(i).Enable = onOff(i <= unlocked || i == WORKFLOW);
            stepBtn(i).Tooltip = sprintf('Step %d: %s', i, lower(BIG_WORDS{i}));
        end
    end

    function startPage(pg)
    % Empties a page and paints its background art.
        delete(pg.Children);
        pageArt(pg);
    end

    function finishPage(pg)
        applyTheme(pg);
    end

    % =====================================================================
    % PAGE 1 - UPLOAD THE IMAGES
    % =====================================================================
    function buildUploadPage(pg)
        imgSize = 256;       % cover is resized to imgSize x imgSize (setting below)
        coverGray = [];  coverPath = '';
        coverRaw  = [];  coverInfo = [];
        wmRaw = [];      wmPath = '';
        Wprep = [];

        startPage(pg);

        % --- cover image
        pCover = card(pg, '1. Original (cover) image', [125 130 430 460]);
        uibutton(pCover, 'push', 'Text', 'Browse...', 'Position', [15 400 110 28], ...
                 'ButtonPushedFcn', @onBrowseCover);
        lblCover = uilabel(pCover, 'Text', 'No image selected', 'Position', [135 400 280 28]);
        axCover = uiaxes(pCover, 'Position', [30 90 370 300]);
        chkColour = uicheckbox(pCover, 'Text', 'Keep colour (hide the logo in the brightness Y of YCbCr)', ...
                               'Value', false, 'Position', [15 62 410 22], 'ValueChangedFcn', @(~, ~) prepareCover());
        chkColour.Tooltip = ['Off (default) = gray image, exactly as in the paper. On = the colour photo is ' ...
                             'split into Y, Cb, Cr; the logo goes into Y and the colour is put back afterwards.'];
        lblCoverInfo = uilabel(pCover, 'Text', '', 'Position', [15 6 400 54], ...
                               'WordWrap', 'on', 'VerticalAlignment', 'top');
        showImage(axCover, [], 'Cover image preview');

        % --- watermark image
        pWm = card(pg, '2. Watermark image (logo)', [575 130 430 460]);
        uibutton(pWm, 'push', 'Text', 'Browse...', 'Position', [15 400 110 28], ...
                 'ButtonPushedFcn', @onBrowseWatermark);
        lblWm = uilabel(pWm, 'Text', 'No image selected', 'Position', [135 400 280 28]);
        axWmIn  = uiaxes(pWm, 'Position', [15 205 195 185]);
        axWmOut = uiaxes(pWm, 'Position', [220 205 195 185]);
        showImage(axWmIn,  [], 'Selected watermark');
        showImage(axWmOut, [], 'Prepared watermark');
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

        % --- bottom bar
        % --- settings: image quality and cover size
        uilabel(pg, 'Text', 'Image quality (higher = better):', 'Position', [125 88 205 22], 'FontWeight', 'bold');
        ddQuality = uidropdown(pg, 'Items', {'No limit - paper exact (most robust)', '38 dB - very robust', ...
                                             '42 dB - recommended', '45 dB - very clean', '48 dB - cleanest (paper PBFO)'}, ...
                               'ItemsData', [0 38 42 45 48], 'Value', 42, 'Position', [330 86 190 26]);
        ddQuality.Tooltip = ['The alpha search picks the most robust alpha that keeps the watermarked image at ' ...
                             'least this good. Higher = better looking image, a little less robust.'];
        uilabel(pg, 'Text', 'Cover size:', 'Position', [535 88 75 22], 'FontWeight', 'bold');
        ddSize = uidropdown(pg, 'Items', {'256 x 256 (fast)', '512 x 512 (paper, slower)', '1024 x 1024 (1K, slow)'}, ...
                            'ItemsData', [256 512 1024], 'Value', 256, 'Position', [610 86 175 26], ...
                            'ValueChangedFcn', @onSizeChanged);
        ddSize.Tooltip = ['A bigger cover spreads the same logo over more pixels: about 6 dB better PSNR per ' ...
                          'doubling, but the alpha search gets much slower (1K: several minutes).'];

        lblStatus = uilabel(pg, 'Text', 'Upload the cover image and the watermark image.', ...
                            'Position', [125 18 640 44], 'WordWrap', 'on', 'FontWeight', 'bold');
        btnSubmit = uibutton(pg, 'push', 'Text', 'Embed the logo  >', 'FontWeight', 'bold', ...
                             'Position', [795 40 210 44], 'ButtonPushedFcn', @onSubmit);
        finishPage(pg);

        % ------------------------------------------------------ callbacks
        function onBrowseCover(~, ~)
            [f, p] = uigetfile(imageFilter(), 'Upload the original (cover) image', imagesDir());
            figure(fig);
            if isequal(f, 0)
                setStatus('Cover image selection was cancelled.', false);
                return;
            end
            fullPath = fullfile(p, f);
            try
                raw = loadImageFile(fullPath);
            catch ME
                uialert(fig, ME.message, 'Cannot use this cover image');
                setStatus(['Cover image not loaded: ' ME.message], true);
                return;
            end
            coverRaw  = raw;
            coverPath = fullPath;
            lblCover.Text = f;
            lblCover.Tooltip = fullPath;
            showImage(axCover, raw, 'Selected cover image');
            prepareCover();
        end

        function onSizeChanged(~, ~)
            imgSize = ddSize.Value;
            prepareCover();
        end

        function prepareCover()
        % Gray mode (paper) or colour mode, depending on the "Keep colour" box.
            if isempty(coverRaw)
                return;
            end
            try
                [gray, info] = prepareCoverImage(coverRaw, imgSize, chkColour.Value);
            catch ME
                uialert(fig, ME.message, 'Cannot use this cover image');
                setStatus(['Cover image not usable: ' ME.message], true);
                coverGray = [];
                return;
            end
            coverGray = gray;
            coverInfo = info;
            if info.colour
                lblCoverInfo.Text = sprintf(['RGB image, %d x %d pixels. COLOUR MODE: resized to %d x %d and ' ...
                                             'split into Y (gets the logo) and Cb, Cr (kept, put back afterwards).'], ...
                                            info.originalSize(1), info.originalSize(2), imgSize, imgSize);
            elseif info.wasRGB
                lblCoverInfo.Text = sprintf(['RGB image, %d x %d pixels. Converted to a %d x %d grayscale image ' ...
                                             '(as in the paper).'], info.originalSize(1), info.originalSize(2), imgSize, imgSize);
            else
                lblCoverInfo.Text = sprintf(['Grayscale image, %d x %d pixels, resized to %d x %d. ' ...
                                             '(Keep colour has no effect on a gray photo.)'], ...
                                            info.originalSize(1), info.originalSize(2), imgSize, imgSize);
            end
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
                raw = loadImageFile(fullPath);
            catch ME
                uialert(fig, ME.message, 'Cannot use this watermark image');
                setStatus(['Watermark image not loaded: ' ME.message], true);
                return;
            end
            wmRaw = raw;
            wmPath = fullPath;
            lblWm.Text = f;
            lblWm.Tooltip = fullPath;
            % Pre-set "Invert" so that the logo (the minority colour) becomes
            % the embedded part (value 1). The user can still change it.
            try
                Wtest = prepareWatermarkLogo(wmRaw, edtMax.Value, chkBin.Value, false);
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
            showImage(axWmIn, wmRaw, 'Selected watermark');
            try
                [Wp, info] = prepareWatermarkLogo(wmRaw, edtMax.Value, chkBin.Value, chkInv.Value);
            catch ME
                showImage(axWmOut, [], 'Prepared watermark');
                lblWmInfo.FontColor = c.error;
                lblWmInfo.Text = ME.message;
                setStatus(['Watermark not usable: ' ME.message], true);
                return;
            end
            Wprep = Wp;
            showImage(axWmOut, Wp, sprintf('Prepared watermark (%d x %d)', info.size(1), info.size(2)));
            lblWmInfo.FontColor = c.text;
            if info.binary, mode = 'black/white'; else, mode = 'gray levels'; end
            lblWmInfo.Text = sprintf(['Original %d x %d pixels, prepared as %d x %d (%s). White pixels ' ...
                                      '(value 1) are the part that is embedded: %.0f%% of the pixels.'], ...
                                     info.originalSize(1), info.originalSize(2), info.size(1), info.size(2), ...
                                     mode, 100 * mean(Wp(:)));
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
            if imgSize >= 1024
                answer = uiconfirm(fig, ['A 1024 x 1024 (1K) cover gives the best picture quality, but the alpha ' ...
                                         'search does over a thousand tests on 512 x 512 matrices. This can take ' ...
                                         'several minutes (longer in MATLAB Online). Continue?'], ...
                                   '1K cover - this will take a while', 'Options', {'Continue', 'Cancel'}, ...
                                   'DefaultOption', 'Continue', 'CancelOption', 'Cancel', 'Icon', 'warning');
                if ~strcmp(answer, 'Continue')
                    return;
                end
            end
            btnSubmit.Enable = 'off';
            dlg = uiprogressdlg(fig, 'Title', 'Embedding the watermark', ...
                                'Message', 'Starting...', 'Indeterminate', 'on', 'Cancelable', 'on');
            setStatus('Working... the BFO/PBFO search can take a minute or two.', false);
            try
                opts = struct('statusFcn', @(msg) updateProgress(dlg, msg), 'minPSNR', ddQuality.Value);
                e = embedAllStages(coverGray, Wprep, opts);
                if coverInfo.colour                % colour mode: put Cb, Cr back
                    e = addColourToStages(e, coverInfo.coverRGB, coverInfo.Cb, coverInfo.Cr);
                end
                dlg.Message = 'Preparing the step-by-step view of the embedding...';
                drawnow;
                [~, ~, tr] = embedStage3_DWT_DCT_SVD(coverGray, Wprep, e.alphaPBFO);
                cv = fitnessCurve(e);
            catch ME
                closeDialog(dlg);
                btnSubmit.Enable = 'on';
                if strcmp(ME.identifier, 'embedAllStages:cancelled')
                    setStatus('The run was cancelled.', false);
                else
                    uialert(fig, ME.message, 'Processing failed');
                    setStatus(['Processing failed: ' ME.message], true);
                end
                return;
            end
            closeDialog(dlg);
            btnSubmit.Enable = 'on';
            e.coverPath = coverPath;
            e.watermarkPath = wmPath;

            % New embedding: everything after step 2 must be redone
            emb = e;  trace = tr;  curve = cv;  lastRes = [];
            built(2:NSTEPS) = false;      % (the workflow is rebuilt with the real alpha)
            for i = 3:NSTEPS
                delete(page(i).Children);
            end
            buildEmbedPage(page(2));
            built(2) = true;
            unlocked = 2;
            setStatus('Done. You can come back here to try other images.', false);
            goToPage(2);
        end

        function setStatus(msg, isError)
            lblStatus.Text = msg;
            if isError, lblStatus.FontColor = c.error; else, lblStatus.FontColor = c.text; end
        end
    end

    % =====================================================================
    % PAGE 2 - THE WATERMARKED IMAGE + HOW IT WAS EMBEDDED
    % =====================================================================
    function buildEmbedPage(pg)
        startPage(pg);

        % --- left: watermarked image + PSNR
        pL = card(pg, 'Watermarked image', [20 80 360 560]);
        axWm = uiaxes(pL, 'Position', [10 140 340 340]);
        showImage(axWm, wmDisplay(emb, S), '');
        uilabel(pL, 'Position', [10 95 340 34], 'FontSize', 16, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'Text', psnrText(emb, S));
        uilabel(pL, 'Position', [10 10 340 80], 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'center', 'Text', ...
                sprintf(['alpha = %.2f (found by PBFO). PSNR above about 40 dB means the logo is ' ...
                         'invisible to the eye.'], emb.alphaPBFO));

        % --- right: step-by-step embedding
        pR = card(pg, 'How the logo was embedded - press Next', [395 80 715 560]);
        wt = createWalkthrough(pR);
        walkthroughSet(wt, embeddingSteps(emb, trace, curve));

        % --- bottom bar
        uibutton(pg, 'push', 'Text', 'Save watermarked image', 'Position', [20 22 200 40], ...
                 'ButtonPushedFcn', @(~, ~) saveImageFile(fig, wmDisplay(emb, S), ...
                                      [baseName(emb) '_watermarked.png'], inputPaths(emb)));
        uilabel(pg, 'Text', 'Save as PNG, BMP or TIFF. JPEG compression would damage the watermark.', ...
                'Position', [235 20 420 42], 'WordWrap', 'on');
        uibutton(pg, 'push', 'Text', 'Extract the watermark  >', 'FontWeight', 'bold', ...
                 'Position', [870 22 240 40], 'ButtonPushedFcn', @onNext);
        finishPage(pg);

        function onNext(~, ~)
            unlocked = max(unlocked, 3);
            goToPage(3);
        end
    end

    % =====================================================================
    % PAGE 3 - EXTRACTED WATERMARK + HOW THE EXTRACTION WORKS
    % =====================================================================
    function buildExtractPage(pg)
    % The logo is extracted from the CLEAN watermarked image (no attack yet).
        Yrx = receivedImage(emb, S);      % gray image, or Y of the colour image
        [We, exTrace] = extractWatermark(Yrx, emb.keys{S}, size(emb.W));
        score = calculateMetrics([], [], emb.W, We);
        nc = clamp01(score.ncc);

        startPage(pg);

        % --- left: given vs extracted + NC
        pL = card(pg, 'Given and extracted watermark', [20 80 360 560]);
        axGiven = uiaxes(pL, 'Position', [10 345 340 180]);
        showImage(axGiven, emb.W, sprintf('Given watermark (%d x %d)', size(emb.W, 1), size(emb.W, 2)));
        axExt = uiaxes(pL, 'Position', [10 155 340 180]);
        showImage(axExt, logoForDisplay(We, emb.isBinary), 'Extracted watermark');
        uilabel(pL, 'Text', sprintf('NC = %.4f', nc), 'Position', [10 95 340 50], ...
                'FontSize', 28, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', c.accent);
        uilabel(pL, 'Position', [10 10 340 80], 'WordWrap', 'on', 'VerticalAlignment', 'top', ...
                'HorizontalAlignment', 'center', 'Text', ...
                ['Normalised cross-correlation between the given and the extracted watermark ' ...
                 '(1 = identical, 0 = no similarity). BER = ' fmtNum(100 * score.ber, '%.2f %%') '.']);

        % --- right: step-by-step extraction
        pR = card(pg, 'How the logo is extracted - press Next', [395 80 715 560]);
        wt = createWalkthrough(pR);
        walkthroughSet(wt, extractionSteps(emb, trace, We, exTrace, score));

        % --- bottom bar
        uilabel(pg, 'Text', 'Next: test whether the logo survives noise attacks on the watermarked image.', ...
                'Position', [20 20 640 42], 'WordWrap', 'on');
        uibutton(pg, 'push', 'Text', 'Attack tests  >', 'FontWeight', 'bold', ...
                 'Position', [870 22 240 40], 'ButtonPushedFcn', @onNext);
        finishPage(pg);

        function onNext(~, ~)
            unlocked = max(unlocked, 4);
            goToPage(4);         % attack tests
        end
    end

    % =====================================================================
    % PAGE 6 - WORKFLOW: THE WHOLE METHOD ON ONE PAGE + WHICH FILE DOES WHAT
    % =====================================================================
    function buildWorkflowPage(pg)
    % Left: flowchart of embedding and extraction (like Fig. 6 and 7 of the
    % paper). Every box has a plain-English headline and the formula below.
    % Right: STEP DETAILS - click a box for a full explanation and the file
    % that does it; the list shows all files in the order they run.
        files = codePath();
        startPage(pg);

        pF = card(pg, 'Flowchart - click any box', [20 80 700 560]);
        axF = uiaxes(pF, 'Position', [8 6 684 524]);
        boxes = drawWorkflow(axF, emb, @onBoxClicked);

        pC = card(pg, 'Step details', [735 80 375 560]);
        lblHead = uilabel(pC, 'Text', '', 'Position', [16 490 345 30], 'FontSize', 12, ...
                          'FontWeight', 'bold', 'FontColor', c.red);
        lblTitle = uilabel(pC, 'Text', '', 'Position', [16 440 345 50], 'FontSize', 15, ...
                           'FontWeight', 'bold', 'WordWrap', 'on', 'VerticalAlignment', 'top');
        lblBody = uilabel(pC, 'Text', '', 'Position', [16 285 345 155], 'FontSize', 13, ...
                          'WordWrap', 'on', 'VerticalAlignment', 'top');
        lblFile = uilabel(pC, 'Text', '', 'Position', [16 200 345 85], 'FontSize', 12, ...
                          'WordWrap', 'on', 'VerticalAlignment', 'top', 'FontColor', [0.30 0.30 0.32]);
        uilabel(pC, 'Text', 'ALL FILES, IN THE ORDER THEY RUN', 'Position', [16 176 345 20], ...
                'FontSize', 11, 'FontWeight', 'bold');
        items = cell(1, numel(files));
        for i = 1:numel(files)
            items{i} = sprintf('%02d   %s', i, shortFileName(files(i).name));
        end
        lst = uilistbox(pC, 'Items', items, 'ItemsData', 1:numel(files), 'Position', [16 10 345 164], ...
                        'FontSize', 12, 'ValueChangedFcn', @onListChanged);
        trySet(lst, 'BackgroundColor', [1 1 1]);
        trySet(lst, 'FontColor', c.text);

        hint = ['Read it top to bottom: the left lane HIDES the logo, the right lane GETS IT BACK. ' ...
                'The dashed red KEY arrow is the secret information extraction needs.'];
        if isempty(emb)
            hint = [hint '  (General view - after you embed an image, this page shows your own alpha.)'];
        end
        uilabel(pg, 'Text', hint, ...
                'Position', [20 18 830 46], 'WordWrap', 'on', 'FontWeight', 'bold');
        uibutton(pg, 'push', 'Text', 'Try other images', ...
                 'Position', [870 22 240 40], 'ButtonPushedFcn', @(~, ~) goToPage(1));
        finishPage(pg);
        onBoxClicked(1);                     % start with the first box

        function onBoxClicked(b)
        % A flowchart box was clicked: full explanation + its file.
            bx = boxes(b);
            lblHead.Text  = sprintf('%s  -  STEP %d', bx.lane, bx.num);
            lblTitle.Text = bx.headline;
            lblBody.Text  = bx.explain;
            f = files(bx.fileIdx);
            lblFile.Text  = sprintf('FILE:  %s\n%s', f.name, f.desc);
            lst.Value = bx.fileIdx;
            highlight(@(o) o == b);
        end

        function onListChanged(src, ~)
        % A file was picked in the list: what it does + where it is used.
            idx = src.Value;
            f = files(idx);
            used = {};
            for b = 1:numel(boxes)
                if boxes(b).fileIdx == idx
                    used{end + 1} = sprintf('%s %d', lower(boxes(b).lane), boxes(b).num); %#ok<AGROW>
                end
            end
            lblHead.Text  = sprintf('FILE %02d', idx);
            lblTitle.Text = shortFileName(f.name);
            lblBody.Text  = f.desc;
            if isempty(used)
                lblFile.Text = sprintf('FILE:  %s\nRuns behind the scenes (no box of its own).', f.name);
            else
                lblFile.Text = sprintf('FILE:  %s\nUsed in: %s', f.name, strjoin(used, ', '));
            end
            highlight(@(o) boxes(o).fileIdx == idx);
        end

        function highlight(isOn)
            for b = 1:numel(boxes)
                if isOn(b)
                    set(boxes(b).patch, 'EdgeColor', c.red, 'LineWidth', 3);
                else
                    set(boxes(b).patch, 'EdgeColor', [0.15 0.15 0.16], 'LineWidth', 1);
                end
            end
        end
    end

    % =====================================================================
    % PAGE 4 - ATTACK TESTS
    % =====================================================================
    function buildAttackPage(pg)
    % Choose a noise and its strength, press OK. The noise is applied to the
    % WATERMARKED image, the logo is extracted from the noised image and
    % compared with the given logo. Try as many attacks as you like.
        types = {'gaussian', 'shot', 'saltpepper', 'speckle'};
        items = {'Gaussian Noise', 'Shot (Poisson) Noise', 'Salt-and-Pepper Noise', 'Speckle Noise'};
        res = [];

        startPage(pg);
        dx = 15;

        % --- three panels: watermarked | noised | extracted
        pA = card(pg, 'Watermarked image', [20 + dx 200 340 420]);
        axA = uiaxes(pA, 'Position', [10 55 320 330]);
        showImage(axA, wmDisplay(emb, S), '');
        uilabel(pA, 'Position', [10 12 320 34], 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
                'Text', psnrText(emb, S));

        pB = card(pg, 'Noised watermarked image', [380 + dx 200 340 420]);
        axB = uiaxes(pB, 'Position', [10 55 320 330]);
        showImage(axB, [], '');
        lblB = uilabel(pB, 'Position', [10 5 320 48], 'WordWrap', 'on', 'HorizontalAlignment', 'center', ...
                       'Text', 'Choose a noise below and press OK.');

        pC = card(pg, 'Extracted watermark (from the noised image)', [740 + dx 200 340 420]);
        axGiven = uiaxes(pC, 'Position', [10 245 155 140]);
        showImage(axGiven, emb.W, 'Given');
        axExt = uiaxes(pC, 'Position', [175 245 155 140]);
        showImage(axExt, [], 'Extracted');
        lblNC = uilabel(pC, 'Text', 'NC = -', 'Position', [10 185 320 50], 'FontSize', 28, ...
                        'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'FontColor', c.accent);
        lblBER = uilabel(pC, 'Text', '', 'Position', [10 155 320 26], 'FontSize', 14, 'HorizontalAlignment', 'center');
        lblVerdict = uilabel(pC, 'Text', '', 'Position', [10 10 320 135], 'WordWrap', 'on', ...
                             'VerticalAlignment', 'top', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

        % --- attack controls
        uilabel(pg, 'Text', 'Noise:', 'FontWeight', 'bold', 'Position', [20 + dx 157 50 22]);
        dd = uidropdown(pg, 'Items', items, 'Value', items{3}, 'Position', [75 + dx 155 230 26], ...
                        'ValueChangedFcn', @(~, ~) onNoiseChanged());
        lblStrength = uilabel(pg, 'Text', 'Density:', 'FontWeight', 'bold', 'HorizontalAlignment', 'right', ...
                              'Position', [315 + dx 157 90 22]);
        edtStrength = uieditfield(pg, 'numeric', 'Limits', [0 1], 'Value', 0.05, 'Position', [410 + dx 155 80 26]);
        uibutton(pg, 'push', 'Text', 'OK', 'FontWeight', 'bold', 'Position', [500 + dx 152 80 32], ...
                 'ButtonPushedFcn', @onOK);
        lblInfo = uilabel(pg, 'Text', '', 'Position', [20 + dx 85 1060 60], 'WordWrap', 'on', ...
                          'VerticalAlignment', 'top', 'FontAngle', 'italic');

        % --- bottom bar
        uibutton(pg, 'push', 'Text', 'Save noised image', 'Position', [20 + dx 22 170 40], 'ButtonPushedFcn', @onSaveNoisy);
        uilabel(pg, 'Text', 'Save as PNG, BMP or TIFF. JPEG compression would damage the watermark.', ...
                'Position', [200 + dx 20 420 42], 'WordWrap', 'on');
        btnResults = uibutton(pg, 'push', 'Text', 'Show results / comparison  >', 'FontWeight', 'bold', ...
                              'Position', [820 22 290 40], 'Enable', 'off', 'ButtonPushedFcn', @onNext);
        finishPage(pg);
        onNoiseChanged();

        % ------------------------------------------------------ callbacks
        function onNoiseChanged()
            type = types{strcmp(items, dd.Value)};
            [fieldName, label, text] = attackInfo(type);
            lblInfo.Text = text;
            if isempty(fieldName)
                lblStrength.Text = 'Strength:';
                edtStrength.Enable = 'off';
            else
                lblStrength.Text = [label ':'];
                edtStrength.Enable = 'on';
                edtStrength.Value = attackCfg.(fieldName);
            end
        end

        function onOK(~, ~)
            type = types{strcmp(items, dd.Value)};
            fieldName = attackInfo(type);
            if ~isempty(fieldName)
                attackCfg.(fieldName) = edtStrength.Value;
            end
            try
                r = attackAndExtract(emb, type, attackCfg);
            catch ME
                uialert(fig, ME.message, 'Could not apply the noise');
                return;
            end
            res = r;
            lastRes = r;
            ncv = clamp01(r.ncc(S));
            showImage(axB, r.attackedImgs{S}, '');
            lblB.Text = sprintf('%s (%s). PSNR against the watermarked image: %s dB.', ...
                                r.attackLabel, r.attackParamText, fmtNum(r.attackPsnr(S), '%.2f'));
            showImage(axExt, logoForDisplay(r.extImgs{S}, r.isBinary), 'Extracted');
            lblNC.Text  = sprintf('NC = %.4f', ncv);
            lblBER.Text = ['BER = ' fmtNum(100 * r.ber(S), '%.2f %%')];
            lblVerdict.Text = verdict(ncv);
            btnResults.Enable = 'on';
            unlocked = max(unlocked, 5);
            refreshStepButtons();
        end

        function onNext(~, ~)
            goToPage(5);
        end

        function onSaveNoisy(~, ~)
            if isempty(res)
                uialert(fig, 'Choose a noise and press OK first.', 'Nothing to save');
                return;
            end
            saveImageFile(fig, res.attackedImgs{S}, [baseName(emb) '_noised_' res.attackType '.png'], inputPaths(emb));
        end
    end

    % =====================================================================
    % PAGE 5 - RESULTS / COMPARISON
    % =====================================================================
    function buildResultsPage(pg)
    % Top row: original, watermarked, noised image, given and extracted logo
    % (last attack of page 4). Below: comparison tables of all five methods,
    % for no attack and for each of the four attacks (strengths of page 4).
        res = lastRes;
        nS = numel(res.stageNames);

        startPage(pg);
        trySet(pg, 'Scrollable', 'on');
        dx = 85;                  % centre the 960-pixel wide content
        top = 840;                % content is taller than the page: it scrolls

        % --- images of the main method (last attack)
        ncv = clamp01(res.ncc(S));
        imgs = {coverDisplay(res), wmDisplay(res, S), res.attackedImgs{S}, res.W, logoForDisplay(res.extImgs{S}, res.isBinary)};
        ttls = {'Original image', 'Watermarked image', 'Watermarked + noise', 'Original watermark', 'Extracted watermark'};
        caps = {sprintf('%d x %d', size(res.cover, 1), size(res.cover, 2)), ...
                psnrText(res, S), ...
                sprintf('%s (%s)\nPSNR = %s dB', res.attackLabel, res.attackParamText, fmtNum(res.attackPsnr(S), '%.2f')), ...
                sprintf('%d x %d', size(res.W, 1), size(res.W, 2)), ...
                sprintf('NC = %.4f', ncv)};
        for k = 1:5
            x = dx + 20 + (k - 1) * 184;
            ax = uiaxes(pg, 'Position', [x top - 190 176 176]);
            showImage(ax, imgs{k}, ttls{k});
            uilabel(pg, 'Text', caps{k}, 'Position', [x top - 242 176 50], 'WordWrap', 'on', ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
                    'FontWeight', 'bold', 'FontSize', 12);
        end

        % --- Table 1: embedding quality
        t1 = cell(nS, 5);
        for s = 1:nS
            t1(s, :) = {res.stageNames{s}, fmtNum(res.alphas(s), '%.2f'), fmtNum(res.psnr(s), '%.2f'), ...
                        fmtNum(res.ssim(s), '%.4f'), fmtNum(res.IF(s), '%.3e')};
        end
        t1Cols   = {'Stage', 'Alpha', 'PSNR (dB)', 'SSIM', 'Image Fidelity'};
        t1Widths = {220, 120, 180, 180, 190};
        if res.isColour                            % colour mode: also the PSNR of the colour images
            t1(:, 6) = arrayfun(@(v) fmtNum(v, '%.2f'), res.psnrColour', 'UniformOutput', false);
            t1Cols   = {'Stage', 'Alpha', 'PSNR on Y (dB)', 'SSIM (Y)', 'Image Fidelity (Y)', 'PSNR colour (dB)'};
            t1Widths = {200, 90, 150, 140, 170, 160};
        end
        uilabel(pg, 'Text', 'Table 1. Embedding quality (original cover vs clean watermarked image)', ...
                'Position', [dx + 20 top - 274 900 22], 'FontWeight', 'bold');
        uitable(pg, 'Data', t1, 'RowName', {}, 'ColumnName', t1Cols, ...
                'ColumnWidth', t1Widths, 'Position', [dx + 20 top - 404 920 125]);

        % --- Tables 2 and 3: NC and BER under every attack
        types = {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'};
        cols  = {'Stage', 'No noise'};
        t2 = cell(nS, numel(types) + 1);
        t3 = t2;
        t2(:, 1) = res.stageNames';
        t3(:, 1) = res.stageNames';
        for a = 1:numel(types)
            r = attackAndExtract(res, types{a}, attackCfg);
            if a > 1
                cols{end + 1} = sprintf('%s (%s)', shortName(r.attackLabel), r.attackParamText); %#ok<AGROW>
            end
            for s = 1:nS
                t2{s, a + 1} = sprintf('%.4f', clamp01(r.ncc(s)));
                t3{s, a + 1} = fmtNum(100 * r.ber(s), '%.2f %%');
            end
        end
        uilabel(pg, 'Text', 'Table 2. Watermark recovery: NC under each noise (1 = perfect)', ...
                'Position', [dx + 20 top - 436 900 22], 'FontWeight', 'bold');
        uitable(pg, 'Data', t2, 'RowName', {}, 'ColumnName', cols, ...
                'ColumnWidth', {180, 100, 160, 160, 160, 150}, 'Position', [dx + 20 top - 566 920 125]);
        uilabel(pg, 'Text', 'Table 3. Watermark recovery: bit error rate under each noise (0 % = perfect)', ...
                'Position', [dx + 20 top - 598 900 22], 'FontWeight', 'bold');
        uitable(pg, 'Data', t3, 'RowName', {}, 'ColumnName', cols, ...
                'ColumnWidth', {180, 100, 160, 160, 160, 150}, 'Position', [dx + 20 top - 728 920 125]);

        uilabel(pg, 'Position', [dx + 20 top - 800 920 66], 'WordWrap', 'on', 'VerticalAlignment', 'top', 'Text', ...
            ['The last row, DWT-DCT-SVD-PBFO, is the main result. PSNR / SSIM / IF compare the original cover with the ' ...
             'clean watermarked image (IF = 1 - sum(I.*I'')/sum(I.^2), close to 0 = very similar). NC closer to 1 and ' ...
             'lower BER are better; BER only exists for a black/white watermark. "n/a" = not defined.']);
        uibutton(pg, 'push', 'Text', 'See the whole workflow  >', 'FontWeight', 'bold', ...
                 'Position', [dx + 700 top - 838 240 34], 'ButtonPushedFcn', @onWorkflow);
        finishPage(pg);
        try
            scroll(pg, 'top');
        catch
        end

        function onWorkflow(~, ~)
            unlocked = max(unlocked, 6);
            goToPage(6);
        end
    end
end


% =========================================================================
% LOOK AND FEEL - flat "poster" style: charcoal and grey planes, slanted
% shapes, signal red, huge cropped type, hard shadows and a little grain.
% Everything decorative is drawn with patch/text on axes that sit BEHIND
% the controls, so the controls themselves stay normal MATLAB components.
% =========================================================================
function c = theme()
% All colours of the GUI in one place.
    c.bg       = [0.79 0.79 0.79];   % page background: light grey
    c.plane    = [0.70 0.70 0.71];   % darker slanted plane on the page
    c.plane2   = [0.85 0.85 0.85];   % lighter plane on the page
    c.charcoal = [0.19 0.19 0.20];   % header background
    c.mid      = [0.42 0.42 0.43];   % header grey planes
    c.light    = [0.60 0.60 0.61];   % header light shapes
    c.red      = [0.74 0.07 0.09];   % signal red: current step, main buttons, big type
    c.lime     = [0.80 0.96 0.18];   % badge
    c.rail     = [0.06 0.06 0.07];   % left navigation rail
    c.railOn   = [0.27 0.27 0.29];   % unlocked step button
    c.railOff  = [0.12 0.12 0.13];   % locked step button
    c.card     = [0.975 0.973 0.965];% cards: warm off-white
    c.shadow   = [0.16 0.16 0.17];   % hard card shadow
    c.primary  = c.red;              % main (bold) buttons
    c.button   = [0.13 0.13 0.14];   % other buttons: black
    c.accent   = c.red;              % highlights: NC values, walkthrough titles
    c.text     = [0.08 0.08 0.09];   % normal text
    c.muted    = [0.38 0.38 0.40];   % axis lines
    c.title    = [0.08 0.08 0.09];   % card titles
    c.error    = [0.80 0.10 0.10];
end

function p = card(parent, titleText, pos)
% A content card: hard offset shadow behind, off-white body, uppercase
% title, red bar on the left edge. Returns the card panel (use it like a
% normal uipanel).
    c = theme();
    uipanel(parent, 'Position', pos + [7 -7 0 0], 'BackgroundColor', c.shadow, ...
            'BorderType', 'none', 'Tag', 'themeAccent');
    p = uipanel(parent, 'Title', upper(titleText), 'Position', pos, 'BackgroundColor', c.card, ...
                'ForegroundColor', c.title, 'FontWeight', 'bold', 'FontSize', 12, ...
                'BorderType', 'none', 'Tag', 'themeCard');
    uipanel(p, 'Position', [0 0 6 pos(4)], 'BackgroundColor', c.red, 'BorderType', 'none', ...
            'Tag', 'themeAccent');
end

function prepareArtAxes(ax, W, H)
% Turns a uiaxes into a plain drawing surface in pixel units.
    trySet(ax.Toolbar, 'Visible', 'off');
    try disableDefaultInteractivity(ax); catch, end
    ax.XLim = [0 W];
    ax.YLim = [0 H];
    ax.Visible = 'off';
    ax.PickableParts = 'none';
    ax.HitTest = 'off';
    trySet(ax, 'Clipping', 'on');
end

function shape(ax, xy, colour)
% One flat polygon (xy = n x 2 corner points).
    patch(ax, xy(:, 1), xy(:, 2), colour, 'EdgeColor', 'none', 'PickableParts', 'none', 'HitTest', 'off');
end

function grain(ax, W, H, strength)
% Light film grain over the whole surface so the flat colours feel printed.
    n = rand(ceil(H / 3), ceil(W / 3));
    im = image(ax, [0 W], [H 0], repmat(n, [1 1 3]), 'PickableParts', 'none', 'HitTest', 'off');
    trySet(im, 'AlphaData', strength);
end

function headerArt(ax, W, H, step, bigWord, subtitle)
% Charcoal header: slanted grey planes, a row of red/grey parallelograms,
% the page name in huge red letters cropped by the bottom edge, and the
% step / subtitle text on the left.
    c = theme();
    cla(ax);
    hold(ax, 'on');
    shape(ax, [0 0; W 0; W H; 0 H], c.charcoal);
    shape(ax, [0 0; 0 70; 640 0], c.mid);                       % slanted plane, bottom left
    shape(ax, [0 0; 0 28; 900 0], c.light);
    for i = 0:5                                                 % parallelogram "flags"
        x = 470 + i * 105;
        y = 78 - 4 * i;
        if mod(i, 2) == 0, col = c.red; else, col = c.light; end
        shape(ax, [x y; x + 58 y + 4; x + 92 y + 40; x + 34 y + 36], col);
    end
    text(ax, W + 6, -30, bigWord, 'Color', c.red, 'FontSize', 92, 'FontWeight', 'bold', ...
         'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'Clipping', 'on', ...
         'FontName', 'Arial', 'PickableParts', 'none');
    text(ax, 26, 92, sprintf('STEP %02d / 06     WATERMARK-INATOR     (click any picture to enlarge)', step), 'Color', [0.66 0.66 0.68], ...
         'FontSize', 11, 'FontWeight', 'bold', 'FontName', 'Arial', 'PickableParts', 'none');
    text(ax, 26, 60, upper(subtitle), 'Color', [1 1 1], 'FontSize', 14, 'FontWeight', 'bold', ...
         'FontName', 'Arial', 'PickableParts', 'none');
    grain(ax, W, H, 0.05);
    hold(ax, 'off');
    ax.XLim = [0 W];
    ax.YLim = [0 H];
end

function pageArt(parent)
% Page background: light grey with two slanted planes, a few red
% parallelograms peeking out at the edges, and grain. Drawn FIRST, so every
% card and control sits on top of it.
    c = theme();
    pos = parent.Position;
    W = pos(3);  H = pos(4);
    ax = uiaxes(parent, 'Position', [0 0 W H], 'Tag', 'themeGrid');
    prepareArtAxes(ax, W, H);
    hold(ax, 'on');
    shape(ax, [0 0; W 0; W H; 0 H], c.bg);
    shape(ax, [0 H; 0 H - 210; W H - 60; W H], c.plane);        % slanted band at the top
    shape(ax, [0 0; 0 150; W 40; W 0], c.plane2);               % lighter wedge at the bottom
    shape(ax, [W - 150 0; W - 40 0; W 70; W 150], c.red);       % red corner shapes
    shape(ax, [W - 260 H; W - 180 H; W - 120 H - 70; W - 200 H - 70], c.red);
    shape(ax, [-20 300; 40 330; 40 380; -20 350], c.red);
    grain(ax, W, H, 0.06);
    hold(ax, 'off');
    ax.XLim = [0 W];
    ax.YLim = [0 H];
end

function railArt(rail, railW)
% Bottom of the left rail: the project name written upwards and a lime
% round badge.
    c = theme();
    ax = uiaxes(rail, 'Position', [0 0 railW 230], 'Tag', 'themeGrid');
    prepareArtAxes(ax, railW, 230);
    hold(ax, 'on');
    text(ax, railW / 2, 150, 'WATERMARK-INATOR', 'Rotation', 90, 'Color', [1 1 1], 'FontSize', 11, ...
         'FontWeight', 'bold', 'FontName', 'Arial', 'HorizontalAlignment', 'center', 'PickableParts', 'none');
    t = linspace(0, 2 * pi, 60);
    shape(ax, [railW / 2 + 26 * cos(t'), 44 + 26 * sin(t')], c.lime);
    text(ax, railW / 2, 50, 'PBFO', 'Color', c.rail, 'FontSize', 11, 'FontWeight', 'bold', ...
         'FontName', 'Arial', 'HorizontalAlignment', 'center', 'PickableParts', 'none');
    text(ax, railW / 2, 36, 'DWT DCT SVD', 'Color', c.rail, 'FontSize', 6, 'FontWeight', 'bold', ...
         'FontName', 'Arial', 'HorizontalAlignment', 'center', 'PickableParts', 'none');
    hold(ax, 'off');
    ax.XLim = [0 railW];
    ax.YLim = [0 230];
end

function applyTheme(parent)
% Gives every control inside "parent" the common look: dark readable text,
% red main buttons (the bold ones), black secondary buttons, clean tables.
% Coloured text (errors, highlights) is kept. Each property is set inside
% try, so an older MATLAB version that lacks a property keeps its default.
    c = theme();
    objs = findall(parent);
    for i = 1:numel(objs)
        o = objs(i);
        tag = get(o, 'Tag');
        if any(strcmp(tag, {'themeHeader', 'themePage', 'themeGrid', 'themeAccent', 'themeCard'}))
            continue;
        end
        switch class(o)
            case 'matlab.ui.container.Panel'           % plain panels, e.g. walkthrough pictures
                trySet(o, 'BackgroundColor', [1 1 1]);
                trySet(o, 'BorderType', 'line');
                trySet(o, 'HighlightColor', [0.82 0.82 0.82]);
            case 'matlab.ui.control.Button'
                trySet(o, 'FontSize', 13);
                trySet(o, 'FontWeight', 'bold');
                if strcmp(get(o, 'UserData'), 'secondary') || ~isPrimary(o)
                    trySet(o, 'BackgroundColor', c.button);
                else
                    trySet(o, 'BackgroundColor', c.primary);
                end
                trySet(o, 'FontColor', [1 1 1]);
            case {'matlab.ui.control.Label', 'matlab.ui.control.CheckBox'}
                col = o.FontColor;
                if max(col) - min(col) < 0.05          % gray/black/white -> readable dark text
                    trySet(o, 'FontColor', c.text);
                end
            case {'matlab.ui.control.DropDown', 'matlab.ui.control.NumericEditField'}
                trySet(o, 'BackgroundColor', [1 1 1]);
                trySet(o, 'FontColor', c.text);
            case 'matlab.ui.control.Table'
                trySet(o, 'BackgroundColor', [1 1 1; 0.94 0.94 0.94]);   % striped rows
                trySet(o, 'ForegroundColor', c.text);
            case 'matlab.ui.control.UIAxes'
                trySet(o, 'BackgroundColor', bgOf(o.Parent, c));
                trySet(o.Title, 'Color', c.text);
                trySet(o, 'XColor', c.muted);
                trySet(o, 'YColor', c.muted);
        end
    end
end

function tf = isPrimary(btn)
% The main action of a page is marked by its bold text and ">" at the end
% (e.g. "Embed the logo  >") or is the OK button of the attack page.
    txt = strtrim(btn.Text);
    tf = endsWith(txt, '>') || strcmp(txt, 'OK');
end

function col = bgOf(p, c)
    switch get(p, 'Tag')
        case 'themePage', col = c.bg;
        case 'themeCard', col = c.card;
        otherwise,        col = [1 1 1];
    end
end

% ---------------------------------------------------------------------
function trySet(o, prop, value)
    try
        set(o, prop, value);
    catch
        % property not available in this MATLAB version - keep the default
    end
end

% ---------------------------------------------------------------------
% What to SHOW for a result: colour images in colour mode, gray otherwise.
% ---------------------------------------------------------------------
function img = wmDisplay(emb, s)
    if emb.isColour
        img = emb.wmRGB{s};
    else
        img = emb.wmImgs{s};
    end
end

function img = coverDisplay(emb)
    if emb.isColour
        img = emb.coverRGB;
    else
        img = emb.cover;
    end
end

function t = psnrText(emb, s)
% PSNR label: on Y (comparable with the paper) and, in colour mode, colour.
    if emb.isColour
        t = sprintf('PSNR  %s dB (Y)  /  %s dB (colour)', fmtNum(emb.psnr(s), '%.2f'), ...
                    fmtNum(emb.psnrColour(s), '%.2f'));
    else
        t = sprintf('PSNR = %s dB', fmtNum(emb.psnr(s), '%.2f'));
    end
end

% ---------------------------------------------------------------------
function n = baseName(emb)
% File name of the cover image, used for the default save names.
    n = 'image';
    if isfield(emb, 'coverPath') && ~isempty(emb.coverPath)
        [~, n] = fileparts(emb.coverPath);
    end
end

function p = inputPaths(emb)
% The user's input files (so that saving never overwrites them).
    p = {};
    if isfield(emb, 'coverPath'),     p{end + 1} = emb.coverPath;     end
    if isfield(emb, 'watermarkPath'), p{end + 1} = emb.watermarkPath; end
end


% =========================================================================
% E. LOCAL HELPER FUNCTIONS
% =========================================================================

% ---------------- paths / files -------------------------------------------
function root = projectRoot()
% Folder that holds main.m (this file lives in <root>/gui).
    root = fileparts(fileparts(mfilename('fullpath')));
end

function d = imagesDir()
    d = fullfile(projectRoot(), 'images');
    if isfolder(d), d = [d filesep]; else, d = ''; end
end

function d = resultsDir()
    d = fullfile(projectRoot(), 'results');
    if ~isfolder(d), d = pwd; end
end

function filt = imageFilter()
    filt = {'*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Image files (*.png, *.jpg, *.bmp, *.tif)'; ...
            '*.*', 'All files'};
end

function saveImageFile(parentFig, img, defName, inputs)
% Save dialog. Refuses to overwrite the user's input files; warns about JPEG
% (its compression destroys the hidden logo).
    filt = {'*.png', 'PNG image (*.png)'; '*.bmp', 'BMP image (*.bmp)'; ...
            '*.tif', 'TIFF image (*.tif)'; '*.jpg', 'JPEG image (*.jpg) - lossy, not recommended'};
    [f, p] = uiputfile(filt, 'Save image', fullfile(resultsDir(), defName));
    figure(parentFig);
    if isequal(f, 0)
        return;
    end
    target = fullfile(p, f);
    if any(strcmpi(target, inputs))
        uialert(parentFig, 'That is one of your input files. Choose a different name.', 'Not saved');
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
        uialert(parentFig, ['Saved, but JPEG compression changes pixel values and will damage the ' ...
                            'hidden logo. Use PNG, BMP or TIFF to keep it extractable.'], ...
                'Saved (with a warning)', 'Icon', 'warning');
    else
        uialert(parentFig, ['Saved to ' target], 'Saved', 'Icon', 'success');
    end
end

% ---------------- progress dialog ------------------------------------------
function cancelNow = updateProgress(dlg, msg)
% Called by embedAllStages with a status text; returns true on Cancel.
    cancelNow = false;
    if isvalid(dlg)
        dlg.Message = msg;
        drawnow;
        cancelNow = dlg.CancelRequested;
    end
end

function closeDialog(dlg)
    if isvalid(dlg)
        close(dlg);
    end
end

% ---------------- WORKFLOW page: code path and flowchart -------------------
function files = codePath()
% Every project file in the order it runs, with one line on what it does.
    f = {
     'main.m', ...
        'Start here. Adds all step folders to the MATLAB path and opens this window.'
     'gui/watermarkingApp.m', ...
        'This window: pages, buttons and pictures only. All maths is in the step folders.'
     'step1_input/loadImageFile.m', ...
        'Reads the file you picked (any format, palette, 16-bit, transparency) and returns a plain uint8 image.'
     'step1_input/prepareCoverImage.m', ...
        ['Cover: colour -> gray with rgbToGray.m (the paper uses 8-bit gray images) and resize to ' ...
         '256 x 256 with resizeNearest.m.']
     'step1_input/prepareWatermarkLogo.m', ...
        'Logo: shrink to at most 32 px, Otsu threshold -> 0/1 matrix W (1 = logo ink), optional invert.'
     'step3_embedding/embedAllStages.m', ...
        'The "Embed" button: runs the alpha search (BFO, then PBFO) and embeds with all 5 methods.'
     'step4_optimization/optimizerBFO.m', ...
        ['Bacterial Foraging: tumble / swim (chemotaxis), reproduction, elimination-dispersal. ' ...
         'Gives alpha for method 4.']
     'step4_optimization/optimizerPBFO.m', ...
        ['PSO (optimizerPSO.m) first tunes the BFO step size, then BFO runs again with it. ' ...
         'Gives alpha for method 5, the main result.']
     'step4_optimization/fitnessFunction.m', ...
        ['Scores one alpha: embed, add the 4 noises, extract, NC each time. ' ...
         'F = 1 / (NC1 + NC2 + NC3 + NC4)  (paper eq. 13). Lower is better.']
     'step3_embedding/embedStage1_DWT.m  +  embedStage2_DWT_DCT.m', ...
        'Methods 1 and 2 for the comparison: add alpha * W to HH, or to DCT(HH).'
     'step3_embedding/embedStage3_DWT_DCT_SVD.m', ...
        ['The main method: DWT -> DCT -> SVD -> s_new = s + alpha * sw -> rebuild. ' ...
         'Also returns the key {s, Uw, Vw, alpha}.']
     'step3_embedding/splitCoverIntoBands.m  +  step2_transforms/haarDWT2.m', ...
        'Checks the inputs and splits the cover with the Haar DWT into LL, LH, HL and HH (half size each).'
     'step2_transforms/dctMatrix.m', ...
        'Builds the DCT matrix T, so the 2-D DCT is D = T * X * T'' and the inverse is X = T'' * D * T.'
     'step3_embedding/rebuildFromBands.m  +  step2_transforms/haarIDWT2.m', ...
        'Inverse DWT with the changed HH band, rounded to 8-bit: the watermarked image.'
     'step5_extraction/extractWatermark.m', ...
        ['Runs the embedding backwards with the key: DWT -> DCT -> SVD -> sw* = (s* - s) / alpha -> ' ...
         'W* = Uw * diag(sw*) * Vw''.']
     'step6_attacks/applyAttack.m', ...
        ['Puts ONE noise on the watermarked image: Gaussian, shot, salt & pepper or speckle ' ...
         '(strengths in defaultAttackSettings.m).']
     'step6_attacks/attackAndExtract.m', ...
        'Attack test for all 5 methods: noise -> extract -> NC and BER (steps 4 and 5).'
     'step7_metrics/calculateMetrics.m', ...
        'PSNR, SSIM, IF (image vs image) and NC, BER (logo vs logo).'
     'step2_transforms/rgbToYCbCr.m  +  yCbCrToRgb.m', ...
        ['COLOUR MODE ONLY. Splits a colour photo into brightness Y and colour Cb, Cr, and joins them ' ...
         'back. The logo lives in Y, so the paper''s gray method runs on Y unchanged.']
     'step3_embedding/addColourToStages.m', ...
        ['COLOUR MODE ONLY. After embedding: watermarked Y + original Cb, Cr -> colour watermarked ' ...
         'image for every method, plus its colour PSNR.']
     'step5_extraction/receivedImage.m', ...
        ['First step of every extraction: gray mode uses the image itself, colour mode takes the ' ...
         'brightness Y out of the colour image.']
     'step3_embedding/analyseCoverAndLogo.m', ...
        ['Steps 1-3 of the main method (DWT, DCT, SVD of cover and logo). They do not depend on alpha, ' ...
         'so the alpha search computes them once and reuses them - much faster, same result.']
    };
    files = struct('name', f(:, 1), 'desc', f(:, 2));
end

function boxes = drawWorkflow(ax, emb, onClick)
% Two lanes of boxes - EMBEDDING (left) and EXTRACTION (right) - with arrows,
% the hand-over of the watermarked image and the dashed KEY arrow.
% Every box: plain-English headline (bold) + the formula / technique below.
% The full explanation (shown in the Step details card) and the file index
% are kept with each box. Returns the boxes so the page can highlight them.
    c = theme();
    W = 684;  H = 524;
    trySet(ax.Toolbar, 'Visible', 'off');
    try disableDefaultInteractivity(ax); catch, end
    cla(ax);
    hold(ax, 'on');
    ax.XLim = [0 W];  ax.YLim = [0 H];
    ax.Visible = 'off';

    hasRun   = ~isempty(emb);                       % has the user embedded something yet?
    isColour = hasRun && emb.isColour;
    if hasRun
        alphaText = sprintf('alpha = %.2f   (BFO / PBFO)', emb.alphaPBFO);
        kText     = sprintf(' It has k = %d layers.', numel(emb.keys{end}.s));
    else
        alphaText = 'alpha  found by BFO / PBFO';
        kText     = '';
    end
    %        headline (plain English)                         technique / formula                       file  explanation
    left = {
        'You choose a cover photo and a logo',               'inputs  (page 1)',                          2, ...
            ['The cover is the photo that will carry the hidden logo. The logo is the secret mark - for ' ...
             'example your initials - that later proves the photo is yours.']
        'Make both images ready for the maths',              'gray 256 x 256 cover,  0/1 logo W',         4, ...
            ['The cover becomes a 256 x 256 grayscale picture (as in the paper), because the transforms ' ...
             'work on one grid of numbers. The logo is shrunk and made black/white: 1 = logo ink, 0 = background.']
        'Split the cover into 4 detail bands, keep HH',     'Haar DWT',                                  12, ...
            ['The wavelet transform separates the picture into a small overview (LL) and three detail layers. ' ...
             'HH holds the finest diagonal detail, where small changes are almost invisible to the eye - ' ...
             'that is where the logo will go.']
        'Rewrite HH as a mix of wave patterns',             'DCT:   D = T * HH * T''',                   13, ...
            ['The cosine transform describes the HH band as a sum of wave patterns instead of single pixels. ' ...
             'A change made here is spread over the whole band, so it is harder to remove.']
        'Measure the strength of every layer',              'SVD:   D = U S V''   and   W = Uw Sw Vw''', 11, ...
            ['SVD splits a matrix into layers and gives each layer a strength (its singular value). ' ...
             'These strengths hardly move when the picture gets noise, so they are a safe hiding ' ...
             'place. The logo is split the same way.' kText]
        'Find the best hiding strength alpha',              alphaText,                                   8, ...
            ['Too weak and noise wipes the logo out; too strong and it becomes visible. BFO (bacteria ' ...
             'searching for food) and PBFO (BFO tuned by a particle swarm) try many values of alpha and keep ' ...
             'the one where the logo survives four kinds of noise best - while keeping the picture quality ' ...
             '(PSNR) above the limit chosen on page 1.']
        'HIDE THE LOGO in the cover''s layer strengths',    's_new = s + alpha * sw',                    11, ...
            ['This is the moment the logo is hidden: the logo''s layer strengths, multiplied by alpha, are ' ...
             'added to the cover''s strongest layers. The secret KEY (original strengths s, the logo''s ' ...
             'layers Uw and Vw, and alpha) is saved for extraction.']
        'Rebuild the picture = watermarked image',          'inverse SVD  >  inverse DCT  >  inverse DWT', 14, ...
            ['All transforms are undone in reverse order, now with the changed strengths. The result looks ' ...
             'like the cover but carries the logo. Save it as PNG so nothing is lost.']
    };
    right = {
        'Start from the watermarked image',                 'maybe attacked with noise',                 16, ...
            ['The receiver only has the watermarked picture - possibly damaged by noise - and the secret KEY. ' ...
             'The original cover photo is not needed.']
        'Same wavelet split, take the HH band',             'Haar DWT  ->  HH*',                         12, ...
            ['Exactly the same transform as in embedding, so the logo is looked for in the same place: ' ...
             'the HH band.']
        'Same wave-pattern rewrite',                        'DCT:   D* = T * HH* * T''',                 13, ...
            'The HH band is rewritten as wave patterns again, exactly like in embedding.'
        'Measure the layer strengths again',                'SVD of D*  ->  s*',                         15, ...
            ['The layer strengths of the received picture are measured. They are the cover''s strengths ' ...
             'PLUS the hidden logo (plus any damage the noise did).']
        'Take away the cover, keep the logo',               'sw* = (s* - s) / alpha',                    15, ...
            ['This undoes the hiding step: the cover''s original strengths s (from the KEY) are subtracted ' ...
             'and the rest is divided by alpha. What is left are the logo''s strengths.']
        'Rebuild the logo',                                 'W* = Uw * diag(sw*) * Vw''',               15, ...
            ['The logo''s strengths are combined with its saved layers Uw and Vw from the KEY. A threshold ' ...
             'at 0.5 turns the result back into a black/white logo.']
        'How well did the logo survive?',                   'NC, BER   (and PSNR, SSIM, IF)',           18, ...
            ['NC = 1 means the extracted logo is identical to the original; BER is the share of wrong logo ' ...
             'pixels. PSNR, SSIM and IF tell how invisible the watermark is in the picture.']
    };
    if isColour                     % colour mode: the colour steps are part of boxes 2 and 8 (left), 1 (right)
        left(2, :)  = {'Split the colour photo, keep its brightness', 'Y, Cb, Cr  (Y = gray 256 x 256),  0/1 logo W', 19, ...
            ['Colour mode: the photo is split into brightness Y and colour Cb, Cr. Only Y is used for hiding - ' ...
             'it IS the grayscale picture, so the paper''s method runs unchanged. The logo is made black/white.']};
        left(8, :)  = {'Rebuild, then put the colour back', 'inverse SVD > IDCT > IDWT,  + Cb, Cr', 20, ...
            ['All transforms are undone with the changed strengths, giving the watermarked brightness Y. ' ...
             'The original colour Cb, Cr is joined back, so the result is a colour watermarked photo.']};
        right(1, :) = {'Start from the colour watermarked image', 'brightness Y  (maybe attacked)', 21, ...
            ['The receiver has the colour picture (maybe damaged by noise) and the KEY. Only its brightness Y ' ...
             'is taken out, because that is where the logo was hidden.']};
    end

    xL = 8;  xR = 360;  bw = 316;  bh = 46;  gap = 10;  top = 476;
    text(ax, xL, 502, 'EMBEDDING  -  hide the logo', 'FontSize', 14, 'FontWeight', 'bold', 'Color', c.red, ...
         'FontName', 'Arial', 'PickableParts', 'none');
    text(ax, xR, 502, 'EXTRACTION  -  get it back', 'FontSize', 14, 'FontWeight', 'bold', 'Color', c.text, ...
         'FontName', 'Arial', 'PickableParts', 'none');

    boxes = struct('patch', {}, 'fileIdx', {}, 'lane', {}, 'num', {}, 'headline', {}, 'explain', {});
    yL = zeros(1, size(left, 1));
    for i = 1:size(left, 1)
        yL(i) = top - (i - 1) * (bh + gap);
        boxes(end + 1) = flowBox(ax, xL, yL(i), bw, bh, i, left(i, :), c.red, 'EMBEDDING', ...
                                 numel(boxes) + 1, onClick); %#ok<AGROW>
        if i > 1, arrowDown(ax, xL + bw / 2, yL(i - 1) - bh, yL(i)); end
    end
    yR = zeros(1, size(right, 1));
    for i = 1:size(right, 1)
        yR(i) = top - (i - 1) * (bh + gap);
        boxes(end + 1) = flowBox(ax, xR, yR(i), bw, bh, i, right(i, :), c.text, 'EXTRACTION', ...
                                 numel(boxes) + 1, onClick); %#ok<AGROW>
        if i > 1, arrowDown(ax, xR + bw / 2, yR(i - 1) - bh, yR(i)); end
    end

    % hand-over: watermarked image (left, last box) -> extraction (right, first box)
    yA = yL(end) - bh / 2;
    yB = yR(1) - bh / 2;
    line(ax, [xL + bw, 349, 349, xR - 6], [yA, yA, yB, yB], 'Color', c.text, 'LineWidth', 2, 'PickableParts', 'none');
    arrowHead(ax, xR - 2, yB, 'right', c.text);

    % the secret KEY: s, Uw, Vw, alpha  (left box 7 -> right box 5)
    y1 = yL(7) - bh / 2;
    y2 = yR(5) - bh / 2;
    line(ax, [xL + bw, 336, 336, xR - 6], [y1, y1, y2, y2], 'Color', c.red, 'LineWidth', 2.2, ...
         'LineStyle', '--', 'PickableParts', 'none');
    arrowHead(ax, xR - 2, y2, 'right', c.red);
    text(ax, 336, (y1 + y2) / 2, 'KEY', 'FontSize', 11, 'FontWeight', 'bold', 'Color', [1 1 1], ...
         'BackgroundColor', c.red, 'HorizontalAlignment', 'center', 'Margin', 2, 'PickableParts', 'none');
    hold(ax, 'off');
    ax.XLim = [0 W];  ax.YLim = [0 H];
end

function b = flowBox(ax, x, yTop, w, h, num, row, numColour, lane, index, onClick)
% One flowchart box: number tab on the left, plain-English headline (bold)
% and the technique / formula below it. Clicking it calls onClick(index).
    p = patch(ax, [x x + w x + w x], [yTop yTop yTop - h yTop - h], [1 1 1], ...
              'EdgeColor', [0.15 0.15 0.16], 'LineWidth', 1, ...
              'ButtonDownFcn', @(~, ~) onClick(index));
    patch(ax, [x x + 26 x + 26 x], [yTop yTop yTop - h yTop - h], numColour, 'EdgeColor', 'none', ...
          'PickableParts', 'none');
    text(ax, x + 13, yTop - h / 2, sprintf('%d', num), 'Color', [1 1 1], 'FontWeight', 'bold', ...
         'FontSize', 13, 'HorizontalAlignment', 'center', 'PickableParts', 'none');
    text(ax, x + 34, yTop - 14, row{1}, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.06 0.06 0.07], ...
         'Interpreter', 'none', 'FontName', 'Arial', 'PickableParts', 'none');
    text(ax, x + 34, yTop - 33, row{2}, 'FontSize', 10, 'Color', [0.22 0.22 0.25], ...
         'Interpreter', 'none', 'FontName', 'Arial', 'PickableParts', 'none');
    b = struct('patch', p, 'fileIdx', row{3}, 'lane', lane, 'num', num, ...
               'headline', row{1}, 'explain', row{4});
end

function n = shortFileName(name)
% 'step3_embedding/splitCoverIntoBands.m  +  step2_transforms/haarDWT2.m'
%   -> 'splitCoverIntoBands.m + haarDWT2.m'  (for the file list)
    n = regexprep(name, '[\w]+/', '');
    n = regexprep(n, '\s+\+\s+', ' + ');
end

function arrowDown(ax, x, yFrom, yTo)
    line(ax, [x x], [yFrom - 1, yTo + 5], 'Color', [0.15 0.15 0.16], 'LineWidth', 1.5, 'PickableParts', 'none');
    arrowHead(ax, x, yTo + 1, 'down', [0.15 0.15 0.16]);
end

function arrowHead(ax, x, y, direction, colour)
    s = 5;
    if strcmp(direction, 'down')
        xy = [x - s, y + 2 * s; x + s, y + 2 * s; x, y];
    else
        xy = [x - 2 * s, y + s; x - 2 * s, y - s; x, y];
    end
    patch(ax, xy(:, 1), xy(:, 2), colour, 'EdgeColor', 'none', 'PickableParts', 'none');
end

% ---------------- click-to-enlarge image viewer ---------------------------
function openImageViewer(u, ttl)
% Opens a picture in its own large window. Scroll to zoom, drag to pan
% (the axes toolbar at the top right has zoom / pan / restore buttons).
    if iscell(ttl), ttl = strjoin(ttl, ' '); end
    if isempty(ttl), ttl = 'Image'; end
    scr = get(0, 'ScreenSize');
    side = min(760, scr(4) - 160);
    v = uifigure('Name', ['Image viewer - ' ttl], 'Position', ...
                 [max(1, (scr(3) - side) / 2), max(1, (scr(4) - side - 60) / 2), side, side + 60]);
    trySet(v, 'Theme', 'light');
    v.Color = [0.12 0.12 0.13];
    ax = uiaxes(v, 'Position', [10 50 side - 20 side]);
    image(ax, u);
    [h, w, ~] = size(u);
    ax.XLim = [0.5 w + 0.5];
    ax.YLim = [0.5 h + 0.5];
    ax.YDir = 'reverse';
    ax.DataAspectRatio = [1 1 1];
    ax.XTick = [];
    ax.YTick = [];
    trySet(ax, 'BackgroundColor', [0.12 0.12 0.13]);
    title(ax, upper(ttl), 'Color', [1 1 1], 'FontSize', 13);
    uilabel(v, 'Text', sprintf('%d x %d pixels   -   scroll to zoom, drag to pan', h, w), ...
            'Position', [10 12 side - 20 26], 'FontColor', [0.85 0.85 0.87], 'HorizontalAlignment', 'center');
end

% ---------------- walkthrough viewer (windows 2 and 3) --------------------
% A walkthrough is a list of sub-steps shown inside a panel. Each sub-step
% has a title, an explanation (left) and a draw function that fills the
% picture area (right). The list and the current index are kept in
% vis.UserData. Previous / Next move through the list.
function wt = createWalkthrough(parent)
    pw = parent.Position(3);
    ph = parent.Position(4) - 25;            % minus the panel title bar
    tw = 270;                                % width of the explanation column
    c  = theme();
    wt.title   = uilabel(parent, 'Text', '', 'Position', [10 ph - 36 pw - 20 28], 'FontSize', 15, ...
                         'FontWeight', 'bold', 'FontColor', c.accent);
    wt.text    = uilabel(parent, 'Text', '', 'Position', [10 55 tw ph - 100], 'WordWrap', 'on', ...
                         'VerticalAlignment', 'top', 'FontSize', 12);
    wt.vis     = uipanel(parent, 'Position', [tw + 20 55 pw - tw - 30 ph - 100], 'BackgroundColor', [1 1 1]);
    wt.prev    = uibutton(parent, 'push', 'Text', '<  Previous', 'Position', [tw + 20 12 110 32]);
    wt.counter = uilabel(parent, 'Text', '', 'Position', [tw + 135 12 140 32], 'HorizontalAlignment', 'center');
    wt.next    = uibutton(parent, 'push', 'Text', 'Next  >', 'FontWeight', 'bold', 'Position', [tw + 280 12 110 32]);
    wt.prev.ButtonPushedFcn = @(~, ~) walkthroughMove(wt, -1);
    wt.next.ButtonPushedFcn = @(~, ~) walkthroughMove(wt, +1);
end

function walkthroughSet(wt, steps)
    wt.vis.UserData = struct('steps', steps, 'idx', 1);
    walkthroughShow(wt);
end

function walkthroughMove(wt, delta)
    ud = wt.vis.UserData;
    ud.idx = min(max(ud.idx + delta, 1), numel(ud.steps));
    wt.vis.UserData = ud;
    walkthroughShow(wt);
end

function walkthroughShow(wt)
    ud = wt.vis.UserData;
    n  = numel(ud.steps);
    st = ud.steps(ud.idx);
    wt.title.Text = st.title;
    wt.text.Text  = st.text;
    delete(wt.vis.Children);
    st.draw(wt.vis);
    axs = findall(wt.vis, 'Type', 'axes');
    for i = 1:numel(axs)
        trySet(axs(i), 'BackgroundColor', [1 1 1]);     % match the white picture area
    end
    wt.counter.Text = sprintf('Step %d of %d', ud.idx, n);
    wt.prev.Enable  = onOff(ud.idx > 1);
    wt.next.Enable  = onOff(ud.idx < n);
end

function st = mkStep(titleText, lines, drawFcn)
    st = struct('title', titleText, 'text', strjoin(lines, newline), 'draw', drawFcn);
end

% ---------------- STEP 2 sub-steps: the embedding algorithm ---------------
function steps = embeddingSteps(e, tr, curve)
    M = numel(e.stageNames);
    k = tr.k;
    steps = mkStep('2.1   Inputs after preparation', { ...
        'Before any maths, both images are made "algorithm-ready":', '', ...
        coverLine(e), '', ...
        sprintf('LOGO: shrunk to %d x %d and turned into a 0/1 matrix W (1 = logo ink, 0 = background).', size(e.W, 1), size(e.W, 2)), '', ...
        'W is the secret that will be hidden inside the cover.', '', ...
        'Code: step1_input/prepareCoverImage.m', '      step1_input/prepareWatermarkLogo.m'}, ...
        @(p) drawImages(p, {e.cover, e.W}, {coverName(e), 'Logo matrix W'}));

    steps(end + 1) = mkStep('2.2   DWT: split the cover into 4 frequency bands', { ...
        'A one-level 2-D Haar Discrete Wavelet Transform splits the cover into four half-size bands:', '', ...
        '  LL  approximation (small copy of the image)', ...
        '  LH  horizontal details', ...
        '  HL  vertical details', ...
        '  HH  diagonal details (fine texture)', '', ...
        'The logo is hidden in HH: the eye hardly notices changes in fine diagonal detail, so the watermark stays invisible.', '', ...
        'Code: step2_transforms/haarDWT2.m'}, ...
        @(p) drawDWT(p, tr));

    steps(end + 1) = mkStep('2.3   DCT: move the HH band into the frequency domain', { ...
        'The 2-D Discrete Cosine Transform writes the HH band as a sum of cosine patterns:', '', ...
        '      D = T * HH * T''', '', ...
        'Low frequencies end up in the top-left corner. A change made in the DCT domain is spread over the ', ...
        'whole HH band instead of single pixels, which makes the watermark harder to remove.', '', ...
        'Code: step2_transforms/dctMatrix.m'}, ...
        @(p) drawImages(p, {stretch(tr.HH), logView(tr.D)}, {'HH band', 'DCT of HH:  log(1 + |D|)'}));

    steps(end + 1) = mkStep('2.4   SVD: find the singular values', { ...
        'Singular Value Decomposition splits a matrix into three parts:', '', ...
        '   cover:  D = U * S * V''        s  = diag(S)', ...
        '   logo :  W = Uw * Sw * Vw''     sw = diag(Sw)', '', ...
        'The singular values describe the "strength" of each layer of the matrix. They change very little ', ...
        'when the image is slightly changed (noise, filtering) - that is why the logo is put there.', '', ...
        sprintf('The logo has k = %d non-zero singular values, so only the first %d values of the cover are changed.', k, k), '', ...
        'Code: step3_embedding/embedStage3_DWT_DCT_SVD.m'}, ...
        @(p) drawSingularValues(p, tr));

    steps(end + 1) = mkStep('2.5   Choose the strength alpha with BFO and PBFO', { ...
        'alpha = how strongly the logo is added. Small alpha: invisible but fragile. Large alpha: robust but visible.', '', ...
        'Fitness to minimise (paper eq. 13):', ...
        '  F = 1 / (NC_gauss + NC_shot + NC_s&p + NC_speckle)', ...
        '(embed, attack with 4 noises, extract, measure NC)', '', ...
        qualityLine(e), '', ...
        'BFO: "bacteria" move along alpha (tumble / swim); the healthy ones reproduce, some are dispersed.', ...
        'PBFO: PSO first tunes the BFO step size, then BFO runs with it.', '', ...
        sprintf('BFO :  alpha = %.2f   F = %.4f   (%d evals, %.1f s)', e.alphaBFO, e.costBFO, e.evalsBFO, e.timeBFO), ...
        sprintf('PBFO:  alpha = %.2f   F = %.4f   (step %.2f, %.1f s)', e.alphaPBFO, e.costPBFO, e.bestStep, e.timePBFO), '', ...
        'Code: step4_optimization/'}, ...
        @(p) drawFitness(p, curve, e));

    steps(end + 1) = mkStep('2.6   THE LOGO IS EMBEDDED HERE', { ...
        'This is the step where the logo is actually hidden.', '', ...
        'WHAT:  the logo W (picture 1) - through its singular values sw.', '', ...
        'WHERE: in the HH band of the DWT (picture 2, red box), after the DCT:', ...
        '       in the singular values s of D = DCT(HH).', '', ...
        'HOW:', ...
        sprintf('   s_new = s + alpha * sw    (alpha = %.2f, first %d values)', e.alphaPBFO, k), '', ...
        'U and V of the cover stay unchanged, so the picture keeps its structure.', '', ...
        'Picture 3: |HH_new - HH|, the change the logo made to the HH band (spread out by the DCT and SVD).', ...
        'Plot: singular values before and after.', '', ...
        'Code: step3_embedding/embedStage3_DWT_DCT_SVD.m (section 4)'}, ...
        @(p) drawEmbedHere(p, tr, e.W));

    steps(end + 1) = mkStep('2.7   Rebuild: inverse SVD -> inverse DCT -> inverse DWT', { ...
        'Everything is undone in reverse order:', '', ...
        '  inverse SVD:  D_new  = U * diag(s_new) * V''', ...
        '  inverse DCT:  HH_new = T'' * D_new * T', ...
        '  inverse DWT:  LL, LH, HL, HH_new  ->  image', '', ...
        sprintf('Quality:  PSNR = %s dB,  SSIM = %s', fmtNum(e.psnr(M), '%.2f'), fmtNum(e.ssim(M), '%.4f')), ...
        '(PSNR above ~40 dB looks identical to the eye)', '', ...
        'The KEY {s, Uw, Vw, alpha} is kept for extraction (non-blind method).', '', ...
        'Right: the difference, amplified so you can see where the logo was hidden.', '', ...
        'Code: step3_embedding/rebuildFromBands.m'}, ...
        @(p) drawRebuild(p, e.cover, e.wmImgs{M}));

    if e.isColour
        % ---- COLOUR MODE: one step before (split) and one after (merge)
        first = mkStep('2.0   COLOUR: split the photo into Y, Cb, Cr', { ...
            'Colour mode is ON. DWT, DCT and SVD need ONE 2-D matrix, so the colour photo is split:', '', ...
            '  Y  =       0.299 R + 0.587 G + 0.114 B   (brightness)', ...
            '  Cb = 128 - 0.169 R - 0.331 G + 0.500 B   (blue-difference)', ...
            '  Cr = 128 + 0.500 R - 0.419 G - 0.081 B   (red-difference)', '', ...
            'Y IS the grayscale image, so the paper''s method runs on Y exactly as on a gray photo.', ...
            'Cb and Cr are kept untouched and put back at the end (step 2.8).', '', ...
            'Why Y? The eye sees detail mostly in brightness, and JPEG / most attacks keep Y best.', '', ...
            'Code: step2_transforms/rgbToYCbCr.m', '      step1_input/prepareCoverImage.m'}, ...
            @(p) drawImages(p, {e.coverRGB, e.cover, normalise(e.Cb), normalise(e.Cr)}, ...
                            {'Colour cover', 'Y (gets the logo)', 'Cb (kept)', 'Cr (kept)'}));
        steps = [first, steps];
        steps(end + 1) = mkStep('2.8   COLOUR: put the colour back', { ...
            'The watermarked brightness Y_new is joined with the ORIGINAL Cb and Cr:', '', ...
            '  R = Y + 1.402 (Cr - 128)', ...
            '  G = Y - 0.344 (Cb - 128) - 0.714 (Cr - 128)', ...
            '  B = Y + 1.772 (Cb - 128)', '', ...
            'Rounded to 8-bit RGB -> the colour watermarked image.', '', ...
            sprintf('PSNR colour cover vs colour watermarked = %s dB', fmtNum(e.psnrColour(M), '%.2f')), '', ...
            'Save it as PNG (lossless) so the logo can still be extracted later.', '', ...
            'Code: step2_transforms/yCbCrToRgb.m', '      step3_embedding/addColourToStages.m'}, ...
            @(p) drawRebuild(p, e.coverRGB, e.wmRGB{M}));
    end
end

function t = coverLine(e)
    if e.isColour
        t = sprintf('COVER: the brightness Y of the colour photo (step 2.0), %d x %d pixels.', size(e.cover, 1), size(e.cover, 2));
    else
        t = sprintf('COVER: converted to grayscale and resized to %d x %d pixels.', size(e.cover, 1), size(e.cover, 2));
    end
end

function t = coverName(e)
    if e.isColour, t = 'Cover: Y channel'; else, t = 'Cover (grayscale)'; end
end

% ---------------- STEP 3 sub-steps: the extraction algorithm --------------
function t = qualityLine(e)
% One line for step 2.5 about the image-quality limit of the alpha search.
    if e.settings.minPSNR > 0
        t = sprintf(['Quality limit: PSNR >= %g dB. Every dB below it adds a big penalty to F, so the search ' ...
                     'finds the most robust alpha that still looks good.'], e.settings.minPSNR);
    else
        t = 'Quality limit: none (paper exact) - the search simply prefers the strongest alpha.';
    end
end

function steps = extractionSteps(e, embTr, We, tr, score)
    M   = numel(e.stageNames);
    key = e.keys{M};
    steps = mkStep('3.1   DWT of the watermarked image', { ...
        'The receiver has the watermarked image and the secret KEY:', '', ...
        '  s      original singular values of the cover', ...
        '  Uw, Vw singular vectors of the logo', ...
        sprintf('  alpha  = %.2f', key.alpha), '', ...
        'Step one is the same Haar DWT as in embedding. The HH* band now carries the logo.', '', ...
        'Code: step5_extraction/extractWatermark.m (section 1)'}, ...
        @(p) drawImages(p, {uint8(receivedImage(e, M)), stretch(tr.HH)}, {coverName(e), 'HH* band'}));

    steps(end + 1) = mkStep('3.2   DCT of the HH* band', { ...
        'Same DCT as before:   D* = T * HH* * T''', '', ...
        'Right: |D* - D|, the difference from the ORIGINAL cover''s DCT values. This difference is the ', ...
        'hidden logo, spread over the whole band by the SVD - it does not look like the logo yet.', '', ...
        'Code: step5_extraction/extractWatermark.m'}, ...
        @(p) drawImages(p, {logView(tr.D), stretch(tr.D - embTr.D)}, {'log(1 + |D*|)', '|D* - D|  (hidden signal)'}));

    steps(end + 1) = mkStep('3.3   SVD: recover the logo''s singular values', { ...
        'SVD of D* gives its singular values s*. Embedding did  s_new = s + alpha * sw,  so:', '', ...
        '   sw* = (s* - s) / alpha', '', ...
        'The plot compares the recovered sw* with the logo''s real singular values sw. If they match, the ', ...
        'logo can be rebuilt exactly.', '', ...
        'Code: step5_extraction/extractWatermark.m (case 3)'}, ...
        @(p) drawRecoveredSV(p, embTr.sw(1:numel(tr.swe)), tr.swe));

    steps(end + 1) = mkStep('3.4   Rebuild the logo', { ...
        'The logo is rebuilt with its saved singular vectors:', '', ...
        '   W* = Uw * diag(sw*) * Vw''', '', ...
        'W* is made of real numbers close to 0 and 1; a threshold at 0.5 turns it into black/white.', '', ...
        sprintf('NC  = %.4f   (1 = identical)', clamp01(score.ncc)), ...
        ['BER = ' fmtNum(100 * score.ber, '%.2f %%') '   (wrong pixels)'], '', ...
        'This was a CLEAN image. Next: the attack tests (noise first, then extract).'}, ...
        @(p) drawImages(p, {e.W, clamp01(We), logoForDisplay(We, e.isBinary)}, ...
                        {'Original logo W', 'Extracted W* (raw)', 'W* after threshold'}));

    if e.isColour
        [Yc, Cbc, Crc] = rgbToYCbCr(e.wmRGB{M});
        first = mkStep('3.0   COLOUR: take the brightness Y back out', { ...
            'Colour mode is ON. The receiver has the COLOUR watermarked image.', '', ...
            'It is split again with the same formula:', ...
            '  Y = 0.299 R + 0.587 G + 0.114 B', '', ...
            'The logo was hidden in Y only, so Cb and Cr are not needed for extraction.', ...
            'Y is used as it is (not rounded) and goes into the normal extraction (3.1 - 3.4).', '', ...
            'The RGB rounding of step 2.8 changes Y by at most about 1 grey level, which costs only a ', ...
            'tiny bit of NC.', '', ...
            'Code: step5_extraction/receivedImage.m', '      step2_transforms/rgbToYCbCr.m'}, ...
            @(p) drawImages(p, {e.wmRGB{M}, Yc / 255, normalise(Cbc), normalise(Crc)}, ...
                            {'Colour watermarked', 'Y (has the logo)', 'Cb (not used)', 'Cr (not used)'}));
        steps = [first, steps];
    end
end

% ---------------- drawing helpers for the walkthroughs --------------------
function ax = makeAxes(panel, n, i)
% i-th of n side-by-side axes in the picture panel.
    pw = panel.Position(3) - 10;
    ph = panel.Position(4) - 20;
    w  = pw / n;
    ax = uiaxes(panel, 'Position', [8 + (i - 1) * w, 10, w - 10, ph - 10]);
end

function drawImages(panel, imgs, titles)
    n = numel(imgs);
    for i = 1:n
        showImage(makeAxes(panel, n, i), imgs{i}, titles{i});
    end
end

function drawDWT(panel, tr)
    bands  = {normalise(tr.LL), stretch(tr.LH); stretch(tr.HL), stretch(tr.HH)};
    titles = {'LL  approximation', 'LH  horizontal'; 'HL  vertical', 'HH  diagonal  <- logo goes here'};
    pw = panel.Position(3) - 10;
    ph = panel.Position(4) - 20;
    for r = 1:2
        for c = 1:2
            ax = uiaxes(panel, 'Position', [8 + (c - 1) * pw / 2, 10 + (2 - r) * ph / 2, pw / 2 - 10, ph / 2 - 6]);
            showImage(ax, bands{r, c}, titles{r, c});
        end
    end
end

function drawSingularValues(panel, tr)
    n  = min(40, numel(tr.s));
    a1 = makeAxes(panel, 2, 1);
    plot(a1, 1:n, tr.s(1:n), '-o', 'MarkerSize', 4, 'LineWidth', 1.2);
    title(a1, sprintf('Cover: s (first %d of %d)', n, numel(tr.s)));
    xlabel(a1, 'index');  ylabel(a1, 'singular value');  grid(a1, 'on');

    a2 = makeAxes(panel, 2, 2);
    m  = numel(tr.sw);
    plot(a2, 1:m, tr.sw, '-s', 'MarkerSize', 4, 'LineWidth', 1.2, 'Color', [0.85 0.33 0.10]);
    title(a2, sprintf('Logo: sw  (k = %d non-zero)', tr.k));
    xlabel(a2, 'index');  ylabel(a2, 'singular value');  grid(a2, 'on');
end

function drawFitness(panel, curve, e)
    ax = makeAxes(panel, 1, 1);
    plot(ax, curve.alpha, curve.f, '-', 'LineWidth', 1.5, 'Color', [0.3 0.3 0.3]);
    hold(ax, 'on');
    plot(ax, e.alphaBFO,  e.costBFO,  'o', 'MarkerSize', 11, 'LineWidth', 2, 'Color', [0.85 0.33 0.10]);
    plot(ax, e.alphaPBFO, e.costPBFO, 's', 'MarkerSize', 13, 'LineWidth', 2, 'Color', [0.00 0.45 0.74]);
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'alpha (embedding strength)');
    ylabel(ax, 'fitness F  (lower = better)');
    title(ax, 'Fitness F(alpha) and the alpha found by each optimiser');
    legend(ax, {'F(alpha)', sprintf('BFO  alpha = %.2f', e.alphaBFO), ...
                sprintf('PBFO alpha = %.2f', e.alphaPBFO)}, 'Location', 'northeast');
end

function drawEmbedHere(panel, tr, W)
% Step 2.6 in pictures. Top row: WHAT is embedded (the logo), WHERE (the
% DWT bands with HH outlined in red) and WHAT CHANGED in HH. Bottom: the
% singular values before and after s_new = s + alpha * sw.
    pw = panel.Position(3) - 10;
    ph = panel.Position(4) - 20;
    topH = round(ph * 0.48);
    w3 = pw / 3;

    showImage(uiaxes(panel, 'Position', [8, ph - topH + 10, w3 - 10, topH]), W, '1. WHAT: the logo W');

    mosaic = [normalise(tr.LL), stretch(tr.LH); stretch(tr.HL), stretch(tr.HH)];
    rgb = repmat(mosaic, [1 1 3]);
    [r, c] = size(tr.HH);
    t = max(2, round(r / 40));                        % red frame around the HH quadrant
    red = cat(3, 1, 0.05, 0.08);
    rows = r + 1:2 * r;  cols = c + 1:2 * c;
    rgb(rows(1:t), cols, :)       = repmat(red, [t, c, 1]);
    rgb(rows(end-t+1:end), cols, :) = repmat(red, [t, c, 1]);
    rgb(rows, cols(1:t), :)       = repmat(red, [r, t, 1]);
    rgb(rows, cols(end-t+1:end), :) = repmat(red, [r, t, 1]);
    showImage(uiaxes(panel, 'Position', [8 + w3, ph - topH + 10, w3 - 10, topH]), rgb, '2. WHERE: HH band');

    showImage(uiaxes(panel, 'Position', [8 + 2 * w3, ph - topH + 10, w3 - 10, topH]), ...
              stretch(tr.HHnew - tr.HH), '3. CHANGE in HH');

    n  = min(max(tr.k + 10, 20), numel(tr.s));
    ax = uiaxes(panel, 'Position', [8, 10, pw - 10, ph - topH - 14]);
    plot(ax, 1:n, tr.s(1:n), '-o', 'LineWidth', 1.2, 'MarkerSize', 4, 'Color', [0.30 0.30 0.32]);
    hold(ax, 'on');
    plot(ax, 1:n, tr.sNew(1:n), '-x', 'LineWidth', 1.6, 'MarkerSize', 6, 'Color', [0.74 0.07 0.09]);
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'index');  ylabel(ax, 'singular value');
    title(ax, 'Singular values of DCT(HH): before and after', 'FontSize', 10);
    legend(ax, {'s  (before)', 's + alpha * sw  (after)'}, 'Location', 'northeast');
end

function drawSingularChange(panel, tr)
    n  = min(max(tr.k + 10, 20), numel(tr.s));
    ax = makeAxes(panel, 1, 1);
    plot(ax, 1:n, tr.s(1:n), '-o', 'LineWidth', 1.2, 'MarkerSize', 5);
    hold(ax, 'on');
    plot(ax, 1:n, tr.sNew(1:n), '-x', 'LineWidth', 1.5, 'MarkerSize', 7, 'Color', [0.85 0.33 0.10]);
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'index');  ylabel(ax, 'singular value');
    title(ax, sprintf('Cover singular values before and after embedding (first %d)', n));
    legend(ax, {'s  (before)', 's + alpha * sw  (after)'}, 'Location', 'northeast');
end

function drawRebuild(panel, cover, wmImg)
    d = abs(double(wmImg) - double(cover));
    gain = max(1, floor(255 / max(max(d(:)), 1)));
    drawImages(panel, {cover, wmImg, uint8(min(d * gain, 255))}, ...
               {'Original cover', 'Watermarked image', sprintf('|difference| x %d', gain)});
end

function drawRecoveredSV(panel, sw, swe)
    ax = makeAxes(panel, 1, 1);
    n  = numel(sw);
    plot(ax, 1:n, sw, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
    hold(ax, 'on');
    plot(ax, 1:n, swe, 'x', 'LineWidth', 2, 'MarkerSize', 10, 'Color', [0.85 0.33 0.10]);
    hold(ax, 'off');
    grid(ax, 'on');
    xlabel(ax, 'index');  ylabel(ax, 'singular value');
    title(ax, 'Logo singular values: original sw vs recovered sw*');
    legend(ax, {'sw  (original logo)', 'sw* = (s* - s) / alpha'}, 'Location', 'northeast');
end

function curve = fitnessCurve(e)
% F(alpha) on a grid, only to DRAW the search landscape in sub-step 2.5.
% Same fitness function and seed as BFO / PBFO used.
    a = linspace(e.settings.alphaRange(1), e.settings.alphaRange(2), 39);
    f = zeros(size(a));
    pre = analyseCoverAndLogo(e.cover, e.W);     % alpha-independent part, once
    for i = 1:numel(a)
        f(i) = fitnessFunction(a(i), e.cover, e.W, defaultAttackSettings(), ...
                               e.settings.trainSeed, e.settings.minPSNR, pre);
    end
    curve = struct('alpha', a, 'f', f);
end

% ---------------- attack descriptions --------------------------------------
function [fieldName, label, text] = attackInfo(type)
    switch type
        case 'gaussian'
            fieldName = 'gaussVar';  label = 'Variance';
            text = ['Gaussian noise: random values from a normal distribution (mean 0) are added to every ' ...
                    'pixel, like camera sensor noise. Paper value: variance 0.01.'];
        case 'shot'
            fieldName = '';  label = '';
            text = ['Shot (Poisson) noise: brighter pixels get more noise, like photon noise in a camera. ' ...
                    'Its strength depends on the image itself, so there is no setting.'];
        case 'saltpepper'
            fieldName = 'saltPepperDensity';  label = 'Density';
            text = ['Salt & pepper noise: a fraction of the pixels becomes pure black (0) or pure white (255), ' ...
                    'like transmission errors. Paper value: density 0.05 (5% of the pixels).'];
        otherwise
            fieldName = 'speckleVar';  label = 'Variance';
            text = ['Speckle noise: multiplicative noise J = I + n.*I, typical of radar and ultrasound ' ...
                    'images. Paper value: variance 0.04.'];
    end
end

function s = shortName(label)
    s = strrep(label, ' noise', '');
end

function t = verdict(nc)
    if nc >= 0.9
        t = 'The logo survived the attack very well.';
    elseif nc >= 0.75
        t = 'The logo is damaged but still clearly recognisable.';
    elseif nc >= 0.5
        t = 'The logo is badly damaged.';
    else
        t = 'The logo was destroyed by this attack.';
    end
end

% ---------------- image display helpers -----------------------------------
function showImage(ax, img, ttl)
% Shows an image in a uiaxes (core MATLAB, no imshow).
%   img : uint8 gray/RGB, logical, or double 0..1.   [] clears the axes.
    cla(ax);
    legend(ax, 'off');
    trySet(ax.Toolbar, 'Visible', 'off');          % no "..." toolbar on pictures
    try disableDefaultInteractivity(ax); catch, end
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
        if ismatrix(u)
            u = cat(3, u, u, u);
        end
        im = image(ax, u);
        im.ButtonDownFcn = @(~, ~) openImageViewer(u, ttl);    % click = open large
        [h, w, ~] = size(u);
        ax.XLim = [0.5 w + 0.5];
        ax.YLim = [0.5 h + 0.5];
        ax.YDir = 'reverse';
        ax.DataAspectRatio = [1 1 1];
        ax.XTick = [];
        ax.YTick = [];
    end
    title(ax, ttl, 'FontSize', 11);
end

function out = normalise(M)
% Linear stretch of min..max to 0..1.
    lo = min(M(:));  hi = max(M(:));
    if hi > lo, out = (M - lo) / (hi - lo); else, out = zeros(size(M)); end
end

function out = stretch(M)
% |M| scaled so the brightest 1 % saturates - makes weak detail bands visible.
    v = sort(abs(M(:)));
    cap = v(max(1, ceil(0.99 * numel(v))));
    if cap <= 0, cap = max(v(end), eps); end
    out = min(abs(M) / cap, 1);
end

function out = logView(D)
% log(1 + |D|) scaled to 0..1 - the usual way to look at DCT values.
    out = normalise(log(1 + abs(D)));
end

function out = logoForDisplay(We, isBinary)
    if isBinary
        out = double(We > 0.5);
    else
        out = clamp01(We);
    end
end

% ---------------- small formatting helpers --------------------------------
function x = clamp01(x)
% NC (and the raw extracted logo) shown in the range 0..1.
    x = min(max(x, 0), 1);
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

function s = fmtNum(x, fmt)
    if isnan(x)
        s = 'n/a';
    elseif isinf(x)
        if x > 0, s = 'Inf'; else, s = '-Inf'; end
    else
        s = sprintf(fmt, x);
    end
end
