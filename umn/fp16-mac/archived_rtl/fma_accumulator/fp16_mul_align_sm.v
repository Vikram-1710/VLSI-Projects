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
