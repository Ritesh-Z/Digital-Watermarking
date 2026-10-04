%% SECURITY TEST - can someone falsely claim ownership?
% A watermark only proves ownership if it cannot be "found" where it was
% never embedded. Two tests per scheme:
%   decoy : owner's key run on a natural image that was NEVER watermarked
%   claim : an attacker uses their OWN watermark ("FAKE") and key on the
%           OWNER's image. For SVD schemes they keep the owner's S and swap
%           in their own Uw, Vw (ambiguity attack, Zhang & Li 2005).
% Want: genuine ~ 1, decoy ~ 0, claim ~ 0. A high decoy/claim score is a
% false positive: anyone could claim the image.

clc; clear; close all;
cover = imread('cover.jpg');
if size(cover, 3) == 3, cover = manual_rgb2gray(cover); end
cover = uint8(manual_imresize(cover, [512 512]));
decoy = uint8(manual_imresize(cover(129:384, 129:384), [512 512]));   % 2x zoom: natural, never marked

%% Classic SVD (non-blind)
owner = uint8(manual_imresize(manual_rgb2gray_safe(imread('logo.png')), [512 512]));
fake  = uint8(insertTextSafe(zeros(512, 512), 'FAKE') * 255);
[wmk, Sa, Uw, Vw] = svd_watermark_embed(cover, owner, 0.05);
[~, ~, Uf, Vf] = svd_watermark_embed(cover, fake, 0.05);
[~, gen] = calculate_metrics_svd(cover, wmk, owner, svd_watermark_extract(wmk, Sa, Uw, Vw, 0.05));
[~, dec] = calculate_metrics_svd(cover, wmk, owner, svd_watermark_extract(decoy, Sa, Uw, Vw, 0.05));
[~, clm] = calculate_metrics_svd(cover, wmk, fake,  svd_watermark_extract(wmk, Sa, Uf, Vf, 0.05));
fprintf('Classic SVD   genuine %.3f  decoy %.3f  fake claim %.3f\n', gen, dec, clm);

%% Proposed scheme (blind, keyed)
wmImg = manual_imresize(manual_rgb2gray_safe(imread('logo.png')), [32 32]);
bits = double(wmImg(:)' > mean(double(wmImg(:))));
fakeBits = double(reshape(insertTextSafe(zeros(32, 32), 'FAKE'), 1, []));
alpha = 28; key = 2025;
wmk = proposed_watermark_embed(cover, bits, alpha, key);
[~, gen] = calculate_metrics(cover, wmk, bits, proposed_watermark_extract(wmk, 1024, alpha, key));
[~, dec] = calculate_metrics(cover, wmk, bits, proposed_watermark_extract(decoy, 1024, alpha, key));
[~, clm] = calculate_metrics(cover, wmk, fakeBits, proposed_watermark_extract(wmk, 1024, alpha, key + 7919));
fprintf('Proposed      genuine %.3f  decoy %.3f  fake claim %.3f\n', gen, dec, clm);

function g = manual_rgb2gray_safe(img)
    if size(img, 3) == 3, g = manual_rgb2gray(img(:, :, 1:3)); else, g = img; end
end
