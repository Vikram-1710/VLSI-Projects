#!/usr/bin/env python3
# =============================================================================
# gen_softmax_golden.py
#
# Generates test vectors and golden reference files for tb_softmax_unit.v.
# Implements the EXACT same arithmetic as softmax_unit.sv + exp.sv:
#   - row max (exact)
#   - exp via LUT (matches exp.sv bit-for-bit)
#   - row sum (exact, 32-bit accumulation)
#
# Outputs (one hex value per line, Q8.8 = 4-digit, 32-bit = 8-digit):
#   softmax_sij.txt          N_TESTS × Br × Bc  input values
#   softmax_golden_m.txt     N_TESTS × Br        m_tilde
#   softmax_golden_p.txt     N_TESTS × Br × Bc   P_tilde
#   softmax_golden_l.txt     N_TESTS × Br        l_tilde (32-bit)
# =============================================================================

import random
random.seed(42)

# ---- Hardware parameters (must match tb_softmax_unit.v) --------------------
Br     = 4
Bc     = 8
DATA_W = 16   # Q8.8
ACC_W  = 32

# ---- exp.sv constants -------------------------------------------------------
LOG2E    = 369   # log2(e) × 256, Q8.8
POW2_LUT = [256, 267, 279, 292, 304, 318, 332, 347,
            362, 378, 395, 412, 431, 450, 470, 490]


# =============================================================================
# Helper: fixed-point conversions
# =============================================================================
def to_q88(f):
    """Float → Q8.8 raw int (signed 16-bit, returned as Python int in [-32768,32767])"""
    v = int(round(f * 256))
    return max(-32768, min(32767, v))

def sign16(v):
    """Interpret Python int as signed 16-bit"""
    v = int(v) & 0xFFFF
    return v - 65536 if v >= 32768 else v

def sign8(v):
    """Interpret Python int as signed 8-bit"""
    v = int(v) & 0xFF
    return v - 256 if v >= 128 else v


# =============================================================================
# hw_exp: bit-exact replica of exp.sv
# =============================================================================
def hw_exp(x_in_raw):
    """
    Input:  x_in_raw  – raw 16-bit signed Q8.8 value (Python int)
    Output: exp_out   – raw 16-bit unsigned Q8.8 value
    Matches exp.sv step by step.
    """
    # Step 1: y = x × log2(e), Q16.16 → take bits [23:8] for Q8.8
    x_in  = sign16(x_in_raw)                     # treat as signed 16-bit
    y_full = (x_in * LOG2E) & 0xFFFFFFFF          # 32-bit product
    y_q8_8 = (y_full >> 8) & 0xFFFF              # bits [23:8]

    # Step 2: split into integer (signed) and fractional (unsigned) parts
    int_part  = sign8((y_q8_8 >> 8) & 0xFF)      # y_q8_8[15:8], signed 8-bit
    frac_part = y_q8_8 & 0xFF                     # y_q8_8[ 7:0], unsigned
    lut_idx   = (frac_part >> 4) & 0xF            # top 4 bits → 16-entry LUT

    # Step 3: LUT lookup
    pow2_frac = POW2_LUT[lut_idx]                 # 9-bit value

    # Step 4: right-shift by -int_part, clamped to [0,8]
    int_clamped = max(-8, min(0, int_part))
    shift_amt   = -int_clamped                    # 0 .. 8
    result      = (pow2_frac & 0x1FF) >> shift_amt

    return result & 0xFFFF


# =============================================================================
# hw_softmax: bit-exact replica of softmax_unit.sv
# =============================================================================
def hw_softmax(sij):
    """
    sij: list[Br][Bc] of raw Q8.8 Python ints
    Returns (m_tile, p_tile, l_tile) matching softmax_unit.sv exactly.
    """
    m_tile, p_tile, l_tile = [], [], []
    for r in range(Br):
        row = sij[r]
        # Row-max (exact)
        m = max(sign16(v) for v in row)
        m_tile.append(m & 0xFFFF)

        # exp(Sij[r][c] - m_tilde[r]) per element
        p_row = []
        l = 0
        for c in range(Bc):
            diff = (sign16(row[c]) - m) & 0xFFFF
            p = hw_exp(diff)
            p_row.append(p)
            l += p   # P_tilde values are non-negative, l_tilde accumulates in 32 bits
        p_tile.append(p_row)
        l_tile.append(l & 0xFFFFFFFF)

    return m_tile, p_tile, l_tile


# =============================================================================
# Test cases
# =============================================================================
test_cases = []
test_names  = []

# TC0: all zeros – exp(0)=1.0 for every element, l=Bc×1.0
test_cases.append([[0]*Bc for _ in range(Br)])
test_names.append("all-zero Sij")

# TC1: uniform positive – all rows/cols equal → P_tilde all exp(0)=1.0
test_cases.append([[to_q88(1.5)]*Bc for _ in range(Br)])
test_names.append("uniform 1.5 Sij")

# TC2: linear gradient across columns: S[r][c] = (c - Bc/2) × 0.25
test_cases.append([[to_q88((c - Bc / 2) * 0.25) for c in range(Bc)]
                   for r in range(Br)])
test_names.append("column gradient S[r][c]=(c-4)×0.25")

# TC3: one-hot per row – S[r][r]=2.0, rest=0 (tests large relative diff)
tc = [[0]*Bc for _ in range(Br)]
for r in range(Br):
    tc[r][r] = to_q88(2.0)
test_cases.append(tc)
test_names.append("one-hot S[r][r]=2.0")

# TC4: almost all very negative (exp≈0) except one large element per row
tc = [[to_q88(-6.0)]*Bc for _ in range(Br)]
for r in range(Br):
    tc[r][0] = to_q88(-1.0)
test_cases.append(tc)
test_names.append("near-zero exp, one dominant")

# TC5: random mixed-sign values in [-3, 3]
test_cases.append([[to_q88(random.uniform(-3.0, 3.0)) for c in range(Bc)]
                   for r in range(Br)])
test_names.append("random mixed ±3.0")

# TC6: different constant per row (tests inter-row independence)
test_cases.append([[to_q88(r * 0.5) for c in range(Bc)] for r in range(Br)])
test_names.append("constant per row (0, 0.5, 1.0, 1.5)")

# TC7: symmetric valley (large softmax concentration at centre)
test_cases.append([[to_q88(-abs(c - Bc / 2 + 0.5) * 0.5)
                    for c in range(Bc)]
                   for r in range(Br)])
test_names.append("symmetric valley")


# =============================================================================
# Write output files
# =============================================================================
N_TESTS = len(test_cases)

with open('softmax_sij.txt',      'w') as fs, \
     open('softmax_golden_m.txt', 'w') as fm, \
     open('softmax_golden_p.txt', 'w') as fp, \
     open('softmax_golden_l.txt', 'w') as fl:

    for tc_idx, tc in enumerate(test_cases):
        m, p, l = hw_softmax(tc)

        # Input
        for row in tc:
            for v in row:
                fs.write(f'{v & 0xFFFF:04x}\n')

        # Outputs
        for v in m:
            fm.write(f'{v & 0xFFFF:04x}\n')
        for row in p:
            for v in row:
                fp.write(f'{v & 0xFFFF:04x}\n')
        for v in l:
            fl.write(f'{v & 0xFFFFFFFF:08x}\n')

# =============================================================================
# Human-readable summary
# =============================================================================
print(f'Generated {N_TESTS} test cases → softmax_sij.txt / golden_m/p/l.txt')
print()
for i, (tc, name) in enumerate(zip(test_cases, test_names)):
    m, p, l = hw_softmax(tc)
    print(f'TC{i} [{name}]')
    for r in range(Br):
        row_s = [f'{sign16(tc[r][c]):7.3f}' for c in range(Bc)]
        row_p = [f'{p[r][c]/256:.3f}' for c in range(Bc)]
        print(f'  row{r}  S=[{", ".join(row_s)}]')
        print(f'        m={sign16(m[r])/256:.3f}  '
              f'P=[{", ".join(row_p)}]  l={l[r]/256:.3f}')
    print()
