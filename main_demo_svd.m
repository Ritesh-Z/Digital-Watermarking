%% DIGITAL WATERMARKING USING SVD - MAIN DEMO SCRIPT
% This script demonstrates watermarking based on Singular Value
% Decomposition (SVD): A = U * S * V'. The watermark's singular values
% are added onto the cover image's singular values.
%
% Pipeline: Load cover image -> Load/generate watermark (SAME SIZE as
%           cover) -> Embed via additive SVD -> Extract using the saved
%           key -> Evaluate (PSNR, correlation) -> Robustness tests
%
% IMPORTANT - read this before you write your report:
% This is a NON-BLIND (semi-blind) scheme. Extraction needs a "key"
% produced at embedding time: the cover's ORIGINAL singular values
% (Sa_orig) plus the watermark's own U and V matrices (Uw, Vw). This is
% a genuine, well-known property of SVD watermarking, not a limitation
% of this code - it's fundamentally different from your DCT and DWT
% projects, which could extract the watermark blindly (no key needed).
%
% NOTE: svd() is base MATLAB (linear algebra), not a toolbox function,
% so this needs NO toolboxes at all. It still uses the shared helper
% files manual_rgb2gray.m, manual_imresize.m, manual_imnoise_gaussian.m,
% manual_imnoise_saltpepper.m, manual_medfilt2.m, insertTextSafe.m -
% make sure they're all in this same folder (from your DCT/DWT projects).

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
cover = manual_imresize(cover, [256 256]);
cover = uint8(cover);

figure, imshow(cover), title('Original Cover Image');

%% 2. Load / generate the watermark
% NOTE: for this classic SVD method, the watermark image must be the
% SAME SIZE as the cover image (256x256) - not a small 32x32 bit pattern
% like the DCT/DWT projects. It can be a full grayscale image.
if isfile('logo.png')
    wmImg = imread('logo.png');
    if size(wmImg,3) == 3
        wmImg = manual_rgb2gray(wmImg);
    end
    wmImg = manual_imresize(wmImg, [256 256]);
else
    txtImg = zeros(256, 256);
    txtImg = insertTextSafe(txtImg, 'VIT');
    wmImg = uint8(txtImg * 255);
end

figure, imshow(wmImg), title('Original Watermark (256x256 grayscale)');

%% 3. Embed the watermark
alpha = 0.05;  % embedding strength: increase for robustness, decrease for imperceptibility
               % (try 0.01 for "very invisible", 0.05 for "balanced", 0.2 for "very robust")
[watermarked, Sa_orig, Uw, Vw] = svd_watermark_embed(cover, wmImg, alpha);

figure, imshow(watermarked), title('Watermarked Image (visually near-identical)');
imwrite(watermarked, 'watermarked_image_svd.png');

%% 4. Extract the watermark (no attack) and evaluate
extractedW = svd_watermark_extract(watermarked, Sa_orig, Uw, Vw, alpha);
[psnrVal, corrVal] = calculate_metrics_svd(cover, watermarked, wmImg, extractedW);

figure, imshow(extractedW), title('Extracted Watermark (no attack)');
fprintf('--- No Attack ---\n');
fprintf('PSNR       : %.2f dB\n', psnrVal);
fprintf('Correlation: %.4f\n\n', corrVal);

%% 5. Robustness tests
% Remember: Sa_orig, Uw, Vw are the KEY from step 3 - they stay the same
% for every extraction attempt below, even on attacked images. We are
% NOT recomputing them from the attacked image.

% (a) JPEG compression
imwrite(watermarked, 'temp_jpeg_svd.jpg', 'Quality', 80);
attackedJPEG = imread('temp_jpeg_svd.jpg');
extJPEG = svd_watermark_extract(attackedJPEG, Sa_orig, Uw, Vw, alpha);
[~, corrJPEG] = calculate_metrics_svd(cover, attackedJPEG, wmImg, extJPEG);
fprintf('--- JPEG Compression (Quality 80) ---\n');
fprintf('Correlation: %.4f\n\n', corrJPEG);

% (b) Additive Gaussian noise
attackedNoise = manual_imnoise_gaussian(watermarked, 0.001);
extNoise = svd_watermark_extract(attackedNoise, Sa_orig, Uw, Vw, alpha);
[~, corrNoise] = calculate_metrics_svd(cover, attackedNoise, wmImg, extNoise);
fprintf('--- Gaussian Noise ---\n');
fprintf('Correlation: %.4f\n\n', corrNoise);

% (c) Salt & pepper noise
attackedSP = manual_imnoise_saltpepper(watermarked, 0.01);
extSP = svd_watermark_extract(attackedSP, Sa_orig, Uw, Vw, alpha);
[~, corrSP] = calculate_metrics_svd(cover, attackedSP, wmImg, extSP);
fprintf('--- Salt & Pepper Noise ---\n');
fprintf('Correlation: %.4f\n\n', corrSP);

% (d) Median filtering
attackedMedian = manual_medfilt2(watermarked, 3);
extMedian = svd_watermark_extract(attackedMedian, Sa_orig, Uw, Vw, alpha);
[~, corrMedian] = calculate_metrics_svd(cover, attackedMedian, wmImg, extMedian);
fprintf('--- Median Filtering (3x3) ---\n');
fprintf('Correlation: %.4f\n\n', corrMedian);

%% 6. Visualize all extracted watermarks side by side
figure;
subplot(2,3,1), imshow(wmImg), title('Original WM');
subplot(2,3,2), imshow(extractedW), title('No Attack');
subplot(2,3,3), imshow(extJPEG), title('After JPEG');
subplot(2,3,4), imshow(extNoise), title('After Gaussian Noise');
subplot(2,3,5), imshow(extSP), title('After Salt & Pepper');
subplot(2,3,6), imshow(extMedian), title('After Median Filter');
