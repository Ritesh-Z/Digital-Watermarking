"""The five watermarking schemes.

    dct          Block DCT coefficient-pair      (port of dct_watermark_*.m)
    dwt          Haar DWT HL-band QIM            (port of dwt_watermark_*.m)
    svd          Classic additive SVD            (port of svd_watermark_*.m)
    hybrid_paper DWT -> 4x4 DCT -> DC matrix -> SVD, exactly as in the base
                 paper (Loke, Swami & Kulkarni, IJES 2025)
    hybrid_qim   Improved, BLIND DWT -> 4x4 DCT -> DC-coefficient QIM with
                 keyed spreading and redundancy (our proposed variant)

Every scheme works on a 2-D float "host" channel and has the same API:

    marked, secret = scheme.embed(host, watermark, alpha, key, redundant)
    recovered      = scheme.extract(host, alpha, key, redundant, secret, wm_shape)

``secret`` is empty for blind schemes; for the SVD-based (non-blind)
schemes it holds the key matrices that must be stored after embedding.
"""
import numpy as np

from .spread import (agreement, copies, dither, layout, qim_embed, qim_embed_bounded,
                     qim_extract, qim_soft, scramble, vote, vote_soft)
from .transforms import (blockwise_dct, blockwise_idct, from_blocks, haar_dwt2, haar_idwt2,
                         median_filter, to_blocks)


PLAIN = {
    "dct": "Cuts the picture into small 8x8 tiles and hides one bit in each tile by nudging two of its "
           "'medium-detail' wave values so one is bigger than the other.",
    "dwt": "Splits the picture into a blurry version plus edge details, then hides bits by rounding the "
           "vertical-edge details to even or odd steps.",
    "svd": "Breaks the picture into 'strength' numbers and adds a little of the logo's strength numbers to them. "
           "To read it back you need extra secret data saved when hiding.",
    "hybrid_paper": "The base paper's method: wavelets, then tiles, then the SVD 'strength' trick, all stacked "
                    "together. Like classic SVD it needs the saved secret data to read the logo back.",
    "hybrid_qim": "Our method: every small tile of the picture hides each bit three different ways (its brightness, "
                  "a smooth pattern and a fine pattern). Different attacks destroy different patterns, so the decoder "
                  "simply trusts whichever one survived. It needs no original picture and cannot be faked.",
}


class Scheme:
    name = ""
    title = ""
    short = ""
    blind = True
    payload = "bits"        # "bits" -> 0/1 watermark, "image" -> grayscale watermark
    alpha_default = 1.0
    alpha_min, alpha_max, alpha_step = 0.1, 10.0, 0.1
    origin = ""
    description = ""
    pipeline = ()

    def watermark_shape(self, size):
        return (32, 32)

    def info(self):
        return {
            "name": self.name, "title": self.title, "short": self.short,
            "blind": self.blind, "payload": self.payload,
            "alpha": {"default": self.alpha_default, "min": self.alpha_min,
                      "max": self.alpha_max, "step": self.alpha_step},
            "origin": self.origin, "description": self.description,
            "pipeline": list(self.pipeline),
            "plain": PLAIN.get(self.name, ""),
        }


class BitScheme(Scheme):
    """Blind 0/1 schemes: read every copy of every bit, then majority-vote."""
    prefilter = False   # median-filter the image before extraction (redundant mode only)

    def slots(self, shape):
        """Number of embedding slots for a host of the given shape."""
        raise NotImplementedError

    def copies(self, shape, wm_shape=(32, 32), redundant=True):
        return copies(int(np.prod(wm_shape)), self.slots(shape), redundant)

    def read_soft(self, host, alpha, key, redundant, n):
        """Soft value per copy in [-1, 1] (positive = bit 1) and the bit each copy carries."""
        raise NotImplementedError

    def read_slots(self, host, alpha, key, redundant, n):
        soft, which = self.read_soft(host, alpha, key, redundant, n)
        return (soft > 0).astype(np.uint8), which

    def uses_prefilter(self, shape, n, redundant):
        # The median pre-filter flips a few individual copies; that is only
        # harmless when several copies of every bit are voted.
        return self.prefilter and copies(n, self.slots(shape), redundant) >= 3

    def _read(self, host, alpha, key, redundant, n, prefilter=True):
        if prefilter and self.uses_prefilter(host.shape, n, redundant):
            host = median_filter(host, 3)
        return self.read_slots(host, alpha, key, redundant, n)

    def extract(self, host, alpha, key=None, redundant=True, secret=None, wm_shape=(32, 32)):
        """Soft-decision voting. If the scheme has a median pre-filter, read the
        image both with and without it and keep the reading whose copies agree
        most (blind: no original needed). The filter removes salt & pepper
        specks but erases thin text, so neither choice is right for every image."""
        n = int(np.prod(wm_shape))
        candidates = [host]
        if self.uses_prefilter(host.shape, n, redundant):
            candidates.append(median_filter(host, 3))
        best = None
        for h in candidates:
            soft, which = self.read_soft(h, alpha, key, redundant, n)
            bits, conf = vote_soft(soft, which, n)
            if best is None or conf > best[1]:
                best = (bits, conf)
        return scramble(best[0], key).reshape(wm_shape)

    def confidence(self, host, alpha, key=None, redundant=True, wm_shape=(32, 32), prefilter=True):
        """How strongly the copies of each bit agree (1 = unanimous, ~0.6 = noise).
        Used for blind re-synchronisation: no original image or watermark needed."""
        n = int(np.prod(wm_shape))
        bits, which = self._read(host, alpha, key, redundant, n, prefilter)
        return agreement(bits, which, n)


# ----------------------------------------------------------------------------
class DCTScheme(BitScheme):
    name, title, short = "dct", "Block DCT", "DCT"
    alpha_default, alpha_min, alpha_max, alpha_step = 25, 2, 100, 1
    origin = "Port of dct_watermark_embed.m / dct_watermark_extract.m"
    description = ("8x8 blocks, 2-D DCT of each. One bit per block: D(4,3) is pushed at least alpha above D(3,4) for a 1, below it for a 0. Blind: read back by comparing the pair.")
    pipeline = ("8x8 blocks", "2-D DCT", "Compare D(4,3) vs D(3,4)", "Enforce margin alpha", "Inverse DCT")
    P1, P2 = (3, 2), (2, 3)   # 0-based for MATLAB's D(4,3), D(3,4)

    def slots(self, shape):
        return (shape[0] // 8) * (shape[1] // 8)

    def embed(self, host, wm, alpha, key=None, redundant=True):
        bits = scramble(wm.ravel().astype(int), key)
        D = blockwise_dct(host, 8)
        nr, nc = D.shape[:2]
        flat = D.reshape(nr * nc, 8, 8)
        slots, which = layout(bits.size, nr * nc, key, redundant)
        b = bits[which]
        c1, c2 = flat[slots, *self.P1], flat[slots, *self.P2]
        d = c1 - c2
        # bit 1 -> need c1 - c2 >= alpha ; bit 0 -> need c2 - c1 >= alpha
        target = np.where(b == 1, alpha, -alpha)
        need = np.where(b == 1, d < alpha, d > -alpha)
        delta = np.where(need, (target - d) / 2, 0.0)
        flat[slots, *self.P1] = c1 + delta
        flat[slots, *self.P2] = c2 - delta
        return blockwise_idct(flat.reshape(D.shape), 8), {}

    def read_soft(self, host, alpha, key, redundant, n):
        flat = blockwise_dct(host, 8).reshape(-1, 8, 8)
        slots, which = layout(n, flat.shape[0], key, redundant)
        margin = flat[slots, *self.P1] - flat[slots, *self.P2]
        return np.clip(margin / max(alpha, 1e-9), -1, 1), which


# ----------------------------------------------------------------------------
class DWTScheme(BitScheme):
    name, title, short = "dwt", "Haar DWT + QIM", "DWT"
    alpha_default, alpha_min, alpha_max, alpha_step = 15, 2, 60, 1
    origin = "Port of dwt_watermark_embed.m / dwt_watermark_extract.m"
    description = ("One-level Haar wavelet. Each HL coefficient is rounded to a multiple of alpha; an even multiple means 0, odd means 1 (QIM). Blind: read back the parity.")
    pipeline = ("Haar DWT", "Take HL band", "Quantise to step alpha", "Parity = bit", "Inverse DWT")

    def slots(self, shape):
        return (shape[0] // 2) * (shape[1] // 2)

    def embed(self, host, wm, alpha, key=None, redundant=True):
        bits = scramble(wm.ravel().astype(int), key)
        LL, LH, HL, HH = haar_dwt2(host)
        c = HL.ravel().copy()
        slots, which = layout(bits.size, c.size, key, redundant)
        c[slots] = qim_embed(c[slots], bits[which], alpha, dither(key, slots.size, alpha))
        return haar_idwt2(LL, LH, c.reshape(HL.shape), HH), {}

    def read_soft(self, host, alpha, key, redundant, n):
        c = haar_dwt2(host)[2].ravel()
        slots, which = layout(n, c.size, key, redundant)
        return qim_soft(c[slots], alpha, dither(key, slots.size, alpha)), which


# ----------------------------------------------------------------------------
class SVDScheme(Scheme):
    name, title, short = "svd", "Classic SVD", "SVD"
    blind, payload = False, "image"
    alpha_default, alpha_min, alpha_max, alpha_step = 0.05, 0.005, 0.5, 0.005
    origin = "Port of svd_watermark_embed.m / svd_watermark_extract.m (Liu & Tan style)"
    description = ("A = U S V^T. Adds the logo's singular values: S' = S + alpha*Sw. Non-blind: needs the key (S, Uw, Vw). Flaw: Uw, Vw carry the logo, so a fake owner can 'extract' theirs.")
    pipeline = ("SVD of cover", "SVD of watermark", "S' = S + alpha*Sw", "Rebuild U S' V^T", "Keep S, Uw, Vw as key")

    def watermark_shape(self, size):
        return (size, size)

    def embed(self, host, wm, alpha, key=None, redundant=True):
        Ua, sa, Vat = np.linalg.svd(host)
        Uw, sw, Vwt = np.linalg.svd(wm.astype(float))
        marked = Ua @ np.diag(sa + alpha * sw) @ Vat
        return marked, {"S": sa, "Uw": Uw, "Vwt": Vwt}

    def extract(self, host, alpha, key=None, redundant=True, secret=None, wm_shape=None):
        s = np.linalg.svd(host, compute_uv=False)
        sw = (s - secret["S"]) / alpha
        W = secret["Uw"] @ np.diag(sw) @ secret["Vwt"]
        return np.clip(np.round(W), 0, 255).astype(np.uint8)


# ----------------------------------------------------------------------------
class HybridPaperScheme(Scheme):
    name, title, short = "hybrid_paper", "Hybrid DWT-DCT-SVD (paper)", "Paper hybrid"
    blind, payload = False, "image"
    alpha_default, alpha_min, alpha_max, alpha_step = 0.1, 0.01, 1.0, 0.01
    origin = "Reproduction of the base paper's algorithm (Loke, Swami & Kulkarni, IJES 2025)"
    description = ("The base paper: Haar DWT, 4x4 block DCT, DC coefficients into matrix C, then SVD with S' = S + alpha*Sw. Non-blind, so it inherits the SVD false-positive flaw.")
    pipeline = ("Haar DWT", "Band -> 4x4 blocks", "DCT each block", "DC matrix C", "SVD: S' = S + alpha*Sw", "Inverse DCT + DWT")
    BAND = {"LL": 0, "LH": 1, "HL": 2, "HH": 3}

    def __init__(self, band="HH"):
        self.band = band

    def watermark_shape(self, size):
        return (size // 8, size // 8)

    def _dc(self, host):
        bands = list(haar_dwt2(host))
        D = blockwise_dct(bands[self.BAND[self.band]], 4)
        return bands, D

    def embed(self, host, wm, alpha, key=None, redundant=True):
        bands, D = self._dc(host)
        Uc, sc, Vct = np.linalg.svd(D[..., 0, 0])
        Uw, sw, Vwt = np.linalg.svd(wm.astype(float))
        D[..., 0, 0] = Uc @ np.diag(sc + alpha * sw) @ Vct
        bands[self.BAND[self.band]] = blockwise_idct(D, 4)
        return haar_idwt2(*bands), {"S": sc, "Uw": Uw, "Vwt": Vwt}

    def extract(self, host, alpha, key=None, redundant=True, secret=None, wm_shape=None):
        _, D = self._dc(host)
        s = np.linalg.svd(D[..., 0, 0], compute_uv=False)
        W = secret["Uw"] @ np.diag((s - secret["S"]) / alpha) @ secret["Vwt"]
        return np.clip(np.round(W), 0, 255).astype(np.uint8)


# ----------------------------------------------------------------------------
class HybridQIMScheme(BitScheme):
    name, title, short = "hybrid_qim", "Hybrid DWT-DCT-QIM (proposed)", "Proposed"
    alpha_default, alpha_min, alpha_max, alpha_step = 28, 4, 120, 1
    prefilter = False          # replaced by the switching (impulse-only) median in extract()
    origin = "Our improvement on the paper's pipeline"
    description = ("Every 8x8 block carries three independent copies of a bit: dithered QIM on its DC (brightness), QIM on a low-frequency DCT pair difference, and the order of a mid-frequency pair. Keyed, clip-aware; a blind decoder weights whichever carrier survived.")
    pipeline = ("8x8 blocks (= Haar LL 4x4)", "QIM on DC", "QIM on low pair", "Order of mid pair", "Keyed spread", "Weighted soft vote")

    def slots(self, shape):
        return (shape[0] // 8) * (shape[1] // 8)

    def copies(self, shape, wm_shape=(32, 32), redundant=True):
        """Copies of each bit across all three carriers (DC + low pair + mid pair)."""
        return 3 * super().copies(shape, wm_shape, redundant)

    PAIR_RATIO = 0.8           # carrier 2 QIM step = PAIR_RATIO * alpha
    DC_LAMBDA = 0.85           # distortion-compensated QIM factor for the DC carrier
    P1, P2 = (2, 1), (1, 2)    # carrier 2: low pair, QIM on D(3,2)-D(2,3) (MATLAB 1-based)
    M1, M2 = (3, 2), (2, 3)    # carrier 3: mid pair ORDER rule, Block DCT's D(4,3) vs D(3,4)
    MID_RATIO = 0.3            # carrier 3 margin = MID_RATIO * alpha

    @staticmethod
    def _pair_key(key):
        return None if key is None else int(key) + 7001

    @staticmethod
    def _mid_key(key):
        return None if key is None else int(key) + 9001

    def embed(self, host, wm, alpha, key=None, redundant=True, headroom=None):
        """Two independent carriers in every 8x8 block:
        1) DC (block brightness) via dithered QIM, robust to noise, JPEG, blur,
           median and rotation;
        2) the mid-frequency pair D(4,3)/D(3,4), unaffected by brightness
           shifts, so it survives sharpening, lines and local overlays.
        DC and AC are orthogonal DCT basis functions, so neither disturbs the other."""
        marked, _ = self._embed_dc(host, wm, alpha, key, redundant, headroom)
        bits = scramble(wm.ravel().astype(int), key)
        D = blockwise_dct(marked, 8)
        flat = D.reshape(-1, 8, 8)
        slots, which = layout(bits.size, flat.shape[0], self._pair_key(key), redundant)
        # dithered QIM on the pair DIFFERENCE: bounded change (never more than
        # one step, whatever the image), and blind to brightness shifts
        # dithered QIM on the pair DIFFERENCE: bounded change (never more than
        # one step, whatever the image), and blind to brightness shifts
        step = self.PAIR_RATIO * alpha
        c1, c2 = flat[slots, *self.P1], flat[slots, *self.P2]
        d = c1 - c2
        d_new = qim_embed(d, bits[which], step, dither(self._pair_key(key), slots.size, step))
        flat[slots, *self.P1] = c1 + (d_new - d) / 2
        flat[slots, *self.P2] = c2 - (d_new - d) / 2

        # carrier 3: order of a mid-frequency pair (scale-invariant: survives
        # sharpening / contrast changes that move QIM values off their grid)
        slots, which = layout(bits.size, flat.shape[0], self._mid_key(key), redundant)
        b, m = bits[which], self.MID_RATIO * alpha
        e1, e2 = flat[slots, *self.M1], flat[slots, *self.M2]
        g = e1 - e2
        need = np.where(b == 1, g < m, g > -m)
        delta = np.where(need, (np.where(b == 1, m, -m) - g) / 2, 0.0)
        flat[slots, *self.M1] = e1 + delta
        flat[slots, *self.M2] = e2 - delta
        return blockwise_idct(flat.reshape(D.shape), 8), {}

    def _clip_weights(self, host):
        """Trust for each block's DC copy, measured on the RECEIVED image (blind).
        Noise or compression on pure black/white areas is clipped at 0/255, which
        biases that block's brightness and flips its DC copy. Exactly-clipped
        pixels are the fingerprint, so blocks full of them get little say. The
        pair carriers use coefficient differences, where such a bias cancels."""
        clipped = (host <= 0.5) | (host >= 254.5)
        frac = to_blocks(clipped.astype(float), 8).mean(axis=(2, 3)).ravel()
        return (1.0 - frac) ** 2

    def _soft_parts(self, host, alpha, key, redundant, n):
        host = np.asarray(host, dtype=float)
        dc_soft, dc_which = self.read_soft_dc(host, alpha, key, redundant, n)
        dc_slots, _ = layout(n, (host.shape[0] // 8) * (host.shape[1] // 8), key, redundant)
        dc_soft = dc_soft * self._clip_weights(host)[dc_slots]
        flat = blockwise_dct(host, 8).reshape(-1, 8, 8)
        slots, pw = layout(n, flat.shape[0], self._pair_key(key), redundant)
        step = self.PAIR_RATIO * alpha
        pair_soft = qim_soft(flat[slots, *self.P1] - flat[slots, *self.P2], step,
                             dither(self._pair_key(key), slots.size, step))
        mslots, mw = layout(n, flat.shape[0], self._mid_key(key), redundant)
        mid_soft = np.clip((flat[mslots, *self.M1] - flat[mslots, *self.M2]) / max(self.MID_RATIO * alpha, 1e-9), -1, 1)
        return (dc_soft, dc_which), (pair_soft, pw), (mid_soft, mw)

    def read_soft(self, host, alpha, key, redundant, n):
        parts = self._soft_parts(host, alpha, key, redundant, n)
        return np.concatenate([p[0] for p in parts]), np.concatenate([p[1] for p in parts])

    @staticmethod
    def _remove_impulses(host):
        """Switching median filter: replace ONLY salt & pepper pixels (pure 0/255
        values that differ strongly from their 3x3 median); every other pixel,
        including thin text strokes, is left untouched."""
        med = median_filter(host, 3)
        impulse = ((host <= 1) | (host >= 254)) & (np.abs(host - med) > 60)
        return np.where(impulse, med, host), int(impulse.sum())

    def _decode(self, host, alpha, key, redundant, n):
        """Confidence^2-weighted sum of both carriers' soft votes."""
        combined, total_conf = np.zeros(n), 0.0
        for soft, which in self._soft_parts(host, alpha, key, redundant, n):
            mean = np.bincount(which, weights=soft, minlength=n) / np.bincount(which, minlength=n)
            conf = float(np.mean(np.abs(mean)))
            combined += mean * conf ** 2
            total_conf += conf
        return combined, total_conf

    def extract(self, host, alpha, key=None, redundant=True, secret=None, wm_shape=(32, 32)):
        """Blind, self-weighting decoder: add the two carriers' soft votes, each
        weighted by confidence^2 (how strongly its own copies agree), so whichever
        carrier survived the attack dominates. If the image contains salt & pepper
        impulses, also decode a version with only those pixels repaired and keep
        whichever reading the copies agree on more. No original image is needed."""
        n = int(np.prod(wm_shape))
        host = np.asarray(host, dtype=float)
        best = self._decode(host, alpha, key, redundant, n)
        cleaned, count = self._remove_impulses(host)
        if count > host.size * 0.0005:                    # more than 0.05 % impulse pixels
            alt = self._decode(cleaned, alpha, key, redundant, n)
            if alt[1] > best[1]:
                best = alt
        return scramble((best[0] > 0).astype(np.uint8), key).reshape(wm_shape)

    def _embed_dc(self, host, wm, alpha, key=None, redundant=True, headroom=None):
        # The DC of a 4x4 DCT block of the Haar LL band equals (sum of the 8x8
        # pixel block) / 8, so the bit lives in each 8x8 block's total
        # brightness. We therefore embed directly in the pixel domain, which
        # gives the exact same DC values as DWT -> DCT -> QIM -> IDCT -> IDWT.
        bits = scramble(wm.ravel().astype(int), key)
        blocks = to_blocks(np.asarray(host, dtype=float), 8)
        nr, nc = blocks.shape[:2]
        dc = blocks.sum(axis=(2, 3)).ravel() / 8
        slots, which = layout(bits.size, dc.size, key, redundant)
        dith = dither(key, slots.size, alpha)

        if headroom is None:          # no clipping information: unlimited room
            down = np.full((slots.size, 64), 1e6)
            up = np.full((slots.size, 64), 1e6)
        else:                         # how far each pixel can move before any RGB channel clips
            down = to_blocks(headroom[0], 8).reshape(nr * nc, 64)[slots]
            up = to_blocks(headroom[1], 8).reshape(nr * nc, 64)[slots]

        # A DC change of D needs the block's pixel SUM to change by 8*D. It does
        # not have to be uniform: pure-black pixels can only go up, pure-white
        # only down, so the block's total range is [-sum(down), +sum(up)] / 8.
        margin = 0.97                 # leave room for rounding to 8-bit RGB
        lo, hi = -down.sum(axis=1) / 8 * margin, up.sum(axis=1) / 8 * margin
        target = qim_embed_bounded(dc[slots], bits[which], alpha, dith, lo, hi)
        # distortion-compensated QIM (Chen & Wornell): move only part of the way
        # to the lattice point. Still decodes correctly, costs much less MSE.
        target = dc[slots] + self.DC_LAMBDA * (target - dc[slots])
        need = 8 * (target - dc[slots])                    # required change of the pixel sum

        # Water-filling: give every pixel the same change t, capped by its own
        # head-room, and find t (per block) so the changes add up to `need`.
        # Unconstrained this is the uniform shift (lowest MSE); near pure
        # black/white it automatically moves the pixels that still have room.
        t_lo = np.full(slots.size, -256.0)
        t_hi = np.full(slots.size, 256.0)
        for _ in range(40):
            t = (t_lo + t_hi) / 2
            total = np.clip(t[:, None], -down, up).sum(axis=1)
            low = total < need
            t_lo = np.where(low, t, t_lo)
            t_hi = np.where(low, t_hi, t)
        change = np.clip(((t_lo + t_hi) / 2)[:, None], -down, up)

        delta = np.zeros((nr * nc, 64))
        delta[slots] = change
        return np.asarray(host, dtype=float) + from_blocks(delta.reshape(nr, nc, 8, 8)), {}

    def read_soft_dc(self, host, alpha, key, redundant, n):
        dc = to_blocks(np.asarray(host, dtype=float), 8).sum(axis=(2, 3)).ravel() / 8   # = DC of LL 4x4 DCT
        slots, which = layout(n, dc.size, key, redundant)
        return qim_soft(dc[slots], alpha, dither(key, slots.size, alpha)), which


SCHEMES = {s.name: s for s in (DCTScheme(), DWTScheme(), SVDScheme(), HybridPaperScheme(), HybridQIMScheme())}


def get_scheme(name, band="HH"):
    if name == "hybrid_paper":
        return HybridPaperScheme(band)
    return SCHEMES[name]
