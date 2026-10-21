function rgb = yCbCrToRgb(Y, Cb, Cr)
% YCBCRTORGB  Brightness (Y) + colour channels (Cb, Cr) -> uint8 colour image.
%             Inverse of rgbToYCbCr, written by hand.
%
% PIPELINE:  STEP 2 (transforms) - only used when "Keep colour" is ticked:
%            the WATERMARKED Y is put back together with the ORIGINAL Cb and
%            Cr, giving a colour watermarked image.
%
%   rgb = yCbCrToRgb(Y, Cb, Cr)
%
%   R = Y + 1.402    (Cr - 128)
%   G = Y - 0.344136 (Cb - 128) - 0.714136 (Cr - 128)
%   B = Y + 1.772    (Cb - 128)
%
% The result is rounded and clipped to 0..255. This rounding is the only
% extra loss of the colour mode (it changes Y by at most about 1).

    Y  = double(Y);
    Cb = double(Cb) - 128;
    Cr = double(Cr) - 128;

    R = Y + 1.402    * Cr;
    G = Y - 0.344136 * Cb - 0.714136 * Cr;
    B = Y + 1.772    * Cb;

    rgb = uint8(min(max(round(cat(3, R, G, B)), 0), 255));
end
