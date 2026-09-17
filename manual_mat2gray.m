function out = manual_mat2gray(A)
% MANUAL_MAT2GRAY  Scales a matrix to the [0,1] range based on its own
% min/max, same behavior as the Image Processing Toolbox's mat2gray.
% Used only for display purposes (e.g. showing DWT sub-bands as images).
    A = double(A);
    lo = min(A(:));
    hi = max(A(:));
    if hi == lo
        out = zeros(size(A));
    else
        out = (A - lo) / (hi - lo);
    end
end
