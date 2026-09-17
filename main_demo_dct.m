%% DIGITAL WATERMARKING USING DCT - MAIN DEMO SCRIPT
% This script demonstrates invisible digital watermarking based on
% block-based DCT coefficient comparison.
%
% Pipeline: Load cover image -> Generate/load watermark -> Embed ->
%           Extract -> Evaluate (PSNR, NC, BER) -> Robustness tests
%
% NOTE: This version needs NO Image Processing Toolbox. All helper
% functions (manual_rgb2gray, manual_imresize, manual_imnoise_gaussian,
% manual_imnoise_saltpepper, manual_medfilt2, insertTextSafe) live in
% their own .m files in this same folder - make sure they're all present.

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
