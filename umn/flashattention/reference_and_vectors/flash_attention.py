#!/usr/bin/env python3
"""
FlashAttention reference implementation following Algorithm 1 exactly.

Parameters:
    N = 64   sequence length
    d = 4    head dimension
    M = 128  on-chip SRAM size (in elements)
             => Bc = ceil(M / (4d)) = ceil(128/16) = 8
             => Br = min(ceil(M / (4d)), d) = min(8, 4) = 4

Fixed-point convention: Q8.8 signed
    1.0  :  0x0100
    0.5  :  0x0080
   -1.0  :  0xFF00

Input matrices Q, K, V are in Q8.8 format.
They are converted to float32 for all computation.
The output O is converted back to Q8.8.
numpy.exp is used directly for the exponential.
"""

import math
import numpy as np

# ===================================================================
# Algorithm Parameters
# ===================================================================

N = 64   # sequence length
d = 4    # head dimension
M = 128  # on-chip SRAM size (number of elements)

# Derived block sizes  (Algorithm 1, line 1)
Bc = math.ceil(M / (4 * d))          # = 8
Br = min(math.ceil(M / (4 * d)), d)  # = 4

# Number of column / row tiles  (Algorithm 1, line 3)
Tc = math.ceil(N / Bc)   # = 8
Tr = math.ceil(N / Br)   # = 16

# ===================================================================
# Q8.8 Helpers
# ===================================================================

def to_q88(f):
    """Convert float to Q8.8 signed 16-bit integer."""
    v = int(round(f * 256))
    v = max(-32768, min(32767, v))
    return np.int16(v)

def q88_to_float(q):
    """Convert Q8.8 signed 16-bit integer to float32."""
    return np.float32(np.int16(q)) / 256.0

def matrix_q88_to_float(mat_q88):
    """Convert a 2-D Q8.8 array to float32."""
    return mat_q88.astype(np.float32) / 256.0

def matrix_float_to_q88(mat_f):
    """Convert a 2-D float32 array to Q8.8 int16."""
    clipped = np.clip(np.round(mat_f * 256.0), -32768, 32767)
    return clipped.astype(np.int16)

# ===================================================================
# FlashAttention  (Algorithm 1)
# ===================================================================

def flash_attention(Q_q88, K_q88, V_q88):
    """
    Compute attention output O following Algorithm 1 exactly.

    Parameters
    ----------
    Q_q88, K_q88, V_q88 : np.ndarray, shape (N, d), dtype int16
        Input matrices in Q8.8 format.

    Returns
    -------
    O_q88 : np.ndarray, shape (N, d), dtype int16
        Output matrix in Q8.8 format.
    """

    # --- Convert Q8.8 inputs to float for all computation -------------
    Q = matrix_q88_to_float(Q_q88)   # (N, d)  float32
    K = matrix_q88_to_float(K_q88)   # (N, d)  float32
    V = matrix_q88_to_float(V_q88)   # (N, d)  float32

    # Algorithm 1, line 2 – initialise O, l, m in HBM
    O = np.zeros((N, d), dtype=np.float32)           # output accumulator
    l = np.zeros(N,      dtype=np.float32)            # row-sum of softmax numerator
    m = np.full(N,       -np.inf, dtype=np.float32)  # running row-maximum

    # Algorithm 1, line 3-4 – conceptual tiling; we index into arrays directly

    # Algorithm 1, line 5 – outer loop over K/V column tiles
    for j in range(Tc):
        j_start = j * Bc
        j_end   = j_start + Bc

        # Algorithm 1, line 6 – load Kj, Vj  (SRAM)
        Kj = K[j_start:j_end, :]   # (Bc, d)
        Vj = V[j_start:j_end, :]   # (Bc, d)

        # Algorithm 1, line 7 – inner loop over Q row tiles
        for i in range(Tr):
            i_start = i * Br
            i_end   = i_start + Br

            # Algorithm 1, line 8 – load Qi, Oi, li, mi  (SRAM)
            Qi = Q[i_start:i_end, :]    # (Br, d)
            Oi = O[i_start:i_end, :]    # (Br, d)
            li = l[i_start:i_end]       # (Br,)
            mi = m[i_start:i_end]       # (Br,)

            # Algorithm 1, line 9 – Sij = Qi @ Kj^T   shape (Br, Bc)
            Sij = Qi @ Kj.T

            # Algorithm 1, line 10
            m_tilde_ij = np.max(Sij, axis=1)                    # rowmax, shape (Br,)
            P_tilde_ij = np.exp(Sij - m_tilde_ij[:, np.newaxis])  # exp(Sij - m̃), (Br, Bc)
            l_tilde_ij = np.sum(P_tilde_ij, axis=1)             # rowsum, shape (Br,)

            # Algorithm 1, line 11
            mi_new = np.maximum(mi, m_tilde_ij)                 # shape (Br,)
            li_new = (np.exp(mi - mi_new) * li
                      + np.exp(m_tilde_ij - mi_new) * l_tilde_ij)  # shape (Br,)

            # Algorithm 1, line 12 – update Oi and write back to HBM
            #   Oi <- diag(li_new)^{-1} * (diag(li)*exp(mi-mi_new)*Oi
            #                               + exp(m̃ij-mi_new)*P̃ij @ Vj)
            scale_old = (np.exp(mi - mi_new) * li)[:, np.newaxis]   # (Br, 1)
            scale_new = np.exp(m_tilde_ij - mi_new)[:, np.newaxis]  # (Br, 1)

            Oi_new = (scale_old * Oi + scale_new * (P_tilde_ij @ Vj))
            Oi_new = Oi_new / li_new[:, np.newaxis]                   # diag(li_new)^{-1}

            O[i_start:i_end, :] = Oi_new   # write to HBM

            # Algorithm 1, line 13 – write li, mi back to HBM
            l[i_start:i_end] = li_new
            m[i_start:i_end] = mi_new

    # Algorithm 1, line 16 – return O
    # Convert float result back to Q8.8
    O_q88 = matrix_float_to_q88(O)
    return O_q88

# ===================================================================
# Utilities
# ===================================================================

def write_matrix(filename, mat_q88):
    """Write an N×d matrix of Q8.8 values to a text file (one hex word per line)."""
    with open(filename, "w") as f:
        for row in mat_q88:
            for val in row:
                f.write(f"{int(val) & 0xFFFF:04X}\n")
    print(f"  Written {filename}")


def naive_attention(Q_q88, K_q88, V_q88):
    """Standard scaled dot-product attention for reference comparison."""
    Q = matrix_q88_to_float(Q_q88)
    K = matrix_q88_to_float(K_q88)
    V = matrix_q88_to_float(V_q88)

    S   = Q @ K.T                        # (N, N)
    S   = S - np.max(S, axis=1, keepdims=True)
    P   = np.exp(S)
    P   = P / np.sum(P, axis=1, keepdims=True)
    O   = P @ V
    return matrix_float_to_q88(O)

# ===================================================================
# Test-case generation
# ===================================================================

def gen_random_tc(seed=42):
    """Random Q, K, V in Q8.8 in the range [-1, 1)."""
    rng = np.random.default_rng(seed)
    floats = rng.uniform(-1.0, 1.0, (3, N, d)).astype(np.float32)
    Q_q88 = matrix_float_to_q88(floats[0])
    K_q88 = matrix_float_to_q88(floats[1])
    V_q88 = matrix_float_to_q88(floats[2])
    return Q_q88, K_q88, V_q88


def gen_identity_tc():
    """Q = K = identity (first d columns), V = 0.5 everywhere."""
    Q = np.zeros((N, d), dtype=np.int16)
    K = np.zeros((N, d), dtype=np.int16)
    for i in range(N):
        Q[i, i % d] = to_q88(1.0)
        K[i, i % d] = to_q88(1.0)
    V = np.full((N, d), to_q88(0.5), dtype=np.int16)
    return Q, K, V


def gen_uniform_tc():
    """All-ones Q=K (large, equal scores), V = 0.25 everywhere."""
    Q = np.full((N, d), to_q88(1.0), dtype=np.int16)
    K = np.full((N, d), to_q88(1.0), dtype=np.int16)
    V = np.full((N, d), to_q88(0.25), dtype=np.int16)
    return Q, K, V

# ===================================================================
# Main
# ===================================================================

if __name__ == "__main__":

    print(f"FlashAttention parameters:")
    print(f"  N={N}, d={d}, M={M}")
    print(f"  Bc={Bc}, Br={Br}, Tc={Tc}, Tr={Tr}")
    print()

    # --- TC1: random inputs -------------------------------------------
    print("TC1: Random Q, K, V")
    Q1, K1, V1 = gen_random_tc(seed=42)
    O1_flash  = flash_attention(Q1, K1, V1)
    O1_naive  = naive_attention(Q1, K1, V1)

    write_matrix("fa_tc1_Q.txt",     Q1)
    write_matrix("fa_tc1_K.txt",     K1)
    write_matrix("fa_tc1_V.txt",     V1)
    write_matrix("fa_tc1_O_flash.txt", O1_flash)
    write_matrix("fa_tc1_O_naive.txt", O1_naive)

    max_err1 = np.max(np.abs(O1_flash.astype(np.int32) - O1_naive.astype(np.int32)))
    print(f"  Max Q8.8 error vs naive: {max_err1} LSB\n")

    # --- TC2: identity-like inputs ------------------------------------
    print("TC2: Identity-like Q=K, uniform V=0.5")
    Q2, K2, V2 = gen_identity_tc()
    O2_flash  = flash_attention(Q2, K2, V2)
    O2_naive  = naive_attention(Q2, K2, V2)

    write_matrix("fa_tc2_Q.txt",       Q2)
    write_matrix("fa_tc2_K.txt",       K2)
    write_matrix("fa_tc2_V.txt",       V2)
    write_matrix("fa_tc2_O_flash.txt", O2_flash)
    write_matrix("fa_tc2_O_naive.txt", O2_naive)

    max_err2 = np.max(np.abs(O2_flash.astype(np.int32) - O2_naive.astype(np.int32)))
    print(f"  Max Q8.8 error vs naive: {max_err2} LSB\n")

    # --- TC3: uniform (large equal scores) ----------------------------
    print("TC3: Uniform Q=K=1.0, V=0.25  (expected O≈0.25)")
    Q3, K3, V3 = gen_uniform_tc()
    O3_flash  = flash_attention(Q3, K3, V3)
    O3_naive  = naive_attention(Q3, K3, V3)

    write_matrix("fa_tc3_Q.txt",       Q3)
    write_matrix("fa_tc3_K.txt",       K3)
    write_matrix("fa_tc3_V.txt",       V3)
    write_matrix("fa_tc3_O_flash.txt", O3_flash)
    write_matrix("fa_tc3_O_naive.txt", O3_naive)

    max_err3 = np.max(np.abs(O3_flash.astype(np.int32) - O3_naive.astype(np.int32)))
    print(f"  Max Q8.8 error vs naive: {max_err3} LSB\n")

    print("Done.")
