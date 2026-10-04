"""Correctness tests:  python -m pytest -q"""
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from wmark import attacks as atk  # noqa: E402
from wmark import imaging as im  # noqa: E402
from wmark.engine import Config, embed, false_positive  # noqa: E402
from wmark.schemes import SCHEMES  # noqa: E402
from wmark.spread import layout  # noqa: E402
from wmark.transforms import (blockwise_dct, blockwise_idct, dct_matrix,  # noqa: E402
                              haar_dwt2, haar_idwt2)


@pytest.fixture(scope="module")
def cover():
    return im.default_cover(512, [Path(__file__).resolve().parents[2]])


@pytest.fixture(scope="module")
def cover256():
    return im.default_cover(256, [Path(__file__).resolve().parents[2]])


# ---------------------------------------------------------------- transforms
def test_dct_matrix_is_orthonormal():
    T = dct_matrix(8)
    assert np.allclose(T @ T.T, np.eye(8))


def test_blockwise_dct_roundtrip():
    x = np.random.default_rng(0).uniform(0, 255, (64, 48))
    assert np.allclose(blockwise_idct(blockwise_dct(x, 8), 8), x)


def test_blockwise_dct_matches_loop():
    x = np.random.default_rng(1).uniform(0, 255, (16, 16))
    T = dct_matrix(8)
    D = blockwise_dct(x, 8)
    assert np.allclose(D[1, 0], T @ x[8:16, 0:8] @ T.T)


def test_haar_roundtrip_and_energy():
    x = np.random.default_rng(2).uniform(0, 255, (32, 32))
    bands = haar_dwt2(x)
    assert np.allclose(haar_idwt2(*bands), x)
    assert np.isclose(sum((b ** 2).sum() for b in bands), (x ** 2).sum())   # orthonormal


def test_layout_is_odd_and_keyed():
    s1, w1 = layout(1024, 4096, key=1)
    s2, _ = layout(1024, 4096, key=2)
    assert len(set(s1)) == len(s1) and np.bincount(w1).min() % 2 == 1
    assert not np.array_equal(s1, s2)


# ---------------------------------------------------------------- schemes
@pytest.mark.parametrize("name", list(SCHEMES))
def test_clean_roundtrip(cover, name):
    m = embed(cover, Config(scheme=name), None)
    assert m.score(m.watermarked)["score"] > 0.99


@pytest.mark.parametrize("name", ["dct", "dwt", "hybrid_qim"])
def test_matlab_mode_roundtrip(cover256, name):
    cfg = Config(scheme=name, channel="gray", key=None, redundant=False, resync=False)
    m = embed(cover256, cfg, None)
    assert m.score(m.watermarked)["score"] == 1.0


@pytest.mark.parametrize("name", list(SCHEMES))
def test_imperceptible(cover, name):
    from wmark.metrics import psnr
    m = embed(cover, Config(scheme=name), None)
    assert psnr(m.cover, m.watermarked) > 30


def test_proposed_scheme_is_robust(cover):
    m = embed(cover, Config(scheme="hybrid_qim"), None)
    for name in ["jpeg", "gaussian_noise", "salt_pepper", "median", "gaussian_blur", "sharpen", "scaling"]:
        assert m.score(atk.apply(name, m.watermarked))["score"] > 0.9, name


def test_blind_resync_recovers_rotation(cover):
    m = embed(cover, Config(scheme="hybrid_qim"), None)
    rotated = atk.rotation(m.watermarked, angle=3.3)
    _, info = m.extract_info(rotated)
    assert abs(info["angle"] - 3.3) < 0.3
    assert m.score(rotated)["score"] > 0.9


def test_wrong_key_reads_noise(cover):
    m = embed(cover, Config(scheme="hybrid_qim", key=11), None)
    other = embed(cover, Config(scheme="hybrid_qim", key=12), None)
    assert abs(other.score(m.watermarked)["score"]) < 0.3


def test_false_positive_pattern(cover):
    rows = {r["scheme"]: r for r in false_positive(cover, Config(), None)}
    assert rows["svd"]["claim"] > 0.8               # known SVD ownership-ambiguity flaw
    assert rows["hybrid_paper"]["claim"] > 0.8      # inherited by the paper's hybrid
    for s in ("dct", "dwt", "hybrid_qim"):
        assert rows[s]["decoy"] < 0.3 and rows[s]["claim"] < 0.3, s


def test_colour_channel_preserved(cover):
    m = embed(cover, Config(scheme="hybrid_qim", channel="Y"), None)
    assert m.watermarked.ndim == 3
    assert np.abs(m.watermarked.astype(int) - m.cover.astype(int)).mean() < 3


@pytest.mark.parametrize("name", list(atk.ATTACKS))
def test_attacks_keep_shape_and_dtype(cover, name):
    out = atk.apply(name, cover)
    assert out.shape == cover.shape and out.dtype == np.uint8


# ---------------------------------------------------------------- input images of any shape
def _png_bytes(pil):
    import io
    b = io.BytesIO()
    pil.save(b, "PNG")
    b.seek(0)
    return b


def test_transparent_logo_survives():
    from PIL import Image, ImageDraw
    pil = Image.new("RGBA", (400, 120), (0, 0, 0, 0))
    ImageDraw.Draw(pil).ellipse((150, 10, 250, 110), fill=(0, 0, 0, 255))
    w = im.binary_watermark(im.load_image(_png_bytes(pil)))
    assert 0.1 < w.mean() < 0.95          # logo still visible, not all black / all white


def test_wide_logo_keeps_proportions():
    from PIL import Image, ImageDraw
    pil = Image.new("RGB", (400, 100), "white")
    ImageDraw.Draw(pil).ellipse((150, 0, 250, 100), fill="black")
    w = im.binary_watermark(np.asarray(pil))
    ys, xs = np.where(w == 0)
    assert abs(np.ptp(xs) - np.ptp(ys)) <= 2   # the circle stays round


def test_any_photo_ratio_is_not_stretched():
    from PIL import Image, ImageDraw
    pil = Image.new("RGB", (1600, 900), "white")
    ImageDraw.Draw(pil).ellipse((550, 200, 1050, 700), fill="black")
    c = im.prepare_cover(np.asarray(pil), 512)
    ys, xs = np.where(im.rgb2gray(c) < 128)
    assert c.shape[:2] == (512, 512) and abs(np.ptp(xs) - np.ptp(ys)) <= 3


@pytest.mark.parametrize("shape", [(37, 91, 3), (1200, 300, 3), (64, 64, 4)])
def test_odd_sized_inputs_work_end_to_end(shape):
    rng = np.random.default_rng(1)
    # smooth random "photo" (pure noise has no head-room anywhere and is not a realistic cover)
    photo = atk.gaussian_blur(rng.integers(0, 256, shape, dtype=np.uint8)[..., :3], sigma=3)
    logo = rng.integers(0, 256, (shape[1], shape[0], 3), dtype=np.uint8)
    cover = im.prepare_cover(photo, 512)
    m = embed(cover, Config(scheme="hybrid_qim"), logo)
    assert m.score(m.watermarked)["score"] > 0.99


def test_saturated_graphic_cover_clip_aware():
    """Large pure-white / pure-black areas: clip-aware QIM must still read back perfectly."""
    from PIL import Image, ImageDraw
    g = Image.new("RGB", (900, 1600), "white")
    d = ImageDraw.Draw(g)
    d.rectangle((0, 800, 900, 1600), fill="black")
    d.ellipse((200, 300, 700, 1300), fill=(230, 80, 60))
    cover = im.prepare_cover(np.asarray(g), 512)
    m = embed(cover, Config(scheme="hybrid_qim"), None)
    assert m.score(m.watermarked)["score"] == 1.0
