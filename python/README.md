# Spectral Watermark Lab: Python edition

> Full write-up of the proposed scheme, its theory, the problems faced and the experiments:
> [`../PROPOSED_SCHEME.md`](../PROPOSED_SCHEME.md)

A Python port of the MATLAB watermarking project, with improvements, a
**3-D interactive web UI**, report-generating scripts, video/webcam demos
and a test suite. Free, runs locally, no MATLAB needed.

The MATLAB code in the parent folder remains the reference implementation;
`--matlab` mode here reproduces its settings exactly.

## Quick start

```bash
pip install -r requirements.txt
python server.py            # opens http://127.0.0.1:8000 (or double-click start_lab.bat)
```

The 3-D frontend loads three.js from a CDN. To run fully **offline** (e.g. in a viva room):

```bash
python fetch_vendor.py      # one-time, saves three.js into web/vendor/
```

## What's inside

| File | Purpose |
| :--- | :--- |
| `server.py` | FastAPI backend serving the web UI and the JSON API |
| `web/` | Three.js frontend: 3-D point-cloud hero, studio, attack arena, 3-D benchmark, α-sweep charts, security lab |
| `demo.py` | Equivalent of `main_demo_*.m`: embed, extract, metrics, attacks, figures |
| `benchmark.py` | All schemes × all attacks + false-positive test → CSV + heat-maps for the report |
| `experiment.py` | Fair comparison of all schemes at equal PSNR (iso-PSNR), with `--skimage` standard test images |
| `alpha_sweep.py` | α vs PSNR / NC curves (the paper's tables and graphs) |
| `video_demo.py` | Frame-by-frame video watermarking with temporal majority voting |
| `webcam_live.py` | Real-time webcam embedding + blind extraction |
| `tests/` | 34 pytest checks (transforms, round-trips, robustness, security) |
| `wmark/` | The engine (pure NumPy, transforms written by hand) |

### Engine map (MATLAB → Python)

| MATLAB | Python |
| :--- | :--- |
| `dct_watermark_embed/extract.m` | `wmark/schemes.py` → `DCTScheme` |
| `dwt_watermark_embed/extract.m` | `wmark/schemes.py` → `DWTScheme` |
| `svd_watermark_embed/extract.m` | `wmark/schemes.py` → `SVDScheme` |
| *(base paper, not in MATLAB)* | `HybridPaperScheme`: DWT → 4×4 DCT → DC matrix → SVD |
| *(new)* | `HybridQIMScheme`: the proposed blind scheme |
| `manual_dwt2_haar.m`, `manual_idwt2_haar.m` | `wmark/transforms.py` |
| `manual_medfilt2.m`, `manual_imnoise_*.m` | `wmark/attacks.py` |
| `calculate_metrics*.m` | `wmark/metrics.py` (+ SSIM) |
| `manual_rgb2gray.m`, `manual_imresize.m`, `insertTextSafe.m` | `wmark/imaging.py` |

## Command-line examples

```bash
python demo.py --scheme dct --matlab        # same settings as main_demo_dct.m (256, gray)
python demo.py --scheme hybrid_qim          # proposed scheme, 512x512, colour
python benchmark.py                         # -> outputs/benchmark/*.csv, *.png
python alpha_sweep.py --scheme hybrid_paper # paper-style alpha vs NC table + plot
python video_demo.py                        # synthetic clip from cover.jpg, or --video my.mp4
python webcam_live.py                       # needs a webcam
python -m pytest -q tests
```

Common options: `--cover`, `--logo`, `--size`, `--channel {Y,gray,R,G,B}`, `--key`, `--alpha`.

## Improvements over the MATLAB version

1. **Paper reproduction:** the base paper's hybrid DWT-DCT-SVD algorithm, implemented step by step.
2. **Proposed scheme:** blind DWT → 4×4 DCT → QIM on the DC coefficients of the LL band.
3. **Keyed spreading + redundancy:** each bit is written several times at secret positions and
   majority-voted (3× at 512², up to 7× at 1024²; always an odd count, so votes never tie).
4. **Key-dependent scrambling and dithered QIM:** a wrong key or an unmarked image decodes to noise.
5. **Median pre-filter at extraction:** removes salt & pepper impulses (0.76 → 1.00).
6. **Blind re-synchronisation:** the agreement between copies of a bit reveals the rotation angle, with no original needed.
7. **Colour support:** embeds in luminance (Y) and keeps the colours.
8. **6 more attacks:** the paper's set (sharpening, blur, lines, rotation) plus crop and scaling,
   all seeded so results are reproducible.
9. **SSIM:** reported alongside PSNR.
10. **Vectorised transforms:** block DCT and median filter without loops, so a full benchmark takes ~12 s.

## Key results: fair comparison at equal image quality

Every scheme's strength is tuned **per image** until the watermarked image has exactly
**PSNR = 40 dB**, and only then is robustness compared (`python experiment.py`). Comparing
schemes at their default strengths would be unfair, because a scheme that changes the image
more always looks more robust.

**Held-out test (the honest number).** The proposed scheme's settings were tuned on one set
of images, then tested on 8 standard scikit-image images it never saw (Coffee, Rocket, Moon,
Grass, Text, Retina, Hubble, Immunohistochemistry), each with 2 logos and all 11 attacks:

| Scheme | Mean robustness | Wins (of 16) |
| :--- | ---: | ---: |
| **Hybrid DWT-DCT-QIM (proposed)** | **0.950** | **12** |
| Block DCT (MATLAB port) | 0.945 | 2 |
| Haar DWT + QIM | 0.712 | 2 |
| Hybrid DWT-DCT-SVD (base paper) | 0.659 | 0 |
| Classic SVD | 0.568 | 0 |

On the project's own images (lion, your poster, screenshots, synthetic graphics; 14 pairs) the
proposed scheme won 14/14 (mean 0.963 vs 0.918), but those images were also used during
development, so the held-out table is the one to quote. It is **not** best on every single
image: Haar DWT wins on Grass and Block DCT narrowly wins on Immunohistochemistry.

**What makes it strong:** each 8x8 block carries three independent copies of each bit
(DC brightness via clip-aware dithered QIM; a low-frequency DCT pair difference via QIM; the
order of a mid-frequency pair, which is scale-invariant), and a blind decoder weights the
carriers by how consistently their copies agree, after repairing salt & pepper impulses.

**Main finding:** both SVD-based schemes, including the paper's hybrid, suffer from the
ownership-ambiguity flaw (Zhang & Li, 2005). Anyone holding the watermarked image can use their
own `Uw`, `Vw` to "extract" their own logo with correlation ≈ 0.73 (anything above 0.5 counts as a match), so the extraction alone
cannot prove ownership. The proposed blind QIM scheme doesn't have this problem.

**Note on metrics:** robustness for grayscale watermarks is reported as Pearson correlation
(mean-centred). The paper's NC formula, Σww′/√(Σw²Σw′²), stays high for any two non-negative
images, so it overstates robustness. Both values are computed (`metrics.nc_image`).
