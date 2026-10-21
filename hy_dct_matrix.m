function T = hy_dct_matrix(N)
% HY_DCT_MATRIX  N x N orthonormal DCT-II matrix, built by hand (no toolbox).
%
%   Forward 2D DCT of a matrix X :  D = Tr * X * Tc'
%   Inverse                      :  X = Tr' * D * Tc
%
% Tr is hy_dct_matrix(number of rows), Tc is hy_dct_matrix(number of columns).

    n = (0:N-1)';          % column of frequency indices
    x = 0:N-1;             % row of sample positions
    T = sqrt(2/N) * cos(pi * n * (2*x + 1) / (2*N));
    T(1, :) = sqrt(1/N);   % the first row (DC) has a different scale
end
