function T = manual_dct_matrix(N)
% MANUAL_DCT_MATRIX  NxN orthonormal DCT-II basis matrix, so that
% D = T*block*T' and block = T'*D*T match dct2/idct2 without any toolbox.
% (Same formula as the local function inside dct_watermark_embed.m,
% shared here for the hybrid and proposed schemes.)
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
