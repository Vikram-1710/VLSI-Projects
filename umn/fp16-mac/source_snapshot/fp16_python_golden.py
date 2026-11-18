import numpy as np

# ---------------------------------
# Config – match your architecture
# ---------------------------------
ACC_FRAC   = 48
WIN_W      = 80
EXTRA_HEAD = 8
ACC_W      = WIN_W + EXTRA_HEAD      # 88 bits total
ACC_HEX_W  = ACC_W // 4              # 22 hex chars


# ---------------------------------
# Helper functions
# ---------------------------------

def hex_to_float16(h):
    """FP16 hex string (4 chars) -> Python float64 value."""
    v = int(h, 16)
    return np.float16(np.uint16(v)).astype(np.float64)


def float_to_fixed(x):
    """Python float -> signed fixed-point integer with ACC_FRAC fractional bits."""
    return int(round(x * (1 << ACC_FRAC)))


def fixed_to_sign_mag_hex(v):
    """
    Signed int -> (sign_bit, magnitude_hex_string) using ACC_W bits.
    sign=0 => non-negative, sign=1 => negative.
    """
    if v < 0:
        sign = 1
        mag = -v
    else:
        sign = 0
        mag = v

    mag &= (1 << ACC_W) - 1  # limit magnitude to ACC_W bits
    mag_hex = f"{mag:0{ACC_HEX_W}X}"
    return sign, mag_hex


# ---------------------------------
# Scenario runner
# ---------------------------------

def run_scenario(title, description, a_hex_list, b_hex_list):
    print("=" * 72)
    print(f"{title}: {description}")
    print("-" * 72)
    print("Step  Ahex  Bhex      prod(real)     golden(real)   acc_s  acc_mag(hex)")
    print("-" * 72)

    acc_fixed   = 0    # accumulator in fixed-point
    golden_real = 0.0  # accumulator in real value

    for i, (ah, bh) in enumerate(zip(a_hex_list, b_hex_list)):
        Aval = float(hex_to_float16(ah))
        Bval = float(hex_to_float16(bh))

        prod_real = Aval * Bval
        golden_real += prod_real

        prod_fx = float_to_fixed(prod_real)
        acc_fixed += prod_fx

        acc_s, acc_mag_hex = fixed_to_sign_mag_hex(acc_fixed)

        print(f"{i:>4d}  {ah:>4s}  {bh:>4s}  "
              f"{prod_real:13.6f}  {golden_real:13.6f}  "
              f"{acc_s:>5d}  {acc_mag_hex}")

    acc_s, acc_mag_hex = fixed_to_sign_mag_hex(acc_fixed)
    print("-" * 72)
    print(f"Expected golden sum = {golden_real:.6g},  "
          f"HW acc_sign={acc_s}, acc_mag=0x{acc_mag_hex}")
    print()  # blank line after scenario


# ---------------------------------
# Define scenarios here
# ---------------------------------

if __name__ == "__main__":

    # Scenario 1: (+1*1), (+2*0.5), (-1*1) => final = +1.0
    scen1_A = ["3C00", "4000", "BC00"]   # 1.0, 2.0, -1.0
    scen1_B = ["3C00", "3800", "3C00"]   # 1.0, 0.5, 1.0

    # Scenario 2: (+1*1) five times, (-1*1) four times => final = +1.0
    scen2_A = ["3C00"] * 5 + ["BC00"] * 4
    scen2_B = ["3C00"] * 9

    # Scenario 3: large magnitude (max fp16 * max fp16) 4x
    # max finite fp16 = 0x7BFF
    scen3_A = ["7BFF"] * 4
    scen3_B = ["7BFF"] * 4

    run_scenario(
        "SCENARIO 1",
        "simple mix (+1*1), (+2*0.5), (-1*1)  ==> final = +1.0",
        scen1_A, scen1_B,
    )

    run_scenario(
        "SCENARIO 2",
        "cancellation (+1*1) 5x and (-1*1) 4x  ==> final = +1.0",
        scen2_A, scen2_B,
    )

    run_scenario(
        "SCENARIO 3",
        "large magnitude (max_fp16 * max_fp16) 4x",
        scen3_A, scen3_B,
    )
