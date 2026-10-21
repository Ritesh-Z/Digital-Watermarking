function T = dctMatrix(N)
% DCTMATRIX  N x N orthonormal DCT-II matrix, built by hand (no toolbox).
%
% PIPELINE:  STEP 2 (transforms) - used on the HH band (embedding stages 2/3
%            and extraction).
%
%   T = dctMatrix(N)
%
% With this matrix the 2-D DCT is just two matrix products:
%   forward :  D = Tr  * X * Tc'
%   inverse :  X = Tr' * D * Tc
% where Tr = dctMatrix(rows of X) and Tc = dctMatrix(columns of X).
%
% Row k of T is a cosine wave with k half-periods:
%   T(k, x) = sqrt(2/N) * cos(pi * k * (2x + 1) / (2N)),   k, x = 0..N-1
% Row 0 (the DC / average term) uses sqrt(1/N) so that T * T' = identity.

    % The same size is asked for thousands of times during the alpha search,
    % so the last matrix is remembered (it only depends on N).
    persistent lastN lastT
    if ~isempty(lastN) && lastN == N
        T = lastT;
        return;
    end

    k = (0:N-1)';          % frequency index (one per row)
    x = 0:N-1;             % sample position (one per column)
    T = sqrt(2/N) * cos(pi * k * (2*x + 1) / (2*N));
    T(1, :) = sqrt(1/N);
    lastN = N;
    lastT = T;
end
