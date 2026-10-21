function W = hy_watermark_vit()
% HY_WATERMARK_VIT  A 9 x 17 black/white watermark that spells "VIT".
% The paper uses a 17 x 9 pixel pattern ("A28"); this has the same size.
% Three 5-pixel-wide letters with 1 blank column between them = 17 columns,
% 7 rows of letter with 1 blank row above and below = 9 rows.

    V = ['10001'; '10001'; '10001'; '10001'; '01010'; '01010'; '00100'] == '1';
    I = ['11111'; '00100'; '00100'; '00100'; '00100'; '00100'; '11111'] == '1';
    T = ['11111'; '00100'; '00100'; '00100'; '00100'; '00100'; '00100'] == '1';

    gap = false(7, 1);
    body = [V, gap, I, gap, T];          % 7 x 17
    W = double([false(1, 17); body; false(1, 17)]);   % 9 x 17
end
