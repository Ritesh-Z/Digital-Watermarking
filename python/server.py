"""Local web server: FastAPI backend for the 3-D watermarking lab.

Run:   python server.py          then open http://127.0.0.1:8000
"""
import base64
import io
import time
import threading
import webbrowser
from pathlib import Path
from threading import Timer

import numpy as np
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from starlette.concurrency import run_in_threadpool
from PIL import Image

from wmark import imaging as im
from wmark import attacks as atk
from wmark.engine import Config, alpha_sweep, benchmark, false_positive, run_experiment
from wmark.schemes import SCHEMES
from wmark.transforms import haar_dwt2

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent                  # MATLAB project folder (cover.jpg / logo.png)
WEB = HERE / "web"
VENDOR = WEB / "vendor"
THREE_CDN = "https://cdn.jsdelivr.net/npm/three@0.170.0/"
GRID = 160                             # resolution of the 3-D point cloud

class SafeJSON(JSONResponse):
    """JSON cannot encode inf/nan (e.g. PSNR of an unchanged image); send null instead."""

    def render(self, content):
        def clean(o):
            if isinstance(o, float):
                return o if np.isfinite(o) else None
            if isinstance(o, (np.floating, np.integer)):
                return clean(o.item())
            if isinstance(o, dict):
                return {k: clean(v) for k, v in o.items()}
            if isinstance(o, (list, tuple)):
                return [clean(v) for v in o]
            return o
        return super().render(clean(content))


app = FastAPI(title="Spectral Watermark Lab", default_response_class=SafeJSON)


@app.middleware("http")
async def no_cache(request, call_next):
    """Always serve the latest web files (no stale CSS/JS after an edit)."""
    response = await call_next(request)
    if not request.url.path.startswith("/vendor/"):
        response.headers["Cache-Control"] = "no-cache"
    return response


# ---------------------------------------------------------------- encoding
def png(arr, scale=None):
    arr = np.asarray(arr)
    if arr.dtype != np.uint8:
        arr = im.to_uint8(arr)
    pil = Image.fromarray(arr)
    if scale:
        pil = pil.resize((pil.width * scale, pil.height * scale), Image.NEAREST)
    buf = io.BytesIO()
    pil.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def jpg(arr, max_side=None, quality=88):
    pil = Image.fromarray(np.asarray(arr))
    if max_side and max(pil.size) > max_side:
        pil.thumbnail((max_side, max_side), Image.LANCZOS)
    buf = io.BytesIO()
    pil.convert("RGB").save(buf, format="JPEG", quality=quality)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def b64(arr):
    return base64.b64encode(np.ascontiguousarray(arr, dtype=np.uint8).tobytes()).decode()


def wm_image(w, payload):
    """Watermarks as viewable images (0/1 bits -> black/white)."""
    w = np.asarray(w)
    img = (w * 255).astype(np.uint8) if payload == "bits" else w
    scale = max(1, 256 // w.shape[0])
    return png(img, scale)


def heat(x):
    """Map [0,1] -> black -> magenta -> coral -> peach -> cream (retro palette)."""
    stops = np.array([[11, 11, 12], [70, 24, 66], [178, 63, 163], [232, 85, 58],
                      [244, 199, 184], [246, 231, 218]], dtype=float)
    t = np.clip(x, 0, 1) * (len(stops) - 1)
    i = np.minimum(t.astype(int), len(stops) - 2)
    f = (t - i)[..., None]
    return im.to_uint8(stops[i] * (1 - f) + stops[i + 1] * f)


def pool(x, n):
    """Average-pool a 2-D array down to n x n."""
    h = x.shape[0] // n
    return x[: h * n, : h * n].reshape(n, h, n, h).mean(axis=(1, 3))


def terrain(cover, watermarked):
    """Point-cloud data for the hero: colour, height (luma) and watermark energy."""
    c = np.asarray(cover)
    rgb = c if c.ndim == 3 else np.repeat(c[..., None], 3, axis=2)
    small = im.resize(rgb, (GRID, GRID)) if rgb.shape[0] != GRID else rgb
    diff = np.abs(im.luma(watermarked) - im.luma(cover))
    energy = pool(diff, GRID)
    energy = energy / (np.percentile(energy, 99.5) + 1e-9)
    return {
        "n": GRID,
        "rgb": b64(small.reshape(-1, 3)),
        "height": b64(im.to_uint8(im.luma(small))),
        "energy": b64(im.to_uint8(np.clip(energy, 0, 1) * 255)),
    }


# ---------------------------------------------------------------- request parsing
async def read_inputs(cover, logo, size):
    size = int(size)
    size -= size % 16
    if cover is not None and cover.filename:
        img = im.prepare_cover(im.load_image(io.BytesIO(await cover.read())), size)
    else:
        img = im.default_cover(size, [PROJECT, HERE])
    wm_src = None
    if logo is not None and logo.filename:
        wm_src = im.load_image(io.BytesIO(await logo.read()))
    elif (PROJECT / "logo.png").is_file():
        wm_src = str(PROJECT / "logo.png")
    return img, wm_src


def make_cfg(scheme, alpha, channel, key, redundant, resync, band):
    key = key.strip() if isinstance(key, str) else key
    return Config(
        scheme=scheme,
        alpha=None if alpha in ("", None) else float(alpha),
        channel=channel,
        key=None if key in ("", None) else int(key),
        redundant=str(redundant).lower() == "true",
        resync=str(resync).lower() == "true",
        band=band,
    )




# ---------------------------------------------------------------- API
@app.get("/api/meta")
def meta():
    return {
        "schemes": [s.info() for s in SCHEMES.values()],
        "attacks": [{"name": k, "label": v[0], "source": v[3]} for k, v in atk.ATTACKS.items()],
        "channels": list(im.CHANNELS),
        "has_project_cover": any((PROJECT / n).is_file() for n in ("cover.jpg", "cover.png")),
        "has_project_logo": (PROJECT / "logo.png").is_file(),
    }


def run_payload(r, img, t0):
    m = r["marked"]
    payload = m.scheme.payload
    diff = np.abs(im.luma(m.watermarked) - im.luma(m.cover))
    amp = float(np.percentile(diff, 99.5) or 1.0)
    LL, LH, HL, HH = haar_dwt2(im.luma(m.cover))
    return {
        "scheme": m.scheme.info(),
        "alpha": m.alpha,
        "size": int(img.shape[0]),
        "elapsed_ms": round((time.perf_counter() - t0) * 1000),
        "psnr": r["psnr"], "ssim": r["ssim"], "clean": r["clean"],
        "max_pixel_change": float(diff.max()),
        "copies": m.copies,
        "images": {
            "cover": jpg(m.cover, 768, 92),
            "watermarked": png(m.watermarked),
            "diff": png(heat(diff / amp)),
            "diff_gain": round(255 / amp, 1),
            "watermark": wm_image(m.watermark, payload),
            "extracted": wm_image(r["extracted"], payload),
            "bands": [png(im.mat2gray(b) * 255) if i == 0 else png(np.clip(np.abs(b) * 4, 0, 255))
                      for i, b in enumerate((LL, LH, HL, HH))],
        },
        "terrain": terrain(m.cover, m.watermarked),
        "attacks": [{
            "name": a["name"], "label": a["label"], "source": a["source"],
            "image": jpg(a["attacked"], 220, 80),
            "extracted": wm_image(a["extracted"], payload),
            "score": a["score"], "nc": a["nc"], "ber": a.get("ber"), "corr": a.get("corr"),
            "psnr": a["psnr"], "resync_angle": a["resync_angle"],
        } for a in r["attacks"]],
    }



# ---------------------------------------------------------------- compute (sync, cacheable)
SWEEP_ATTACKS = ["jpeg", "gaussian_noise", "salt_pepper", "median", "sharpen", "gaussian_blur", "rotation", "crop"]


def do_run(img, wm_src, cfg):
    t0 = time.perf_counter()
    return run_payload(run_experiment(img, cfg, wm_src), img, t0)


def do_benchmark(img, wm_src, cfg):
    t0 = time.perf_counter()
    rows = benchmark(img, cfg, wm_src)
    return {"rows": rows, "attacks": [{"name": k, "label": v[0]} for k, v in atk.ATTACKS.items()],
            "elapsed_ms": round((time.perf_counter() - t0) * 1000)}


def do_sweep(img, wm_src, cfg, points):
    t0 = time.perf_counter()
    s = SCHEMES[cfg.scheme]
    alphas = np.linspace(s.alpha_min, s.alpha_max, int(points))
    data = alpha_sweep(img, cfg, alphas, wm_src, SWEEP_ATTACKS)
    return {"scheme": s.info(), "points": data,
            "attacks": [{"name": n, "label": atk.ATTACKS[n][0]} for n in SWEEP_ATTACKS],
            "elapsed_ms": round((time.perf_counter() - t0) * 1000)}


def do_security(img, wm_src, cfg):
    out = []
    for r in false_positive(img, cfg, wm_src):
        payload = SCHEMES[r["scheme"]].payload
        out.append({
            "scheme": r["scheme"], "title": r["title"], "blind": r["blind"],
            "genuine": r["genuine"], "decoy": r["decoy"], "claim": r["claim"],
            "images": {k: wm_image(r[k], payload) for k in
                       ("owner_watermark", "decoy_extract", "fake_watermark", "claim_extract")},
        })
    return {"rows": out}


# ---------------------------------------------------------------- cache for the default inputs
# Results for the project's own cover.jpg / logo.png are cached, and the defaults are
# pre-computed in the background at start-up, so every page is ready on first load.
_CACHE, _LOCKS, _LOCKS_GUARD = {}, {}, threading.Lock()


def cache_key(kind, size, cfg, *extra):
    return (kind, int(size), cfg.scheme, cfg.alpha, cfg.channel, cfg.key, cfg.redundant,
            cfg.resync, cfg.band, *extra)


def cached(key, fn):
    """Compute once per key; concurrent callers for the same key wait for the first one."""
    if key is None:
        return fn()
    with _LOCKS_GUARD:
        lock = _LOCKS.setdefault(key, threading.Lock())
    with lock:
        if key not in _CACHE:
            _CACHE[key] = fn()
        return _CACHE[key]


def uploaded(*files):
    return any(f is not None and f.filename for f in files)


def warm_up():
    """Pre-compute what the page requests on first load (proposed scheme, default settings)."""
    t0 = time.perf_counter()
    size = 512
    img = im.default_cover(size, [PROJECT, HERE])
    wm_src = str(PROJECT / "logo.png") if (PROJECT / "logo.png").is_file() else None
    base = make_cfg("hybrid_qim", "", "Y", "2025", "true", "true", "HH")
    jobs = [
        (cache_key("run", size, base), lambda: do_run(img, wm_src, base)),
        (cache_key("security", size, base), lambda: do_security(img, wm_src, base)),
        (cache_key("benchmark", size, base), lambda: do_benchmark(img, wm_src, base)),
        (cache_key("sweep", size, base, 12), lambda: do_sweep(img, wm_src, base, 12)),
    ]
    for key, fn in jobs:
        try:
            cached(key, fn)
        except Exception as e:                 # never let warm-up take the server down
            print(f"  warm-up {key[0]} failed: {e}")
    print(f"  defaults pre-computed in {time.perf_counter() - t0:.1f} s (all pages ready)")


@app.on_event("startup")
def start_warm_up():
    threading.Thread(target=warm_up, daemon=True).start()


# ---------------------------------------------------------------- API
@app.post("/api/run")
async def api_run(cover: UploadFile | None = File(None), logo: UploadFile | None = File(None),
                  scheme: str = Form("hybrid_qim"), alpha: str = Form(""),
                  size: str = Form("512"), channel: str = Form("Y"),
                  key: str = Form("2025"), redundant: str = Form("true"),
                  resync: str = Form("true"), band: str = Form("HH")):
    img, wm_src = await read_inputs(cover, logo, size)
    cfg = make_cfg(scheme, alpha, channel, key, redundant, resync, band)
    k = None if uploaded(cover, logo) else cache_key("run", img.shape[0], cfg)
    return await run_in_threadpool(cached, k, lambda: do_run(img, wm_src, cfg))


@app.post("/api/benchmark")
async def api_benchmark(cover: UploadFile | None = File(None), logo: UploadFile | None = File(None),
                        size: str = Form("512"), channel: str = Form("Y"),
                        key: str = Form("2025"), redundant: str = Form("true"),
                        resync: str = Form("true"), band: str = Form("HH")):
    img, wm_src = await read_inputs(cover, logo, size)
    cfg = make_cfg("hybrid_qim", "", channel, key, redundant, resync, band)
    k = None if uploaded(cover, logo) else cache_key("benchmark", img.shape[0], cfg)
    return await run_in_threadpool(cached, k, lambda: do_benchmark(img, wm_src, cfg))


@app.post("/api/sweep")
async def api_sweep(cover: UploadFile | None = File(None), logo: UploadFile | None = File(None),
                    scheme: str = Form("hybrid_qim"), size: str = Form("512"),
                    channel: str = Form("Y"), key: str = Form("2025"),
                    redundant: str = Form("true"), resync: str = Form("true"),
                    band: str = Form("HH"), points: str = Form("12")):
    img, wm_src = await read_inputs(cover, logo, size)
    cfg = make_cfg(scheme, "", channel, key, redundant, resync, band)
    k = None if uploaded(cover, logo) else cache_key("sweep", img.shape[0], cfg, int(points))
    return await run_in_threadpool(cached, k, lambda: do_sweep(img, wm_src, cfg, points))


@app.post("/api/security")
async def api_security(cover: UploadFile | None = File(None), logo: UploadFile | None = File(None),
                       size: str = Form("512"), channel: str = Form("Y"),
                       key: str = Form("2025"), redundant: str = Form("true"),
                       resync: str = Form("true"), band: str = Form("HH")):
    img, wm_src = await read_inputs(cover, logo, size)
    cfg = make_cfg("hybrid_qim", "", channel, key, redundant, resync, band)
    k = None if uploaded(cover, logo) else cache_key("security", img.shape[0], cfg)
    return await run_in_threadpool(cached, k, lambda: do_security(img, wm_src, cfg))


# ---------------------------------------------------------------- static files
@app.get("/vendor/{path:path}")
def vendor(path: str):
    """Serve three.js locally if fetched (python fetch_vendor.py), else redirect to the CDN."""
    local = (VENDOR / path).resolve()
    if local.is_file() and VENDOR.resolve() in local.parents:
        return FileResponse(local)
    return RedirectResponse(THREE_CDN + path)


@app.get("/")
def index():
    return FileResponse(WEB / "index.html")


app.mount("/", StaticFiles(directory=WEB), name="web")


if __name__ == "__main__":
    import argparse
    import uvicorn

    ap = argparse.ArgumentParser(description="Spectral Watermark Lab - local web UI")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--no-browser", action="store_true")
    args = ap.parse_args()
    url = f"http://127.0.0.1:{args.port}"
    print(f"\n  Spectral Watermark Lab running at {url}\n  (Ctrl+C to stop)\n")
    if not args.no_browser:
        Timer(1.2, lambda: webbrowser.open(url)).start()
    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning")
