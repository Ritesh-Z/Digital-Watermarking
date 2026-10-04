%% DIGITAL WATERMARKING - BASE PAPER HYBRID DWT-DCT-SVD - MAIN DEMO
% Reproduction of: Loke, Swami & Kulkarni, "Hybrid Digital Watermarking
% Using DWT, DCT and SVD for Robust Image Protection", IJES 2025.
%
% Pipeline: Haar DWT -> chosen band -> 4x4 block DCT -> matrix of DC
%           coefficients -> SVD -> S' = S + alpha*Sw -> inverse
% NON-BLIND: extraction needs the saved key (Sc, Uw, Vw).
% The paper's six attacks are tested: sharpening, Gaussian blur,
% horizontal lines, vertical lines, salt & pepper, rotation.

clc; clear; close all;

%% 1. Cover (512x512 -> the DC matrix is 64x64)
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

%% 2. Grayscale watermark, size of the DC matrix (64x64)
if isfile('logo.png')
    wmImg = imread('logo.png');
    if size(wmImg, 3) == 3
        wmImg = manual_rgb2gray(wmImg);
    end
    wmImg = uint8(manual_imresize(wmImg, [64 64]));
else
    wmImg = uint8(insertTextSafe(zeros(64, 64), 'VIT') * 255);
end

%% 3. Embed (paper's HH band)
alpha = 0.1;  band = 'HH';
[watermarked, Sc, Uw, Vw] = hybrid_paper_embed(cover, wmImg, alpha, band);
extracted = hybrid_paper_extract(watermarked, Sc, Uw, Vw, alpha, band);
[psnrVal, corrVal] = calculate_metrics_svd(cover, watermarked, wmImg, extracted);
fprintf('--- No Attack ---\nPSNR       : %.2f dB\nCorrelation: %.4f\n\n', psnrVal, corrVal);

%% 4. The paper's six attacks
hl = watermarked; hl(1:32:end, :) = 255;
vl = watermarked; vl(:, 1:32:end) = 255;
attacks = {'Sharpening', manual_sharpen(watermarked, 1.0);
           'Gaussian blur', manual_gaussian_blur(watermarked, 1.0);
           'Horizontal lines', hl;
           'Vertical lines', vl;
           'Salt & pepper', manual_imnoise_saltpepper(watermarked, 0.01);
           'Rotation 2 deg', manual_imrotate(watermarked, 2)};
figure('Name', 'Base paper hybrid - extracted watermarks');
subplot(2, 4, 1), imshow(wmImg), title('Original WM');
subplot(2, 4, 2), imshow(extracted), title('No attack');
for i = 1:size(attacks, 1)
    ext = hybrid_paper_extract(attacks{i, 2}, Sc, Uw, Vw, alpha, band);
    [~, c] = calculate_metrics_svd(cover, attacks{i, 2}, wmImg, ext);
    fprintf('--- %-16s Correlation: %.4f\n', attacks{i, 1}, c);
    subplot(2, 4, i + 2), imshow(ext), title(sprintf('%s\n%.3f', attacks{i, 1}, c));
end
