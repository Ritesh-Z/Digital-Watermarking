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

## 📜 License

This project is licensed under the MIT License.
