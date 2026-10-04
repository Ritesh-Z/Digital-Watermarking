"""VIDEO DEMO - frame-by-frame watermarking with temporal majority voting.

Embeds the same 32x32 watermark into every frame (blind scheme), writes a
real lossy MPEG-4 file, reads it back and extracts the watermark:
    per frame   : extract from each frame on its own
    temporal    : vote every bit across all frames (much more robust)
Also tests frame dropping and frame-averaging (a simple collusion attack).

    python video_demo.py                       # synthetic pan/zoom clip from cover.jpg
    python video_demo.py --video clip.mp4      # your own video
"""
from pathlib import Path

import cv2
import numpy as np

from wmark import imaging as im
from wmark import metrics as mt
from wmark.cli import PROJECT, HERE, outdir
from wmark.engine import Config, make_watermark
from wmark.schemes import get_scheme


def synthetic_clip(n=72, w=640, h=368):
    """Slow 'Ken Burns' pan + zoom over the cover image."""
    src = im.default_cover(1024, [PROJECT, HERE])
    frames = []
    for i in range(n):
        t = i / (n - 1)
        zoom = 1.0 + 0.35 * t
        cw, ch = int(1024 / zoom), int(1024 * h / w / zoom)
        x0 = int((1024 - cw) * (0.2 + 0.6 * t))
        y0 = int((1024 - ch) * 0.5)
        frames.append(im.resize(src[y0:y0 + ch, x0:x0 + cw], (h, w)))
    return frames, 24.0


def read_video(path, max_frames=150):
    cap = cv2.VideoCapture(str(path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    frames = []
    while len(frames) < max_frames:
        ok, f = cap.read()
        if not ok:
            break
        f = cv2.cvtColor(f, cv2.COLOR_BGR2RGB)
        h, w = f.shape[:2]
        frames.append(f[: h - h % 16, : w - w % 16])
    cap.release()
    return frames, fps


def write_video(path, frames, fps):
    h, w = frames[0].shape[:2]
    vw = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (w, h))
    for f in frames:
        vw.write(cv2.cvtColor(f, cv2.COLOR_RGB2BGR))
    vw.release()


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--video", default=None)
    p.add_argument("--scheme", default="hybrid_qim", choices=["dct", "dwt", "hybrid_qim"])
    p.add_argument("--alpha", type=float, default=None)
    p.add_argument("--key", type=int, default=2025)
    args = p.parse_args()

    frames, fps = read_video(args.video) if args.video else synthetic_clip()
    out = outdir("video")
    scheme = get_scheme(args.scheme)
    # Video codecs compress far harder than JPEG Q80, so the proposed scheme
    # defaults to a stronger step for video (alpha 36 -> 60, ~37 dB PSNR).
    alpha = args.alpha or (60 if args.scheme == "hybrid_qim" else scheme.alpha_default)
    cfg = Config(scheme=args.scheme, key=args.key)
    logo = str(PROJECT / "logo.png") if (PROJECT / "logo.png").is_file() else None
    wm = make_watermark(scheme, 0, logo)
    print(f"\n{len(frames)} frames {frames[0].shape[1]}x{frames[0].shape[0]} @ {fps:.0f} fps, "
          f"scheme={scheme.title}, alpha={alpha}")

    marked, psnrs = [], []
    for f in frames:
        host, ctx = im.split_channel(f, "Y")
        mh, _ = scheme.embed(host, wm, alpha, cfg.key, True)
        mf = im.merge_channel(mh, ctx)
        marked.append(mf)
        psnrs.append(mt.psnr(f, mf))
    print(f"mean PSNR per frame: {np.mean(psnrs):.2f} dB (min {np.min(psnrs):.2f})")

    write_video(out / "original.mp4", frames, fps)
    write_video(out / "watermarked.mp4", marked, fps)
    decoded, _ = read_video(out / "watermarked.mp4")
    print(f"wrote + re-read watermarked.mp4 (MPEG-4, lossy) -> {len(decoded)} frames")

    def evaluate(name, clip):
        per = [scheme.extract(im.get_channel(f, "Y"), alpha, cfg.key, True, None, wm.shape) for f in clip]
        per_nc = [mt.nc_bits(wm, e) for e in per]
        voted = (np.mean(per, axis=0) > 0.5).astype(np.uint8)
        print(f"  {name:<28} per-frame NC mean {np.mean(per_nc):.4f} (worst {np.min(per_nc):.4f})"
              f"  ->  temporal vote NC {mt.nc_bits(wm, voted):.4f}  BER {mt.ber(wm, voted):.4f}")
        return voted

    print("\nExtraction:")
    evaluate("MPEG-4 decoded", decoded)
    evaluate("MPEG-4 + drop every 3rd frame", [f for i, f in enumerate(decoded) if i % 3])
    avg = [im.to_uint8((decoded[i].astype(float) + decoded[i + 1]) / 2) for i in range(len(decoded) - 1)]
    evaluate("frame averaging (collusion)", avg)
    noisy = [im.to_uint8(f + np.random.default_rng(i).normal(0, 6, f.shape)) for i, f in enumerate(decoded)]
    voted = evaluate("MPEG-4 + noise sigma 6", noisy)

    big = np.kron(np.hstack([wm, voted]), np.ones((8, 8), np.uint8)) * 255
    cv2.imwrite(str(out / "watermark_vs_extracted.png"), big)
    print(f"\n  saved outputs/video/ (original.mp4, watermarked.mp4, watermark_vs_extracted.png)")


if __name__ == "__main__":
    main()
