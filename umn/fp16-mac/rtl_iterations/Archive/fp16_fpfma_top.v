`timescale 1ns/1ps

//=============================================================================
// fp16_fpfma_top
//=============================================================================
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

    // Unpacked FP16 A
    wire        a_sign;
    wire [5:0]  a_exp_unb;
    wire [10:0] a_sig_11;
    wire        a_is_zero;

    // Unpacked FP16 B
    wire        b_sign;
    wire [5:0]  b_exp_unb;
    wire [10:0] b_sig_11;
    wire        b_is_zero;

    // Product (aligned)
    wire        p_sign;
    wire [WIN_W-1:0] p_mag;
    wire        p_valid;

    //============ UNPACK =============
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

    //============ ITERATIVE MULTIPLY + ALIGN =============
    fp16_mul_align_sm U_MUL_ALN (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (valid_in),   // start pulse from TB

        .a_sign    (a_sign),
        .a_exp_unb (a_exp_unb),
        .a_sig_11  (a_sig_11),
        .a_is_zero (a_is_zero),

        .b_sign    (b_sign),
        .b_exp_unb (b_exp_unb),
        .b_sig_11  (b_sig_11),
        .b_is_zero (b_is_zero),

        .p_sign    (p_sign),
        .p_mag     (p_mag),
        .p_valid   (p_valid)     // done pulse to accumulator
    );

    //============ SIGN-MAGNITUDE ACCUMULATOR =============
    acc_signmag_sm #(
        .WIN_W      (WIN_W),
        .EXTRA_HEAD (EXTRA_HEAD),
        .ACC_W      (ACC_W)
    ) U_ACC (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (p_valid),     // driven by p_valid
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
//=============================================================================
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

    assign sign    = s;
    assign exp_unb = normal ? ({1'b0, e} - 6'd15) : 6'd0;
    assign sig_11  = normal ? {1'b1, f} : 11'd0;
    assign is_zero = (~normal) || (f == 10'd0 && e == 5'd0);
endmodule

//=============================================================================
// fp16_mul_align_sm  (MULTI-CYCLE ITERATIVE MANTISSA MULTIPLIER)
//=============================================================================
module fp16_mul_align_sm #(
    parameter integer ACC_FRAC = 48,
    parameter integer OUT_W    = 80
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,

    input  wire        a_sign,
    input  wire [5:0]  a_exp_unb,
    input  wire [10:0] a_sig_11,
    input  wire        a_is_zero,

    input  wire        b_sign,
    input  wire [5:0]  b_exp_unb,
    input  wire [10:0] b_sig_11,
    input  wire        b_is_zero,

    output wire        p_sign,
    output reg  [OUT_W-1:0] p_mag,
    output reg         p_valid
);
    // FSM states
    localparam S_IDLE  = 2'd0,
               S_LOAD  = 2'd1,
               S_RUN   = 2'd2,
               S_DONE  = 2'd3;

    reg [1:0] state;

    // Latched inputs
    reg        a_sign_r, b_sign_r;
    reg [5:0]  a_exp_r,  b_exp_r;
    reg [10:0] a_sig_r,  b_sig_r;
    reg        a_zero_r, b_zero_r;

    wire any_zero_r = a_zero_r | b_zero_r;
    assign p_sign   = a_sign_r ^ b_sign_r;

    // Iterative multiply
    reg [21:0] partial;
    reg [3:0]  idx;     // 0..10

    // Normalization + exponent + alignment
    reg  [21:0] prod_norm;
    reg         norm_adj;
    reg  signed [7:0] exp_sum;
    integer           shift_int;
    integer           shift_abs;
    reg [OUT_W-1:0]   temp_val;

    //---------------- NORMALIZE + ALIGN (combinational from partial) -----
    always @(*) begin
        // Default
        p_mag    = {OUT_W{1'b0}};
        prod_norm = 22'd0;
        norm_adj  = 1'b0;
        exp_sum   = 0;
        shift_int = 0;
        temp_val  = {OUT_W{1'b0}};

        if (!any_zero_r) begin
            // normalize product (range [1,4))
            if (partial[21]) begin
                prod_norm = partial >> 1;
                norm_adj  = 1'b1;
            end else begin
                prod_norm = partial;
                norm_adj  = 1'b0;
            end

            // exponent sum
            exp_sum = $signed({{2{a_exp_r[5]}}, a_exp_r}) +
                      $signed({{2{b_exp_r[5]}}, b_exp_r}) +
                      $signed({7'd0, norm_adj});

            // alignment shift
            shift_int = exp_sum + ACC_FRAC - 21;

            temp_val = {{(OUT_W-22){1'b0}}, prod_norm};

            if (shift_int >= 0) begin
                if (shift_int < OUT_W)
                    p_mag = temp_val << shift_int;
            end else begin
                shift_abs = -shift_int;
                if (shift_abs < OUT_W)
                    p_mag = temp_val >> shift_abs;
            end
        end
    end

    //---------------- FSM + ITERATIVE MULTIPLY (sequential) --------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            a_sign_r <= 1'b0;
            b_sign_r <= 1'b0;
            a_exp_r  <= 6'd0;
            b_exp_r  <= 6'd0;
            a_sig_r  <= 11'd0;
            b_sig_r  <= 11'd0;
            a_zero_r <= 1'b0;
            b_zero_r <= 1'b0;
            partial  <= 22'd0;
            idx      <= 4'd0;
            p_valid  <= 1'b0;
        end else begin
            p_valid <= 1'b0;   // default, asserted only in S_DONE

            case (state)
                S_IDLE: begin
                    if (start) begin
                        // latch inputs
                        a_sign_r <= a_sign;
                        b_sign_r <= b_sign;
                        a_exp_r  <= a_exp_unb;
                        b_exp_r  <= b_exp_unb;
                        a_sig_r  <= a_sig_11;
                        b_sig_r  <= b_sig_11;
                        a_zero_r <= a_is_zero;
                        b_zero_r <= b_is_zero;
                        state    <= S_LOAD;
                    end
                end

                S_LOAD: begin
                    // decide: zero product or start iterative multiply
                    if (any_zero_r) begin
                        partial <= 22'd0;
                        state   <= S_DONE;
                    end else begin
                        partial <= 22'd0;
                        idx     <= 4'd0;
                        state   <= S_RUN;
                    end
                end

                S_RUN: begin
                    // iterate over b_sig bits 0..10
                    if (idx < 4'd11) begin
                        if (b_sig_r[idx])
                            partial <= partial + ( {11'd0, a_sig_r} << idx );
                        idx <= idx + 1'b1;

                        if (idx == 4'd10)
                            state <= S_DONE;
                    end
                end

                S_DONE: begin
                    // one-cycle done pulse
                    p_valid <= 1'b1;
                    state   <= S_IDLE;
                end
            endcase
        end
    end

endmodule

//=============================================================================
// acc_signmag_sm
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
                next_mag = acc_mag;
            end else if (acc_is_zero) begin
                next_sign = p_sign;
                next_mag  = p_ext;
            end else if (signs_equal) begin
                next_sign = acc_sign;
                next_mag  = sum_full[ACC_W-1:0];
                next_ovf  = sum_full[ACC_W];
            end else begin
                next_sign = (acc_mag >= p_ext) ? acc_sign : p_sign;
                next_mag  = diff_full[ACC_W-1:0];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_sign  <= 1'b0;
            acc_mag   <= {ACC_W{1'b0}};
            overflow  <= 1'b0;
        end else begin
            acc_sign  <= next_sign;
            acc_mag   <= next_mag;
            overflow  <= overflow | next_ovf; // sticky
        end
    end
endmodule


