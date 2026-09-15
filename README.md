# Digital Watermarking Using Discrete Cosine Transform (DCT)

A zero-dependency MATLAB implementation of invisible digital image watermarking based on block-based Discrete Cosine Transform (DCT) mid-frequency coefficient comparison. The system includes watermark embedding, blind extraction, quantitative evaluation, and robustness testing against common image processing attacks.

> [!NOTE]
> **Toolbox-Free Architecture**: This codebase is built entirely using **Base MATLAB** operations and requires **NO Toolboxes** (such as the Image Processing Toolbox). All transformation, metric, filtering, and image manipulation algorithms are implemented from scratch using matrix algebra.

---

## 📌 Features

- **Zero-Toolbox Dependency**: Hand-crafted implementations of 2D DCT, 2D IDCT, PSNR calculation, grayscale conversion, image resizing, noise models, and median filtering.
- **Block-Based DCT Watermarking**: Divides cover images into $8 \times 8$ non-overlapping blocks and embeds binary watermark bits into mid-frequency DCT coefficients.
- **Imperceptible & Blind Extraction**: Preserves original image quality while allowing watermark extraction without requiring the original cover image.
- **Quantitative Performance Evaluation**:
  - **PSNR (Peak Signal-to-Noise Ratio)**: Hand-calculated visual imperceptibility ($10 \log_{10}(255^2 / \text{MSE})$).
  - **NC (Normalized Correlation)**: Bipolar correlation measuring extracted watermark similarity ($1.0 = \text{perfect match}$).
  - **BER (Bit Error Rate)**: Quantifies bit mismatch ratio ($0.0 = \text{no error}$).
- **Robustness Attack Benchmark**: Tests watermark survival against:
  - JPEG Compression (Quality Factor 80)
  - Additive Gaussian Noise (Hand-written zero-mean model)
  - Salt & Pepper Noise (Hand-written density model)
  - Median Filtering ($3 \times 3$ sliding window with replicate padding)

---

## 📁 Repository Structure

| File | Description |
| :--- | :--- |
| [`main_demo.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo.m) | Main demo script executing the full embedding, extraction, evaluation, and attack suite. Includes standalone helper functions (`manual_rgb2gray`, `manual_imresize`, `manual_imnoise_*`, `manual_medfilt2`). |
| [`dct_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_embed.m) | Embeds a binary watermark into a grayscale cover image using an $8 \times 8$ DCT-II basis matrix $T$. |
| [`dct_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_extract.m) | Blind extraction of watermark bits using DCT coefficient comparison. |
| [`calculate_metrics.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/calculate_metrics.m) | Computes evaluation metrics (PSNR, NC, BER) without toolbox dependencies. |

---

## ⚙️ How It Works

### 1. Manual 2D DCT Transformation
The $8 \times 8$ DCT-II basis matrix $T$ is constructed as:
$$T(u, x) = a(u) \cos \left( \frac{\pi (2x + 1) u}{2N} \right), \quad \text{where } a(u) = \begin{cases} \sqrt{\frac{1}{N}} & u = 0 \\ \sqrt{\frac{2}{N}} & u > 0 \end{cases}$$

For each $8 \times 8$ image block $B$:
- **Forward DCT**: $D = T \cdot B \cdot T^T$
- **Inverse DCT**: $B = T^T \cdot D \cdot T$

### 2. Watermark Embedding
A single binary watermark bit $w \in \{0, 1\}$ is embedded per block by enforcing a strength margin $\alpha$ between mid-frequency DCT coefficients $D(4,3)$ and $D(3,4)$:
- If $w = 1$: Enforce $D(4,3) - D(3,4) \ge \alpha$
- If $w = 0$: Enforce $D(3,4) - D(4,3) \ge \alpha$

### 3. Watermark Extraction
Reconstructs bits blindly without the original cover image:
$$w_{\text{extracted}} = \begin{cases} 1 & \text{if } D(4,3) > D(3,4) \\ 0 & \text{otherwise} \end{cases}$$

---

## 🚀 Usage Instructions

### Prerequisites
- Any version of **MATLAB** (Base installation only; **no toolboxes required**).

### Running the Demo
1. Clone the repository:
   ```bash
   git clone https://github.com/Ritesh-Z/Digital-Watermarking.git
   cd Digital-Watermarking
   ```
2. Open MATLAB, navigate to the project directory, and run:
   ```matlab
   main_demo
   ```
3. (Optional) Custom Inputs:
   - Place a `cover.jpg` or `cover.png` image in the working directory to use custom cover images.
   - Place a `logo.png` binary logo image to use custom watermark logos.

---

## 📊 Evaluation & Results

Running `main_demo.m` generates interactive figures displaying:
- Cover image vs. Watermarked image.
- Original watermark vs. Extracted watermark (unattacked).
- Extracted watermarks following JPEG compression, Gaussian noise, Salt & Pepper noise, and Median filtering.
- Formatted console metrics log (PSNR, NC, BER).

---

## 📜 License

This project is licensed under the MIT License.
