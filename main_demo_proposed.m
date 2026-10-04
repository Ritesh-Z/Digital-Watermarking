%% DIGITAL WATERMARKING - PROPOSED TRIPLE-CARRIER SCHEME - MAIN DEMO
% Blind, keyed watermarking where every 8x8 block carries three
% independent copies of each bit (DC brightness, a low-frequency DCT pair
% difference, and the order of a mid-frequency pair). A blind decoder
% trusts whichever carrier survived the attack.
% (MATLAB port of the Python project in python/; see PROPOSED_SCHEME.md.)
%
% Pipeline: load cover -> load/generate 32x32 logo -> embed with key ->
%           extract -> PSNR / NC / BER -> 11 attacks (MATLAB + paper + extra)
%
% NOTE: toolbox-free, like the other demos. Needs the helper files in this
% folder (img_to_blocks, wm_layout, qim_*, manual_*, ...).

clc; clear; close all;

%% 1. Load cover image (512x512 so every bit gets 3 copies per carrier)
if isfile('cover.jpg')
    cover = imread('cover.jpg');
elseif isfile('cover.png')
    cover = imread('cover.png');
else
    error('No cover image found. Place cover.jpg or cover.png in this folder.');
end
if size(cover, 3) == 3
    cover = manual_rgb2gray(cover);
end
cover = uint8(manual_imresize(cover, [512 512]));
figure, imshow(cover), title('Original Cover Image');

%% 2. Generate / load the 32x32 binary watermark
wmRows = 32; wmCols = 32;
if isfile('logo.png')
    wmImg = imread('logo.png');
    if size(wmImg, 3) == 3
        wmImg = manual_rgb2gray(wmImg);
    end
    wmImg = manual_imresize(wmImg, [wmRows wmCols]);
    wmImg = wmImg > mean(double(wmImg(:)));
else
    wmImg = logical(insertTextSafe(zeros(wmRows, wmCols), 'VIT'));
end
watermarkBits = double(wmImg(:))';
numBits = numel(watermarkBits);
figure, imshow(wmImg), title('Original Watermark (32x32 binary)');

%% 3. Embed
alpha = 28;     % strength: ~41 dB PSNR on a typical photo
key = 2025;     % secret key - the SAME key is needed to extract
watermarked = proposed_watermark_embed(cover, watermarkBits, alpha, key);
figure, imshow(watermarked), title('Watermarked Image (proposed)');
imwrite(watermarked, 'watermarked_image_proposed.png');

%% 4. Extract (no attack) and evaluate
extractedBits = proposed_watermark_extract(watermarked, numBits, alpha, key);
[psnrVal, ncVal, berVal] = calculate_metrics(cover, watermarked, watermarkBits, extractedBits);
fprintf('--- No Attack ---\nPSNR: %.2f dB\nNC  : %.4f\nBER : %.4f\n\n', psnrVal, ncVal, berVal);

%% 5. Robustness tests (your 4 MATLAB attacks + the paper's + extra)
attacks = {};
imwrite(watermarked, 'temp_jpeg_proposed.jpg', 'Quality', 80);
attacks(end+1, :) = {'JPEG Q80', imread('temp_jpeg_proposed.jpg')};
attacks(end+1, :) = {'Gaussian noise', manual_imnoise_gaussian(watermarked, 0.001)};
attacks(end+1, :) = {'Salt & pepper', manual_imnoise_saltpepper(watermarked, 0.01)};
attacks(end+1, :) = {'Median 3x3', manual_medfilt2(watermarked, 3)};
attacks(end+1, :) = {'Sharpening', manual_sharpen(watermarked, 1.0)};
attacks(end+1, :) = {'Gaussian blur', manual_gaussian_blur(watermarked, 1.0)};
hl = watermarked; hl(1:32:end, :) = 255;  attacks(end+1, :) = {'Horizontal lines', hl};
vl = watermarked; vl(:, 1:32:end) = 255;  attacks(end+1, :) = {'Vertical lines', vl};
attacks(end+1, :) = {'Rotation 2 deg', manual_imrotate(watermarked, 2)};
cr = watermarked; cr(1:256, 1:256) = 0;   attacks(end+1, :) = {'Crop 25%', cr};
attacks(end+1, :) = {'Scale 0.5x', uint8(manual_imresize(manual_imresize(watermarked, [256 256]), [512 512]))};

results = zeros(size(attacks, 1), 2);
extracted = cell(size(attacks, 1), 1);
for i = 1:size(attacks, 1)
    [bits, ang] = proposed_watermark_extract(attacks{i, 2}, numBits, alpha, key);
    [~, nc, ber] = calculate_metrics(cover, attacks{i, 2}, watermarkBits, bits);
    results(i, :) = [nc ber];
    extracted{i} = reshape(bits, wmRows, wmCols);
    if ang ~= 0
        fprintf('--- %-16s NC: %.4f | BER: %.4f   (re-synced %.2f deg)\n', attacks{i, 1}, nc, ber, ang);
    else
        fprintf('--- %-16s NC: %.4f | BER: %.4f\n', attacks{i, 1}, nc, ber);
    end
end
fprintf('\nMean NC over 11 attacks: %.4f\n', mean(results(:, 1)));

%% 6. Visualise all extracted watermarks
figure('Name', 'Proposed scheme - extracted watermarks');
subplot(3, 5, 1), imshow(wmImg), title('Original WM');
subplot(3, 5, 2), imshow(reshape(extractedBits, wmRows, wmCols)), title('No attack');
for i = 1:size(attacks, 1)
    subplot(3, 5, i + 2), imshow(extracted{i}), title(sprintf('%s\nNC %.3f', attacks{i, 1}, results(i, 1)));
end
