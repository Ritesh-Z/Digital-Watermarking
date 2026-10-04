"""High-level experiment pipeline shared by the CLI scripts and the web server.

    run_experiment  embed -> extract -> metrics -> attacks (like main_demo_*.m)
    benchmark       every scheme x every attack
    alpha_sweep     alpha vs PSNR / robustness curves (like the paper's tables)
    false_positive  extract from an image that was NEVER watermarked
"""
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from . import attacks as atk
from . import imaging as im
from . import metrics as mt
from .schemes import SCHEMES, get_scheme
from .transforms import median_filter


@dataclass
class Config:
    scheme: str = "hybrid_qim"
    alpha: float | None = None      # None -> scheme default
    channel: str = "Y"
    key: int | None = 2025          # None -> MATLAB-style sequential layout
    redundant: bool = True
    band: str = "HH"                # hybrid_paper only
    seed: int = 0
    resync: bool = True             # blind rotation recovery for keyed blind schemes


@dataclass
class Marked:
    scheme: object
    cfg: Config
    alpha: float
    cover: np.ndarray
    watermark: np.ndarray
    watermarked: np.ndarray
    secret: dict = field(default_factory=dict)

    def extract(self, img):
        return self.extract_info(img)[0]

    def extract_info(self, img):
        """Returns (watermark, info). info["angle"] is the rotation that blind
        re-synchronisation undid (0 when not needed / not applicable)."""
        host = im.get_channel(img, self.cfg.channel)
        info = {"angle": 0.0, "confidence": None}
        if self.can_resync:
            host, info = self._resync(host)
        wm = self.scheme.extract(host, self.alpha, self.cfg.key, self.cfg.redundant,
                                 self.secret, self.watermark.shape)
        return wm, info

    @property
    def copies(self):
        """Copies of each watermark bit in the image (1 for non-blind schemes)."""
        if not self.scheme.blind:
            return 1
        return self.scheme.copies(self.watermarked.shape[:2], self.watermark.shape, self.cfg.redundant)

    @property
    def can_resync(self):
        # agreement between copies is the alignment signal, so >= 3 copies are needed
        return (self.cfg.resync and self.scheme.blind and self.cfg.key is not None
                and self.copies >= 3)

    def _confidence(self, host, prefilter=True):
        return self.scheme.confidence(host, self.alpha, self.cfg.key, self.cfg.redundant,
                                      self.watermark.shape, prefilter)

    def _resync(self, host, threshold=0.9):
        """Blind rotation recovery. Each bit is stored 7 times; when the image
        is aligned the copies agree (~1.0), when it is rotated they look
        random (~0.6). Search for the counter-rotation that maximises
        agreement - coarse 1 deg grid, then 0.25 and 0.1 deg refinements."""
        best = (self._confidence(host), 0.0, host)
        if best[0] >= threshold:
            return host, {"angle": 0.0, "confidence": best[0]}
        # Median-filter once and rotate the filtered image (median and small
        # rotations nearly commute) instead of re-filtering at every angle.
        n = int(np.prod(self.watermark.shape))
        filt = host
        pil = Image.fromarray(filt.astype(np.float32), mode="F")
        pil_raw = Image.fromarray(host.astype(np.float32), mode="F")

        def try_angle(a):
            h = np.asarray(pil.rotate(-a, resample=Image.BILINEAR), dtype=float)
            return self._confidence(h, prefilter=False), a, None

        offsets = (np.arange(-8, 8.01, 1.0),            # coarse, around 0
                   np.array([-0.75, -0.5, -0.25, 0.25, 0.5, 0.75]),
                   np.array([-0.2, -0.1, 0.1, 0.2]))
        for i, grid in enumerate(offsets):
            if i == 1 and best[1] == 0.0:
                break            # no rotation found by the coarse pass: skip refinement
            centre = 0.0 if i == 0 else best[1]
            for a in grid:
                a = round(float(centre + a), 2)
                if a != 0:
                    best = max(best, try_angle(a), key=lambda t: t[0])
        if best[1] == 0.0:
            return host, {"angle": 0.0, "confidence": float(best[0])}
        aligned = np.asarray(pil_raw.rotate(-best[1], resample=Image.BILINEAR), dtype=float)
        return aligned, {"angle": float(best[1]), "confidence": float(best[0])}

    def score(self, img):
        return mt.robustness(self.scheme.payload, self.watermark, self.extract(img))


def make_watermark(scheme, size, source=None, text="VIT"):
    rows, cols = scheme.watermark_shape(size)
    if scheme.payload == "bits":
        return im.binary_watermark(source, rows, cols, text)
    return im.gray_watermark(source, rows, cols, text)


def embed(cover, cfg, wm_source=None, text="VIT"):
    """cover: square RGB/gray uint8 whose side is a multiple of 16."""
    scheme = get_scheme(cfg.scheme, cfg.band)
    alpha = scheme.alpha_default if cfg.alpha is None else float(cfg.alpha)
    wm = make_watermark(scheme, cover.shape[0], wm_source, text)
    host, ctx = im.split_channel(cover, cfg.channel)
    if "headroom" in scheme.embed.__code__.co_varnames:      # clip-aware schemes
        marked_host, secret = scheme.embed(host, wm, alpha, cfg.key, cfg.redundant,
                                           headroom=im.headroom(cover, cfg.channel))
    else:
        marked_host, secret = scheme.embed(host, wm, alpha, cfg.key, cfg.redundant)
    watermarked = im.merge_channel(marked_host, ctx)
    # Reference cover as the viewer sees it (gray mode compares against gray).
    ref = im.merge_channel(host, ctx)
    return Marked(scheme, cfg, alpha, ref, wm, watermarked, secret)


def run_experiment(cover, cfg, wm_source=None, attack_names=None, text="VIT"):
    m = embed(cover, cfg, wm_source, text)
    clean = m.extract(m.watermarked)
    result = {
        "marked": m,
        "extracted": clean,
        "psnr": mt.psnr(m.cover, m.watermarked),
        "ssim": mt.ssim(m.cover, m.watermarked),
        "clean": mt.robustness(m.scheme.payload, m.watermark, clean),
        "attacks": [],
    }
    for name in attack_names if attack_names is not None else atk.ATTACKS:
        attacked = atk.apply(name, m.watermarked, seed=cfg.seed)
        ext, info = m.extract_info(attacked)
        result["attacks"].append({
            "name": name,
            "label": atk.ATTACKS[name][0],
            "source": atk.ATTACKS[name][3],
            "attacked": attacked,
            "extracted": ext,
            "psnr": mt.psnr(m.watermarked, attacked),
            "resync_angle": info["angle"],
            **mt.robustness(m.scheme.payload, m.watermark, ext),
        })
    return result


def benchmark(cover, base_cfg, wm_source=None, scheme_names=None, attack_names=None, alphas=None):
    """Rows of {scheme, psnr, ssim, clean, <attack>: score} for every scheme."""
    rows = []
    for name in scheme_names or SCHEMES:
        cfg = Config(**{**base_cfg.__dict__, "scheme": name,
                        "alpha": (alphas or {}).get(name)})
        r = run_experiment(cover, cfg, wm_source, attack_names)
        rows.append({
            "scheme": name,
            "title": r["marked"].scheme.title,
            "alpha": r["marked"].alpha,
            "blind": r["marked"].scheme.blind,
            "psnr": r["psnr"], "ssim": r["ssim"],
            "clean": r["clean"]["score"],
            "attacks": {a["name"]: a["score"] for a in r["attacks"]},
        })
    return rows


def alpha_sweep(cover, base_cfg, alphas, wm_source=None, attack_names=None):
    """For each alpha: PSNR, SSIM, clean score and per-attack score."""
    out = []
    for a in alphas:
        cfg = Config(**{**base_cfg.__dict__, "alpha": float(a)})
        r = run_experiment(cover, cfg, wm_source, attack_names)
        out.append({"alpha": float(a), "psnr": r["psnr"], "ssim": r["ssim"],
                    "clean": r["clean"]["score"],
                    "attacks": {x["name"]: x["score"] for x in r["attacks"]}})
    return out


def natural_decoy(cover):
    """A natural-looking image that was never watermarked: a 2x zoom of the cover's centre."""
    h, w = cover.shape[:2]
    return im.resize(cover[h // 4: 3 * h // 4, w // 4: 3 * w // 4], (h, w))


def false_positive(cover, base_cfg, wm_source=None, scheme_names=None, decoy=None):
    """Security test. For every scheme:

      genuine : owner's key on the owner's watermarked image   -> should be ~1
      decoy   : owner's key on a natural image that was NEVER
                watermarked                                    -> should be ~0
      claim   : ownership-ambiguity attack. A second party with a different
                watermark ("FAKE") and their own key runs the detector on
                the OWNER's image. For SVD schemes they keep the owner's S
                and swap in their own Uw, Vw (Zhang & Li, 2005).  -> should be ~0

    A high decoy/claim score is a false positive: the detector "finds" a
    watermark that was never embedded, so it cannot prove ownership.
    """
    decoy = natural_decoy(cover) if decoy is None else decoy
    rows = []
    for name in scheme_names or SCHEMES:
        cfg = Config(**{**base_cfg.__dict__, "scheme": name, "alpha": None})
        owner = embed(cover, cfg, wm_source)
        fake_cfg = Config(**{**cfg.__dict__, "key": (cfg.key or 0) + 7919})
        fake = embed(cover, fake_cfg, None, text="FAKE")
        if not owner.scheme.blind:
            fake.secret = {**fake.secret, "S": owner.secret["S"]}
        claim_ext = fake.extract(owner.watermarked)
        rows.append({
            "scheme": name, "title": owner.scheme.title, "blind": owner.scheme.blind,
            "genuine": owner.score(owner.watermarked)["score"],
            "decoy": owner.score(decoy)["score"],
            "claim": mt.robustness(owner.scheme.payload, fake.watermark, claim_ext)["score"],
            "owner_watermark": owner.watermark,
            "decoy_extract": owner.extract(decoy),
            "fake_watermark": fake.watermark,
            "claim_extract": claim_ext,
        })
    return rows
