# Digital Watermarking: hybrid DWT-DCT-SVD with BFO / PBFO

This project hides a small logo inside a photo so that nobody can see it, and later gets the logo back
out, even after the photo has been attacked with noise. The embedding strength `alpha` is chosen
automatically by Bacterial Foraging Optimization (BFO). PBFO is the same search with its step size
tuned by Particle Swarm Optimization (PSO).

**How to run it:** open MATLAB in this folder and type `main`. You need MATLAB R2018a or newer, and no toolboxes.

**The GUI: one window, six steps** (use the step buttons in the black left rail to move between unlocked steps; click any picture to enlarge it)
1. **Upload images:** browse for the cover image and the logo, then press Submit.
2. **Watermarked image:** shows the result and its PSNR, and walks through how the logo was embedded
   (DWT, DCT, SVD, alpha found by PBFO, embed, rebuild) with Previous/Next.
3. **Extracted watermark:** shows the given logo next to the extracted one with its NC, and walks through
   how the extraction works.
4. **Attack tests:** pick a noise and its strength and press OK. The noise goes on the watermarked image,
   the logo is extracted again, and NC and BER are shown.
5. **Results / comparison:** shows the images and tables comparing all five methods under every noise.
6. **Workflow:** a flowchart of the embedding and extraction, with the formula and file for every box, and every project file listed in the order it runs.

---

## The pipeline (folders are numbered in this order)

```
 cover photo ─┐
              ├─ STEP 1 input ──► STEP 2 transforms ──► STEP 3 embedding ◄── STEP 4 optimisation (alpha)
 logo ────────┘                                              │
                                                       watermarked image
                                                             │
                                  STEP 5 extraction ◄────────┤
                                                             │
                                  STEP 6 attacks ──► noisy image ──► STEP 5 extraction again
                                                             │
                                  STEP 7 metrics  (PSNR, SSIM, IF, NC, BER)
```

| Folder | File | What it does |
|---|---|---|
| `step1_input/` | `loadImageFile.m` | Reads any image file and returns plain uint8 (handles palette, 16-bit and transparency) |
| | `prepareCoverImage.m` | Cover image: RGB → gray, resized to 256 × 256 |
| | `prepareWatermarkLogo.m` | Logo: shrinks it to 32 px or less and turns it into a black/white 0/1 matrix **W** (Otsu threshold) |
| | `rgbToGray.m`, `resizeNearest.m` | Small helpers |
| `step2_transforms/` | `haarDWT2.m` / `haarIDWT2.m` | One-level Haar wavelet transform → LL, LH, HL, **HH**, and its inverse |
| | `dctMatrix.m` | DCT matrix T, so that `D = T*X*T'` |
| | `rgbToYCbCr.m` / `yCbCrToRgb.m` | **Colour mode only:** splits a colour photo into brightness Y plus colour Cb and Cr, and joins them back |
| `step3_embedding/` | `splitCoverIntoBands.m` | Shared first part: DWT of the cover |
| | `embedStage1_DWT.m` | Method 1: `HH + alpha*W` |
| | `embedStage2_DWT_DCT.m` | Method 2: `DCT(HH) + alpha*W` |
| | `analyseCoverAndLogo.m` | Steps 1–3 of the main method (DWT, DCT, SVD), which do not depend on α. The α search computes them once, which makes it faster |
| | `embedStage3_DWT_DCT_SVD.m` | **Method 3 (main method):** `s_new = s + alpha*sw` |
| | `rebuildFromBands.m` | Shared last part: inverse DWT, then round to 8-bit |
| | `embedAllStages.m` | Runs the alpha search and all five methods |
| | `addColourToStages.m` | **Colour mode only:** watermarked Y plus the original Cb and Cr gives a colour watermarked image |
| `step4_optimization/` | `fitnessFunction.m` | `F(alpha) = 1 / (NC_gauss + NC_shot + NC_s&p + NC_speckle)`. Lower is better. |
| | `optimizerBFO.m` | Bacterial foraging (tumble, swim, reproduce, disperse) |
| | `optimizerPSO.m` | Particle swarm |
| | `optimizerPBFO.m` | PSO tunes the BFO step size, then BFO runs with it |
| `step5_extraction/` | `extractWatermark.m` | Runs the embedding backwards: `sw* = (s* − s)/alpha`, then `W* = Uw·diag(sw*)·Vw'` |
| | `receivedImage.m` | Gives the image that extraction works on: the image itself, or Y taken from the colour image |
| `step6_attacks/` | `applyAttack.m` | Gaussian, shot (Poisson), salt & pepper and speckle noise |
| | `attackAndExtract.m` | Attacks the image, extracts the logo and scores it, for all five methods |
| | `defaultAttackSettings.m` | The paper's noise strengths |
| `step7_metrics/` | `calculateMetrics.m` | PSNR, SSIM, IF (image vs image) and NC, BER (logo vs logo) |
| `gui/` | `watermarkingApp.m` | The step-by-step window |

## The five methods that are compared

| # | Method | alpha |
|---|---|---|
| 1 | DWT | 30 (fixed) |
| 2 | DWT-DCT | 30 (fixed) |
| 3 | DWT-DCT-SVD | 30 (fixed) |
| 4 | DWT-DCT-SVD-BFO | found by BFO |
| 5 | **DWT-DCT-SVD-PBFO** | found by PBFO (the result of this project) |

## The main algorithm (method 3/5) in one place

**Embedding**
1. `[LL,LH,HL,HH] = DWT(cover)`. Use the HH band, because the eye notices changes to fine diagonal
   detail the least.
2. `D = DCT(HH)`. This spreads the change over the whole band.
3. `D = U·S·V'` and `W = Uw·Sw·Vw'`. Singular values hardly change under noise, so they are a robust
   place to hide the logo.
4. `s_new = s + alpha·sw`, using the first *k* values, where *k* is the rank of the logo.
5. Inverse SVD, then inverse DCT, then inverse DWT. This gives the watermarked image.
6. Keep the key `{s, Uw, Vw, alpha}`. The method is non-blind, so extraction needs this key.

**Extraction**
1. `HH* = DWT(image)`, then `D* = DCT(HH*)`, then `s* = svd(D*)`.
2. `sw* = (s* − s) / alpha`.
3. `W* = Uw·diag(sw*)·Vw'`, then a threshold at 0.5.

**Reading the scores**
- PSNR above about 40 dB means the change cannot be seen.
- SSIM close to 1 means the image structure is unchanged.
- NC close to 1 means the logo came back intact.
- BER close to 0 % means few logo pixels are wrong.

A larger alpha gives a higher NC but a lower PSNR. That trade-off is why alpha is optimised.

## Colour mode (optional, off by default)

The paper works on 8-bit **grayscale** images, so by default the cover photo is converted to gray.
If you tick **"Keep colour"** on the Upload page:

1. The colour cover is split into **Y** (brightness), **Cb** and **Cr** (colour) with `rgbToYCbCr.m`.
2. The paper's method runs on **Y** unchanged, because Y *is* the grayscale image.
3. The watermarked Y is joined with the original Cb and Cr in `yCbCrToRgb.m`, giving a colour watermarked image.
4. Extraction takes Y back out of the colour image (`receivedImage.m`). Attacks are applied to the colour image.

The embedding and extraction walkthroughs then show the extra colour steps (2.0, 2.8 and 3.0), and the
results also give a colour PSNR. Save as PNG: it is lossless, so the hidden logo survives.

## Image quality setting (Upload page)

The paper's fitness (eq. 13) only rewards robustness (NC), so on its own the alpha search always picks
the strongest alpha. That makes the watermark more visible: for example α = 100 gives a PSNR of about 35 dB.

- **Image quality (minimum PSNR)**, default **42 dB:** the search adds a large penalty for every dB below
  the limit, so it finds the **most robust alpha that still keeps PSNR above the limit**
  (`fitnessFunction.m`, setting `minPSNR` in `embedAllStages.m`). "No limit" is exactly the paper's eq. 13.
- **Cover size:** 256 × 256 (fast, the default), 512 × 512 (as in the paper) or 1024 × 1024 (1K). Each doubling
  spreads the same logo over four times as many pixels, which gives about 6 dB better PSNR and a sharper picture.
  The alpha search gets much slower: 1K takes several minutes, and the app asks before it starts.
