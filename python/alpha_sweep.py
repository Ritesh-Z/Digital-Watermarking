"""ALPHA SWEEP - alpha vs PSNR / NC under every attack (the paper's tables and graphs).

    python alpha_sweep.py --scheme hybrid_paper            # paper's alpha range 0.01 .. 1.0
    python alpha_sweep.py --scheme hybrid_qim --points 15

Writes outputs/sweep_<scheme>/sweep.csv and sweep.png.
"""
import csv

import matplotlib.pyplot as plt
import numpy as np

from wmark import attacks as atk
from wmark.cli import outdir, parser, save, setup
from wmark.engine import alpha_sweep
from wmark.schemes import get_scheme


def main():
    p = parser(__doc__.splitlines()[0])
    p.add_argument("--points", type=int, default=12)
    args = p.parse_args()
    cover, logo, cfg = setup(args)
    s = get_scheme(cfg.scheme, cfg.band)
    alphas = np.linspace(s.alpha_min, s.alpha_max, args.points)
    names = list(atk.ATTACKS)
    labels = [atk.ATTACKS[n][0] for n in names]
    out = outdir(f"sweep_{cfg.scheme}")

    print(f"\nAlpha sweep: {s.title}, {args.points} points in [{s.alpha_min}, {s.alpha_max}]")
    data = alpha_sweep(cover, cfg, alphas, logo)
    print(f"{'alpha':>8}{'PSNR':>8}{'SSIM':>8}{'clean':>8}" + "".join(f"{l[:7]:>8}" for l in labels))
    for d in data:
        print(f"{d['alpha']:>8.3g}{d['psnr']:>8.2f}{d['ssim']:>8.3f}{d['clean']:>8.3f}"
              + "".join(f"{d['attacks'][n]:>8.3f}" for n in names))

    with open(out / "sweep.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["alpha", "psnr", "ssim", "clean", *labels])
        for d in data:
            w.writerow([f"{d['alpha']:.5g}", f"{d['psnr']:.3f}", f"{d['ssim']:.4f}", f"{d['clean']:.4f}",
                        *[f"{d['attacks'][n]:.4f}" for n in names]])
    print(f"  saved {(out / 'sweep.csv').name}")

    fig, ax = plt.subplots(figsize=(10, 5))
    a = [d["alpha"] for d in data]
    ax.plot(a, [d["clean"] for d in data], "k-", lw=2, label="No attack")
    for n, l in zip(names, labels):
        ax.plot(a, [d["attacks"][n] for d in data], marker=".", lw=1.3, label=l)
    ax.set_xlabel("alpha (embedding strength)")
    ax.set_ylabel("NC / correlation")
    ax.grid(alpha=0.3)
    ax2 = ax.twinx()
    ax2.plot(a, [d["psnr"] for d in data], "k--", lw=2, label="PSNR")
    ax2.set_ylabel("PSNR (dB)")
    ax.legend(fontsize=7, ncol=2, loc="lower right")
    ax.set_title(f"{s.title}: robustness vs imperceptibility")
    save(fig, out / "sweep.png")


if __name__ == "__main__":
    main()
