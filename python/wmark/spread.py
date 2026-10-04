"""Keyed spreading + redundancy for bit watermarks (new vs. the MATLAB code).

The MATLAB schemes write bit k into slot k (block k / coefficient k), once.
That has two weaknesses:
  * one damaged region (a crop, a line, a logo overlay) destroys a
    contiguous piece of the watermark, and
  * anyone who knows the algorithm knows exactly where every bit lives.

Here every scheme exposes N "slots" (8x8 blocks, HL coefficients, ...).
With a secret ``key`` the slot order is a pseudo-random permutation, and
with ``redundant=True`` each of the n bits is written floor(N/n) times.
Extraction reads every copy and takes a majority vote.

key=None, redundant=False reproduces the original MATLAB behaviour.
"""
import numpy as np


MAX_REPS = 7


def layout(n_bits, n_slots, key=None, redundant=True):
    """Return (slot indices, which bit each of those slots carries).

    The number of copies is capped (each copy costs image quality) and kept
    odd so a majority vote can never tie.
    """
    if n_slots < n_bits:
        raise ValueError(f"watermark needs {n_bits} slots but the image only has {n_slots}")
    reps = copies(n_bits, n_slots, redundant)
    bit_of_slot = np.tile(np.arange(n_bits), reps)
    if key is None:
        slots = np.arange(bit_of_slot.size)
    else:
        slots = np.random.default_rng(int(key)).permutation(n_slots)[: bit_of_slot.size]
    return slots, bit_of_slot


def vote(slot_bits, bit_of_slot, n_bits):
    """Majority vote over all copies of each bit (ties -> 0)."""
    ones = np.bincount(bit_of_slot, weights=slot_bits, minlength=n_bits)
    total = np.bincount(bit_of_slot, minlength=n_bits)
    return (ones / total > 0.5).astype(np.uint8)


def copies(n_bits, n_slots, redundant=True):
    """How many copies of each bit ``layout`` writes."""
    reps = min(MAX_REPS, n_slots // n_bits) if redundant else 1
    return reps - 1 if reps % 2 == 0 else reps


def scramble(bits, key):
    """XOR the watermark with a key-derived pseudo-random bit sequence.

    Logos are mostly one colour, so two unrelated logos still "correlate".
    Scrambling makes the embedded bits balanced (50% ones), so a wrong key
    or unmarked image reads as noise. XOR is its own inverse, so the same
    call unscrambles at extraction.
    """
    if key is None:
        return bits
    pn = np.random.default_rng(int(key) + 2).integers(0, 2, bits.shape)
    return (bits.astype(np.int64) ^ pn).astype(bits.dtype)


def agreement(slot_bits, bit_of_slot, n_bits):
    """Mean fraction of copies that agree with the majority for each bit."""
    ones = np.bincount(bit_of_slot, weights=slot_bits, minlength=n_bits)
    total = np.bincount(bit_of_slot, minlength=n_bits)
    return float(np.mean(np.maximum(ones, total - ones) / total))


def dither(key, n, step):
    """Secret per-slot offset in [-step, step) (dithered QIM).

    Without it, unmarked content decodes as "all zeros" (small coefficients
    round to index 0) and the quantisation grid is public. With it, the grid
    is shifted by a key-dependent amount, so unmarked images or a wrong key
    decode to random bits (BER ~ 0.5, NC ~ 0). The range must cover a full
    odd/even period (2*step), otherwise near-zero coefficients still round
    to index 0 and read as bit 0.
    """
    if key is None:
        return np.zeros(n)
    return np.random.default_rng(int(key) + 1).uniform(-step, step, n)


def qim_embed(c, bits, step, d=0.0):
    """Odd/even quantisation index modulation (same rule as dwt_watermark_embed.m):
    round c to a multiple of ``step``; even index = bit 0, odd index = bit 1."""
    c = c - d
    q = np.round(c / step)
    wrong = np.mod(q, 2) != bits
    q = np.where(wrong, np.where(c - q * step >= 0, q + 1, q - 1), q)
    return q * step + d


def qim_embed_bounded(c, bits, step, d, lo, hi):
    """QIM that never needs more change than the pixels can take.

    Every level q*step with the right parity encodes the bit, so besides the
    nearest one we may use the next one up or down (q +- 2). For each slot we
    pick the closest level whose change c' - c lies in [lo, hi]; if none fits,
    the one that overshoots least. This avoids writing bits into blocks where
    pure white / black pixels would be clipped (and the bit lost).
    """
    base = qim_embed(c, bits, step, d)
    cands = np.stack([base, base - 2 * step, base + 2 * step])      # (3, n)
    delta = cands - c
    over = np.maximum(lo - delta, 0) + np.maximum(delta - hi, 0)    # 0 when feasible
    cost = over * 1e6 + np.abs(delta)
    return cands[np.argmin(cost, axis=0), np.arange(c.size)]


def qim_soft(c, step, d=0.0):
    """Soft QIM read-out in [-1, 1]: +1 exactly on an odd step (bit 1), -1 exactly
    on an even step (bit 0), ~0 half-way between (an unreliable copy)."""
    return -np.cos(np.pi * (c - d) / step)


def vote_soft(soft, bit_of_slot, n_bits):
    """Soft majority vote: sum the copies' soft values; positive -> bit 1.
    Returns (bits, confidence) where confidence is the mean |sum| per copy."""
    total = np.bincount(bit_of_slot, weights=soft, minlength=n_bits)
    count = np.bincount(bit_of_slot, minlength=n_bits)
    return (total > 0).astype(np.uint8), float(np.mean(np.abs(total) / count))


def qim_extract(c, step, d=0.0):
    return np.mod(np.round((c - d) / step), 2).astype(np.uint8)
