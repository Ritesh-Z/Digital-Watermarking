function extractedBits = dwt_watermark_extract(HL, numBits, alpha)
% DWT_WATERMARK_EXTRACT  Extracts a binary watermark previously embedded
% with dwt_watermark_embed, by re-reading the parity of each quantized
% HL coefficient. Blind extraction - no original image needed.
%
%   extractedBits = dwt_watermark_extract(HL, numBits, alpha)
%
%   HL        : HL sub-band (possibly attacked/modified) to extract from
%   numBits   : number of watermark bits to extract
%   alpha     : MUST be the same quantization step used during embedding
%
%   extractedBits : 1xnumBits vector of recovered bits (0/1)

    [rows, cols] = size(HL);
    extractedBits = zeros(1, numBits);
    idx = 1;

    for i = 1:rows
        for j = 1:cols
            if idx > numBits
                break;
            end

            q = round(HL(i,j)/alpha);
            extractedBits(idx) = mod(q,2);
            idx = idx + 1;
        end
        if idx > numBits
            break;
        end
    end
end
