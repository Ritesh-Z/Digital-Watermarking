%% DIGITAL WATERMARKING USING DWT - MAIN DEMO SCRIPT
% This script demonstrates invisible digital watermarking based on a
% single-level Haar Discrete Wavelet Transform (DWT), embedding the
% watermark into the HL (vertical detail) sub-band using odd-even
% quantization index modulation (QIM).
%
% Pipeline: Load cover image -> DWT decompose -> Generate/load watermark
%           -> Embed into HL sub-band -> Inverse DWT -> Extract ->
%           Evaluate (PSNR, NC, BER) -> Robustness tests
%
% NOTE: Needs NO toolboxes. The Haar DWT (manual_dwt2_haar /
% manual_idwt2_haar) and every helper (manual_rgb2gray, manual_imresize,
% manual_imnoise_gaussian, manual_imnoise_saltpepper, manual_medfilt2,
% insertTextSafe) are hand-written and live in their own .m files in
% this same folder - make sure they're all present (same folder you
% used for the DCT project).

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
cover = manual_imresize(cover, [256 256]);   % must be even for DWT pairing
cover = uint8(cover);

figure, imshow(cover), title('Original Cover Image');

%% 2. Decompose the cover image with a single-level Haar DWT
[LL, LH, HL, HH] = manual_dwt2_haar(cover);
% Each sub-band is 128x128 (half the size of the 256x256 cover)

figure;
subplot(2,2,1), imshow(manual_mat2gray(LL)), title('LL (Approximation)');
subplot(2,2,2), imshow(manual_mat2gray(LH)), title('LH (Horizontal Detail)');
subplot(2,2,3), imshow(manual_mat2gray(HL)), title('HL (Vertical Detail) - used for embedding');
subplot(2,2,4), imshow(manual_mat2gray(HH)), title('HH (Diagonal Detail)');
sgtitle('Haar DWT Decomposition of Cover Image');

%% 3. Generate / load the watermark
% We embed 1 bit per HL coefficient, so we can fit up to 128x128 = 16384
% bits. We'll use the same 32x32 = 1024-bit watermark size as the DCT
% project for a fair, direct comparison in your report.
wmRows = 32;
wmCols = 32;

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

%% 4. Embed the watermark into the HL sub-band
alpha = 15;  % quantization step: increase for robustness, decrease for imperceptibility
             % (try 5 for "weak/invisible", 15 for "balanced", 30+ for "very robust")
watermarkedHL = dwt_watermark_embed(HL, watermarkBits, alpha);

% Reconstruct the full watermarked image via inverse DWT
watermarked = manual_idwt2_haar(LL, LH, watermarkedHL, HH);
watermarked = uint8(min(max(watermarked, 0), 255));

figure, imshow(watermarked), title('Watermarked Image (visually identical)');
imwrite(watermarked, 'watermarked_image_dwt.png');

%% 5. Extract the watermark (no attack) and evaluate
[~, ~, HLcheck, ~] = manual_dwt2_haar(watermarked);
extractedBits = dwt_watermark_extract(HLcheck, numBits, alpha);
extractedImg = reshape(extractedBits, wmRows, wmCols);

[psnrVal, ncVal, berVal] = calculate_metrics(cover, watermarked, watermarkBits, extractedBits);

figure, imshow(extractedImg), title('Extracted Watermark (no attack)');
fprintf('--- No Attack ---\n');
fprintf('PSNR: %.2f dB\n', psnrVal);
fprintf('NC  : %.4f\n', ncVal);
fprintf('BER : %.4f\n\n', berVal);

%% 6. Robustness tests
% (a) JPEG compression
imwrite(watermarked, 'temp_jpeg_dwt.jpg', 'Quality', 80);
attackedJPEG = imread('temp_jpeg_dwt.jpg');
[~, ~, HL_JPEG, ~] = manual_dwt2_haar(attackedJPEG);
bitsJPEG = dwt_watermark_extract(HL_JPEG, numBits, alpha);
[~, ncJPEG, berJPEG] = calculate_metrics(cover, attackedJPEG, watermarkBits, bitsJPEG);
fprintf('--- JPEG Compression (Quality 80) ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncJPEG, berJPEG);

% (b) Additive Gaussian noise
attackedNoise = manual_imnoise_gaussian(watermarked, 0.001);
[~, ~, HL_Noise, ~] = manual_dwt2_haar(attackedNoise);
bitsNoise = dwt_watermark_extract(HL_Noise, numBits, alpha);
[~, ncNoise, berNoise] = calculate_metrics(cover, attackedNoise, watermarkBits, bitsNoise);
fprintf('--- Gaussian Noise ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncNoise, berNoise);

% (c) Salt & pepper noise
attackedSP = manual_imnoise_saltpepper(watermarked, 0.01);
[~, ~, HL_SP, ~] = manual_dwt2_haar(attackedSP);
bitsSP = dwt_watermark_extract(HL_SP, numBits, alpha);
[~, ncSP, berSP] = calculate_metrics(cover, attackedSP, watermarkBits, bitsSP);
fprintf('--- Salt & Pepper Noise ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncSP, berSP);

% (d) Median filtering
attackedMedian = manual_medfilt2(watermarked, 3);
[~, ~, HL_Median, ~] = manual_dwt2_haar(attackedMedian);
bitsMedian = dwt_watermark_extract(HL_Median, numBits, alpha);
[~, ncMedian, berMedian] = calculate_metrics(cover, attackedMedian, watermarkBits, bitsMedian);
fprintf('--- Median Filtering (3x3) ---\n');
fprintf('NC : %.4f | BER: %.4f\n\n', ncMedian, berMedian);

%% 7. Visualize all extracted watermarks side by side
figure;
subplot(2,3,1), imshow(wmImg), title('Original WM');
subplot(2,3,2), imshow(extractedImg), title('No Attack');
subplot(2,3,3), imshow(reshape(bitsJPEG, wmRows, wmCols)), title('After JPEG');
subplot(2,3,4), imshow(reshape(bitsNoise, wmRows, wmCols)), title('After Gaussian Noise');
subplot(2,3,5), imshow(reshape(bitsSP, wmRows, wmCols)), title('After Salt & Pepper');
subplot(2,3,6), imshow(reshape(bitsMedian, wmRows, wmCols)), title('After Median Filter');
