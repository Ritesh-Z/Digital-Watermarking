"""EXPERIMENT - fair comparison of every scheme at EQUAL image quality (iso-PSNR).

Comparing schemes at their default strengths is unfair: a scheme that changes
the picture more will always look more robust. Here every scheme's alpha is
tuned, separately for every cover image, until the watermarked image has the
same PSNR (default 40 dB). Only then are robustness scores compared.

    python experiment.py                         # project images + test images
    python experiment.py --covers a.jpg b.png --logos l1.png l2.png --psnr 42

Writes outputs/experiment/results.csv, summary.csv and summary.png.
"""
import argparse
import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from PIL import Image, ImageDraw

from wmark import attacks as atk
from wmark import imaging as im
from wmark import metrics as mt
from wmark.cli import HERE, OUT, PROJECT, save
from wmark.engine import Config, embed, run_experiment
from wmark.schemes import SCHEMES, get_scheme

SIZE = 512


def synthetic_covers():
    """Hard, varied test images that need no downloads."""
    yy, xx = np.mgrid[0:SIZE, 0:SIZE] / SIZE
    smooth = np.stack([200 * xx + 30, 180 * yy + 40, 160 * (1 - xx) + 50], axis=-1)        # gradients
    g = Image.new("RGB", (SIZE, SIZE), "white")                                           # graphic + text
    d = ImageDraw.Draw(g)
    d.rectangle((0, SIZE // 2, SIZE, SIZE), fill="black")
    d.ellipse((120, 60, 400, 340), fill=(232, 85, 58))
    for i in range(10):
        d.text((20, SIZE // 2 + 20 + i * 24), "INVISIBLE WATERMARK TEST " * 2, fill="white")
    rng = np.random.default_rng(3)                                                        # texture
    texture = atk.gaussian_blur(rng.integers(0, 256, (SIZE, SIZE, 3), dtype=np.uint8), sigma=1.2)
    return {"synthetic-gradient": im.to_uint8(smooth), "synthetic-graphic+text": np.asarray(g),
            "synthetic-texture": texture}


SKIMAGE_SET = ["camera", "astronaut", "coffee", "chelsea", "rocket", "coins", "moon", "brick",
               "grass", "gravel", "text", "page", "retina", "hubble_deep_field", "immunohistochemistry"]


def skimage_covers():
    """Standard test images shipped with scikit-image (pip install scikit-image)."""
    from skimage import data
    out = {}
    for name in SKIMAGE_SET:
        img = np.asarray(getattr(data, name)())
        if img.ndim == 2:
            img = np.repeat(img[..., None], 3, axis=2)
        out[f"sk-{name}"] = im.prepare_cover(im.to_uint8(img[..., :3]), SIZE)
    return out


def calibrate(cover, cfg, logo, target, iters=12):
    """Binary-search alpha so that PSNR(cover, watermarked) ~= target."""
    s = get_scheme(cfg.scheme, cfg.band)
    lo, hi = s.alpha_min * 0.25, s.alpha_max * 2
    for _ in range(iters):
        mid = (lo * hi) ** 0.5                       # geometric: alpha spans decades for SVD
        m = embed(cover, Config(**{**cfg.__dict__, "alpha": mid}), logo)
        p = mt.psnr(m.cover, m.watermarked)
        if p > target:
            lo = mid                                 # too invisible -> stronger
        else:
            hi = mid
    return (lo * hi) ** 0.5


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--covers", nargs="*", default=None)
    ap.add_argument("--logos", nargs="*", default=None)
    ap.add_argument("--psnr", type=float, default=40.0)
    ap.add_argument("--schemes", nargs="*", default=list(SCHEMES))
    ap.add_argument("--no-synthetic", action="store_true", help="skip the built-in synthetic test images")
    ap.add_argument("--skimage", action="store_true", help="add the 15 standard scikit-image test images")
    ap.add_argument("--no-project", action="store_true", help="skip the project's own cover.jpg")
    args = ap.parse_args()

    covers = {}
    for p in (args.covers or ([] if args.no_project else [str(PROJECT / "cover.jpg")])):
        covers[Path(p).stem] = im.prepare_cover(im.load_image(p), SIZE)
    if not args.no_synthetic:
        covers.update(synthetic_covers())
    if args.skimage:
        covers.update(skimage_covers())
    logos = args.logos or [str(PROJECT / "logo.png"), None]          # None = "VIT" text logo

    out = OUT / ("experiment_standard" if args.skimage else "experiment")
    out.mkdir(parents=True, exist_ok=True)
    names = list(atk.ATTACKS)
    rows = []
    for cname, cover in covers.items():
        for logo in logos:
            lname = Path(logo).stem if logo else "VIT-text"
            for sname in args.schemes:
                cfg = Config(scheme=sname)
                alpha = calibrate(cover, cfg, logo, args.psnr)
                r = run_experiment(cover, Config(**{**cfg.__dict__, "alpha": alpha}), logo)
                scores = [r["clean"]["score"], *[a["score"] for a in r["attacks"]]]
                rows.append({"cover": cname, "logo": lname, "scheme": sname, "alpha": alpha,
                             "psnr": r["psnr"], "ssim": r["ssim"], "clean": scores[0],
                             **{n: a["score"] for n, a in zip(names, r["attacks"])},
                             "mean": float(np.mean(scores)), "worst": float(np.min(scores))})
                print(f"  {cname:24s} {lname:9s} {sname:13s} alpha {alpha:8.4g}  PSNR {r['psnr']:5.2f}  "
                      f"mean {rows[-1]['mean']:.3f}  worst {rows[-1]['worst']:.3f}")

    with open(out / "results.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    # ---- summary: average over all cover x logo pairs, plus how often each scheme wins
    pairs = sorted({(r["cover"], r["logo"]) for r in rows})
    wins = {s: 0 for s in args.schemes}
    for cv, lg in pairs:
        group = [r for r in rows if r["cover"] == cv and r["logo"] == lg]
        wins[max(group, key=lambda r: r["mean"])["scheme"]] += 1
    summary = []
    for s in args.schemes:
        rs = [r for r in rows if r["scheme"] == s]
        summary.append({"scheme": SCHEMES[s].title, "psnr": np.mean([r["psnr"] for r in rs]),
                        "ssim": np.mean([r["ssim"] for r in rs]),
                        "mean_robustness": np.mean([r["mean"] for r in rs]),
                        "worst_case": np.min([r["worst"] for r in rs]),
                        **{n: np.mean([r[n] for r in rs]) for n in ["clean", *names]},
                        "wins": f"{wins[s]}/{len(pairs)}"})
    with open(out / "summary.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(summary[0]))
        w.writeheader()
        for r in summary:
            w.writerow({k: (f"{v:.4f}" if isinstance(v, float) else v) for k, v in r.items()})

    print(f"\n=== Iso-PSNR comparison at {args.psnr} dB over {len(pairs)} cover/logo pairs ===")
    print(f"{'scheme':32s}{'PSNR':>7}{'SSIM':>7}{'mean':>8}{'worst':>8}{'wins':>8}")
    for r in sorted(summary, key=lambda r: -r["mean_robustness"]):
        print(f"{r['scheme']:32s}{r['psnr']:7.2f}{r['ssim']:7.3f}{r['mean_robustness']:8.3f}{r['worst_case']:8.3f}{r['wins']:>8}")

    fig, ax = plt.subplots(figsize=(13, 4))
    labels = ["No attack", *[atk.ATTACKS[n][0] for n in names]]
    x = np.arange(len(labels))
    wdt = 0.8 / len(summary)
    for i, r in enumerate(summary):
        ax.bar(x + i * wdt, [r["clean"], *[r[n] for n in names]], wdt, label=r["scheme"])
    ax.set_xticks(x + 0.4 - wdt / 2, labels, rotation=30, ha="right", fontsize=8)
    ax.set_ylim(-0.2, 1.05)
    ax.set_ylabel("mean NC / correlation")
    ax.set_title(f"Robustness at equal image quality (PSNR = {args.psnr} dB), {len(pairs)} cover/logo pairs")
    ax.legend(fontsize=8, ncol=3)
    ax.grid(axis="y", alpha=.3)
    save(fig, out / "summary.png")


if __name__ == "__main__":
    main()
