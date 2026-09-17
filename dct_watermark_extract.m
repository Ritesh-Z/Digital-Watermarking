function extractedBits = dct_watermark_extract(watermarkedImage, numBits)
% DCT_WATERMARK_EXTRACT  Extracts a binary watermark previously embedded
% with dct_watermark_embed, using the same coefficient-comparison rule.
%
% NOTE: Uses a hand-written DCT (manual_dct_matrix below) instead of the
% Image Processing Toolbox's dct2, so this works on ANY MATLAB install,
% no toolbox required.
%
%   extractedBits = dct_watermark_extract(watermarkedImage, numBits)
%
%   watermarkedImage : grayscale image (uint8) to extract watermark from
%   numBits           : number of watermark bits to extract
%
%   extractedBits     : 1xnumBits vector of recovered bits (0/1)

    watermarkedImage = double(watermarkedImage);
    [rows, cols] = size(watermarkedImage);
    blockSize = 8;

    pos1 = [4, 3];
    pos2 = [3, 4];

    T = manual_dct_matrix(blockSize);

    extractedBits = zeros(1, numBits);
    idx = 1;

    for i = 1:blockSize:rows
        for j = 1:blockSize:cols
            if idx > numBits
                break;
            end

            block = watermarkedImage(i:i+blockSize-1, j:j+blockSize-1);
            D = T * block * T';   % manual DCT2

            if D(pos1(1), pos1(2)) > D(pos2(1), pos2(2))
                extractedBits(idx) = 1;
            else
                extractedBits(idx) = 0;
            end

            idx = idx + 1;
        end
        if idx > numBits
            break;
        end
    end
end

function T = manual_dct_matrix(N)
% Builds the NxN DCT-II basis matrix by hand - see dct_watermark_embed.m
% for details. Must match that file exactly for embed/extract to agree.
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
