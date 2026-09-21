function [watermarked, Sa_orig, Uw, Vw] = svd_watermark_embed(cover, watermarkImg, alpha)
% SVD_WATERMARK_EMBED  Embeds a watermark image into a cover image by
% adding the watermark's singular values onto the cover's singular
% values (classic additive SVD watermarking).
%
%   [watermarked, Sa_orig, Uw, Vw] = svd_watermark_embed(cover, watermarkImg, alpha)
%
%   cover        : grayscale cover image (uint8), e.g. 256x256
%   watermarkImg : grayscale watermark image, SAME SIZE as cover
%   alpha        : embedding strength (scales how much the watermark's
%                  singular values get added). Typical values: 0.01 to 0.2
%                  (much smaller than DCT/DWT alphas, since singular
%                  values themselves can be large numbers)
%
%   watermarked  : uint8 watermarked image, same size as cover
%   Sa_orig      : the COVER's original singular values, BEFORE
%                  watermarking - you must keep this safe, it's required
%                  to extract the watermark later (this is the "key")
%   Uw, Vw       : the WATERMARK's own U and V matrices from its SVD -
%                  also required at extraction time (also part of the "key")
%
% IMPORTANT: this is a semi-blind / non-blind scheme. Unlike the DCT and
% DWT projects, you cannot extract the watermark from the watermarked
% image alone - you must have kept Sa_orig, Uw, and Vw safe somewhere.
% That is a deliberate, real property of SVD-based watermarking, not a
% limitation of this implementation.

    A = double(cover);
    W = double(watermarkImg);

    [Ua, Sa, Va] = svd(A);
    [Uw, Sw, Vw] = svd(W);

    Sa_marked = Sa + alpha * Sw;
    watermarked = Ua * Sa_marked * Va';
    watermarked = uint8(min(max(watermarked, 0), 255));

    Sa_orig = Sa;   % save this - the "key" needed to extract later
end
