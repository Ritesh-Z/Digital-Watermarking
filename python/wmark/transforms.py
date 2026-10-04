"""Hand-written transforms (Python port of the toolbox-free MATLAB helpers).

Everything here is plain NumPy matrix algebra so the maths is visible:
    - dct_matrix / blockwise_dct / blockwise_idct   <- dct_watermark_embed.m
    - haar_dwt2 / haar_idwt2                         <- manual_dwt2_haar.m / manual_idwt2_haar.m

Improvement over the MATLAB version: the block DCT is fully vectorised.
Instead of looping over every 8x8 block, the image is reshaped into a
stack of blocks and ``T @ blocks @ T.T`` transforms all of them at once.
"""
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view


def dct_matrix(n):
    """NxN orthonormal DCT-II basis matrix T, so that D = T @ B @ T.T."""
    u = np.arange(n)[:, None]
    x = np.arange(n)[None, :]
    T = np.sqrt(2.0 / n) * np.cos(np.pi * (2 * x + 1) * u / (2 * n))
    T[0, :] = np.sqrt(1.0 / n)
    return T


def to_blocks(img, b):
    """(H, W) -> (H/b, W/b, b, b) stack of non-overlapping b x b blocks."""
    h, w = img.shape
    return img.reshape(h // b, b, w // b, b).swapaxes(1, 2)


def from_blocks(blocks):
    """Inverse of to_blocks."""
    nr, nc, b, _ = blocks.shape
    return blocks.swapaxes(1, 2).reshape(nr * b, nc * b)


def blockwise_dct(img, b=8):
    """2-D DCT of every b x b block. Returns the (H/b, W/b, b, b) coefficient stack."""
    T = dct_matrix(b)
    return T @ to_blocks(np.asarray(img, dtype=float), b) @ T.T


def blockwise_idct(coeffs, b=8):
    """Inverse of blockwise_dct, returns the reassembled (H, W) image."""
    T = dct_matrix(b)
    return from_blocks(T.T @ coeffs @ T)


def haar_dwt2(img):
    """Single-level 2-D Haar DWT (same convention as manual_dwt2_haar.m).

    Returns LL, LH, HL, HH, each half the width and height of ``img``.
    HL (high across columns, low across rows) is the "vertical detail"
    band used by the DWT scheme.
    """
    img = np.asarray(img, dtype=float)
    s = np.sqrt(2.0)
    Lc = (img[:, 0::2] + img[:, 1::2]) / s
    Hc = (img[:, 0::2] - img[:, 1::2]) / s
    LL = (Lc[0::2, :] + Lc[1::2, :]) / s
    LH = (Lc[0::2, :] - Lc[1::2, :]) / s
    HL = (Hc[0::2, :] + Hc[1::2, :]) / s
    HH = (Hc[0::2, :] - Hc[1::2, :]) / s
    return LL, LH, HL, HH


def haar_idwt2(LL, LH, HL, HH):
    """Inverse of haar_dwt2 (same convention as manual_idwt2_haar.m)."""
    s = np.sqrt(2.0)
    r, c = LL.shape
    Lc = np.empty((2 * r, c))
    Hc = np.empty((2 * r, c))
    Lc[0::2, :] = (LL + LH) / s
    Lc[1::2, :] = (LL - LH) / s
    Hc[0::2, :] = (HL + HH) / s
    Hc[1::2, :] = (HL - HH) / s
    img = np.empty((2 * r, 2 * c))
    img[:, 0::2] = (Lc + Hc) / s
    img[:, 1::2] = (Lc - Hc) / s
    return img


def median_filter(img, size=3):
    """Sliding-window median with replicate padding (port of manual_medfilt2.m),
    vectorised with a strided window view instead of a double loop."""
    p = size // 2
    win = sliding_window_view(np.pad(np.asarray(img, dtype=float), p, mode="edge"), (size, size))
    flat = win.reshape(*win.shape[:2], size * size)
    k = size * size // 2
    return np.partition(flat, k, axis=-1)[..., k]      # O(n) selection, faster than np.median
