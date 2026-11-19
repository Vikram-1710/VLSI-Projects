`timescale 1ns/1ps

module fft16 #(
    parameter int DATA_W = 16,
    parameter int N      = 16
)(
    input  logic                         clk_i,
    input  logic                         resetn_i,

    input  logic                         frame_start_i,
    input  logic                         in_valid_i,
    input  logic                         in_ch_sel_i,   // 0 -> CH0, 1 -> CH1

    input  logic signed [DATA_W-1:0]     in0_re_i,
    input  logic signed [DATA_W-1:0]     in0_im_i,
    input  logic signed [DATA_W-1:0]     in1_re_i,
    input  logic signed [DATA_W-1:0]     in1_im_i,

    output logic                         out_valid_o,
    output logic                         out_ch_sel_o,
    output logic                         out_last_o,
    output logic        [3:0]            out_idx0_o,
    output logic        [3:0]            out_idx1_o,

    output logic signed [DATA_W-1:0]     out0_re_o,
    output logic signed [DATA_W-1:0]     out0_im_o,
    output logic signed [DATA_W-1:0]     out1_re_o,
    output logic signed [DATA_W-1:0]     out1_im_o
);

    typedef enum logic [2:0] {
        S_IDLE     = 3'd0,
        S_LOAD     = 3'd1,
        S_FEED_CH0 = 3'd2,
        S_FEED_CH1 = 3'd3,
        S_WAIT     = 3'd4,
        S_OUT_ALT  = 3'd5
    } state_t;

    state_t state_reg, state_next;

    logic [4:0] load_cnt_ch0_reg, load_cnt_ch1_reg;  // 0,2,...,16
    logic [3:0] out_ptr_reg;
    logic       out_phase_reg;                       // 0->CH0, 1->CH1

    logic       got_ch0_reg, got_ch1_reg;

    logic signed [DATA_W-1:0] ch0_in_re [0:N-1];
    logic signed [DATA_W-1:0] ch0_in_im [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_re [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_im [0:N-1];

    logic signed [DATA_W-1:0] ch0_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch0_out_im [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_im [0:N-1];

    logic                         core_frame_valid;
    logic                         core_frame_tag;
    logic signed [DATA_W-1:0]     core_in_re [0:N-1];
    logic signed [DATA_W-1:0]     core_in_im [0:N-1];

    logic                         core_out_valid;
    logic                         core_out_tag;
    logic signed [DATA_W-1:0]     core_out_re [0:N-1];
    logic signed [DATA_W-1:0]     core_out_im [0:N-1];

    fft16_dif_pipeline_core #(
        .DATA_W(DATA_W),
        .N(N)
    ) u_core (
        .clk_i         (clk_i),
        .resetn_i      (resetn_i),
        .frame_valid_i (core_frame_valid),
        .frame_tag_i   (core_frame_tag),
        .in_re         (core_in_re),
        .in_im         (core_in_im),
        .out_valid_o   (core_out_valid),
        .out_tag_o     (core_out_tag),
        .out_re        (core_out_re),
        .out_im        (core_out_im)
    );

    // ------------------------------------------------------------------------
    // Shared-core feed select
    // ------------------------------------------------------------------------
    always_comb begin
        core_frame_valid = 1'b0;
        core_frame_tag   = 1'b0;

        for (int k = 0; k < N; k = k + 1) begin
            core_in_re[k] = '0;
            core_in_im[k] = '0;
        end

        if (state_reg == S_FEED_CH0) begin
            core_frame_valid = 1'b1;
            core_frame_tag   = 1'b0;
            for (int k = 0; k < N; k = k + 1) begin
                core_in_re[k] = ch0_in_re[k];
                core_in_im[k] = ch0_in_im[k];
            end
        end
        else if (state_reg == S_FEED_CH1) begin
            core_frame_valid = 1'b1;
            core_frame_tag   = 1'b1;
            for (int k = 0; k < N; k = k + 1) begin
                core_in_re[k] = ch1_in_re[k];
                core_in_im[k] = ch1_in_im[k];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Controller
    // ------------------------------------------------------------------------
    always_comb begin
        state_next = state_reg;

        unique case (state_reg)
            S_IDLE: begin
                if (frame_start_i && in_valid_i)
                    state_next = S_LOAD;
            end

            S_LOAD: begin
                if ((load_cnt_ch0_reg == 5'd16) && (load_cnt_ch1_reg == 5'd16))
                    state_next = S_FEED_CH0;
            end

            S_FEED_CH0: begin
                state_next = S_FEED_CH1;
            end

            S_FEED_CH1: begin
                state_next = S_WAIT;
            end

            S_WAIT: begin
                if (got_ch0_reg && got_ch1_reg)
                    state_next = S_OUT_ALT;
            end

            S_OUT_ALT: begin
                if ((out_ptr_reg == 4'd14) && (out_phase_reg == 1'b1))
                    state_next = S_IDLE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // Sequential updates
    // ------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            state_reg        <= S_IDLE;
            load_cnt_ch0_reg <= 5'd0;
            load_cnt_ch1_reg <= 5'd0;
            out_ptr_reg      <= 4'd0;
            out_phase_reg    <= 1'b0;
            got_ch0_reg      <= 1'b0;
            got_ch1_reg      <= 1'b0;

            for (int k = 0; k < N; k = k + 1) begin
                ch0_in_re[k]  <= '0;
                ch0_in_im[k]  <= '0;
                ch1_in_re[k]  <= '0;
                ch1_in_im[k]  <= '0;
                ch0_out_re[k] <= '0;
                ch0_out_im[k] <= '0;
                ch1_out_re[k] <= '0;
                ch1_out_im[k] <= '0;
            end
        end
        else begin
            state_reg <= state_next;

            // Capture outputs from shared core
            if (core_out_valid) begin
                if (core_out_tag == 1'b0) begin
                    for (int k = 0; k < N; k = k + 1) begin
                        ch0_out_re[k] <= core_out_re[k];
                        ch0_out_im[k] <= core_out_im[k];
                    end
                    got_ch0_reg <= 1'b1;
                end
                else begin
                    for (int k = 0; k < N; k = k + 1) begin
                        ch1_out_re[k] <= core_out_re[k];
                        ch1_out_im[k] <= core_out_im[k];
                    end
                    got_ch1_reg <= 1'b1;
                end
            end

            unique case (state_reg)
                S_IDLE: begin
                    load_cnt_ch0_reg <= 5'd0;
                    load_cnt_ch1_reg <= 5'd0;
                    out_ptr_reg      <= 4'd0;
                    out_phase_reg    <= 1'b0;
                    got_ch0_reg      <= 1'b0;
                    got_ch1_reg      <= 1'b0;

                    if (frame_start_i && in_valid_i) begin
                        if (in_ch_sel_i == 1'b0) begin
                            ch0_in_re[0] <= in0_re_i;
                            ch0_in_im[0] <= in0_im_i;
                            ch0_in_re[1] <= in1_re_i;
                            ch0_in_im[1] <= in1_im_i;
                            load_cnt_ch0_reg <= 5'd2;
                        end
                        else begin
                            ch1_in_re[0] <= in0_re_i;
                            ch1_in_im[0] <= in0_im_i;
                            ch1_in_re[1] <= in1_re_i;
                            ch1_in_im[1] <= in1_im_i;
                            load_cnt_ch1_reg <= 5'd2;
                        end
                    end
                end

                S_LOAD: begin
                    if (in_valid_i) begin
                        if ((in_ch_sel_i == 1'b0) && (load_cnt_ch0_reg < 5'd16)) begin
                            ch0_in_re[load_cnt_ch0_reg+0] <= in0_re_i;
                            ch0_in_im[load_cnt_ch0_reg+0] <= in0_im_i;
                            ch0_in_re[load_cnt_ch0_reg+1] <= in1_re_i;
                            ch0_in_im[load_cnt_ch0_reg+1] <= in1_im_i;
                            load_cnt_ch0_reg <= load_cnt_ch0_reg + 5'd2;
                        end
                        else if ((in_ch_sel_i == 1'b1) && (load_cnt_ch1_reg < 5'd16)) begin
                            ch1_in_re[load_cnt_ch1_reg+0] <= in0_re_i;
                            ch1_in_im[load_cnt_ch1_reg+0] <= in0_im_i;
                            ch1_in_re[load_cnt_ch1_reg+1] <= in1_re_i;
                            ch1_in_im[load_cnt_ch1_reg+1] <= in1_im_i;
                            load_cnt_ch1_reg <= load_cnt_ch1_reg + 5'd2;
                        end
                    end
                end

                S_FEED_CH0: begin
                    // one-cycle pulse
                end

                S_FEED_CH1: begin
                    // one-cycle pulse
                end

                S_WAIT: begin
                    out_ptr_reg   <= 4'd0;
                    out_phase_reg <= 1'b0;
                end

                S_OUT_ALT: begin
                    if (out_phase_reg == 1'b0) begin
                        out_phase_reg <= 1'b1;
                    end
                    else begin
                        out_phase_reg <= 1'b0;
                        if (out_ptr_reg != 4'd14)
                            out_ptr_reg <= out_ptr_reg + 4'd2;
                        else
                            out_ptr_reg <= 4'd0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Interleaved post-output scheduling
    // ------------------------------------------------------------------------
    always_comb begin
        out_valid_o  = 1'b0;
        out_ch_sel_o = 1'b0;
        out_last_o   = 1'b0;
        out_idx0_o   = 4'd0;
        out_idx1_o   = 4'd1;
        out0_re_o    = '0;
        out0_im_o    = '0;
        out1_re_o    = '0;
        out1_im_o    = '0;

        if (state_reg == S_OUT_ALT) begin
            out_valid_o = 1'b1;
            out_idx0_o  = out_ptr_reg;
            out_idx1_o  = out_ptr_reg + 4'd1;

            if (out_phase_reg == 1'b0) begin
                out_ch_sel_o = 1'b0;
                out0_re_o    = ch0_out_re[out_ptr_reg+0];
                out0_im_o    = ch0_out_im[out_ptr_reg+0];
                out1_re_o    = ch0_out_re[out_ptr_reg+1];
                out1_im_o    = ch0_out_im[out_ptr_reg+1];
            end
            else begin
                out_ch_sel_o = 1'b1;
                out0_re_o    = ch1_out_re[out_ptr_reg+0];
                out0_im_o    = ch1_out_im[out_ptr_reg+0];
                out1_re_o    = ch1_out_re[out_ptr_reg+1];
                out1_im_o    = ch1_out_im[out_ptr_reg+1];

                if (out_ptr_reg == 4'd14)
                    out_last_o = 1'b1;
            end
        end
    end

endmodule


// ============================================================================
// Shared 4-stage pipelined 16-point DIF FFT core
// ============================================================================
module fft16_dif_pipeline_core #(
    parameter int DATA_W = 16,
    parameter int N      = 16
)(
    input  logic                         clk_i,
    input  logic                         resetn_i,
    input  logic                         frame_valid_i,
    input  logic                         frame_tag_i,

    input  logic signed [DATA_W-1:0]     in_re  [0:N-1],
    input  logic signed [DATA_W-1:0]     in_im  [0:N-1],

    output logic                         out_valid_o,
    output logic                         out_tag_o,
    output logic signed [DATA_W-1:0]     out_re [0:N-1],
    output logic signed [DATA_W-1:0]     out_im [0:N-1]
);

    logic signed [DATA_W-1:0] s1_c_re [0:N-1];
    logic signed [DATA_W-1:0] s1_c_im [0:N-1];
    logic signed [DATA_W-1:0] s2_c_re [0:N-1];
    logic signed [DATA_W-1:0] s2_c_im [0:N-1];
    logic signed [DATA_W-1:0] s3_c_re [0:N-1];
    logic signed [DATA_W-1:0] s3_c_im [0:N-1];
    logic signed [DATA_W-1:0] s4_c_re [0:N-1];
    logic signed [DATA_W-1:0] s4_c_im [0:N-1];

    logic signed [DATA_W-1:0] s1_r_re [0:N-1];
    logic signed [DATA_W-1:0] s1_r_im [0:N-1];
    logic signed [DATA_W-1:0] s2_r_re [0:N-1];
    logic signed [DATA_W-1:0] s2_r_im [0:N-1];
    logic signed [DATA_W-1:0] s3_r_re [0:N-1];
    logic signed [DATA_W-1:0] s3_r_im [0:N-1];
    logic signed [DATA_W-1:0] s4_r_re [0:N-1];
    logic signed [DATA_W-1:0] s4_r_im [0:N-1];

    logic vld1_reg, vld2_reg, vld3_reg, vld4_reg;
    logic tag1_reg, tag2_reg, tag3_reg, tag4_reg;

    fft16_dif_stage_scaled #(.DATA_W(DATA_W), .HALF_SPAN(8), .TW_STEP(1)) u_stage1 (
        .in_re  (in_re),
        .in_im  (in_im),
        .out_re (s1_c_re),
        .out_im (s1_c_im)
    );

    fft16_dif_stage_scaled #(.DATA_W(DATA_W), .HALF_SPAN(4), .TW_STEP(2)) u_stage2 (
        .in_re  (s1_r_re),
        .in_im  (s1_r_im),
        .out_re (s2_c_re),
        .out_im (s2_c_im)
    );

    fft16_dif_stage_scaled #(.DATA_W(DATA_W), .HALF_SPAN(2), .TW_STEP(4)) u_stage3 (
        .in_re  (s2_r_re),
        .in_im  (s2_r_im),
        .out_re (s3_c_re),
        .out_im (s3_c_im)
    );

    fft16_dif_stage_scaled #(.DATA_W(DATA_W), .HALF_SPAN(1), .TW_STEP(8)) u_stage4 (
        .in_re  (s3_r_re),
        .in_im  (s3_r_im),
        .out_re (s4_c_re),
        .out_im (s4_c_im)
    );

    always_ff @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            vld1_reg <= 1'b0;
            vld2_reg <= 1'b0;
            vld3_reg <= 1'b0;
            vld4_reg <= 1'b0;
            tag1_reg <= 1'b0;
            tag2_reg <= 1'b0;
            tag3_reg <= 1'b0;
            tag4_reg <= 1'b0;

            for (int k = 0; k < N; k = k + 1) begin
                s1_r_re[k] <= '0; s1_r_im[k] <= '0;
                s2_r_re[k] <= '0; s2_r_im[k] <= '0;
                s3_r_re[k] <= '0; s3_r_im[k] <= '0;
                s4_r_re[k] <= '0; s4_r_im[k] <= '0;
            end
        end
        else begin
            if (frame_valid_i) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s1_r_re[k] <= s1_c_re[k];
                    s1_r_im[k] <= s1_c_im[k];
                end
            end

            if (vld1_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s2_r_re[k] <= s2_c_re[k];
                    s2_r_im[k] <= s2_c_im[k];
                end
            end

            if (vld2_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s3_r_re[k] <= s3_c_re[k];
                    s3_r_im[k] <= s3_c_im[k];
                end
            end

            if (vld3_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s4_r_re[k] <= s4_c_re[k];
                    s4_r_im[k] <= s4_c_im[k];
                end
            end

            vld4_reg <= vld3_reg;
            vld3_reg <= vld2_reg;
            vld2_reg <= vld1_reg;
            vld1_reg <= frame_valid_i;

            tag4_reg <= tag3_reg;
            tag3_reg <= tag2_reg;
            tag2_reg <= tag1_reg;
            tag1_reg <= frame_tag_i;
        end
    end

    assign out_valid_o = vld4_reg;
    assign out_tag_o   = tag4_reg;

    always_comb begin
        for (int k = 0; k < N; k = k + 1) begin
            out_re[k] = s4_r_re[k];
            out_im[k] = s4_r_im[k];
        end
    end

endmodule


// ============================================================================
// One radix-2 DIF stage
// y0 = (u + v)/2
// y1 = ((u - v) * W16^k)/2
// ============================================================================
module fft16_dif_stage_scaled #(
    parameter int DATA_W    = 16,
    parameter int HALF_SPAN = 8,
    parameter int TW_STEP   = 1
)(
    input  logic signed [DATA_W-1:0] in_re  [0:15],
    input  logic signed [DATA_W-1:0] in_im  [0:15],
    output logic signed [DATA_W-1:0] out_re [0:15],
    output logic signed [DATA_W-1:0] out_im [0:15]
);

    logic signed [DATA_W-1:0] u_re, u_im, v_re, v_im;
    logic signed [DATA_W-1:0] d_re, d_im;
    logic signed [DATA_W-1:0] w_re, w_im;
    logic signed [DATA_W-1:0] t_re, t_im;
    logic signed [DATA_W:0]   add_re, add_im;
    integer i0, i1, full_span;

    task automatic get_twiddle16(
        input  int k,
        output logic signed [DATA_W-1:0] re,
        output logic signed [DATA_W-1:0] im
    );
        begin
            case (k & 7)
                0: begin re = 16'sd32767;  im = 16'sd0;      end
                1: begin re = 16'sd30274;  im = -16'sd12540; end
                2: begin re = 16'sd23170;  im = -16'sd23170; end
                3: begin re = 16'sd12540;  im = -16'sd30274; end
                4: begin re = 16'sd0;      im = -16'sd32768; end
                5: begin re = -16'sd12540; im = -16'sd30274; end
                6: begin re = -16'sd23170; im = -16'sd23170; end
                7: begin re = -16'sd30274; im = -16'sd12540; end
                default: begin re = 16'sd32767; im = 16'sd0; end
            endcase
        end
    endtask

    task automatic cmul_q15(
        input  logic signed [DATA_W-1:0] ar,
        input  logic signed [DATA_W-1:0] ai,
        input  logic signed [DATA_W-1:0] br,
        input  logic signed [DATA_W-1:0] bi,
        output logic signed [DATA_W-1:0] yr,
        output logic signed [DATA_W-1:0] yi
    );
        logic signed [2*DATA_W-1:0] p_rr, p_ii, p_ri, p_ir;
        logic signed [2*DATA_W:0]   tmp_re, tmp_im;
        begin
            p_rr  = ar * br;
            p_ii  = ai * bi;
            p_ri  = ar * bi;
            p_ir  = ai * br;

            tmp_re = p_rr - p_ii;
            tmp_im = p_ri + p_ir;

            yr = tmp_re >>> 15;
            yi = tmp_im >>> 15;
        end
    endtask

    always_comb begin
        full_span = 2 * HALF_SPAN;

        for (int idx = 0; idx < 16; idx = idx + 1) begin
            out_re[idx] = in_re[idx];
            out_im[idx] = in_im[idx];
        end

        for (int grp = 0; grp < 16; grp = grp + full_span) begin
            for (int j = 0; j < HALF_SPAN; j = j + 1) begin
                i0 = grp + j;
                i1 = grp + j + HALF_SPAN;

                u_re = in_re[i0];
                u_im = in_im[i0];
                v_re = in_re[i1];
                v_im = in_im[i1];

                add_re = u_re + v_re;
                add_im = u_im + v_im;

                d_re = u_re - v_re;
                d_im = u_im - v_im;

                get_twiddle16(j * TW_STEP, w_re, w_im);
                cmul_q15(d_re, d_im, w_re, w_im, t_re, t_im);

                out_re[i0] = add_re >>> 1;
                out_im[i0] = add_im >>> 1;
                out_re[i1] = t_re >>> 1;
                out_im[i1] = t_im >>> 1;
            end
        end
    end

endmodule

