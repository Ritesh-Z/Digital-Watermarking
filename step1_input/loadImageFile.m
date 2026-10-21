function img = loadImageFile(filePath)
% LOADIMAGEFILE  Reads any image file and returns a clean uint8 image.
%
% PIPELINE:  STEP 1 (input) - first thing that happens to every image the
%            user picks. Output goes to prepareCoverImage / prepareWatermarkLogo.
%
%   img = loadImageFile(filePath)
%
% OUTPUT
%   img : M x N      uint8 grayscale image, or
%         M x N x 3  uint8 RGB image
%
% WHY THIS FILE EXISTS
%   imread() can return many different formats. This function turns all of
%   them into plain uint8 so the rest of the project never has to care:
%     - palette (indexed) images  -> RGB
%     - 16-bit / logical / double -> uint8 (0..255)
%     - extra channels            -> dropped (keep gray or RGB)
%     - animated GIF              -> first frame
%     - transparency (PNG alpha)  -> transparent pixels become WHITE, so a
%                                    transparent logo background counts as
%                                    "light background"
%   Only core MATLAB is used (no toolbox).

    % ---- 1. Check the path -------------------------------------------------
    if nargin < 1 || isempty(filePath) || ~(ischar(filePath) || isstring(filePath))
        error('loadImageFile:noFile', 'No image file was selected.');
    end
    filePath = char(filePath);
    if ~isfile(filePath)
        error('loadImageFile:notFound', 'The file "%s" does not exist.', filePath);
    end

    % ---- 2. Read the file --------------------------------------------------
    try
        [raw, map, alpha] = imread(filePath);
    catch ME
        % "File format ... is not supported" usually means MATLAB's list of
        % image formats (imformats) was damaged. Reset it once and retry.
        recovered = false;
        if contains(ME.message, 'not supported')
            try
                imformats('factory');
                [raw, map, alpha] = imread(filePath);
                recovered = true;
            catch
                recovered = false;
            end
        end
        if ~recovered
            error('loadImageFile:unreadable', ...
                  ['The file "%s" could not be read as an image (%s). If every image fails ' ...
                   'with a "format not supported" message, run  restoredefaultpath; ' ...
                   'rehash toolboxcache  and restart MATLAB.'], filePath, ME.message);
        end
    end
    if isempty(raw)
        error('loadImageFile:empty', 'The image file "%s" is empty.', filePath);
    end

    if ndims(raw) == 4                      % multi-frame file -> first frame
        raw = raw(:, :, :, 1);
    end

    % ---- 3. Transparency as a 0..1 matrix (if the file has one) -------------
    alphaF = [];
    if ~isempty(alpha) && size(alpha, 1) == size(raw, 1) && size(alpha, 2) == size(raw, 2)
        if islogical(alpha)
            alphaF = double(alpha(:, :, 1));
        elseif isinteger(alpha)
            alphaF = double(alpha(:, :, 1)) / double(intmax(class(alpha)));
        else
            alphaF = min(max(double(alpha(:, :, 1)), 0), 1);
        end
    end

    % ---- 4. Palette (indexed) image -> RGB ----------------------------------
    if ~isempty(map)
        raw = uint8(round(255 * ind2rgb(raw, map)));
        alphaF = [];
    end

    % ---- 5. Any data type -> uint8 -------------------------------------------
    switch class(raw)
        case 'uint8'
            % already fine
        case 'uint16'
            raw = uint8(double(raw) / 257);
        case 'logical'
            raw = uint8(raw) * 255;
        case {'double', 'single'}
            raw = uint8(round(255 * min(max(double(raw), 0), 1)));
        otherwise
            d  = double(raw);
            lo = min(d(:));
            hi = max(d(:));
            if hi == lo
                raw = zeros(size(d), 'uint8');
            else
                raw = uint8(round(255 * (d - lo) / (hi - lo)));
            end
    end

    % ---- 6. Keep 1 channel (gray) or 3 channels (RGB) -----------------------
    if ndims(raw) == 3
        nCh = size(raw, 3);
        if nCh == 1 || nCh == 2
            raw = raw(:, :, 1);
        elseif nCh > 3
            raw = raw(:, :, 1:3);
        end
    end

    % ---- 7. Put transparent pixels on a white background --------------------
    if ~isempty(alphaF)
        if ndims(raw) == 3
            a = repmat(alphaF, [1 1 3]);
        else
            a = alphaF;
        end
        raw = uint8(round(double(raw) .* a + 255 * (1 - a)));
    end

    img = raw;
end
