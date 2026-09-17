function watermarkedHL = dwt_watermark_embed(HL, watermarkBits, alpha)
% DWT_WATERMARK_EMBED  Embeds a binary watermark into the HL (vertical
% detail) sub-band of a Haar DWT decomposition, using odd-even
% quantization index modulation (QIM) - one bit per coefficient.
%
%   watermarkedHL = dwt_watermark_embed(HL, watermarkBits, alpha)
%
%   HL            : HL sub-band from manual_dwt2_haar (2D matrix)
%   watermarkBits : 1xN vector of bits (0/1) to embed, one bit per coefficient
%   alpha         : quantization step size (higher = more robust, more visible)
%                   typical values: 5 to 40
%
%   watermarkedHL : HL sub-band with the watermark embedded (same size as HL)
%
% HOW IT WORKS (odd-even QIM):
%   Every coefficient is rounded to the nearest multiple of alpha, giving
%   a quantization index q = round(c/alpha). We then nudge q by at most 1
%   so that q's parity (odd/even) matches the bit we want to hide:
%   even q -> bit 0, odd q -> bit 1. This is simple, blind (no original
%   image needed at extraction), and a classic QIM-style scheme.

    [rows, cols] = size(HL);
    watermarkedHL = HL;
    numBits = length(watermarkBits);
    idx = 1;

    for i = 1:rows
        for j = 1:cols
            if idx > numBits
                break;
            end

            c = HL(i,j);
            b = watermarkBits(idx);

            q = round(c/alpha);
            if mod(q,2) ~= b
                % nudge to the nearest quantization level with correct parity
                if c - q*alpha >= 0
                    q = q + 1;
                else
                    q = q - 1;
                end
            end

            watermarkedHL(i,j) = q*alpha;
            idx = idx + 1;
        end
        if idx > numBits
            break;
        end
    end
end
