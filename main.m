%% DIGITAL WATERMARKING - hybrid DWT-DCT-SVD with BFO / PBFO
% START HERE: press Run, or type  main  in the Command Window.
%
% Opens the GUI (gui/watermarkingApp.m): ONE window with six steps. The
% step buttons in the black left rail switch pages; each step unlocks after the last.
%   1 UPLOAD   choose the cover image and the logo, "Embed the logo"
%   2 EMBED    watermarked image + PSNR, and the embedding shown step by step
%              (DWT -> DCT -> SVD -> alpha by PBFO -> embed -> rebuild)
%   3 EXTRACT  given vs extracted logo + NC, and the extraction step by step
%   4 ATTACKS  pick a noise (Gaussian, shot, salt & pepper, speckle) + strength,
%              OK: noised image, extracted logo, NC
%   5 RESULTS  images + comparison tables of all five methods
%   6 WORKFLOW the whole method as a flowchart + which file does what
%
% FOLDERS - numbered in the order the data flows through them
%   step1_input/         read + prepare the cover image and the logo
%   step2_transforms/    Haar DWT, inverse DWT, DCT matrix (the maths tools)
%   step3_embedding/     hide the logo (3 methods) + embedAllStages
%   step4_optimization/  find the best strength alpha (fitness, BFO, PSO, PBFO)
%   step5_extraction/    get the logo back
%   step6_attacks/       noise attacks on the watermarked image + re-extraction
%   step7_metrics/       PSNR, SSIM, IF, NC, BER
%   gui/                 the window
%   images/              sample cover + logo        results/  saved images
%
% See README.md for the full explanation. MATLAB R2018a or newer, no toolbox.

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));
watermarkingApp();
