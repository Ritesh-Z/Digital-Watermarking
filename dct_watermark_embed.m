function watermarked = dct_watermark_embed(coverImage, watermarkBits, alpha)
% DCT_WATERMARK_EMBED  Embeds a binary watermark into a grayscale image
% using block-based DCT coefficient comparison.
%
%   watermarked = dct_watermark_embed(coverImage, watermarkBits, alpha)
%
%   coverImage    : grayscale image (uint8), dimensions must be
%                   divisible by 8 in both directions
%   watermarkBits : 1xN vector of bits (0/1) to embed, one bit per 8x8 block
%   alpha         : embedding strength (higher = more robust, more visible)
%                   typical values: 3 to 15
%
%   watermarked   : uint8 watermarked image, same size as coverImage

    coverImage = double(coverImage);
    [rows, cols] = size(coverImage);
    blockSize = 8;

    % Mid-frequency coefficient pair used to encode each bit.
    % These positions avoid low frequencies (visible distortion) and
    % high frequencies (destroyed easily by compression/noise).
    pos1 = [4, 3];
    pos2 = [3, 4];

    watermarked = coverImage;
    numBits = length(watermarkBits);
    idx = 1;

    for i = 1:blockSize:rows
        for j = 1:blockSize:cols
            if idx > numBits
                break;
            end

            block = coverImage(i:i+blockSize-1, j:j+blockSize-1);
            D = dct2(block);

            bit = watermarkBits(idx);
            c1 = D(pos1(1), pos1(2));
            c2 = D(pos2(1), pos2(2));

            % Force the required relationship between c1 and c2 with a
            % safety margin of 'alpha', while disturbing the coefficients
            % as little as possible (split the correction symmetrically).
            if bit == 1
                if (c1 - c2) < alpha
                    delta = (alpha - (c1 - c2)) / 2;
                    c1 = c1 + delta;
                    c2 = c2 - delta;
                end
            else
                if (c2 - c1) < alpha
                    delta = (alpha - (c2 - c1)) / 2;
                    c2 = c2 + delta;
                    c1 = c1 - delta;
                end
            end

            D(pos1(1), pos1(2)) = c1;
            D(pos2(1), pos2(2)) = c2;

            watermarked(i:i+blockSize-1, j:j+blockSize-1) = idct2(D);
            idx = idx + 1;
        end
        if idx > numBits
            break;
        end
    end

    watermarked = uint8(watermarked);
end
