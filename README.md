# Digital Watermarking System (DCT, DWT & SVD)

A zero-dependency MATLAB implementation of invisible digital image watermarking based on three fundamental frequency and spatial domain techniques:
1. **Block-based Discrete Cosine Transform (DCT)**
2. **Single-Level Haar Discrete Wavelet Transform (DWT)**
3. **Singular Value Decomposition (SVD)**

The codebase includes watermark embedding, blind and non-blind extraction, quantitative evaluation, and robustness testing against common image processing attacks.

> [!NOTE]
> **Toolbox-Free Architecture**: This codebase is built entirely using **Base MATLAB** operations and requires **NO Toolboxes** (such as the Image Processing Toolbox). All transformation, metric calculation, noise generation, filtering, and image manipulation algorithms are implemented from scratch using matrix algebra and modular helper files.

---

## 📌 Features

- **Zero-Toolbox Dependency**: Hand-crafted implementations of 2D DCT, 2D DWT (Haar), 2D SVD, PSNR calculation, grayscale conversion, image resizing, noise models, and median filtering.
- **Modularized Codebase**: All helper utilities and core transformation functions reside in clean, independent `.m` files.
- **Triple Watermarking Paradigms**:
  - **DCT Scheme ([`main_demo_dct.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dct.m))**: Divides cover images into $8 \times 8$ non-overlapping blocks and embeds binary watermark bits into mid-frequency DCT coefficients.
  - **DWT Scheme ([`main_demo_dwt.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dwt.m))**: Decomposes cover images using a 2D Haar Discrete Wavelet Transform and embeds binary watermark bits into the HL (vertical detail) sub-band using Quantization Index Modulation (QIM).
  - **SVD Scheme ([`main_demo_svd.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_svd.m))**: Decomposes cover image using Singular Value Decomposition ($A = U S V^T$) and embeds singular values of the watermark image into singular values of the cover image.
- **Blind & Non-Blind Extraction**:
  - **Blind Extraction (DCT & DWT)**: Recovers watermarks without requiring the original cover image.
  - **Non-Blind / Semi-Blind Extraction (SVD)**: Recovers watermarks using key matrices ($U_w, V_w, S_{orig}$).
- **Quantitative Performance Evaluation**:
  - **PSNR (Peak Signal-to-Noise Ratio)**: Visual imperceptibility metric ($10 \log_{10}(255^2 / \text{MSE})$).
  - **NC (Normalized Correlation)**: Measures extracted watermark similarity ($1.0 = \text{perfect match}$).
  - **BER (Bit Error Rate)**: Quantifies bit mismatch ratio ($0.0 = \text{no error}$).
- **Robustness Attack Benchmark**: Tests watermark survival against:
  - JPEG Compression (Quality Factor 80)
  - Additive Gaussian Noise
  - Salt & Pepper Noise
  - Median Filtering ($3 \times 3$ sliding window with replicate padding)

---

## 📁 Repository Structure

| File | Description |
| :--- | :--- |
| [`main_demo_dct.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dct.m) | Main demo script for DCT-based watermarking (Embedding, Blind Extraction, Evaluation, Attacks). |
| [`main_demo_dwt.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dwt.m) | Main demo script for DWT-based watermarking (Sub-band decomposition, QIM Embedding, Extraction, Evaluation, Attacks). |
| [`main_demo_svd.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_svd.m) | Main demo script for SVD-based watermarking (Singular Value embedding, Key generation, Non-blind Extraction, Evaluation, Attacks). |
| [`dct_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_embed.m) | Embeds binary watermark into mid-frequency 2D DCT coefficients. |
| [`dct_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_extract.m) | Extracts binary watermark blindly from 2D DCT coefficients. |
| [`dwt_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dwt_watermark_embed.m) | Embeds binary watermark into the HL sub-band of a DWT-decomposed image. |
| [`dwt_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dwt_watermark_extract.m) | Extracts binary watermark from the HL sub-band. |
| [`svd_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/svd_watermark_embed.m) | Embeds image watermark singular values into the cover image SVD matrices. |
| [`svd_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/svd_watermark_extract.m) | Extracts image watermark using SVD key matrices ($U_w, V_w, S_{orig}$). |
| [`calculate_metrics.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/calculate_metrics.m) | Computes evaluation metrics (PSNR, NC, BER) for binary watermarking. |
| [`calculate_metrics_svd.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/calculate_metrics_svd.m) | Computes evaluation metrics (PSNR, NC, Correlation) for image/SVD watermarking. |
| [`manual_dwt2_haar.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_dwt2_haar.m) | Toolbox-free single-level 2D Haar DWT implementation. |
| [`manual_idwt2_haar.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_idwt2_haar.m) | Toolbox-free single-level 2D Haar Inverse DWT implementation. |
| [`manual_mat2gray.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_mat2gray.m) | Rescales intensity matrix values to [0, 1] range for visualization without toolboxes. |
| [`manual_rgb2gray.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_rgb2gray.m) | Converts RGB image to grayscale using luminance weighting. |
| [`manual_imresize.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_imresize.m) | Nearest-neighbor image resize without toolboxes. |
| [`manual_imnoise_gaussian.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_imnoise_gaussian.m) | Zero-mean Gaussian noise generator. |
| [`manual_imnoise_saltpepper.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_imnoise_saltpepper.m) | Salt & Pepper noise generator. |
| [`manual_medfilt2.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_medfilt2.m) | $3 \times 3$ median filter with replicate padding. |
| [`insertTextSafe.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/insertTextSafe.m) | Draws text into a binary watermark canvas without Image Processing Toolbox. |

---

## ⚙️ How It Works

### 1. Discrete Cosine Transform (DCT) Scheme
- **Block Decomposition**: Image divided into $8 \times 8$ blocks.
- **Mid-Frequency Embedding**: Enforces a margin $\alpha$ between $D(4,3)$ and $D(3,4)$ coefficients depending on watermark bit value (1 or 0).
- **Blind Extraction**: Bit determined by relative magnitude of $D(4,3)$ vs $D(3,4)$.

### 2. Discrete Wavelet Transform (DWT) Scheme
- **2D Haar Decomposition**: Decomposes cover image into four sub-bands ($LL$, $LH$, $HL$, $HH$).
- **QIM Embedding**: Quantizes HL detail sub-band coefficients based on target watermark bits.
- **Reconstruction & Extraction**: Performs Inverse DWT (IDWT) to form watermarked image; extracts bits blindly from HL coefficients during detection.

### 3. Singular Value Decomposition (SVD) Scheme
- **SVD Factorization**: Cover image $A$ is factored into $A = U_a S_a V_a^T$. Watermark image $W$ is factored into $W = U_w S_w V_w^T$.
- **Singular Value Embedding**: $S_w$ is scaled by scaling factor $\alpha$ and added to cover singular values: $S_{watermarked} = S_a + \alpha S_w$.
- **Reconstruction & Extraction**: Watermarked image $A^* = U_a S_{watermarked} V_a^T$. Watermark extraction extracts $S_{ext} = (S_{watermarked}^* - S_a)/\alpha$ and reconstructs $W_{ext} = U_w S_{ext} V_w^T$ using key parameters.

---

## 🚀 Usage Instructions

### Prerequisites
- MATLAB (Base installation only; **no toolboxes required**).

### Running the Demos
1. Clone the repository:
   ```bash
   git clone https://github.com/Ritesh-Z/Digital-Watermarking.git
   cd Digital-Watermarking
   ```
2. Run DCT Watermarking Demo:
   ```matlab
   main_demo_dct
   ```
3. Run DWT Watermarking Demo:
   ```matlab
   main_demo_dwt
   ```
4. Run SVD Watermarking Demo:
   ```matlab
   main_demo_svd
   ```
5. **Custom Inputs**:
   - Place `cover.jpg` or `cover.png` in the folder to use custom cover images.
   - Place `logo.png` in the folder to use a custom binary watermark logo.

---

## 📊 Evaluation & Metrics

All scripts automatically generate output figures and print performance metrics in the console:
- **PSNR**: Visual quality of watermarked image vs cover image.
- **NC / Correlation**: Correlation between original and extracted watermarks.
- **BER**: Bit error rate under clean and attack conditions (JPEG compression, Gaussian noise, Salt & Pepper noise, Median filter).

---

## 🐍 Python Edition & 3-D Web Lab

The [`python/`](python/) folder contains a free, local Python port of this project with an
interactive **Three.js web interface**. It adds a reproduction of the base paper's hybrid
DWT-DCT-SVD scheme, an improved blind hybrid scheme, 11 attacks, a false-positive security
test, α-sweeps, video watermarking and report-ready figures. See [`python/README.md`](python/README.md),
and [`PROPOSED_SCHEME.md`](PROPOSED_SCHEME.md) for the full write-up of the proposed scheme and its experiments.

```bash
cd python
pip install -r requirements.txt
python server.py
```

---

## 🧪 Proposed Scheme & Base-Paper Reproduction (MATLAB)

Toolbox-free MATLAB versions of the project's proposed watermarking scheme and of the base
paper's hybrid DWT-DCT-SVD algorithm (see [`PROPOSED_SCHEME.md`](PROPOSED_SCHEME.md) for the full write-up).

| File | Description |
| :--- | :--- |
| `main_demo_proposed.m` | Proposed blind triple-carrier scheme: embed, extract, 11 attacks |
| `main_demo_hybrid_paper.m` | Base paper's hybrid DWT-DCT-SVD (Loke et al., IJES 2025) with its 6 attacks |
| `main_security_test.m` | False-ownership test: classic SVD vs proposed |
| `proposed_watermark_embed.m` / `proposed_watermark_extract.m` | Proposed scheme (DC QIM + low-pair QIM + mid-pair order, keyed, clip-aware, blind decoder, rotation re-sync) |
| `hybrid_paper_embed.m` / `hybrid_paper_extract.m` | Base-paper reproduction (non-blind) |
| `proposed_params.m` | Settings of the proposed scheme |
| `wm_layout.m`, `wm_dither.m`, `wm_scramble.m`, `qim_embed.m`, `qim_embed_bounded.m`, `qim_soft.m` | Keyed spreading, dither, scrambling and QIM helpers |
| `img_to_blocks.m`, `blocks_to_img.m`, `manual_dct_matrix.m` | Block and DCT helpers |
| `manual_imrotate.m`, `manual_gaussian_blur.m`, `manual_sharpen.m` | Extra toolbox-free attacks |

**Verified in MATLAB Online (R2026a)** on `cover.jpg` + `logo.png` (512×512):

| Proposed scheme | |
| :--- | :--- |
| PSNR | 41.94 dB |
| NC, no attack | 1.0000 |
| JPEG Q80 / salt & pepper / median / sharpening / lines / crop 25 % | 1.0000 |
| Gaussian noise / Gaussian blur / scale 0.5× | 0.9883 / 0.9980 / 0.9941 |
| Rotation 2° | 1.0000 (blind re-sync found 2.00°) |
| **Mean NC over 11 attacks** | **0.9982** |

| Security test | Genuine | Decoy | Fake claim |
| :--- | ---: | ---: | ---: |
| Classic SVD | 1.000 | 0.669 | **0.996 ✗** |
| Proposed | 1.000 | 0.035 | −0.031 ✓ |

Base paper hybrid (HH band, α = 0.1): PSNR 42.31 dB; sharpening 0.999, lines 0.999, salt & pepper
0.947, rotation 0.965, but **Gaussian blur −0.444** (watermark destroyed).

---

## 📜 License


This project is licensed under the MIT License.