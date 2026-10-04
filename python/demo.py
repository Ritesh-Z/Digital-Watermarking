"""DEMO - Python equivalent of main_demo_dct.m / main_demo_dwt.m / main_demo_svd.m

Pipeline: load cover -> load/generate watermark -> embed -> extract ->
          evaluate (PSNR, SSIM, NC, BER) -> robustness tests -> figures

    python demo.py --scheme dct --matlab     # same settings as main_demo_dct.m
    python demo.py --scheme hybrid_qim       # proposed scheme, 512x512 colour
"""
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image

from wmark import imaging as im
from wmark.cli import outdir, parser, save, setup, show
from wmark.engine import run_experiment


def main():
    args = parser(__doc__.splitlines()[0]).parse_args()
    cover, logo, cfg = setup(args)
    r = run_experiment(cover, cfg, logo)
    m = r["marked"]
    bits = m.scheme.payload == "bits"
    out = outdir(f"demo_{cfg.scheme}")

    print(f"\n=== {m.scheme.title}   alpha={m.alpha}   {cover.shape[0]}x{cover.shape[1]} "
          f"channel={cfg.channel} key={cfg.key} ===")
    print("--- No Attack ---")
    print(f"PSNR : {r['psnr']:.2f} dB")
    print(f"SSIM : {r['ssim']:.4f}")
    if bits:
        print(f"NC   : {r['clean']['nc']:.4f}\nBER  : {r['clean']['ber']:.4f}\n")
    else:
        print(f"Corr : {r['clean']['corr']:.4f}\nNC   : {r['clean']['nc']:.4f}\n")
    for a in r["attacks"]:
        extra = f"BER: {a['ber']:.4f}" if bits else f"NC: {a['nc']:.4f}"
        rs = f"   (re-synced {a['resync_angle']:+.2f} deg)" if a["resync_angle"] else ""
        print(f"--- {a['label']:<17} {'NC' if bits else 'Corr'}: {a['score']:.4f} | {extra}{rs}")

    # images
    Image.fromarray(m.watermarked).save(out / "watermarked.png")
    diff = np.abs(im.luma(m.watermarked) - im.luma(m.cover))
    fig, ax = plt.subplots(1, 4, figsize=(13, 3.6))
    show(ax[0], m.cover, "Original cover")
    show(ax[1], m.watermarked, f"Watermarked  (PSNR {r['psnr']:.2f} dB)")
    ax[2].imshow(diff, cmap="magma"); ax[2].set_title(f"|difference| (max {diff.max():.1f})", fontsize=9); ax[2].axis("off")
    show(ax[3], np.hstack([m.watermark, r["extracted"]]), "Watermark | extracted")
    save(fig, out / "overview.png")

    # attack grid (like section 6 of the MATLAB demos)
    n = len(r["attacks"]) + 2
    cols = 5
    rows = int(np.ceil(n / cols))
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 2.4, rows * 2.6))
    axes = axes.ravel()
    show(axes[0], m.watermark, "Original WM")
    show(axes[1], r["extracted"], "No attack")
    for ax, a in zip(axes[2:], r["attacks"]):
        show(ax, a["extracted"], f"{a['label']}\n{'NC' if bits else 'corr'} {a['score']:.3f}")
    for ax in axes[n:]:
        ax.axis("off")
    save(fig, out / "attacks.png")


if __name__ == "__main__":
    main()
