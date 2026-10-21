%% DIGITAL WATERMARKING: hybrid DWT-DCT-SVD with BFO and PSO (PBFO)
% Start here. Press Run, or type   main   in the Command Window.
%
% This adds every folder of the project to the MATLAB path and opens the
% graphical interface (gui/watermarkingApp.m):
%   window 1  upload the cover image and the watermark image (try images/), Submit
%   window 2  watermarked image + PSNR; pick a noise, OK, see the noised image (stays open);
%             "Extract watermark"
%   window 3  given vs extracted watermark with the NC value (0 to 1);
%             "Show results / comparison" opens
%   window 4  the comparison tables
%
% Folders
%   embedding/      embedDWT, embedDWTDCT, embedDWTDCT_SVD (hide the watermark)
%   extraction/     extractWatermark (get it back)
%   optimization/   BFO, PSO, PBFO (choose the embedding strength alpha)
%   attacks/        applyNoise (Gaussian, shot, salt and pepper, speckle)
%   metrics/        calculateMetrics (PSNR, SSIM, IF, NCC, BER)
%   gui/            watermarkingApp
%   utils/          small helpers: Haar DWT, DCT matrix, image loading and
%                   preparing; embedAllStages (BFO/PBFO + embedding, five
%                   stages) and attackAndExtract (noise + extraction +
%                   metrics); runPipeline runs both in one call
%   images/         sample cover image and logo
%   results/        where the save dialogs start
%
% Needs MATLAB R2018a or newer. No toolbox needed.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
watermarkingApp();
