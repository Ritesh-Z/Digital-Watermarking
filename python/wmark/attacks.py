"""Attacks used for robustness testing.

From the MATLAB demos : JPEG (Q80), Gaussian noise, salt & pepper, 3x3 median
From the base paper   : sharpening, Gaussian blur, horizontal lines,
                        vertical lines, salt & pepper, rotation
Extra                 : cropping, down/up scaling

All attacks take and return uint8 arrays (2-D or RGB) and are deterministic
for a given ``seed`` so results are reproducible run to run (the MATLAB
noise attacks were not seeded).
"""
import io

import numpy as np
from PIL import Image

from .imaging import to_uint8
from .transforms import median_filter


def _per_channel(fn, img):
    img = np.asarray(img)
    if img.ndim == 2:
        return fn(img.astype(float))
    return np.stack([fn(img[..., k].astype(float)) for k in range(img.shape[2])], axis=-1)


def _conv_sep(x, k):
    """Separable 2-D convolution with replicate padding."""
    p = len(k) // 2
    xp = np.pad(x, ((0, 0), (p, p)), mode="edge")
    x = sum(k[i] * xp[:, i:i + x.shape[1]] for i in range(len(k)))
    xp = np.pad(x, ((p, p), (0, 0)), mode="edge")
    return sum(k[i] * xp[i:i + x.shape[0], :] for i in range(len(k)))


def _gauss_kernel(sigma):
    r = max(1, int(np.ceil(3 * sigma)))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    return k / k.sum()


def jpeg(img, quality=80, **_):
    buf = io.BytesIO()
    Image.fromarray(img).save(buf, format="JPEG", quality=int(quality))
    return np.asarray(Image.open(buf))


def gaussian_noise(img, variance=0.001, seed=0, **_):
    rng = np.random.default_rng(seed)
    noisy = img / 255.0 + np.sqrt(variance) * rng.standard_normal(img.shape)
    return to_uint8(np.clip(noisy, 0, 1) * 255)


def salt_pepper(img, density=0.01, seed=0, **_):
    rng = np.random.default_rng(seed)
    out = img.copy()
    m = rng.random(img.shape[:2])
    out[m < density / 2] = 0
    out[(m >= density / 2) & (m < density)] = 255
    return out


def median(img, size=3, **_):
    return _per_channel(lambda x: to_uint8(median_filter(x, size)), img)


def gaussian_blur(img, sigma=1.0, **_):
    return _per_channel(lambda x: to_uint8(_conv_sep(x, _gauss_kernel(sigma))), img)


def sharpen(img, amount=1.0, **_):
    """Unsharp masking: x + amount * (x - blur(x))."""
    k = _gauss_kernel(1.0)
    return _per_channel(lambda x: to_uint8(x + amount * (x - _conv_sep(x, k))), img)


def lines(img, orientation="h", spacing=32, **_):
    """Overwrite every ``spacing``-th row (h) or column (v) with white."""
    out = img.copy()
    if orientation == "h":
        out[::spacing, ...] = 255
    else:
        out[:, ::spacing, ...] = 255
    return out


def rotation(img, angle=2.0, **_):
    """Rotate about the centre (no re-alignment before extraction)."""
    return np.asarray(Image.fromarray(img).rotate(angle, resample=Image.BILINEAR))


def crop(img, fraction=0.25, **_):
    """Black out the top-left ``fraction`` of the image area."""
    out = img.copy()
    h, w = img.shape[:2]
    s = np.sqrt(fraction)
    out[: int(h * s), : int(w * s), ...] = 0
    return out


def scaling(img, factor=0.5, **_):
    """Downscale then upscale back to the original size."""
    h, w = img.shape[:2]
    pil = Image.fromarray(img)
    small = pil.resize((max(1, int(w * factor)), max(1, int(h * factor))), Image.BILINEAR)
    return np.asarray(small.resize((w, h), Image.BILINEAR))


# name -> (label, function, default params, source)
ATTACKS = {
    "jpeg":           ("JPEG Q80",          jpeg,           {"quality": 80},          "matlab"),
    "gaussian_noise": ("Gaussian noise",    gaussian_noise, {"variance": 0.001},      "matlab"),
    "salt_pepper":    ("Salt & pepper",     salt_pepper,    {"density": 0.01},        "both"),
    "median":         ("Median 3x3",        median,         {"size": 3},              "matlab"),
    "sharpen":        ("Sharpening",        sharpen,        {"amount": 1.0},          "paper"),
    "gaussian_blur":  ("Gaussian blur",     gaussian_blur,  {"sigma": 1.0},           "paper"),
    "h_lines":        ("Horizontal lines",  lines,          {"orientation": "h"},     "paper"),
    "v_lines":        ("Vertical lines",    lines,          {"orientation": "v"},     "paper"),
    "rotation":       ("Rotation 2°",  rotation,       {"angle": 2.0},           "paper"),
    "crop":           ("Crop 25%",          crop,           {"fraction": 0.25},       "extra"),
    "scaling":        ("Scale 0.5x",        scaling,        {"factor": 0.5},          "extra"),
}


def apply(name, img, seed=0, **params):
    label, fn, defaults, _ = ATTACKS[name]
    return fn(np.asarray(img), seed=seed, **{**defaults, **params})
