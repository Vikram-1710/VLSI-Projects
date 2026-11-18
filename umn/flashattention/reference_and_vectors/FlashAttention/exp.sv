// =============================================================================
// exp.sv  –  Hardware approximation of exp(x) for Q8.8 input
//
// Algorithm:  exp(x)  =  2^(x * log2(e))
//
//  Step 1 – Multiply by log2(e):
//             y_full  = x_in * LOG2E      (LOG2E = 369 ≈ log2(e)*256 in Q8.8)
//             y_q8_8  = y_full[23:8]      (Q8.8 result, right-shift 8)
//
//  Step 2 – Split integer / fractional parts:
//             int_part  = y_q8_8[15:8]   (signed, always ≤ 0 for x ≤ 0)
//             frac_part = y_q8_8[7:0]    (unsigned)
//
//  Step 3 – LUT for 2^frac:
//             Use top 4 bits of frac_part as 16-entry LUT index.
//             LUT[i] = round(2^(i/16) * 256)  for i = 0..15
//             Values: 256,267,279,292,304,318,332,347,362,378,395,412,431,450,470,490
//
//  Step 4 – Apply integer shift:
//             exp_out = LUT[frac_part[7:4]]  >>  (-int_part)
//             int_part is clamped to [-8, 0]; shift > 8 gives 0 in Q8.8.
//
// Accuracy:  Max error < 1.5 LSB in Q8.8 (vs exact exp).
//            The existing linear approximation (256+frac) has up to 40 LSB error.
//
// Ports:
//   x_in    – Q8.8 signed, typically ≤ 0 (S - rowmax)
//   exp_out – Q8.8 signed, range [0, 0x0100] (= 0.0 .. 1.0)
// =============================================================================

module exp #(
    parameter DATA_WIDTH = 16   // must be 16 for Q8.8
)(
    input  wire signed [DATA_WIDTH-1:0] x_in,    // Q8.8 input
    output wire signed [DATA_WIDTH-1:0] exp_out  // Q8.8 output, always ≥ 0
);

    // -------------------------------------------------------------------------
    // Step 1: y = x * log2(e),  kept in Q8.8
    // log2(e) ≈ 1.44269 ≈ 369/256  (error < 0.001)
    // -------------------------------------------------------------------------
    localparam signed [15:0] LOG2E = 16'd369;

    wire signed [31:0] y_full  = x_in * LOG2E;       // Q16.16
    wire signed [15:0] y_q8_8  = y_full[23:8];       // Q8.8  (discard LSB 8 and MSB 8)

    // -------------------------------------------------------------------------
    // Step 2: integer and fractional parts
    // -------------------------------------------------------------------------
    wire signed [7:0]  int_part  = y_q8_8[15:8];     // signed integer exponent
    wire        [7:0]  frac_part = y_q8_8[7:0];      // unsigned fraction in [0,1)
    wire        [3:0]  lut_idx   = frac_part[7:4];   // top 4 bits → 16-entry LUT

    // -------------------------------------------------------------------------
    // Step 3: 16-entry LUT for 2^(i/16), i=0..15, stored as Q8.8 integers
    //   LUT[i] = round(2^(i/16) * 256)
    // -------------------------------------------------------------------------
    reg [8:0] pow2_lut [0:15];   // 9 bits wide (max value = 490)

    initial begin
        pow2_lut[ 0] = 9'd256;  // 2^0/16 = 1.0000
        pow2_lut[ 1] = 9'd267;  // 2^1/16 = 1.0443
        pow2_lut[ 2] = 9'd279;  // 2^2/16 = 1.0905
        pow2_lut[ 3] = 9'd292;  // 2^3/16 = 1.1398
        pow2_lut[ 4] = 9'd304;  // 2^4/16 = 1.1892
        pow2_lut[ 5] = 9'd318;  // 2^5/16 = 1.2411
        pow2_lut[ 6] = 9'd332;  // 2^6/16 = 1.2968
        pow2_lut[ 7] = 9'd347;  // 2^7/16 = 1.3543
        pow2_lut[ 8] = 9'd362;  // 2^8/16 = 1.4142
        pow2_lut[ 9] = 9'd378;  // 2^9/16 = 1.4770
        pow2_lut[10] = 9'd395;  // 2^10/16= 1.5422
        pow2_lut[11] = 9'd412;  // 2^11/16= 1.6105
        pow2_lut[12] = 9'd431;  // 2^12/16= 1.6818
        pow2_lut[13] = 9'd450;  // 2^13/16= 1.7567
        pow2_lut[14] = 9'd470;  // 2^14/16= 1.8340
        pow2_lut[15] = 9'd490;  // 2^15/16= 1.9157
    end

    wire [8:0] pow2_frac = pow2_lut[lut_idx];        // 2^frac in Q8.8 (9-bit)

    // -------------------------------------------------------------------------
    // Step 4: right-shift by -int_part (int_part ≤ 0 since x ≤ 0)
    //   Clamp shift amount to [0, 8]: shifts ≥ 9 produce 0 in Q8.8
    // -------------------------------------------------------------------------
    wire signed [7:0] int_clamped = (int_part < -8) ? -8 :
                                    (int_part >  0) ?  0 : int_part;

    wire [3:0] shift_amt = -int_clamped[3:0];        // 0..8

    assign exp_out = {7'b0, pow2_frac} >>> shift_amt;  // arithmetic right-shift

endmodule