function extractedW = svd_watermark_extract(watermarkedImg, Sa_orig, Uw, Vw, alpha)
% SVD_WATERMARK_EXTRACT  Extracts a watermark previously embedded with
% svd_watermark_embed. Requires the "key" produced at embedding time:
% Sa_orig (cover's original singular values), Uw and Vw (watermark's
% own U and V matrices), and the same alpha used to embed.
%
%   extractedW = svd_watermark_extract(watermarkedImg, Sa_orig, Uw, Vw, alpha)
%
%   watermarkedImg : the (possibly attacked) watermarked image
%   Sa_orig        : cover's original singular values (from embedding step)
%   Uw, Vw         : watermark's U and V matrices (from embedding step)
%   alpha          : MUST be the same value used during embedding
%
%   extractedW     : uint8 recovered watermark image

    Aprime = double(watermarkedImg);
    [~, Sa_prime, ~] = svd(Aprime);

    Sw_extracted = (Sa_prime - Sa_orig) / alpha;
    extractedW = Uw * Sw_extracted * Vw';
    extractedW = uint8(min(max(extractedW, 0), 255));
end
