function main_demo_paper2()
% MAIN_DEMO_PAPER2  Starts the GUI for hybrid DWT-DCT-SVD image watermarking
% with BFO and PSO (PBFO), after Yildiz, Ustunsoy, Sayan (2024).
%
% Run it with the Run button or by typing   main_demo_paper2   in the
% Command Window. Keep this file together with all hy_*.m and manual_*.m
% files in one folder.
%
%   Window 1  hy_gui_select   choose the cover image and the watermark image
%   Window 2  hy_gui_noise    choose None / Gaussian / Shot / Salt-and-Pepper / Speckle
%   Window 3  hy_gui_results  previews, metrics table, save buttons
%             hy_plot_comparison  the comparison charts
%
% The processing itself is in hy_run_pipeline. The original command-line demo
% (cover.jpg, built-in VIT watermark, all four noises at once) is kept as
% demo_batch_paper2.m.
%
% Needs MATLAB R2018a or newer (uifigure, uiaxes, uiprogressdlg). No toolbox.

    thisDir = fileparts(mfilename('fullpath'));
    if ~isempty(thisDir)
        addpath(thisDir);
    end
    if verLessThan('matlab', '9.4')
        error('main_demo_paper2:oldMatlab', ...
              'This GUI needs MATLAB R2018a or newer (it uses uifigure and uiprogressdlg).');
    end
    hy_gui_select();
end
