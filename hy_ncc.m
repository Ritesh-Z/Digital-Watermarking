function v = hy_ncc(W, We)
% HY_NCC  Normalized cross correlation between the original watermark W and
% the extracted watermark We. 1 means identical, 0 means unrelated.
%
% NOTE: the paper's equation (18) is printed in a way that does not give
% values near 1 (their tables show about 0.004). This is the standard
% definition that the paper's own text describes.

    W = double(W(:));
    We = double(We(:));
    d = sqrt(sum(W.^2) * sum(We.^2));
    if d == 0
        v = 0;
    else
        v = sum(W .* We) / d;
    end
end
