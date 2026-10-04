"""Quality metrics (port of calculate_metrics.m / calculate_metrics_svd.m, plus SSIM).

Imperceptibility : PSNR, SSIM (SSIM is new - it tracks perceived quality
                   better than PSNR)
Robustness       : NC and BER for 0/1 watermarks (bipolar NC, as in MATLAB),
                   NC (paper formula) and Pearson correlation for grayscale ones
"""
import numpy as np

from .attacks import _conv_sep, _gauss_kernel
from .imaging import luma


def psnr(a, b):
    mse = np.mean((luma(a) - luma(b)) ** 2)
    return float("inf") if mse == 0 else float(10 * np.log10(255.0 ** 2 / mse))


def ssim(a, b):
    """Mean SSIM (Wang et al. 2004), 11x11 Gaussian window, sigma 1.5."""
    x, y = luma(a), luma(b)
    k = _gauss_kernel(1.5)
    f = lambda z: _conv_sep(z, k)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mx, my = f(x), f(y)
    sxx, syy, sxy = f(x * x) - mx ** 2, f(y * y) - my ** 2, f(x * y) - mx * my
    m = ((2 * mx * my + c1) * (2 * sxy + c2)) / ((mx ** 2 + my ** 2 + c1) * (sxx + syy + c2))
    return float(m.mean())


def nc_bits(w, we):
    a, b = 2.0 * w.ravel() - 1, 2.0 * we.ravel() - 1
    return float(np.sum(a * b) / np.sqrt(np.sum(a * a) * np.sum(b * b)))


def ber(w, we):
    return float(np.mean(w.ravel() != we.ravel()))


def nc_image(w, we):
    """NC = sum(w*w') / sqrt(sum(w^2) * sum(w'^2)), the formula used in the paper."""
    a, b = w.astype(float).ravel(), we.astype(float).ravel()
    d = np.sqrt(np.sum(a * a) * np.sum(b * b))
    return 0.0 if d == 0 else float(np.sum(a * b) / d)


def correlation(w, we):
    a, b = w.astype(float).ravel(), we.astype(float).ravel()
    a, b = a - a.mean(), b - b.mean()
    d = np.sqrt(np.sum(a * a) * np.sum(b * b))
    return 0.0 if d == 0 else float(np.sum(a * b) / d)


def robustness(payload, w, we):
    """Metrics comparing original and extracted watermark. 'score' is the headline number."""
    if payload == "bits":
        nc = nc_bits(w, we)
        return {"nc": nc, "ber": ber(w, we), "score": nc}
    corr = correlation(w, we)
    return {"nc": nc_image(w, we), "corr": corr, "score": corr}
