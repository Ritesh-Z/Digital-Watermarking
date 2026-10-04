# Proposed Scheme: Blind Triple-Carrier DWT-DCT-QIM Watermarking

A detailed write-up of the project's proposed watermarking scheme: what it is, why it works, how
it evolved, how it was tested, and how it compares with the classic schemes and the base paper.

- **Python implementation:** `python/wmark/schemes.py` → `HybridQIMScheme` (tested, 41 automated tests)
- **MATLAB implementation:** `proposed_watermark_embed.m` / `proposed_watermark_extract.m` on branch
  `matlab-proposed` (toolbox-free port, verified in MATLAB Online R2026a; see "MATLAB notes" below)
- **Base paper:** A. Loke, R. K. Swami, U. Kulkarni, *"Hybrid Digital Watermarking Using DWT, DCT and
  SVD for Robust Image Protection"*, International Journal of Environmental Sciences, 2025.

---

## 1. Summary

The proposed scheme hides a 32×32 binary logo (1024 bits) in an image so that it is

- **invisible:** about 41 dB PSNR at the default strength,
- **blind:** it can be read back from the watermarked image alone, using only a secret key number,
- **secure:** an image that was never marked, or a forger with a different key or logo, decodes to noise,
- **robust:** it survives JPEG, noise, salt & pepper, median, blur, sharpening, lines, rotation,
  cropping and scaling.

Its central idea comes from communication theory: **diversity**. Every 8×8 block stores each bit
in **three independent carriers** that fail under *different* attacks, and a blind decoder trusts
whichever carrier survived.

**Headline result (fair test, all schemes at equal image quality, PSNR = 40 dB, on 8 standard test
images never used during design):** mean robustness **0.950**, best of all five schemes, winning
12 of 16 image/logo pairs. Block DCT scores 0.945, the base paper's method 0.659 and classic SVD 0.568.

---

## 2. Background: the five schemes in this project

| Scheme | Where the bit goes | Blind? | Origin |
| :--- | :--- | :---: | :--- |
| Block DCT | Order of the mid-frequency pair D(4,3) vs D(3,4) in each 8×8 block | ✓ | MATLAB project |
| Haar DWT + QIM | Odd/even quantisation of HL-band coefficients | ✓ | MATLAB project |
| Classic SVD | Watermark singular values added to the cover's: S' = S + αSw | ✗ | MATLAB project (Liu & Tan style) |
| Hybrid DWT-DCT-SVD | DWT → 4×4 block DCT → matrix of DC coefficients → SVD | ✗ | Base paper |
| **Proposed** | **Three carriers per 8×8 block (below)** | **✓** | **This project** |

Key terms:
- **Blind:** extraction needs only the watermarked image and the key.
  **Non-blind:** extraction also needs data saved at embedding time (here S, Uw, Vw).
- **QIM (quantisation index modulation):** round a value to a grid of steps; an even step means 0,
  an odd step means 1.
- **PSNR:** image quality in dB; above about 40 dB the change is invisible. **SSIM:** structural
  similarity, where 1 means identical.
- **NC / BER:** how well the recovered logo matches (NC 1 = perfect; BER 0 = no wrong bits).

---

## 3. The proposed scheme

### 3.1 Embedding (per 8×8 pixel block)

| Carrier | What stores the bit | Strength | Survives best |
| :--- | :--- | :--- | :--- |
| **1. DC (brightness)** | Block average, dithered QIM, step α, distortion-compensated (λ = 0.85) | α | noise, JPEG, blur, median, rotation |
| **2. Low-frequency pair** | Difference D(3,2) − D(2,3), dithered QIM, step 0.8α | 0.8α | brightness drift near pure black/white, smoothing |
| **3. Mid-frequency pair** | Order of D(4,3) vs D(3,4), margin 0.3α (Block DCT's rule) | 0.3α | sharpening, contrast / scaling changes |

(DCT positions are MATLAB 1-based. The DC of the 4×4 DCT of the Haar LL band equals the 8×8 block's
pixel sum ÷ 8, so carrier 1 *is* the base paper's DWT → DCT front end, computed in one step.)

Supporting mechanisms:

- **Keyed spreading and redundancy:** each bit is written at key-chosen positions, 3 times per carrier
  at 512×512 (9 copies in total). The number of copies is always odd, so votes never tie.
- **Bit scrambling:** the logo is XOR-ed with a key-derived random sequence, so its bits are balanced.
  Unrelated logos then don't "correlate" by accident.
- **Secret dither:** the QIM grid is shifted by a key-dependent amount, so unmarked images and wrong
  keys read as noise instead of a biased "all zeros".
- **Clip-aware water-filling (carrier 1):** a block's brightness change doesn't have to be uniform.
  Black pixels can only go up and white pixels only down, so the required total change is spread over
  the pixels that have room. No bits are lost when values would clip at 0 or 255.

### 3.2 Extraction (blind)

1. **Soft read-out:** each copy gives a value in [−1, 1] instead of a hard 0/1. A copy right on its
   grid point counts fully; one near the boundary counts little.
2. **Reliability-weighted combining:** each carrier's votes are weighted by confidence², where
   confidence is how strongly that carrier's own copies agree. Whichever carrier survived the attack
   dominates. This is a blind form of maximal-ratio combining.
3. **Clipping awareness:** DC copies from blocks full of exactly-clipped (0/255) pixels get less say,
   because clipping biases block brightness.
4. **Switching median:** if the image contains salt & pepper specks, only those isolated 0/255 pixels
   are median-filtered. That reading is kept only if the copies agree more.
5. **Blind rotation re-sync:** if the copies disagree, angles in [−8°, 8°] are tried, and the one
   where the copies agree most is kept.

### 3.3 Parameters

| Parameter | Value | Meaning |
| :--- | :--- | :--- |
| α (default) | 28 | strength, about 41 dB PSNR on a typical photo |
| λ | 0.85 | distortion-compensated QIM factor (carrier 1) |
| pair ratio | 0.8 | carrier 2 QIM step = 0.8α |
| mid ratio | 0.3 | carrier 3 margin = 0.3α |
| copies | ≤ 7, odd, per carrier | 3 per carrier at 512×512 |

The ratios were selected by a search over six settings on a **training set** of 13 images, then
confirmed on **held-out** images (section 6).

---

## 4. Why it is better: the theory

1. **Diversity.** Different attacks damage different coefficients:

   | Attack | Damages | Left mostly intact |
   | :--- | :--- | :--- |
   | Noise, JPEG | fine detail | block brightness |
   | Blur, median, scaling | mid/high frequencies | brightness, low frequencies |
   | Sharpening, contrast | coefficient *size* | the *order* of two coefficients |
   | Clipping near black/white | brightness (one-sided drift) | coefficient *differences* |

   A single-carrier scheme always has a row it can't survive; the three carriers together cover every
   row. Combining independent copies lowers the error rate sharply, the same reason phones use several
   antennas.
2. **Orthogonality.** DC, D(3,2)/D(2,3) and D(4,3)/D(3,4) are orthogonal DCT basis functions, so the
   three carriers share the same pixels without interfering (the principle behind OFDM in Wi-Fi/4G).
3. **Near-optimal combining.** Weighting copies by reliability is the communication-theory optimum
   (maximal-ratio combining); here it's done blindly from the agreement between copies.
4. **Dirty-paper coding.** QIM (Costa 1983; Chen & Wornell 2001) lets the embedder cancel the image's
   own interference. Additive SVD, as in the base paper, cannot do this.
5. **Security.** Dither, scrambling and keyed positions make the detector return noise for wrong keys
   or unmarked images, so there are no false ownership claims.

**The honest limit.** At a fixed PSNR the change budget is split three ways. Against one attack that
could have been predicted (for example strong down-scaling of a fine texture), Block DCT's single,
stronger carrier can win. The proposed scheme is designed for the realistic case where the attack is
**unknown**, and there it is best on average.

| Property | DCT | DWT | SVD / paper | Proposed |
| :--- | :---: | :---: | :---: | :---: |
| Blind | ✓ | ✓ | ✗ | ✓ |
| Can't be falsely claimed | ✓ | ✓ | ✗ | ✓ |
| Image doesn't interfere (QIM) | partly | ✓ | ✗ | ✓ |
| Survives scaling / contrast | ✓ | ✗ | partly | ✓ |
| Survives clipping drift | ✓ | partly | partly | ✓ |
| Diversity + weighted vote | ✗ | ✗ | ✗ | ✓ |

---

## 5. Problems faced and how they were fixed

Every design change came from a measured failure:

| # | Problem (measured) | Cause | Fix | Before → after |
| :-- | :--- | :--- | :--- | :--- |
| 1 | Paper hybrid had no effect: PSNR = ∞ | Watermark scaled to 0–1 made changes < ½ grey level; rounding erased them | Embed with the 0–255 watermark | ∞ → 43 dB, working |
| 2 | Anyone could claim the image: SVD/paper fake-claim score 0.73 | Uw, Vw carry the logo, so a forger's matrices "extract" their own logo (Zhang & Li 2005) | Blind, keyed QIM + secret dither + scrambling | 0.73 → 0.02 |
| 3 | 2° rotation destroyed blind schemes (NC ≈ 0.04) | Blocks no longer line up with where bits were written | Blind re-sync by copy agreement | 0.04 → 0.99 |
| 4 | Text-heavy poster failed even with no attack (0.826) | The always-on 3×3 median erased thin text strokes | Switching median: repair only impulse pixels | 0.826 → 1.000 |
| 5 | Bits lost on pure black/white graphics (0.912) | Blocks with both 0 and 255 couldn't shift brightness | Clip-aware water-filling | 0.912 → 1.000 |
| 6 | Noise "fooled" the decoder on dark areas (DC copies −0.02) | Clipped noise drifts dark blocks brighter together, so DC copies agree on the wrong bit | Carrier 2: QIM on a coefficient difference (drift cancels) | → 0.69 on that attack |
| 7 | Only tied Block DCT (6/14 wins) | Sharpening/scaling move QIM values off their grid | Carrier 3: scale-invariant order rule; soft, confidence-weighted vote | 6/14 → 14/14 wins |
| 8 | Was it overfitted to our own images? (DCT mean 0.962 > 0.958 on standard images) | Development images had also been used for testing | Train/test split; report only held-out images | held-out: 0.950 vs 0.945, 12/16 wins |

Ideas that were tried and **rejected** because the measurements were worse:
- **Down-weighting all near-saturated blocks:** destroyed copies on graphics (mean 0.758 vs 0.900).
- **Order rule on a low-frequency pair:** the cost is unbounded when the coefficients naturally differ
  a lot (PSNR capped at about 36 dB).
- **Angle QIM** on the vector (D21, D12): scale-invariant in theory, but too costly in flat areas.
- **Distortion-compensation factor 0.7:** no gain over 0.85.

---

## 6. Experiments

### 6.1 Method: iso-PSNR

Comparing schemes at their default strengths is unfair, because a scheme that changes the image more
always looks more robust. `python/experiment.py` therefore tunes every scheme's α **per image**
(binary search) until PSNR = 40 dB, then runs no attack plus 11 attacks: JPEG Q80, Gaussian noise
(σ² = 0.001), salt & pepper (1 %), median 3×3, sharpening, Gaussian blur (σ = 1), horizontal lines,
vertical lines, rotation 2°, crop 25 %, scale 0.5×. Robustness is NC for binary logos and Pearson
correlation for grayscale logos (the SVD schemes).

### 6.2 Held-out standard images (the result to quote)

8 scikit-image test images never used for tuning (Coffee, Rocket, Moon, Grass, Text, Retina, Hubble
Deep Field, Immunohistochemistry) × 2 logos = 16 pairs:

| Scheme | Mean robustness | Wins |
| :--- | ---: | ---: |
| **Proposed** | **0.950** | **12/16** |
| Block DCT | 0.945 | 2/16 |
| Haar DWT + QIM | 0.712 | 2/16 |
| Hybrid DWT-DCT-SVD (paper) | 0.659 | 0/16 |
| Classic SVD | 0.568 | 0/16 |

Per image (project logo): Coffee 0.997 vs DCT 0.989 · Rocket 1.000 vs 0.998 · Moon 1.000 vs 0.999 ·
Grass 0.633 vs 0.611 · Text 1.000 vs 0.999 · Retina 1.000 vs 0.997 · Hubble 0.986 vs 0.983 ·
Immunohistochemistry 0.991 vs **0.995**.

### 6.3 Project images (used during development)

Lion, the poster screenshot, a grey photo, a UI screenshot and 3 synthetic images × 2 logos = 14 pairs:
proposed **0.963, 14/14 wins**; Block DCT 0.918; Haar DWT 0.730; paper 0.652; SVD 0.446. On the
text-heavy poster with the orca logo: proposed 0.806 vs Block DCT 0.631.

### 6.4 Security (false ownership claims)

| Scheme | Genuine | Decoy (never marked) | Fake claim |
| :--- | ---: | ---: | ---: |
| Block DCT | 1.000 | 0.010 | 0.004 |
| Haar DWT + QIM | 1.000 | 0.029 | 0.033 |
| Classic SVD | 1.000 | 0.160 | **0.730 ✗** |
| Paper hybrid | 0.996 | −0.587 | **0.730 ✗** |
| **Proposed** | **1.000** | **0.037** | **0.023 ✓** |

### 6.5 Reproduce

```bash
cd python
pip install -r requirements.txt scikit-image
python experiment.py                       # project + synthetic images
python experiment.py --skimage --no-synthetic --no-project --logos ../logo.png
python benchmark.py                        # quick table + security test
python -m pytest -q tests                  # 41 tests
```

---

## 7. Comparison with the base paper (Loke et al., 2025)

| | Base paper | Proposed |
| :--- | :--- | :--- |
| Pipeline | DWT → 4×4 DCT → DC matrix → SVD | DWT-DCT front end (DC) + two DCT-pair carriers |
| Blind | ✗ (needs S, Uw, Vw) | ✓ (key number only) |
| Ownership proof | ✗ fake claim 0.73 | ✓ fake claim 0.02 |
| Rotation | ✗ paper reports NC 0.55 → 0.07 | ✓ blind re-sync, ≈ 0.99 |
| Gaussian blur | ✗ paper reports NC 0.04 – 0.09 | ✓ ≈ 0.95 – 1.00 |
| Salt & pepper | paper reports NC 0.93 → 0.73 | ≈ 1.00 |
| Mean robustness, held-out (iso-PSNR) | 0.659 | **0.950** |
| Watermark capacity | grayscale image (more data) | 1024-bit binary logo |

Notes:
- The paper's NC formula Σww′/√(Σw²Σw′²) does not subtract the mean, so it stays high even for
  unrelated non-negative images; its reported 0.99s are optimistic. This project reports Pearson
  correlation for grayscale watermarks.
- The comparison uses this project's reproduction of the paper's algorithm (the paper published no
  code), so details may differ. The identified flaws (non-blind, false positives, failing under blur)
  come from the method itself.

---

## 8. Limitations and future work

- Not best on every single image: Haar DWT wins on the Grass texture, and Block DCT narrowly wins on one
  microscopy image.
- Strong down-scaling of fine textures remains the hardest attack for every scheme here.
- Capacity is 1024 bits; an error-correcting code (BCH or LDPC) instead of plain repetition would buy
  extra robustness.
- Geometric attacks beyond rotation (shear, perspective, camcording) would need feature-based
  synchronisation.
- **Future:** a deep-learning encoder/decoder trained with these attacks as augmentation (like
  StegaStamp or SynthID), and video watermarking with temporal voting (`python/video_demo.py`
  already demonstrates this).

---

## 9. How to run

**MATLAB** (base MATLAB only, no toolboxes):
```matlab
main_demo_proposed       % proposed scheme, 11 attacks
main_demo_hybrid_paper   % base paper reproduction, its 6 attacks
main_security_test       % false-ownership test: classic SVD vs proposed
```

**Python** (free, local web UI):
```bash
cd python
pip install -r requirements.txt
python server.py          # http://127.0.0.1:8000
```

**MATLAB notes.** The MATLAB files are a line-by-line port of the tested Python code. MATLAB and NumPy
use different random generators, so a given key places bits at different positions in the two
languages. Each language extracts its own watermarks, but a MATLAB-embedded image must be read back
with the MATLAB extractor (and vice versa). The MATLAB port (branch `matlab-proposed`) was verified in
MATLAB Online R2026a: PSNR 41.94 dB, NC 1.000 with no attack, mean NC 0.9982 over the 11 attacks
(rotation re-synced at 2.00°), and in `main_security_test` classic SVD's fake-claim score was 0.996
against −0.031 for the proposed scheme.

---

## 10. Viva questions and answers

**Q: What is new compared with the base paper?**
A: We kept its DWT-DCT idea but made the scheme blind and keyed, removed its false-positive flaw,
and replaced the single SVD carrier with three orthogonal carriers plus a reliability-weighted blind
decoder. At equal PSNR it is far more robust: 0.950 vs 0.659 on unseen images.

**Q: Why not just use SVD like the paper?**
A: Additive SVD is non-blind, and the extracted watermark is dominated by the key matrices Uw, Vw.
Anyone can use their own Uw, Vw to "extract" their own logo. We measured a fake-claim correlation of
0.73, so it can't prove ownership.

**Q: How can three carriers fit in one block without interfering?**
A: They use different, orthogonal DCT basis functions (DC, D(3,2)/D(2,3), D(4,3)/D(3,4)). Changing one
coefficient doesn't change the others.

**Q: How does the decoder know which carrier to trust without the original image?**
A: If a carrier survived, its copies of each bit agree. If it was damaged, they disagree. Agreement
is measured from the received image alone and used as the weight (confidence²).

**Q: Why do you compare at equal PSNR?**
A: Robustness can always be bought with visible distortion. Fixing the PSNR at 40 dB for every scheme
makes the comparison fair.

**Q: Is it the best possible watermarking method?**
A: No method is best against every attack: at fixed quality there is a robustness trade-off. Ours is
best on average for unknown attacks among the methods tested, and we report where it loses (Grass,
one microscopy image).

**Q: How does it survive rotation?**
A: Blind re-synchronisation: we rotate the received image back by trial angles and keep the angle where
the hidden copies agree most. In tests it recovered a 2° rotation exactly and a 2.3° rotation to
within 0.05°, with NC ≈ 0.99.

**Q: What happens with a wrong key?**
A: Positions, scrambling and dither all depend on the key, so a wrong key reads random bits
(NC ≈ 0.02). That is also why a forger can't make a claim.

**Q: What does "blind" mean, and why does it matter?**
A: Extraction needs only the image and the key, not the original picture or saved matrices. In practice
the original is often unavailable, and storing per-image matrices doesn't scale.

**Q: Which industry systems use similar ideas?**
A: Robust commercial watermarks (e.g. Digimarc) and forensic video marking use keyed, redundant,
frequency-domain embedding with synchronisation. Newer systems (Google SynthID, Meta Video Seal) learn
the embedding with neural networks. Our diversity-and-voting design follows the same robustness
principles with transparent, hand-written transforms.
