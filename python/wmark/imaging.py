"""Image loading, colour handling and watermark generation.

Ports of manual_rgb2gray.m, manual_imresize.m, manual_mat2gray.m and
insertTextSafe.m, plus colour support (the MATLAB code is grayscale only):

    channel="gray" : convert to grayscale, like the MATLAB demos
    channel="Y"    : embed in the luminance of YCbCr and keep the colours
    channel="R"/"G"/"B" : embed in one RGB plane (the paper uses the R plane)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

CHANNELS = ("Y", "gray", "R", "G", "B")


def rgb2gray(rgb):
    """Luminance weights used by MATLAB's rgb2gray (ITU-R BT.601)."""
    rgb = np.asarray(rgb, dtype=float)
    return 0.2989 * rgb[..., 0] + 0.5870 * rgb[..., 1] + 0.1140 * rgb[..., 2]


def rgb2ycbcr(rgb):
    rgb = np.asarray(rgb, dtype=float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    y = 0.299 * r + 0.587 * g + 0.114 * b
    cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b
    cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b
    return np.stack([y, cb, cr], axis=-1)


def ycbcr2rgb(ycc):
    y, cb, cr = ycc[..., 0], ycc[..., 1] - 128, ycc[..., 2] - 128
    r = y + 1.402 * cr
    g = y - 0.344136 * cb - 0.714136 * cr
    b = y + 1.772 * cb
    return np.stack([r, g, b], axis=-1)


def to_uint8(x):
    """Clip then round. NumPy uint8 arithmetic wraps around (250+10 -> 4)
    instead of saturating like MATLAB, so every result goes through here."""
    return np.clip(np.round(x), 0, 255).astype(np.uint8)


def mat2gray(a):
    """Rescale to [0, 1] for display (port of manual_mat2gray.m)."""
    a = np.asarray(a, dtype=float)
    lo, hi = a.min(), a.max()
    return np.zeros_like(a) if hi == lo else (a - lo) / (hi - lo)


def resize(img, size, resample=Image.LANCZOS):
    """Resize a 2-D or RGB array to (rows, cols)."""
    img = np.asarray(img)
    pil = Image.fromarray(to_uint8(img) if img.dtype != np.uint8 else img)
    return np.asarray(pil.resize((size[1], size[0]), resample))


def load_image(path_or_file):
    """Load any image file (path or file-like) as an RGB uint8 array.

    Transparent areas (PNG logos) are placed on white. A plain
    convert("RGB") would turn them black, so a black logo on a
    transparent background would vanish completely.
    """
    pil = Image.open(path_or_file)
    if pil.mode in ("RGBA", "LA") or (pil.mode == "P" and "transparency" in pil.info):
        pil = pil.convert("RGBA")
        white = Image.new("RGBA", pil.size, (255, 255, 255, 255))
        pil = Image.alpha_composite(white, pil)
    return np.asarray(pil.convert("RGB"))


def center_crop_square(img):
    """Largest centred square, so photos of any aspect ratio are not stretched."""
    img = np.asarray(img)
    h, w = img.shape[:2]
    s = min(h, w)
    y, x = (h - s) // 2, (w - s) // 2
    return img[y:y + s, x:x + s]


def pad_square(img):
    """Pad to a square with the image's own border colour, keeping the logo's
    proportions (a wide logo is letter-boxed instead of squashed)."""
    img = np.asarray(img)
    h, w = img.shape[:2]
    if h == w:
        return img
    border = np.concatenate([img[0], img[-1], img[:, 0], img[:, -1]])
    fill = np.median(border, axis=0)
    s = max(h, w)
    out = np.empty((s, s) + img.shape[2:], dtype=img.dtype)
    out[...] = fill
    y, x = (s - h) // 2, (s - w) // 2
    out[y:y + h, x:x + w] = img
    return out


def prepare_cover(img, size):
    """Any photo -> size x size cover: centre-crop to square, then resize."""
    return resize(center_crop_square(img), (size, size))


def otsu_threshold(g):
    """Otsu's method: the grey level that best separates dark and light pixels."""
    hist = np.bincount(np.clip(np.round(g), 0, 255).astype(int).ravel(), minlength=256).astype(float)
    p = hist / hist.sum()
    omega = np.cumsum(p)
    mu = np.cumsum(p * np.arange(256))
    with np.errstate(divide="ignore", invalid="ignore"):
        between = (mu[-1] * omega - mu) ** 2 / (omega * (1 - omega))
    between[~np.isfinite(between)] = 0
    return float(np.argmax(between))


def default_cover(size, search_dirs=()):
    """cover.jpg / cover.png from the project folder, else a synthetic test image."""
    for d in search_dirs:
        for name in ("cover.jpg", "cover.png"):
            p = Path(d) / name
            if p.is_file():
                return prepare_cover(load_image(p), size)
    # Fallback: smooth gradients + shapes, so the demo still runs anywhere.
    yy, xx = np.mgrid[0:size, 0:size] / size
    r = 255 * (0.5 + 0.5 * np.sin(6 * xx) * np.cos(4 * yy))
    g = 255 * yy
    b = 255 * (1 - xx)
    img = np.stack([r, g, b], axis=-1)
    img[(xx - 0.5) ** 2 + (yy - 0.5) ** 2 < 0.04] = [240, 200, 60]
    return to_uint8(img)


def split_channel(rgb, channel):
    """Return (2-D float host channel, context needed to rebuild the image)."""
    rgb = np.asarray(rgb)
    if rgb.ndim == 2:
        return rgb.astype(float), ("gray", None)
    if channel == "gray":
        return np.round(rgb2gray(rgb)), ("gray", None)
    if channel == "Y":
        ycc = rgb2ycbcr(rgb)
        return ycc[..., 0], ("Y", ycc)
    idx = "RGB".index(channel)
    return rgb[..., idx].astype(float), (channel, rgb)


def merge_channel(host, ctx):
    """Inverse of split_channel: put the (watermarked) host channel back."""
    channel, data = ctx
    if channel == "gray":
        return to_uint8(host)
    if channel == "Y":
        ycc = data.copy()
        ycc[..., 0] = host
        return to_uint8(ycbcr2rgb(ycc))
    out = np.asarray(data).copy()
    out[..., "RGB".index(channel)] = to_uint8(host)
    return out


def headroom(img, channel):
    """(down, up): how far each pixel's host value can move before some colour
    channel clips at 0 or 255. Adding d to Y adds d to R, G and B alike."""
    img = np.asarray(img, dtype=float)
    if img.ndim == 2 or channel == "gray":
        g = img if img.ndim == 2 else np.round(rgb2gray(img))
        return g, 255 - g
    if channel == "Y":
        return img.min(axis=2), 255 - img.max(axis=2)
    c = img[..., "RGB".index(channel)]
    return c, 255 - c


def get_channel(img, channel):
    """Host channel of a (possibly attacked) image, used at extraction time."""
    return split_channel(img, channel)[0]


def luma(img):
    """Grayscale view of any image, used for PSNR/SSIM."""
    img = np.asarray(img, dtype=float)
    return img if img.ndim == 2 else rgb2gray(img)


def text_watermark(rows, cols, text="VIT"):
    """Binary watermark with text drawn on it (port of insertTextSafe.m)."""
    scale = 8
    canvas = Image.new("L", (cols * scale, rows * scale), 0)
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=int(rows * scale * 0.55))
    draw.text((cols * scale / 2, rows * scale / 2), text, fill=255, font=font, anchor="mm")
    small = canvas.resize((cols, rows), Image.BOX)
    return (np.asarray(small) > 100).astype(np.uint8)


def binary_watermark(source, rows=32, cols=32, text="VIT"):
    """0/1 watermark of shape (rows, cols) from an image (path/array) or text.

    Works for any logo size or aspect ratio: it is padded to a square
    (not squashed), area-averaged down so thin strokes survive, and split
    into black/white with Otsu's threshold.
    """
    if source is None:
        return text_watermark(rows, cols, text)
    img = source if isinstance(source, np.ndarray) else load_image(source)
    g = rgb2gray(img) if img.ndim == 3 else img.astype(float)
    g = resize(pad_square(g), (rows, cols), Image.BOX).astype(float)
    if g.max() - g.min() < 1:            # blank image: nothing to separate
        return np.zeros((rows, cols), np.uint8)
    return (g > otsu_threshold(g)).astype(np.uint8)


def gray_watermark(source, rows, cols, text="VIT"):
    """Grayscale (0..255) watermark for the SVD schemes."""
    if source is None:
        return text_watermark(rows, cols, text).astype(np.uint8) * 255
    img = source if isinstance(source, np.ndarray) else load_image(source)
    g = rgb2gray(img) if img.ndim == 3 else img.astype(float)
    return resize(pad_square(g), (rows, cols)).astype(np.uint8)
