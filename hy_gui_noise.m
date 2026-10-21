function sel = hy_gui_noise(parentFig)
% HY_GUI_NOISE  Second window: a small modal popup where the user picks the
% noise that is applied to the watermarked image. Default: None.
%
%   sel = hy_gui_noise(parentFig)
%
%   sel : [] if the user pressed Cancel or closed the window, otherwise a
%         struct with fields
%           type   'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%           label  text for titles
%           cfg    noise strengths (gaussVar, saltPepperDensity, speckleVar)
%           value  the strength typed in (NaN when the noise has none)

    sel = [];

    defaults    = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
    items       = {'None', 'Gaussian Noise', 'Shot (Poisson) Noise', 'Salt-and-Pepper Noise', 'Speckle Noise'};
    types       = {'none', 'gaussian', 'shot', 'saltpepper', 'speckle'};
    shortLabels = {'None', 'Gaussian', 'Shot (Poisson)', 'Salt-and-Pepper', 'Speckle'};

    w = 440;  h = 330;
    if nargin >= 1 && ~isempty(parentFig) && isvalid(parentFig)
        pp = parentFig.Position;
        pos = [pp(1) + (pp(3) - w) / 2, pp(2) + (pp(4) - h) / 2, w, h];
    else
        scr = get(0, 'ScreenSize');
        pos = [(scr(3) - w) / 2, (scr(4) - h) / 2, w, h];
    end

    dlg = uifigure('Name', '2. Select the noise', 'Position', pos, ...
                   'Resize', 'off', 'WindowStyle', 'modal');

    uilabel(dlg, 'Text', 'Noise to apply to the watermarked image:', ...
            'Position', [20 285 400 24], 'FontWeight', 'bold');
    dd = uidropdown(dlg, 'Items', items, 'Value', 'None', ...
                    'Position', [20 248 400 28], 'ValueChangedFcn', @onChange);
    lblParam = uilabel(dlg, 'Text', '', 'Position', [20 205 235 22]);
    edt = uieditfield(dlg, 'numeric', 'Value', 0, 'Enable', 'off', ...
                      'ValueDisplayFormat', '%.4g', 'Position', [265 205 100 22]);
    lblHelp = uilabel(dlg, 'Text', '', 'Position', [20 80 400 112], ...
                      'WordWrap', 'on', 'VerticalAlignment', 'top');
    uibutton(dlg, 'push', 'Text', 'Run', 'Position', [70 25 140 38], ...
             'FontWeight', 'bold', 'ButtonPushedFcn', @onRun);
    uibutton(dlg, 'push', 'Text', 'Cancel', 'Position', [230 25 140 38], ...
             'ButtonPushedFcn', @(~, ~) delete(dlg));

    onChange();
    uiwait(dlg);

    % ------------------------------------------------------------------
    function onChange(~, ~)
        idx = find(strcmp(items, dd.Value), 1);
        switch types{idx}
            case 'none'
                lblParam.Text = 'Noise strength: not used';
                edt.Enable = 'off';  edt.Value = 0;
                lblHelp.Text = ['No noise is applied. The watermark is extracted from the ' ...
                                'clean watermarked image.'];
            case 'gaussian'
                lblParam.Text = 'Variance (image scaled 0 to 1):';
                edt.Enable = 'on';  edt.Value = defaults.gaussVar;
                lblHelp.Text = ['Zero-mean Gaussian noise is added to the watermarked image. ' ...
                                'The default variance 0.01 is the value used in the project.'];
            case 'shot'
                lblParam.Text = 'Noise strength: not used';
                edt.Enable = 'off';  edt.Value = 0;
                lblHelp.Text = ['Shot (Poisson) noise depends on the pixel brightness and has ' ...
                                'no strength setting.'];
            case 'saltpepper'
                lblParam.Text = 'Density (fraction of pixels, 0 to 1):';
                edt.Enable = 'on';  edt.Value = defaults.saltPepperDensity;
                lblHelp.Text = ['A fraction of the pixels is set to black or white. The default ' ...
                                'density 0.05 is the value used in the project.'];
            case 'speckle'
                lblParam.Text = 'Variance:';
                edt.Enable = 'on';  edt.Value = defaults.speckleVar;
                lblHelp.Text = ['Multiplicative speckle noise. The default variance 0.04 is the ' ...
                                'value used in the project.'];
        end
    end

    function onRun(~, ~)
        idx = find(strcmp(items, dd.Value), 1);
        t = types{idx};
        cfgOut = defaults;
        v = NaN;
        field = '';
        switch t
            case 'gaussian',   field = 'gaussVar';
            case 'saltpepper', field = 'saltPepperDensity';
            case 'speckle',    field = 'speckleVar';
        end
        if ~isempty(field)
            v = edt.Value;
            if ~(isfinite(v) && v > 0 && v <= 1)
                uialert(dlg, 'Enter a value greater than 0 and at most 1.', 'Invalid noise strength');
                return;
            end
            cfgOut.(field) = v;
        end
        sel = struct('type', t, 'label', shortLabels{idx}, 'cfg', cfgOut, 'value', v);
        delete(dlg);
    end
end
