`timescale 1ns/1ps
//=====================================================
// fp16_fpfma_top
// - Top-level: FP16×FP16 → sign-magnitude fixed-point accumulation
// - Internal accumulator:
//      WIN_W      = 80-bit exact window
//      EXTRA_HEAD = 16-bit headroom
// - Exposes raw sign + magnitude of accumulator for now
//=====================================================
module fp16_fpfma_top #(
    parameter integer ACC_FRAC    = 48,
    parameter integer WIN_W       = 80,
    parameter integer EXTRA_HEAD  = 8,
    parameter integer ACC_W       = WIN_W + EXTRA_HEAD
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 valid_in,
    input  wire                 acc_clear,

    input  wire [15:0]          a_fp16,
    input  wire [15:0]          b_fp16,

    output wire                 acc_sign,
    output wire [ACC_W-1:0]     acc_mag,
    output wire                 overflow
);

    // Unpacked signals for A
    wire        a_sign;
    wire [5:0]  a_exp_unb;
    wire [10:0] a_sig_11;
    wire        a_is_zero;

    // Unpacked signals for B
    wire        b_sign;
    wire [5:0]  b_exp_unb;
    wire [10:0] b_sig_11;
    wire        b_is_zero;

    // Product after multiply + align
    wire        p_sign;
    wire [WIN_W-1:0] p_mag;

    // Unpack A and B
    fp16_unpack_sm U_UNP_A (
        .fp16_in (a_fp16),
        .sign    (a_sign),
        .exp_unb (a_exp_unb),
        .sig_11  (a_sig_11),
        .is_zero (a_is_zero)
    );

    fp16_unpack_sm U_UNP_B (
        .fp16_in (b_fp16),
        .sign    (b_sign),
        .exp_unb (b_exp_unb),
        .sig_11  (b_sig_11),
        .is_zero (b_is_zero)
    );

    // Multiply and align into 80-bit window
    fp16_mul_align_sm #(
        .ACC_FRAC (ACC_FRAC),
        .OUT_W    (WIN_W)
    ) U_MUL_ALN (
        .a_sign    (a_sign),
        .a_exp_unb (a_exp_unb),
        .a_sig_11  (a_sig_11),
        .a_is_zero (a_is_zero),

        .b_sign    (b_sign),
        .b_exp_unb (b_exp_unb),
        .b_sig_11  (b_sig_11),
        .b_is_zero (b_is_zero),

        .p_sign    (p_sign),
        .p_mag     (p_mag)
    );

    // Accumulate in sign-magnitude domain
    acc_signmag_sm #(
        .WIN_W      (WIN_W),
        .EXTRA_HEAD (EXTRA_HEAD),
        .ACC_W      (ACC_W)
    ) U_ACC (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .acc_clear (acc_clear),

        .p_sign    (p_sign),
        .p_mag     (p_mag),

        .acc_sign  (acc_sign),
        .acc_mag   (acc_mag),
        .overflow  (overflow)
    );

endmodule


//=====================================================
// fp16_unpack_sm
// Unpack IEEE-754 FP16 into sign, unbiased exponent, and 11-bit significand.
// - Normal numbers: sig = {1'b1, frac}, exp_unb = E - 15
// - Others (zero, subnormal, inf, nan) => treated as zero for v1
//=====================================================
module fp16_unpack_sm (
    input  wire [15:0] fp16_in,
    output wire        sign,
    output wire [5:0]  exp_unb,
    output wire [10:0] sig_11,
    output wire        is_zero
);

    wire        s;
    wire [4:0]  e;
    wire [9:0]  f;
    wire        normal;

    assign s = fp16_in[15];
    assign e = fp16_in[14:10];
    assign f = fp16_in[9:0];

    assign normal = (e != 5'b00000) && (e != 5'b11111);

    assign sign   = s;
    assign exp_unb = normal ? ( {1'b0, e} - 6'd15 ) : 6'd0;
    assign sig_11  = normal ? {1'b1, f}             : 11'd0;
    assign is_zero = (normal == 1'b0) || (f == 10'd0 && e == 5'd0);

endmodule


//=====================================================
// fp16_mul_align_sm
// - Takes unpacked FP16 A and B
// - Multiplies 11-bit significands (unsigned 11x11 -> 22 bits)
// - Normalizes product (if MSB=1 at bit 21, shift right 1, bump exponent)
// - Sums unbiased exponents
// - Aligns product into fixed 80-bit window (ACC_FRAC fractional bits)
// - Outputs product sign and aligned 80-bit magnitude
//=====================================================
module fp16_mul_align_sm #(
    parameter integer ACC_FRAC = 48,   // fractional bits in accumulator
    parameter integer OUT_W    = 80    // accumulator window width
) (
    // Operand A
    input  wire        a_sign,
    input  wire [5:0]  a_exp_unb,
    input  wire [10:0] a_sig_11,
    input  wire        a_is_zero,

    // Operand B
    input  wire        b_sign,
    input  wire [5:0]  b_exp_unb,
    input  wire [10:0] b_sig_11,
    input  wire        b_is_zero,

    // Product (aligned)
    output wire        p_sign,
    output reg  [OUT_W-1:0] p_mag
);

    wire        any_zero;
    wire [21:0] prod_raw;
    reg  [21:0] prod_norm;
    reg         norm_adj;

    // Signed exponent sum (8 bits is safe: range is small)
    reg signed [7:0] exp_sum;
    integer          shift_int;
    integer          shift_abs;
    reg [OUT_W-1:0]  temp_val;

    assign any_zero = a_is_zero | b_is_zero;
    assign p_sign   = a_sign ^ b_sign;

    assign prod_raw = any_zero ? 22'd0 : (a_sig_11 * b_sig_11); // 11x11->22 unsigned multiply

    always @(*) begin
        // Normalize product: product is in [1,4) region
        // If MSB (bit21) is 1, we shift right by 1 and add 1 to exponent.
        if (prod_raw[21] == 1'b1) begin
            prod_norm = prod_raw >> 1;
            norm_adj  = 1'b1;
        end else begin
            prod_norm = prod_raw;
            norm_adj  = 1'b0;
        end

        // Sign-extend exponents to 8 bits and add
        exp_sum = $signed({{2{a_exp_unb[5]}}, a_exp_unb}) +
                  $signed({{2{b_exp_unb[5]}}, b_exp_unb}) +
                  $signed({7'd0, norm_adj});

        // Compute shift amount for fixed-point alignment.
        // prod_norm is roughly Q1.21, so:
        // shift = exp_sum + ACC_FRAC - 21
        shift_int = exp_sum + ACC_FRAC - 21;

        // Default output
        p_mag   = {OUT_W{1'b0}};
        temp_val = {OUT_W{1'b0}};

        if (any_zero) begin
            p_mag = {OUT_W{1'b0}};
        end else begin
            // Put prod_norm into lower bits of OUT_W
            temp_val = {{(OUT_W-22){1'b0}}, prod_norm};

            if (shift_int >= 0) begin
                // Left shift, saturating if shift is too large for width
                if (shift_int >= OUT_W) begin
                    p_mag = {OUT_W{1'b0}};
                end else begin
                    p_mag = temp_val << shift_int;
                end
            end else begin
                // Right shift
                shift_abs = -shift_int;
                if (shift_abs >= OUT_W) begin
                    p_mag = {OUT_W{1'b0}};
                end else begin
                    p_mag = temp_val >> shift_abs;
                end
            end
        end
    end

endmodule

//=====================================================
// acc_signmag_sm
// - Sign-magnitude accumulator
// - ACC_W = WIN_W + EXTRA_HEAD
//=====================================================
module acc_signmag_sm #(
    parameter integer WIN_W      = 80,
    parameter integer EXTRA_HEAD = 16,
    parameter integer ACC_W      = WIN_W + EXTRA_HEAD
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 valid_in,
    input  wire                 acc_clear,

    input  wire                 p_sign,
    input  wire [WIN_W-1:0]     p_mag,

    output reg                  acc_sign,
    output reg  [ACC_W-1:0]     acc_mag,
    output reg                  overflow
);

    wire [ACC_W-1:0] p_ext;
    wire             p_is_zero;
    wire             acc_is_zero;
    wire             signs_equal;
    wire [ACC_W:0]   sum_full;
    wire [ACC_W:0]   diff_full;
    reg              next_sign;
    reg  [ACC_W-1:0] next_mag;
    reg              next_ovf;

    assign p_ext       = {{EXTRA_HEAD{1'b0}}, p_mag};
    assign p_is_zero   = (p_mag  == {WIN_W{1'b0}});
    assign acc_is_zero = (acc_mag == {ACC_W{1'b0}});
    assign signs_equal = (p_sign == acc_sign);

    // addition result (same-sign case)
    assign sum_full = {1'b0, acc_mag} + {1'b0, p_ext};

    // subtraction result (different-sign case): |acc_mag - p_ext|
    assign diff_full = (acc_mag >= p_ext) ?
                       ({1'b0, acc_mag} - {1'b0, p_ext}) :
                       ({1'b0, p_ext}   - {1'b0, acc_mag});

    // combinational next-state logic
    always @(*) begin
        next_sign = acc_sign;
        next_mag  = acc_mag;
        next_ovf  = 1'b0;

        if (acc_clear) begin
            next_sign = 1'b0;
            next_mag  = {ACC_W{1'b0}};
            next_ovf  = 1'b0;
        end else if (valid_in) begin
            if (p_is_zero) begin
                // no change
                next_sign = acc_sign;
                next_mag  = acc_mag;
            end else if (acc_is_zero) begin
                // accumulator empty, take product directly
                next_sign = p_sign;
                next_mag  = p_ext;
            end else if (signs_equal) begin
                // same sign: add magnitudes
                next_sign = acc_sign;
                next_mag  = sum_full[ACC_W-1:0];
                next_ovf  = sum_full[ACC_W]; // carry beyond width
            end else begin
                // different signs: subtract smaller magnitude from larger
                if (acc_mag >= p_ext) begin
                    next_sign = acc_sign;
                end else begin
                    next_sign = p_sign;
                end
                next_mag = diff_full[ACC_W-1:0];
                next_ovf = 1'b0;
            end
        end
    end

    // sequential registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_sign  <= 1'b0;
            acc_mag   <= {ACC_W{1'b0}};
            overflow  <= 1'b0;
        end else begin
            acc_sign  <= next_sign;
            acc_mag   <= next_mag;
            overflow  <= overflow | next_ovf; // sticky overflow
        end
    end

endmodule
