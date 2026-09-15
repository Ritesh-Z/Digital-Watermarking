function extractedBits = dct_watermark_extract(watermarkedImage, numBits)
% DCT_WATERMARK_EXTRACT  Extracts a binary watermark previously embedded
% with dct_watermark_embed, using the same coefficient-comparison rule.
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

    extractedBits = zeros(1, numBits);
    idx = 1;

    for i = 1:blockSize:rows
        for j = 1:blockSize:cols
            if idx > numBits
                break;
            end

            block = watermarkedImage(i:i+blockSize-1, j:j+blockSize-1);
            D = dct2(block);

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
