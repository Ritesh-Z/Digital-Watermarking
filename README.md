
# Digital Watermarking Using Discrete Cosine Transform (DCT)

A MATLAB implementation of invisible digital image watermarking based on block-based Discrete Cosine Transform (DCT) mid-frequency coefficient comparison. The system includes watermark embedding, blind extraction, quantitative evaluation, and robustness testing against common image processing attacks.

---

## 📌 Features

- **Block-Based DCT Watermarking**: Divides cover images into $8 \times 8$ non-overlapping blocks and embeds binary watermark bits into mid-frequency DCT coefficients.
- **Imperceptible & Blind Extraction**: Preserves original image quality while allowing watermark extraction without requiring the original cover image.
- **Quantitative Performance Evaluation**:
  - **PSNR (Peak Signal-to-Noise Ratio)**: Measures visual imperceptibility.
  - **NC (Normalized Correlation)**: Measures extracted watermark similarity ($1.0 = \text{perfect match}$).
  - **BER (Bit Error Rate)**: Quantifies bit mismatch ratio ($0.0 = \text{no error}$).
- **Robustness Attack Benchmark**: Tests watermark survival against:
  - JPEG Compression (Quality Factor 80)
  - Additive Gaussian Noise
  - Salt & Pepper Noise
  - Median Filtering ($3 \times 3$)

---

## 📁 Repository Structure

| File | Description |
| :--- | :--- |
| [`main_demo.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/main_demo.m) | Main demo script to run the complete pipeline, evaluation, and attack suite. |
| [`dct_watermark_embed.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_embed.m) | Function to embed a binary watermark into a grayscale cover image. |
| [`dct_watermark_extract.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/dct_watermark_extract.m) | Function for blind extraction of watermark bits from a watermarked image. |
| [`calculate_metrics.m`](file:///c:/Users/Ritesh/Documents/Digital_Watermarking/calculate_metrics.m) | Computes evaluation metrics (PSNR, NC, BER). |

---

## ⚙️ How It Works

### 1. Watermark Embedding
Each $8 \times 8$ pixel block of the cover image undergoes 2D DCT transformation ($D$). A single binary watermark bit $w \in \{0, 1\}$ is embedded per block by enforcing a relationship between mid-frequency DCT coefficients $D(4,3)$ and $D(3,4)$:
- If $w = 1$: Enforce $D(4,3) - D(3,4) \ge \alpha$
- If $w = 0$: Enforce $D(3,4) - D(4,3) \ge \alpha$

$\alpha$ represents the embedding strength parameter (higher values increase robustness, lower values increase imperceptibility).

### 2. Watermark Extraction
The watermarked image is split into $8 \times 8$ blocks and transformed with 2D DCT. The bit is reconstructed blindsidedly by comparing coefficients:
$$w_{\text{extracted}} = \begin{cases} 1 & \text{if } D(4,3) > D(3,4) \\ 0 & \text{otherwise} \end{cases}$$

---

## 🚀 Usage Instructions

### Prerequisites
- MATLAB (R2018b or newer recommended)
- Image Processing Toolbox (`dct2`, `idct2`, `psnr`, `imbinarize`, `imnoise`, `medfilt2`)

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

Running `main_demo.m` generates figures showing:
- Original Cover Image vs. Watermarked Image.
- Original Watermark vs. Extracted Watermark (No Attack).
- Extracted Watermarks after JPEG Compression, Gaussian Noise, Salt & Pepper Noise, and Median Filtering.
- Command window console log of PSNR, NC, and BER values.

---

## 📜 License

This project is licensed under the MIT License.
