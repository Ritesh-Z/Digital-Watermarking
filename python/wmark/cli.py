"""Shared command-line options and figure helpers for the demo scripts."""
import argparse
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

from . import imaging as im  # noqa: E402
from .engine import Config  # noqa: E402

HERE = Path(__file__).resolve().parent.parent      # python/
PROJECT = HERE.parent                               # MATLAB project (cover.jpg, logo.png)
OUT = HERE / "outputs"


def parser(description, scheme=True):
    p = argparse.ArgumentParser(description=description)
    if scheme:
        p.add_argument("--scheme", default="hybrid_qim",
                       choices=["dct", "dwt", "svd", "hybrid_paper", "hybrid_qim"])
        p.add_argument("--alpha", type=float, default=None, help="embedding strength (default: scheme default)")
    p.add_argument("--cover", default=None, help="cover image (default: ../cover.jpg)")
    p.add_argument("--logo", default=None, help="watermark logo (default: ../logo.png, else 'VIT' text)")
    p.add_argument("--size", type=int, default=512, help="cover is resized to size x size (multiple of 16)")
    p.add_argument("--channel", default="Y", choices=list(im.CHANNELS))
    p.add_argument("--key", type=int, default=2025)
    p.add_argument("--band", default="HH", choices=["LH", "HL", "HH"], help="paper hybrid band")
    p.add_argument("--matlab", action="store_true",
                   help="reproduce the MATLAB demos: 256x256 gray, no key/redundancy/resync")
    return p


def setup(args):
    """Returns (cover, watermark source, Config) from parsed args."""
    if args.matlab:
        args.size, args.channel = 256, "gray"
    size = args.size - args.size % 16
    if args.cover:
        cover = im.prepare_cover(im.load_image(args.cover), size)
    else:
        cover = im.default_cover(size, [PROJECT, HERE])
    logo = args.logo or (str(PROJECT / "logo.png") if (PROJECT / "logo.png").is_file() else None)
    cfg = Config(
        scheme=getattr(args, "scheme", "hybrid_qim"),
        alpha=getattr(args, "alpha", None),
        channel=args.channel,
        key=None if args.matlab else args.key,
        redundant=not args.matlab,
        resync=not args.matlab,
        band=args.band,
    )
    return cover, logo, cfg


def outdir(name):
    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    return d


def show(ax, img, title, cmap="gray"):
    img = np.asarray(img)
    ax.imshow(img, cmap=cmap if img.ndim == 2 else None, vmin=0 if img.ndim == 2 else None,
              vmax=(1 if img.max() <= 1 else 255) if img.ndim == 2 else None,
              interpolation="nearest")
    ax.set_title(title, fontsize=9)
    ax.axis("off")


def save(fig, path):
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"  saved {path.relative_to(HERE)}")
