# Digital Watermarking System (DCT & DWT)

A zero-dependency MATLAB implementation of invisible digital image watermarking based on two fundamental frequency-domain techniques: **Block-based Discrete Cosine Transform (DCT)** and **Single-Level Haar Discrete Wavelet Transform (DWT)**. The codebase includes watermark embedding, blind extraction, quantitative evaluation, and robustness testing against common image processing attacks.

> [!NOTE]
> **Toolbox-Free Architecture**: This codebase is built entirely using **Base MATLAB** operations and requires **NO Toolboxes** (such as the Image Processing Toolbox). All transformation, metric calculation, noise generation, filtering, and image manipulation algorithms are implemented from scratch using matrix algebra and modular helper files.

---

## 📌 Features

- **Zero-Toolbox Dependency**: Hand-crafted implementations of 2D DCT, 2D DWT (Haar), PSNR calculation, grayscale conversion, image resizing, noise models, and median filtering.
- **Modularized Codebase**: All helper utilities and core transformation functions reside in clean, independent `.m` files.
- **Dual Watermarking Paradigms**:
  - **DCT Scheme ([`main_demo.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo.m))**: Divides cover images into $8 \times 8$ non-overlapping blocks and embeds binary watermark bits into mid-frequency DCT coefficients.
  - **DWT Scheme ([`main_demo_dwt.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dwt.m))**: Decomposes cover images using a 2D Haar Discrete Wavelet Transform and embeds binary watermark bits into the HL (vertical detail) sub-band using Quantization Index Modulation (QIM).
- **Imperceptible & Blind Extraction**: Preserves visual quality while permitting watermark extraction without requiring the original cover image.
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
| [`main_demo.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo.m) | Main demo script for DCT-based watermarking (Embedding, Blind Extraction, Evaluation, Attacks). |
| [`main_demo_dwt.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo_dwt.m) | Main demo script for DWT-based watermarking (Sub-band decomposition, QIM Embedding, Extraction, Evaluation, Attacks). |
| [`dwt_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dwt_watermark_embed.m) | Embeds binary watermark into the HL sub-band of a DWT-decomposed image. |
| [`dwt_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dwt_watermark_extract.m) | Extracts binary watermark from the HL sub-band. |
| [`manual_dwt2_haar.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_dwt2_haar.m) | Toolbox-free single-level 2D Haar DWT implementation. |
| [`manual_idwt2_haar.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/manual_idwt2_haar.m) | Toolbox-free single-level 2D Haar Inverse DWT implementation. |
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
   main_demo
   ```
3. Run DWT Watermarking Demo:
   ```matlab
   main_demo_dwt
   ```
4. **Custom Inputs**:
   - Place `cover.jpg` or `cover.png` in the folder to use custom cover images.
   - Place `logo.png` in the folder to use a custom binary watermark logo.

---

## 📊 Evaluation & Metrics

Both scripts automatically generate output figures and print performance metrics in the console:
- **PSNR**: Visual quality of watermarked image vs cover image.
- **NC**: Correlation between original and extracted watermarks.
- **BER**: Bit error rate under clean and attack conditions (JPEG compression, Gaussian noise, Salt & Pepper noise, Median filter).

---

## 📜 License

This project is licensed under the MIT License.
