"""Download the few three.js files the web UI needs into web/vendor/, so the
3-D frontend also works with no internet (e.g. in a viva room).

    python fetch_vendor.py

Without this, the server simply redirects /vendor/... to the jsDelivr CDN.
"""
import re
import urllib.request
from pathlib import Path

CDN = "https://cdn.jsdelivr.net/npm/three@0.170.0/"
VENDOR = Path(__file__).resolve().parent / "web" / "vendor"
ENTRY = [
    "build/three.module.js",
    "examples/jsm/controls/OrbitControls.js",
    "examples/jsm/renderers/CSS2DRenderer.js",
    "examples/jsm/postprocessing/EffectComposer.js",
    "examples/jsm/postprocessing/RenderPass.js",
    "examples/jsm/postprocessing/UnrealBloomPass.js",
    "examples/jsm/postprocessing/OutputPass.js",
]
REL = re.compile(r"""from\s+['"](\.{1,2}/[^'"]+)['"]""")


def fetch(path, seen):
    if path in seen:
        return
    seen.add(path)
    dest = VENDOR / path
    if not dest.exists():
        dest.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(CDN + path) as r:
            dest.write_bytes(r.read())
        print("  ", path)
    base = Path(path).parent
    for rel in REL.findall(dest.read_text(encoding="utf-8")):
        fetch(_norm(base, rel), seen)


def _norm(base, rel):
    parts = list(base.parts)
    for p in rel.split("/"):
        if p == "..":
            parts.pop()
        elif p != ".":
            parts.append(p)
    return "/".join(parts)


if __name__ == "__main__":
    print(f"Fetching three.js into {VENDOR}")
    seen = set()
    for e in ENTRY:
        fetch(e, seen)
    print(f"Done - {len(seen)} files. The web UI now works offline.")
