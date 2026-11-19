`timescale 1ns/1ps

module fft256_top #(
    parameter int DATA_W = 16,
    parameter int N      = 256,
    parameter int IDX_W  = 8
)(
    input  logic                         clk_i,
    input  logic                         resetn_i,

    input  logic                         frame_start_i,
    input  logic                         in_valid_i,
    input  logic                         in_ch_sel_i,

    input  logic signed [DATA_W-1:0]     in0_re_i,
    input  logic signed [DATA_W-1:0]     in0_im_i,
    input  logic signed [DATA_W-1:0]     in1_re_i,
    input  logic signed [DATA_W-1:0]     in1_im_i,

    output logic                         out_valid_o,
    output logic                         out_ch_sel_o,
    output logic                         out_last_o,

    output logic        [IDX_W-1:0]      out_idx0_o,
    output logic        [IDX_W-1:0]      out_idx1_o,

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

    logic [IDX_W:0]     load_cnt_ch0_reg;
    logic [IDX_W:0]     load_cnt_ch1_reg;
    logic [IDX_W-1:0]   out_ptr_reg;
    logic               out_phase_reg;

    logic               got_ch0_reg;
    logic               got_ch1_reg;

    logic signed [DATA_W-1:0] ch0_in_re  [0:N-1];
    logic signed [DATA_W-1:0] ch0_in_im  [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_re  [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_im  [0:N-1];

    logic signed [DATA_W-1:0] ch0_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch0_out_im [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_im [0:N-1];

    logic                         core_frame_valid;
    logic                         core_frame_tag;

    logic signed [DATA_W-1:0]     core_in_re  [0:N-1];
    logic signed [DATA_W-1:0]     core_in_im  [0:N-1];

    logic                         core_out_valid;
    logic                         core_out_tag;

    logic signed [DATA_W-1:0]     core_out_re [0:N-1];
    logic signed [DATA_W-1:0]     core_out_im [0:N-1];

    fft256_core #(
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
        end else if (state_reg == S_FEED_CH1) begin
            core_frame_valid = 1'b1;
            core_frame_tag   = 1'b1;

            for (int k = 0; k < N; k = k + 1) begin
                core_in_re[k] = ch1_in_re[k];
                core_in_im[k] = ch1_in_im[k];
            end
        end
    end

    always_comb begin
        state_next = state_reg;

        unique case (state_reg)
            S_IDLE: begin
                if (frame_start_i && in_valid_i)
                    state_next = S_LOAD;
            end

            S_LOAD: begin
                if ((load_cnt_ch0_reg == N[IDX_W:0]) &&
                    (load_cnt_ch1_reg == N[IDX_W:0]))
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
                if ((out_ptr_reg == IDX_W'(N-2)) && (out_phase_reg == 1'b1))
                    state_next = S_IDLE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            state_reg        <= S_IDLE;
            load_cnt_ch0_reg <= '0;
            load_cnt_ch1_reg <= '0;
            out_ptr_reg      <= '0;
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
        end else begin
            state_reg <= state_next;

            if (core_out_valid) begin
                if (core_out_tag == 1'b0) begin
                    for (int k = 0; k < N; k = k + 1) begin
                        ch0_out_re[k] <= core_out_re[k];
                        ch0_out_im[k] <= core_out_im[k];
                    end
                    got_ch0_reg <= 1'b1;
                end else begin
                    for (int k = 0; k < N; k = k + 1) begin
                        ch1_out_re[k] <= core_out_re[k];
                        ch1_out_im[k] <= core_out_im[k];
                    end
                    got_ch1_reg <= 1'b1;
                end
            end

            unique case (state_reg)
                S_IDLE: begin
                    load_cnt_ch0_reg <= '0;
                    load_cnt_ch1_reg <= '0;
                    out_ptr_reg      <= '0;
                    out_phase_reg    <= 1'b0;
                    got_ch0_reg      <= 1'b0;
                    got_ch1_reg      <= 1'b0;

                    if (frame_start_i && in_valid_i) begin
                        if (in_ch_sel_i == 1'b0) begin
                            ch0_in_re[0] <= in0_re_i;
                            ch0_in_im[0] <= in0_im_i;
                            ch0_in_re[1] <= in1_re_i;
                            ch0_in_im[1] <= in1_im_i;
                            load_cnt_ch0_reg <= 2;
                        end else begin
                            ch1_in_re[0] <= in0_re_i;
                            ch1_in_im[0] <= in0_im_i;
                            ch1_in_re[1] <= in1_re_i;
                            ch1_in_im[1] <= in1_im_i;
                            load_cnt_ch1_reg <= 2;
                        end
                    end
                end

                S_LOAD: begin
                    if (in_valid_i) begin
                        if ((in_ch_sel_i == 1'b0) && (load_cnt_ch0_reg < N[IDX_W:0])) begin
                            ch0_in_re[load_cnt_ch0_reg + 0] <= in0_re_i;
                            ch0_in_im[load_cnt_ch0_reg + 0] <= in0_im_i;
                            ch0_in_re[load_cnt_ch0_reg + 1] <= in1_re_i;
                            ch0_in_im[load_cnt_ch0_reg + 1] <= in1_im_i;
                            load_cnt_ch0_reg <= load_cnt_ch0_reg + 2;
                        end else if ((in_ch_sel_i == 1'b1) && (load_cnt_ch1_reg < N[IDX_W:0])) begin
                            ch1_in_re[load_cnt_ch1_reg + 0] <= in0_re_i;
                            ch1_in_im[load_cnt_ch1_reg + 0] <= in0_im_i;
                            ch1_in_re[load_cnt_ch1_reg + 1] <= in1_re_i;
                            ch1_in_im[load_cnt_ch1_reg + 1] <= in1_im_i;
                            load_cnt_ch1_reg <= load_cnt_ch1_reg + 2;
                        end
                    end
                end

                S_WAIT: begin
                    out_ptr_reg   <= '0;
                    out_phase_reg <= 1'b0;
                end

                S_OUT_ALT: begin
                    if (out_phase_reg == 1'b0) begin
                        out_phase_reg <= 1'b1;
                    end else begin
                        out_phase_reg <= 1'b0;

                        if (out_ptr_reg != IDX_W'(N-2))
                            out_ptr_reg <= out_ptr_reg + 2;
                        else
                            out_ptr_reg <= '0;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    always_comb begin
        out_valid_o  = 1'b0;
        out_ch_sel_o = 1'b0;
        out_last_o   = 1'b0;

        out_idx0_o = '0;
        out_idx1_o = 1;

        out0_re_o = '0;
        out0_im_o = '0;
        out1_re_o = '0;
        out1_im_o = '0;

        if (state_reg == S_OUT_ALT) begin
            out_valid_o = 1'b1;

            out_idx0_o = out_ptr_reg;
            out_idx1_o = out_ptr_reg + 1;

            if (out_phase_reg == 1'b0) begin
                out_ch_sel_o = 1'b0;

                out0_re_o = ch0_out_re[out_ptr_reg + 0];
                out0_im_o = ch0_out_im[out_ptr_reg + 0];
                out1_re_o = ch0_out_re[out_ptr_reg + 1];
                out1_im_o = ch0_out_im[out_ptr_reg + 1];
            end else begin
                out_ch_sel_o = 1'b1;

                out0_re_o = ch1_out_re[out_ptr_reg + 0];
                out0_im_o = ch1_out_im[out_ptr_reg + 0];
                out1_re_o = ch1_out_re[out_ptr_reg + 1];
                out1_im_o = ch1_out_im[out_ptr_reg + 1];

                if (out_ptr_reg == IDX_W'(N-2))
                    out_last_o = 1'b1;
            end
        end
    end

endmodule
