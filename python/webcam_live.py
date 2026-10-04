"""LIVE WEBCAM - real-time watermark embedding and blind extraction.

Every webcam frame is watermarked with the proposed scheme, optionally
attacked, and the watermark is extracted again - live.

Keys:  j = toggle JPEG(Q50) attack   n = toggle noise attack
       +/- = change alpha            q / Esc = quit

    python webcam_live.py [--camera 0]
"""
import argparse
import time

import cv2
import numpy as np

from wmark import attacks as atk
from wmark import imaging as im
from wmark import metrics as mt
from wmark.cli import PROJECT
from wmark.engine import make_watermark
from wmark.schemes import get_scheme


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--camera", type=int, default=0)
    p.add_argument("--scheme", default="hybrid_qim", choices=["dct", "dwt", "hybrid_qim"])
    p.add_argument("--key", type=int, default=2025)
    args = p.parse_args()

    cap = cv2.VideoCapture(args.camera)
    if not cap.isOpened():
        raise SystemExit(f"Could not open camera {args.camera}")
    scheme = get_scheme(args.scheme)
    alpha = scheme.alpha_default
    logo = str(PROJECT / "logo.png") if (PROJECT / "logo.png").is_file() else None
    wm = make_watermark(scheme, 0, logo)
    use_jpeg = use_noise = False
    t_prev, fps = time.perf_counter(), 0.0

    while True:
        ok, frame = cap.read()
        if not ok:
            break
        rgb = cv2.cvtColor(cv2.resize(frame, (640, 480)), cv2.COLOR_BGR2RGB)
        host, ctx = im.split_channel(rgb, "Y")
        mh, _ = scheme.embed(host, wm, alpha, args.key, True)
        marked = im.merge_channel(mh, ctx)
        received = marked
        if use_jpeg:
            received = atk.jpeg(received, quality=50)
        if use_noise:
            received = atk.gaussian_noise(received, variance=0.001, seed=int(time.time() * 1000) % 10000)
        ext = scheme.extract(im.get_channel(received, "Y"), alpha, args.key, True, None, wm.shape)
        nc, psnr = mt.nc_bits(wm, ext), mt.psnr(rgb, marked)

        now = time.perf_counter()
        fps = 0.9 * fps + 0.1 / max(now - t_prev, 1e-6)
        t_prev = now

        left = cv2.cvtColor(received, cv2.COLOR_RGB2BGR)
        panel = np.zeros((480, 300, 3), np.uint8)
        big = cv2.resize((np.hstack([wm, ext]) * 255).astype(np.uint8), (280, 140), interpolation=cv2.INTER_NEAREST)
        panel[20:160, 10:290] = big[..., None]
        lines = [f"{scheme.title}", f"alpha {alpha:g}", f"PSNR {psnr:5.2f} dB", f"NC   {nc:6.4f}",
                 f"FPS  {fps:5.1f}", "", f"[j] JPEG Q50: {'ON' if use_jpeg else 'off'}",
                 f"[n] noise:    {'ON' if use_noise else 'off'}", "[+/-] alpha   [q] quit"]
        for i, t in enumerate(lines):
            cv2.putText(panel, t, (12, 200 + i * 28), cv2.FONT_HERSHEY_SIMPLEX, 0.55,
                        (120, 255, 120) if t.startswith("NC") and nc > 0.9 else (230, 230, 230), 1, cv2.LINE_AA)
        cv2.putText(panel, "original | extracted", (12, 15), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (180, 180, 180), 1)
        cv2.imshow("Spectral Watermark Lab - live", np.hstack([left, panel]))

        k = cv2.waitKey(1) & 0xFF
        if k in (ord("q"), 27):
            break
        if k == ord("j"):
            use_jpeg = not use_jpeg
        if k == ord("n"):
            use_noise = not use_noise
        if k in (ord("+"), ord("=")):
            alpha = min(scheme.alpha_max, alpha + scheme.alpha_step * 4)
        if k == ord("-"):
            alpha = max(scheme.alpha_min, alpha - scheme.alpha_step * 4)

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
