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
    parameter integer EXTRA_HEAD  = 16,
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
