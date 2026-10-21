%% HYBRID DWT-DCT-SVD WATERMARKING WITH BFO AND PSO (PBFO)  -  BATCH DEMO
% This is the ORIGINAL command-line demo (previously main_demo_paper2.m).
% It still uses cover.jpg and the built-in VIT watermark and evaluates all
% four noises at once. The GUI version is now main_demo_paper2.m.
%
% Follows Yildiz, Ustunsoy, Sayan (2024), Politeknik Dergisi 27(3).
%
% Five stages are compared:
%   1. DWT
%   2. DWT-DCT
%   3. DWT-DCT-SVD
%   4. DWT-DCT-SVD-BFO   (alpha chosen by bacterial foraging)
%   5. DWT-DCT-SVD-PBFO  (alpha chosen by BFO whose step size is tuned by PSO)
%
% The watermark goes into the HH band, and extraction is non-blind
% (the original values are kept in a "key"), as in the paper.
% No toolbox is needed. Keep every file from the earlier projects
% (manual_*.m) plus every hy_*.m file in this same folder.

clc; clear; close all;

%% 1. Settings
imgSize      = 256;        % paper uses 512, which is slower
alphaFixed   = 30;         % strength for stages 1 to 3
alphaRange   = [5 100];    % search range for BFO and PBFO
qualityWeight = 0;         % 0 = paper exact. Try 0.1 to also reward image quality
noiseCfg = struct('gaussVar', 0.01, 'saltPepperDensity', 0.05, 'speckleVar', 0.04);
trainSeed = 7;             % noise used while optimising
testSeed  = 99;            % different noise used for the final test
optSeed   = 5;

bfoCfg     = struct('N',6,'nc',5,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
bfoCfgFast = struct('N',4,'nc',3,'ns',2,'nre',2,'ned',1,'Ped',0.25,'step',3);
psoCfg     = struct('nParticles',4,'iters',3,'w',0.6,'c1',1.5,'c2',1.5);
stepRange  = [1 30];

%% 2. Load cover image and watermark
if isfile('cover.jpg')
    cover = imread('cover.jpg');
elseif isfile('cover.png')
    cover = imread('cover.png');
else
    try
        cover = imread('cameraman.tif');
    catch
        error('Put a file named cover.jpg in this folder.');
    end
end
if size(cover, 3) == 3
    cover = manual_rgb2gray(cover);
end
cover = uint8(manual_imresize(cover, [imgSize imgSize]));
W = hy_watermark_vit();

%% 3. Find alpha with BFO and with PBFO
lo = alphaRange(1);  hi = alphaRange(2);
objFcn = @(a) hy_objective(a, cover, W, noiseCfg, trainSeed, qualityWeight);

fprintf('Running BFO (this can take a few minutes)...\n');
tic;
rng(optSeed);
[alphaBFO, costBFO, evalsBFO] = hy_bfo(objFcn, lo, hi, bfoCfg);
tBFO = toc;
fprintf('BFO done: alpha = %.2f, cost = %.4f, %d evaluations, %.1f s\n', ...
        alphaBFO, costBFO, evalsBFO, tBFO);

fprintf('Running PSO to tune the BFO step size...\n');
tic;
trialFcn = @(st) hy_bfo_trial(st, objFcn, lo, hi, bfoCfgFast, optSeed);
[bestStep, ~] = hy_pso(trialFcn, stepRange(1), stepRange(2), psoCfg);
cfgTuned = bfoCfg;
cfgTuned.step = bestStep;
rng(optSeed);
[alphaPBFO, costPBFO, evalsPBFO] = hy_bfo(objFcn, lo, hi, cfgTuned);
tPBFO = toc;
fprintf('PBFO done: step = %.2f, alpha = %.2f, cost = %.4f, %.1f s\n\n', ...
        bestStep, alphaPBFO, costPBFO, tPBFO);

%% 4. Run the five stages
stageNames = {'DWT','DWT-DCT','DWT-DCT-SVD','DWT-DCT-SVD-BFO','DWT-DCT-SVD-PBFO'};
stageType  = [1 2 3 3 3];
alphas     = [alphaFixed alphaFixed alphaFixed alphaBFO alphaPBFO];
noiseNames = {'Gaussian','Shot','Salt&Pepper','Speckle'};
nS = numel(stageNames);

psnrAll = zeros(1, nS);
ssimAll = zeros(1, nS);
atkPsnr = zeros(nS, 4);   % attacked image vs watermarked image
atkSsim = zeros(nS, 4);
ifAll   = zeros(1, nS);
nccAll  = zeros(nS, 4);
wmImgs  = cell(1, nS);
extAll  = cell(nS, 4);

for s = 1:nS
    [wmImg, key] = hy_embed(cover, W, alphas(s), stageType(s));
    wmImgs{s} = wmImg;
    [psnrAll(s), ifAll(s), ssimAll(s)] = hy_image_metrics(cover, wmImg);

    attacked = hy_attacks(wmImg, testSeed, noiseCfg);
    for n = 1:4
        [atkPsnr(s, n), ~, atkSsim(s, n)] = hy_image_metrics(wmImg, attacked{n});
        We = hy_extract(attacked{n}, key, size(W));
        extAll{s, n} = We;
        nccAll(s, n) = hy_ncc(W, We);
    end
end

%% 5. Results tables
% Table 1: image quality of the watermarked image (vs the original cover)
%          and robustness (NCC of the extracted watermark)
fprintf('%-18s %6s %8s %7s | %9s %6s %12s %8s | %7s %7s\n', 'Stage', 'alpha', ...
        'PSNR', 'SSIM', noiseNames{1}, noiseNames{2}, noiseNames{3}, noiseNames{4}, 'avgNCC', 'IF');
fprintf('%s\n', repmat('-', 1, 113));
for s = 1:nS
    fprintf('%-18s %6.1f %8.2f %7.4f | %9.4f %6.4f %12.4f %8.4f | %7.4f %7.5f\n', ...
            stageNames{s}, alphas(s), psnrAll(s), ssimAll(s), nccAll(s,1), nccAll(s,2), ...
            nccAll(s,3), nccAll(s,4), mean(nccAll(s,:)), ifAll(s));
end
fprintf('\nNoise used: Gaussian var %.3f, salt and pepper density %.2f, speckle var %.2f\n', ...
        noiseCfg.gaussVar, noiseCfg.saltPepperDensity, noiseCfg.speckleVar);

% Table 2: PSNR / SSIM of each attacked image compared with the
%          watermarked image it was made from
fprintf('\nAttacked image vs watermarked image (PSNR dB / SSIM)\n');
fprintf('%-18s', 'Stage');
for n = 1:4
    fprintf(' | %-17s', noiseNames{n});
end
fprintf('\n%s\n', repmat('-', 1, 18 + 4 * 20));
for s = 1:nS
    fprintf('%-18s', stageNames{s});
    for n = 1:4
        fprintf(' | %7.2f / %7.4f', atkPsnr(s, n), atkSsim(s, n));
    end
    fprintf('\n');
end

%% 6. Figures
% Figure 1: images
figure('Name', 'Images');
subplot(2,2,1); hy_show(cover, 'Cover image', [0 255]);
subplot(2,2,2); hy_show(double(W), 'Watermark (9x17)', [0 1]);
subplot(2,2,3); hy_show(wmImgs{5}, 'Watermarked (PBFO)', [0 255]);
d = abs(double(wmImgs{5}) - double(cover));
subplot(2,2,4); hy_show(d * (255 / max(max(d(:)), 1)), 'Difference (amplified)', [0 255]);

% Figure 2: extracted watermarks, one row per stage, one column per noise
figure('Name', 'Extracted watermarks');
for s = 1:nS
    for n = 1:4
        subplot(nS, 4, (s-1)*4 + n);
        hy_show(double(extAll{s, n} > 0.5), ...
                sprintf('%s | %s | %.2f', stageNames{s}, noiseNames{n}, nccAll(s, n)), [0 1]);
    end
end

% Figure 3: bar charts
figure('Name', 'Comparison');
subplot(1,3,1);
bar(psnrAll);
set(gca, 'XTick', 1:nS, 'XTickLabel', stageNames, 'XTickLabelRotation', 30);
ylabel('PSNR (dB)'); title('Image quality (PSNR)');
subplot(1,3,2);
bar(ssimAll);
set(gca, 'XTick', 1:nS, 'XTickLabel', stageNames, 'XTickLabelRotation', 30);
ylabel('SSIM'); ylim([0 1]); title('Image quality (SSIM)');
subplot(1,3,3);
bar(mean(nccAll, 2));
set(gca, 'XTick', 1:nS, 'XTickLabel', stageNames, 'XTickLabelRotation', 30);
ylabel('Mean NCC'); ylim([0 1]); title('Robustness (mean over 4 noises)');
