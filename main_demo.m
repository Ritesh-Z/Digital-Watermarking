%% DIGITAL WATERMARKING USING DCT - MAIN DEMO SCRIPT
% This script demonstrates invisible digital watermarking based on
% block-based DCT coefficient comparison.
%
% Pipeline: Load cover image -> Generate/load watermark -> Embed ->
%           Extract -> Evaluate (PSNR, NC, BER) -> Robustness tests
%
% NOTE: This version needs NO Image Processing Toolbox. Every function
% that toolbox would normally provide (dct2/idct2, rgb2gray, imresize,
% imnoise, medfilt2, psnr, imbinarize) has been hand-written below using
% only base MATLAB. Only imread/imwrite/figure/imshow are used from
% outside base MATLAB, and those ship with MATLAB itself, not the toolbox.

clc; clear; close all;

%% 1. Load cover image
if isfile('cover.jpg')
    cover = imread('cover.jpg');
elseif isfile('cover.png')
    cover = imread('cover.png');
else
    try
        cover = imread('cameraman.tif');
    catch
        error(['No cover image found. Place a file named cover.jpg or ' ...
               'cover.png in this folder.']);
    end
end

if size(cover, 3) == 3
    cover = manual_rgb2gray(cover);
end
cover = manual_imresize(cover, [256 256]);   % must be divisible by 8
cover = uint8(cover);

figure, imshow(cover), title('Original Cover Image');

%% 2. Generate / load the watermark
wmRows = size(cover,1) / 8;   % 32
wmCols = size(cover,2) / 8;   % 32

if isfile('logo.png')
    wmImg = imread('logo.png');
    if size(wmImg,3) == 3
        wmImg = manual_rgb2gray(wmImg);
    end
    wmImg = manual_imresize(wmImg, [wmRows wmCols]);
    wmThresh = mean(double(wmImg(:)));
    wmImg = wmImg > wmThresh;
else
    rng(42);
    txtImg = zeros(wmRows, wmCols);
    txtImg = insertTextSafe(txtImg, 'VIT');
    wmImg = logical(txtImg);
end

watermarkBits = double(wmImg(:))';
numBits = length(watermarkBits);

figure, imshow(wmImg), title('Original Watermark (32x32 binary)');

%% 3. Embed the watermark
alpha = 25;  % embedding strength: increase for robustness, decrease for imperceptibility
watermarked = dct_watermark_embed(cover, watermarkBits, alpha);

figure, imshow(watermarked), title('Watermarked Image (visually identical)');
imwrite(watermarked, 'watermarked_image.png');

%% 4. Extract the watermark (no attack) and evaluate
extractedBits = dct_watermark_extract(watermarked, numBits);
extractedImg = reshape(extractedBits, wmRows, wmCols);

[psnrVal, ncVal, berVal] = calculate_metrics(cover, watermarked, watermarkBits, extractedBits);

figure, imshow(extractedImg), title('Extracted Watermark (no attack)');
fprintf('--- No Attack ---\n');
fprintf('PSNR: %.2f dB\n', psnrVal);
fprintf('NC  : %.4f\n', ncVal);
fprintf('BER : %.4f\n\n', berVal);

%% 5. Robustness tests
% (a) JPEG compression
imwrite(watermarked, 'temp_jpeg.jpg', 'Quality', 80);
attackedJPEG = imread('temp_jpeg.jpg');
bitsJPEG = dct_watermark_extract(attackedJPEG, numBits);
[~, ncJPEG, berJPEG] = calculate_metrics(cover, attackedJPEG, watermarkBits, bitsJPEG);
fprintf('--- JPEG Compression (Quality 80) ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncJPEG, berJPEG);

% (b) Additive Gaussian noise
attackedNoise = manual_imnoise_gaussian(watermarked, 0.001);
bitsNoise = dct_watermark_extract(attackedNoise, numBits);
[~, ncNoise, berNoise] = calculate_metrics(cover, attackedNoise, watermarkBits, bitsNoise);
fprintf('--- Gaussian Noise ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncNoise, berNoise);

% (c) Salt & pepper noise
attackedSP = manual_imnoise_saltpepper(watermarked, 0.01);
bitsSP = dct_watermark_extract(attackedSP, numBits);
[~, ncSP, berSP] = calculate_metrics(cover, attackedSP, watermarkBits, bitsSP);
fprintf('--- Salt & Pepper Noise ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncSP, berSP);

% (d) Median filtering
attackedMedian = manual_medfilt2(watermarked, 3);
bitsMedian = dct_watermark_extract(attackedMedian, numBits);
[~, ncMedian, berMedian] = calculate_metrics(cover, attackedMedian, watermarkBits, bitsMedian);
fprintf('--- Median Filtering (3x3) ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncMedian, berMedian);

%% 6. Visualize all extracted watermarks side by side
figure;
subplot(2,3,1), imshow(wmImg), title('Original WM');
subplot(2,3,2), imshow(extractedImg), title('No Attack');
subplot(2,3,3), imshow(reshape(bitsJPEG, wmRows, wmCols)), title('After JPEG');
subplot(2,3,4), imshow(reshape(bitsNoise, wmRows, wmCols)), title('After Gaussian Noise');
subplot(2,3,5), imshow(reshape(bitsSP, wmRows, wmCols)), title('After Salt & Pepper');
subplot(2,3,6), imshow(reshape(bitsMedian, wmRows, wmCols)), title('After Median Filter');

%% ===================== Toolbox-free helper functions =====================

function gray = manual_rgb2gray(rgbImg)
% Standard luminance formula, same weights rgb2gray uses internally.
    rgbImg = double(rgbImg);
    gray = uint8(0.2989*rgbImg(:,:,1) + 0.5870*rgbImg(:,:,2) + 0.1140*rgbImg(:,:,3));
end

function out = manual_imresize(img, outSize)
% Nearest-neighbor resize - simple, robust, no toolbox needed.
% Works for 2D grayscale/logical images.
    img = double(img);
    [inRows, inCols] = size(img);
    outRows = outSize(1); outCols = outSize(2);
    rIdx = round(linspace(1, inRows, outRows));
    cIdx = round(linspace(1, inCols, outCols));
    rIdx(rIdx < 1) = 1; cIdx(cIdx < 1) = 1;
    out = img(rIdx, cIdx);
end

function out = manual_imnoise_gaussian(img, variance)
% Adds zero-mean Gaussian noise, image treated on a [0,1] scale
% (matching imnoise's convention) then converted back to uint8.
    imgD = double(img) / 255;
    noise = sqrt(variance) * randn(size(imgD));
    noisy = min(max(imgD + noise, 0), 1);
    out = uint8(noisy * 255);
end

function out = manual_imnoise_saltpepper(img, density)
% Randomly sets a fraction 'density' of pixels to 0 or 255.
    imgD = double(img);
    mask = rand(size(imgD));
    imgD(mask < density/2) = 0;
    imgD(mask >= density/2 & mask < density) = 255;
    out = uint8(imgD);
end

function out = manual_medfilt2(img, winSize)
% Simple sliding-window median filter with replicate-edge padding.
    imgD = double(img);
    [rows, cols] = size(imgD);
    pad = floor(winSize/2);

    padded = zeros(rows+2*pad, cols+2*pad);
    padded(pad+1:pad+rows, pad+1:pad+cols) = imgD;
    padded(1:pad, pad+1:pad+cols) = repmat(imgD(1,:), pad, 1);
    padded(pad+rows+1:end, pad+1:pad+cols) = repmat(imgD(end,:), pad, 1);
    padded(:, 1:pad) = repmat(padded(:, pad+1), 1, pad);
    padded(:, pad+cols+1:end) = repmat(padded(:, pad+cols), 1, pad);

    out = zeros(rows, cols);
    for r = 1:rows
        for c = 1:cols
            window = padded(r:r+winSize-1, c:c+winSize-1);
            out(r,c) = median(window(:));
        end
    end
    out = uint8(out);
end

function img = insertTextSafe(img, txt)
% Draws simple block text into a small binary canvas using only core
% graphics functions (figure/text/getframe), no toolbox needed.
    fig = figure('Visible', 'off', 'Color', 'k', ...
                 'Units', 'pixels', 'Position', [0 0 size(img,2) size(img,1)]);
    ax = axes('Parent', fig, 'Position', [0 0 1 1], 'Color', 'k');
    text(ax, 0.5, 0.5, txt, 'Color', 'w', 'FontSize', size(img,1)*0.5, ...
         'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
         'VerticalAlignment', 'middle');
    axis(ax, 'off');
    frame = getframe(ax);
    close(fig);
    gray = manual_rgb2gray(frame.cdata);
    img = double(manual_imresize(gray, [size(img,1), size(img,2)]) > 128);
end
