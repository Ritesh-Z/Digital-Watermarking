function gray = manual_rgb2gray(rgbImg)
% MANUAL_RGB2GRAY  Standard luminance formula (same weights the
% Image Processing Toolbox's rgb2gray uses internally). No toolbox needed.
    rgbImg = double(rgbImg);
    gray = uint8(0.2989*rgbImg(:,:,1) + 0.5870*rgbImg(:,:,2) + 0.1140*rgbImg(:,:,3));
end
