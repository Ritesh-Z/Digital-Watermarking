function img = hy_load_image(filePath)
% HY_LOAD_IMAGE  Reads an image file for the GUI and returns a plain uint8
% image that the rest of the project can use:
%       M x N      grayscale
%       M x N x 3  RGB
%
%   img = hy_load_image(filePath)
%
% Handles the things imread leaves to the caller: palette (indexed) images,
% 16-bit and logical images, extra channels, animated GIFs (first frame) and
% transparency (transparent pixels become white, so a transparent logo
% background counts as "light background"). Only core MATLAB is used.
% A clear error is thrown if the file is missing or is not an image.

    if nargin < 1 || isempty(filePath) || ~(ischar(filePath) || isstring(filePath))
        error('hy_load_image:noFile', 'No image file was selected.');
    end
    filePath = char(filePath);
    if ~isfile(filePath)
        error('hy_load_image:notFound', 'The file "%s" does not exist.', filePath);
    end

    try
        [raw, map, alpha] = imread(filePath);
    catch ME
        % "File format ... is not supported" means MATLAB's list of image
        % formats (imformats) is damaged or was changed. Reset it to the
        % factory defaults and try once more.
        recovered = false;
        if ~isempty(strfind(ME.message, 'not supported'))
            try
                imformats('factory');
                [raw, map, alpha] = imread(filePath);
                recovered = true;
            catch
                recovered = false;
            end
        end
        if ~recovered
            error('hy_load_image:unreadable', ...
                  ['The file "%s" could not be read as an image (%s). If every image fails ' ...
                   'with a "format not supported" message, MATLAB''s path or image-format ' ...
                   'list is damaged: run  restoredefaultpath; rehash toolboxcache  and restart MATLAB.'], ...
                  filePath, ME.message);
        end
    end
    if isempty(raw)
        error('hy_load_image:empty', 'The image file "%s" is empty.', filePath);
    end

    if ndims(raw) == 4              % multi-frame file: keep the first frame
        raw = raw(:, :, :, 1);
    end

    % Transparency (PNG etc.) as a 0..1 matrix, if the file has one
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

    % Palette (indexed) image -> RGB
    if ~isempty(map)
        raw = ind2rgb(raw, map);                 % double RGB in [0, 1]
        raw = uint8(round(255 * raw));
        alphaF = [];
    end

    % Bring every data type to uint8
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
            d = double(raw);
            lo = min(d(:));
            hi = max(d(:));
            if hi == lo
                raw = zeros(size(d), 'uint8');
            else
                raw = uint8(round(255 * (d - lo) / (hi - lo)));
            end
    end

    % Keep 1 channel (gray) or 3 channels (RGB)
    if ndims(raw) == 3
        nCh = size(raw, 3);
        if nCh == 1 || nCh == 2
            raw = raw(:, :, 1);
        elseif nCh > 3
            raw = raw(:, :, 1:3);
        end
    end

    % Put transparent pixels on a white background
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
