function B = img_to_blocks(img, b)
% IMG_TO_BLOCKS  Cut an image into non-overlapping b x b blocks.
%   B = img_to_blocks(img, b)   ->   B is (b*b) x nBlocks, one block per column.
% Inverse: blocks_to_img. Image size must be a multiple of b.
    img = double(img);
    [H, W] = size(img);
    B = reshape(permute(reshape(img, b, H/b, b, W/b), [1 3 2 4]), b*b, []);
end
