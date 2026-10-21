function res = runPipeline(cover, W, noiseType, opts)
% RUNPIPELINE  Both processing steps in one call (no GUI code in it). The GUI
% itself now calls the two steps separately, because the noise is chosen after
% the watermarked image has been shown:
%
%   emb = embedAllStages(cover, W, opts)        BFO/PBFO search + embedding
%   res = attackAndExtract(emb, noiseType, cfg) noise + extraction + metrics
%
%   res = runPipeline(cover, W, noiseType, opts)
%
%   noiseType : 'none' | 'gaussian' | 'shot' | 'saltpepper' | 'speckle'
%   opts      : optional struct. opts.noiseCfg sets the strength of the final
%               noise (gaussVar, saltPepperDensity, speckleVar); the other
%               fields (e.g. opts.statusFcn) go to embedAllStages.
%
% res has the fields described in embedAllStages and attackAndExtract.

    if nargin < 4 || isempty(opts)
        opts = struct();
    end
    noiseCfg = [];
    if isfield(opts, 'noiseCfg')
        noiseCfg = opts.noiseCfg;
        opts = rmfield(opts, 'noiseCfg');
    end
    emb = embedAllStages(cover, W, opts);
    res = attackAndExtract(emb, noiseType, noiseCfg);
end
