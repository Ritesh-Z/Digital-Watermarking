function emb = addColourToStages(emb, coverRGB, Cb, Cr)
% ADDCOLOURTOSTAGES  Colour mode only: turns the watermarked brightness
% images back into colour images.
%
% PIPELINE:  STEP 3 (embedding), after embedAllStages, only when "Keep
%            colour" is ticked. embedAllStages worked on the brightness
%            channel Y exactly as the paper does on a gray image; here the
%            ORIGINAL colour channels Cb, Cr are put back:
%
%               watermarked Y  +  Cb  +  Cr   --yCbCrToRgb-->   colour image
%
%   emb = addColourToStages(emb, coverRGB, Cb, Cr)
%
% Adds to emb:
%   isColour    true
%   coverRGB    resized colour cover
%   Cb, Cr      colour channels of the cover
%   wmRGB       colour watermarked image per stage
%   psnrColour  PSNR of colour cover vs colour watermarked image per stage
%               (emb.psnr stays the PSNR on Y, comparable with the paper)

    nS = numel(emb.stageNames);
    emb.isColour   = true;
    emb.coverRGB   = coverRGB;
    emb.Cb         = Cb;
    emb.Cr         = Cr;
    emb.wmRGB      = cell(1, nS);
    emb.psnrColour = zeros(1, nS);
    for s = 1:nS
        emb.wmRGB{s} = yCbCrToRgb(emb.wmImgs{s}, Cb, Cr);
        q = calculateMetrics(coverRGB, emb.wmRGB{s}, [], [], false);
        emb.psnrColour(s) = q.psnr;
    end
end
