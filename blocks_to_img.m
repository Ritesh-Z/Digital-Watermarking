function img = blocks_to_img(B, b, H, W)
% BLOCKS_TO_IMG  Inverse of img_to_blocks: (b*b) x nBlocks -> H x W image.
    img = reshape(permute(reshape(B, b, b, H/b, W/b), [1 3 2 4]), H, W);
end
