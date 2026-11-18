`timescale 1ns/1ps

//=============================================================================
// Top: fp16_fpfma_top
//   - FP16 x FP16 -> sign-magnitude fixed-point accumulation
//   - Iterative mantissa multiplier (cycles = MANT_W)
//   - Configurable mantissa width MANT_W (<= 11)
//=============================================================================
module fp16_fpfma_top #(
    parameter integer ACC_FRAC    = 48,          // fractional bits in accumulator
    parameter integer WIN_W       = 80,          // accumulator "window" width
    parameter integer EXTRA_HEAD  = 8,          // extra headroom bits
    parameter integer MANT_W      = 11,          // mantissa width incl. hidden 1 (<=11)
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

    // Unpacked A
    wire        a_sign;
    wire [5:0]  a_exp_unb;
    wire [MANT_W-1:0] a_sig_m;
    wire        a_is_zero;

    // Unpacked B
    wire        b_sign;
    wire [5:0]  b_exp_unb;
    wire [MANT_W-1:0] b_sig_m;
    wire        b_is_zero;

    // Product aligned into WIN_W window
    wire        p_sign;
    wire [WIN_W-1:0] p_mag;
    wire        p_valid;  // one-cycle pulse when product ready

    // -------- Unpack FP16 operands --------
    fp16_unpack_sm #(
        .MANT_W (MANT_W)
    ) U_UNP_A (
        .fp16_in (a_fp16),
        .sign    (a_sign),
        .exp_unb (a_exp_unb),
        .sig_m   (a_sig_m),
        .is_zero (a_is_zero)
    );

    fp16_unpack_sm #(
        .MANT_W (MANT_W)
    ) U_UNP_B (
        .fp16_in (b_fp16),
        .sign    (b_sign),
        .exp_unb (b_exp_unb),
        .sig_m   (b_sig_m),
        .is_zero (b_is_zero)
    );

    // -------- Iterative multiply + align --------
    fp16_mul_align_sm #(
        .ACC_FRAC (ACC_FRAC),
        .OUT_W    (WIN_W),
        .MANT_W   (MANT_W)
    ) U_MUL_ALN (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (valid_in),   // 1-cycle start pulse

        .a_sign    (a_sign),
        .a_exp_unb (a_exp_unb),
        .a_sig_m   (a_sig_m),
        .a_is_zero (a_is_zero),

        .b_sign    (b_sign),
        .b_exp_unb (b_exp_unb),
        .b_sig_m   (b_sig_m),
        .b_is_zero (b_is_zero),

        .p_sign    (p_sign),
        .p_mag     (p_mag),
        .p_valid   (p_valid)
    );

    // -------- Sign-magnitude accumulator --------
    acc_signmag_sm #(
        .WIN_W      (WIN_W),
        .EXTRA_HEAD (EXTRA_HEAD),
        .ACC_W      (ACC_W)
    ) U_ACC (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (p_valid),     // accumulate only when product is ready
        .acc_clear (acc_clear),

        .p_sign    (p_sign),
        .p_mag     (p_mag),

        .acc_sign  (acc_sign),
        .acc_mag   (acc_mag),
        .overflow  (overflow)
    );

endmodule

//=============================================================================
// fp16_unpack_sm
//   - IEEE-754 FP16 -> sign, unbiased exponent, MANT_W-bit significand
//   - sig_m is the top MANT_W bits of {1, frac[9:0]} when normal
//=============================================================================
module fp16_unpack_sm #(
    parameter integer MANT_W = 11   // must be 1..11
) (
    input  wire [15:0] fp16_in,
    output wire        sign,
    output wire [5:0]  exp_unb,
    output wire [MANT_W-1:0] sig_m,
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

    assign sign    = s;
    assign exp_unb = normal ? ({1'b0, e} - 6'd15) : 6'd0;

    // full 11-bit significand with hidden 1
    wire [10:0] sig_full = normal ? {1'b1, f} : 11'd0;

    // use the top MANT_W bits from sig_full[10:0]
    // e.g. MANT_W=9 -> sig_full[10:2]
    localparam integer LSB_MANT = 11 - MANT_W;

    assign sig_m   = normal ? sig_full[10:LSB_MANT] : {MANT_W{1'b0}};
    assign is_zero = (normal == 1'b0) || (f == 10'd0 && e == 5'd0);

endmodule

//=============================================================================
// fp16_mul_align_sm
//   - Iterative mantissa multiply (MANT_W x MANT_W, runs MANT_W cycles)
//   - Normalization & exponent sum
//   - Fixed-point alignment into OUT_W-bit window
//=============================================================================
module fp16_mul_align_sm #(
    parameter integer ACC_FRAC = 48,
    parameter integer OUT_W    = 80,
    parameter integer MANT_W   = 11
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire        a_sign,
    input  wire [5:0]  a_exp_unb,
    input  wire [MANT_W-1:0] a_sig_m,
    input  wire        a_is_zero,

    input  wire        b_sign,
    input  wire [5:0]  b_exp_unb,
    input  wire [MANT_W-1:0] b_sig_m,
    input  wire        b_is_zero,

    output wire        p_sign,
    output reg  [OUT_W-1:0] p_mag,
    output reg         p_valid
);
    // FSM states
    localparam [1:0] S_IDLE  = 2'd0,
                     S_LOAD  = 2'd1,
                     S_RUN   = 2'd2,
                     S_DONE  = 2'd3;

    reg [1:0] state;

    // Latched inputs
    reg        a_sign_r, b_sign_r;
    reg [5:0]  a_exp_r,  b_exp_r;
    reg [MANT_W-1:0] a_sig_r,  b_sig_r;
    reg        a_zero_r, b_zero_r;

    wire any_zero_r = a_zero_r | b_zero_r;
    assign p_sign   = a_sign_r ^ b_sign_r;

    // Iterative multiply: partial sum
    reg [2*MANT_W-1:0] partial;
    reg [4:0]          idx;   // supports up to MANT_W <= 32

    // Normalization + exponent + alignment
    reg  [2*MANT_W-1:0] prod_norm;
    reg                 norm_adj;
    reg  signed [7:0]   exp_sum;
    integer             shift_int;
    integer             shift_abs;
    reg [OUT_W-1:0]     temp_val;

    // -------- NORMALIZE + ALIGN (combinational from 'partial') --------
    always @(*) begin
        p_mag     = {OUT_W{1'b0}};
        prod_norm = {2*MANT_W{1'b0}};
        norm_adj  = 1'b0;
        exp_sum   = 0;
        shift_int = 0;
        temp_val  = {OUT_W{1'b0}};

        if (!any_zero_r) begin
            // normalize product: check MSB of partial
            if (partial[2*MANT_W-1]) begin
                prod_norm = partial >> 1;
                norm_adj  = 1'b1;
            end else begin
                prod_norm = partial;
                norm_adj  = 1'b0;
            end

            // exponent sum (unbiased exponents + normalization adjust)
            exp_sum = $signed({{2{a_exp_r[5]}}, a_exp_r}) +
                      $signed({{2{b_exp_r[5]}}, b_exp_r}) +
                      $signed({7'd0, norm_adj});

            // prod_norm is approx Q1.(2*MANT_W-1)
            shift_int = exp_sum + ACC_FRAC - (2*MANT_W - 1);

            // pack product into lower bits of OUT_W
            temp_val = {{(OUT_W-(2*MANT_W)){1'b0}}, prod_norm};

            if (shift_int >= 0) begin
                if (shift_int >= OUT_W) begin
                    p_mag = {OUT_W{1'b0}};
                end else begin
                    p_mag = temp_val << shift_int;
                end
            end else begin
                shift_abs = -shift_int;
                if (shift_abs >= OUT_W) begin
                    p_mag = {OUT_W{1'b0}};
                end else begin
                    p_mag = temp_val >> shift_abs;
                end
            end
        end
    end

    // -------- FSM + ITERATIVE MULTIPLY (sequential) --------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            a_sign_r <= 1'b0;
            b_sign_r <= 1'b0;
            a_exp_r  <= 6'd0;
            b_exp_r  <= 6'd0;
            a_sig_r  <= {MANT_W{1'b0}};
            b_sig_r  <= {MANT_W{1'b0}};
            a_zero_r <= 1'b0;
            b_zero_r <= 1'b0;
            partial  <= {2*MANT_W{1'b0}};
            idx      <= 5'd0;
            p_valid  <= 1'b0;
        end else begin
            p_valid <= 1'b0;  // default: pulse only in S_DONE

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // latch inputs
                        a_sign_r <= a_sign;
                        b_sign_r <= b_sign;
                        a_exp_r  <= a_exp_unb;
                        b_exp_r  <= b_exp_unb;
                        a_sig_r  <= a_sig_m;
                        b_sig_r  <= b_sig_m;
                        a_zero_r <= a_is_zero;
                        b_zero_r <= b_is_zero;
                        state    <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    // operand-zero bypass
                    if (any_zero_r) begin
                        partial <= {2*MANT_W{1'b0}};
                        state   <= S_DONE;
                    end else begin
                        partial <= {2*MANT_W{1'b0}};
                        idx     <= 5'd0;
                        state   <= S_RUN;
                    end
                end

                S_RUN: begin
                    // iterative shift-add: runs MANT_W cycles
                    if (idx < MANT_W) begin
                        if (b_sig_r[idx]) begin
                            partial <= partial +
                                       ( {{MANT_W{1'b0}}, a_sig_r} << idx );
                        end
                        idx <= idx + 1'b1;

                        if (idx == (MANT_W-1))
                            state <= S_DONE;
                    end
                end

                S_DONE: begin
                    p_valid <= 1'b1;  // one-cycle done pulse
                    state   <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

//=============================================================================
// acc_signmag_sm
//   - Sign-magnitude accumulator
//   - Adds or subtracts based on signs, with extra headroom bits
//=============================================================================
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
    wire [ACC_W-1:0] p_ext       = {{EXTRA_HEAD{1'b0}}, p_mag};
    wire             p_is_zero   = (p_mag  == {WIN_W{1'b0}});
    wire             acc_is_zero = (acc_mag == {ACC_W{1'b0}});
    wire             signs_equal = (p_sign == acc_sign);

    wire [ACC_W:0]   sum_full  = {1'b0, acc_mag} + {1'b0, p_ext};
    wire [ACC_W:0]   diff_full = (acc_mag >= p_ext) ?
                                 ({1'b0, acc_mag} - {1'b0, p_ext}) :
                                 ({1'b0, p_ext}   - {1'b0, acc_mag});

    reg              next_sign;
    reg  [ACC_W-1:0] next_mag;
    reg              next_ovf;

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
                // nothing to add
                next_mag = acc_mag;
            end else if (acc_is_zero) begin
                // accumulator empty -> take product
                next_sign = p_sign;
                next_mag  = p_ext;
            end else if (signs_equal) begin
                // same sign -> add
                next_sign = acc_sign;
                next_mag  = sum_full[ACC_W-1:0];
                next_ovf  = sum_full[ACC_W];  // carry-out
            end else begin
                // different signs -> subtract
                if (acc_mag >= p_ext)
                    next_sign = acc_sign;
                else
                    next_sign = p_sign;
                next_mag  = diff_full[ACC_W-1:0];
                next_ovf  = 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_sign <= 1'b0;
            acc_mag  <= {ACC_W{1'b0}};
            overflow <= 1'b0;
        end else begin
            acc_sign <= next_sign;
            acc_mag  <= next_mag;
            overflow <= overflow | next_ovf;  // sticky overflow
        end
    end

endmodule

