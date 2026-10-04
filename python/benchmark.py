"""BENCHMARK - every scheme x every attack, plus the false-positive security test.

Writes report-ready files to outputs/benchmark/:
    benchmark.csv / benchmark.png   robustness heat-map (PSNR, SSIM, per-attack score)
    security.csv  / security.png    genuine vs decoy vs fake-claim extraction

    python benchmark.py               # improved settings (512, colour, key, redundancy)
    python benchmark.py --matlab      # MATLAB demo settings for a like-for-like comparison
"""
import csv

import matplotlib.pyplot as plt
import numpy as np

from wmark import attacks as atk
from wmark.cli import outdir, parser, save, setup, show
from wmark.engine import benchmark, false_positive


def main():
    args = parser(__doc__.splitlines()[0], scheme=False).parse_args()
    cover, logo, cfg = setup(args)
    out = outdir("benchmark" + ("_matlab" if args.matlab else ""))
    names = list(atk.ATTACKS)
    labels = [atk.ATTACKS[n][0] for n in names]

    print(f"\nBenchmark on {cover.shape[0]}x{cover.shape[1]}, channel={cfg.channel}, key={cfg.key}")
    rows = benchmark(cover, cfg, logo)
    head = f"{'scheme':<30}{'alpha':>7}{'PSNR':>7}{'SSIM':>7}{'clean':>7}" + "".join(f"{l[:7]:>8}" for l in labels) + f"{'mean':>7}"
    print(head + "\n" + "-" * len(head))
    for r in rows:
        r["mean"] = float(np.mean([r["clean"], *r["attacks"].values()]))
        print(f"{r['title']:<30}{r['alpha']:>7.3g}{r['psnr']:>7.2f}{r['ssim']:>7.3f}{r['clean']:>7.3f}"
              + "".join(f"{r['attacks'][n]:>8.3f}" for n in names) + f"{r['mean']:>7.3f}")

    with open(out / "benchmark.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["scheme", "alpha", "blind", "psnr", "ssim", "clean", *labels, "mean"])
        for r in rows:
            w.writerow([r["title"], r["alpha"], r["blind"], f"{r['psnr']:.3f}", f"{r['ssim']:.4f}",
                        f"{r['clean']:.4f}", *[f"{r['attacks'][n]:.4f}" for n in names], f"{r['mean']:.4f}"])
    print(f"  saved {(out / 'benchmark.csv').name}")

    grid = np.array([[r["clean"], *[r["attacks"][n] for n in names]] for r in rows])
    fig, ax = plt.subplots(figsize=(13, 3.8))
    imh = ax.imshow(grid, cmap="RdYlGn", vmin=0, vmax=1, aspect="auto")
    ax.set_xticks(range(grid.shape[1]), ["No attack", *labels], rotation=35, ha="right", fontsize=8)
    ax.set_yticks(range(len(rows)), [f"{r['title']}\nPSNR {r['psnr']:.1f} dB" for r in rows], fontsize=8)
    for i in range(grid.shape[0]):
        for j in range(grid.shape[1]):
            ax.text(j, i, f"{grid[i, j]:.2f}", ha="center", va="center", fontsize=7)
    fig.colorbar(imh, ax=ax, fraction=0.025, label="NC / correlation")
    ax.set_title("Robustness of each scheme under each attack")
    save(fig, out / "benchmark.png")

    # ---- security / false positives
    print("\nFalse-positive test (want genuine ~1, decoy ~0, fake claim ~0)")
    sec = false_positive(cover, cfg, logo)
    for r in sec:
        flag = "FALSE POSITIVE" if r["decoy"] > 0.5 or r["claim"] > 0.5 else "secure"
        print(f"  {r['title']:<30} genuine {r['genuine']:6.3f}  decoy {r['decoy']:6.3f}  claim {r['claim']:6.3f}  -> {flag}")
    with open(out / "security.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["scheme", "blind", "genuine", "decoy", "fake_claim"])
        for r in sec:
            w.writerow([r["title"], r["blind"], f"{r['genuine']:.4f}", f"{r['decoy']:.4f}", f"{r['claim']:.4f}"])
    fig, axes = plt.subplots(len(sec), 4, figsize=(8, 2.1 * len(sec)))
    for row, r in zip(axes, sec):
        show(row[0], r["owner_watermark"], f"{r['title'][:24]}\nowner's mark")
        show(row[1], r["decoy_extract"], f"decoy  {r['decoy']:.2f}")
        show(row[2], r["fake_watermark"], "attacker's mark")
        show(row[3], r["claim_extract"], f"fake claim  {r['claim']:.2f}")
    save(fig, out / "security.png")


if __name__ == "__main__":
    main()
