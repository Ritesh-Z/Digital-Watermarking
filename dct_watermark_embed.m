function watermarked = dct_watermark_embed(coverImage, watermarkBits, alpha)
% DCT_WATERMARK_EMBED  Embeds a binary watermark into a grayscale image
% using block-based DCT coefficient comparison.
%
% NOTE: Uses a hand-written DCT (manual_dct_matrix below) instead of the
% Image Processing Toolbox's dct2/idct2, so this works on ANY MATLAB
% install, no toolbox required.
%
%   watermarked = dct_watermark_embed(coverImage, watermarkBits, alpha)
%
%   coverImage    : grayscale image (uint8), dimensions must be
%                   divisible by 8 in both directions
%   watermarkBits : 1xN vector of bits (0/1) to embed, one bit per 8x8 block
%   alpha         : embedding strength (higher = more robust, more visible)
%                   typical values: 3 to 50
%
%   watermarked   : uint8 watermarked image, same size as coverImage

    coverImage = double(coverImage);
    [rows, cols] = size(coverImage);
    blockSize = 8;

    % Mid-frequency coefficient pair used to encode each bit.
    pos1 = [4, 3];
    pos2 = [3, 4];

    T = manual_dct_matrix(blockSize);  % build once, reuse for every block

    watermarked = coverImage;
    numBits = length(watermarkBits);
    idx = 1;

    for i = 1:blockSize:rows
        for j = 1:blockSize:cols
            if idx > numBits
                break;
            end

            block = coverImage(i:i+blockSize-1, j:j+blockSize-1);
            D = T * block * T';   % manual DCT2

            bit = watermarkBits(idx);
            c1 = D(pos1(1), pos1(2));
            c2 = D(pos2(1), pos2(2));

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

            watermarked(i:i+blockSize-1, j:j+blockSize-1) = T' * D * T;  % manual IDCT2
            idx = idx + 1;
        end
        if idx > numBits
            break;
        end
    end

    watermarked = uint8(min(max(watermarked, 0), 255));
end

function T = manual_dct_matrix(N)
% Builds the NxN DCT-II basis matrix by hand (same formula the
% Image Processing Toolbox's dct2 uses internally), so D = T*block*T'
% and block = T'*D*T give identical results to dct2/idct2 without
% needing the toolbox.
    T = zeros(N);
    for u = 0:N-1
        if u == 0
            a = sqrt(1/N);
        else
            a = sqrt(2/N);
        end
        for x = 0:N-1
            T(u+1, x+1) = a * cos(pi*(2*x+1)*u/(2*N));
        end
    end
end
