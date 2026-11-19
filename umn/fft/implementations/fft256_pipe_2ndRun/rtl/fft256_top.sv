`timescale 1ns/1ps

module fft256_top #(
    parameter int DATA_W = 16,
    parameter int N      = 256,
    parameter int FRAC_W = 15
)(
    input  logic clk_i,
    input  logic resetn_i,

    input  logic frame_start_i,
    input  logic in_valid_i,
    input  logic in_ch_sel_i,

    input  logic signed [DATA_W-1:0] in0_re_i,
    input  logic signed [DATA_W-1:0] in0_im_i,
    input  logic signed [DATA_W-1:0] in1_re_i,
    input  logic signed [DATA_W-1:0] in1_im_i,

    output logic out_valid_o,
    output logic out_ch_sel_o,
    output logic out_last_o,
    output logic [7:0] out_idx0_o,
    output logic [7:0] out_idx1_o,

    output logic signed [DATA_W-1:0] out0_re_o,
    output logic signed [DATA_W-1:0] out0_im_o,
    output logic signed [DATA_W-1:0] out1_re_o,
    output logic signed [DATA_W-1:0] out1_im_o
);

    typedef enum logic [2:0] {
        S_IDLE    = 3'd0,
        S_LOAD    = 3'd1,
        S_START0  = 3'd2,
        S_WAIT0   = 3'd3,
        S_START1  = 3'd4,
        S_WAIT1   = 3'd5,
        S_OUT_ALT = 3'd6
    } state_t;

    state_t state_reg;
    state_t state_next;

    logic [8:0] load_cnt_ch0_reg;
    logic [8:0] load_cnt_ch1_reg;

    logic [7:0] out_ptr_reg;
    logic       out_phase_reg;

    logic signed [DATA_W-1:0] ch0_in_re  [0:N-1];
    logic signed [DATA_W-1:0] ch0_in_im  [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_re  [0:N-1];
    logic signed [DATA_W-1:0] ch1_in_im  [0:N-1];

    logic signed [DATA_W-1:0] ch0_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch0_out_im [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_re [0:N-1];
    logic signed [DATA_W-1:0] ch1_out_im [0:N-1];

    logic core_start;
    logic core_done;

    logic signed [DATA_W-1:0] core_in_re  [0:N-1];
    logic signed [DATA_W-1:0] core_in_im  [0:N-1];
    logic signed [DATA_W-1:0] core_out_re [0:N-1];
    logic signed [DATA_W-1:0] core_out_im [0:N-1];

    logic out_valid_c;
    logic out_ch_sel_c;
    logic out_last_c;
    logic [7:0] out_idx0_c;
    logic [7:0] out_idx1_c;

    logic signed [DATA_W-1:0] out0_re_c;
    logic signed [DATA_W-1:0] out0_im_c;
    logic signed [DATA_W-1:0] out1_re_c;
    logic signed [DATA_W-1:0] out1_im_c;

    fft256_core #(
        .DATA_W(DATA_W),
        .N(N),
        .FRAC_W(FRAC_W)
    ) u_core (
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .start_i(core_start),
        .in_re(core_in_re),
        .in_im(core_in_im),
        .done_o(core_done),
        .out_re(core_out_re),
        .out_im(core_out_im)
    );

    always_comb begin
        for (int k = 0; k < N; k++) begin
            if (state_reg == S_START1) begin
                core_in_re[k] = ch1_in_re[k];
                core_in_im[k] = ch1_in_im[k];
            end
            else begin
                core_in_re[k] = ch0_in_re[k];
                core_in_im[k] = ch0_in_im[k];
            end
        end
    end

    assign core_start = (state_reg == S_START0) || (state_reg == S_START1);

    always_comb begin
        state_next = state_reg;

        case (state_reg)
            S_IDLE: begin
                if (frame_start_i && in_valid_i)
                    state_next = S_LOAD;
            end

            S_LOAD: begin
                if ((load_cnt_ch0_reg == N) && (load_cnt_ch1_reg == N))
                    state_next = S_START0;
            end

            S_START0: begin
                state_next = S_WAIT0;
            end

            S_WAIT0: begin
                if (core_done)
                    state_next = S_START1;
            end

            S_START1: begin
                state_next = S_WAIT1;
            end

            S_WAIT1: begin
                if (core_done)
                    state_next = S_OUT_ALT;
            end

            S_OUT_ALT: begin
                if ((out_ptr_reg == 8'd254) && (out_phase_reg == 1'b1))
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

            out_valid_o  <= 1'b0;
            out_ch_sel_o <= 1'b0;
            out_last_o   <= 1'b0;
            out_idx0_o   <= '0;
            out_idx1_o   <= '0;
            out0_re_o    <= '0;
            out0_im_o    <= '0;
            out1_re_o    <= '0;
            out1_im_o    <= '0;

            for (int k = 0; k < N; k++) begin
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

            out_valid_o  <= out_valid_c;
            out_ch_sel_o <= out_ch_sel_c;
            out_last_o   <= out_last_c;
            out_idx0_o   <= out_idx0_c;
            out_idx1_o   <= out_idx1_c;
            out0_re_o    <= out0_re_c;
            out0_im_o    <= out0_im_c;
            out1_re_o    <= out1_re_c;
            out1_im_o    <= out1_im_c;

            case (state_reg)
                S_IDLE: begin
                    load_cnt_ch0_reg <= '0;
                    load_cnt_ch1_reg <= '0;
                    out_ptr_reg      <= '0;
                    out_phase_reg    <= 1'b0;

                    if (frame_start_i && in_valid_i) begin
                        if (in_ch_sel_i == 1'b0) begin
                            ch0_in_re[0] <= in0_re_i;
                            ch0_in_im[0] <= in0_im_i;
                            ch0_in_re[1] <= in1_re_i;
                            ch0_in_im[1] <= in1_im_i;
                            load_cnt_ch0_reg <= 9'd2;
                        end
                        else begin
                            ch1_in_re[0] <= in0_re_i;
                            ch1_in_im[0] <= in0_im_i;
                            ch1_in_re[1] <= in1_re_i;
                            ch1_in_im[1] <= in1_im_i;
                            load_cnt_ch1_reg <= 9'd2;
                        end
                    end
                end

                S_LOAD: begin
                    if (in_valid_i) begin
                        if ((in_ch_sel_i == 1'b0) && (load_cnt_ch0_reg < N)) begin
                            ch0_in_re[load_cnt_ch0_reg + 0] <= in0_re_i;
                            ch0_in_im[load_cnt_ch0_reg + 0] <= in0_im_i;
                            ch0_in_re[load_cnt_ch0_reg + 1] <= in1_re_i;
                            ch0_in_im[load_cnt_ch0_reg + 1] <= in1_im_i;
                            load_cnt_ch0_reg <= load_cnt_ch0_reg + 9'd2;
                        end
                        else if ((in_ch_sel_i == 1'b1) && (load_cnt_ch1_reg < N)) begin
                            ch1_in_re[load_cnt_ch1_reg + 0] <= in0_re_i;
                            ch1_in_im[load_cnt_ch1_reg + 0] <= in0_im_i;
                            ch1_in_re[load_cnt_ch1_reg + 1] <= in1_re_i;
                            ch1_in_im[load_cnt_ch1_reg + 1] <= in1_im_i;
                            load_cnt_ch1_reg <= load_cnt_ch1_reg + 9'd2;
                        end
                    end
                end

                S_WAIT0: begin
                    if (core_done) begin
                        for (int k = 0; k < N; k++) begin
                            ch0_out_re[k] <= core_out_re[k];
                            ch0_out_im[k] <= core_out_im[k];
                        end
                    end
                end

                S_WAIT1: begin
                    if (core_done) begin
                        for (int k = 0; k < N; k++) begin
                            ch1_out_re[k] <= core_out_re[k];
                            ch1_out_im[k] <= core_out_im[k];
                        end
                    end
                end

                S_OUT_ALT: begin
                    if (out_phase_reg == 1'b0) begin
                        out_phase_reg <= 1'b1;
                    end
                    else begin
                        out_phase_reg <= 1'b0;
                        if (out_ptr_reg != 8'd254)
                            out_ptr_reg <= out_ptr_reg + 8'd2;
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
        out_valid_c  = 1'b0;
        out_ch_sel_c = 1'b0;
        out_last_c   = 1'b0;

        out_idx0_c = '0;
        out_idx1_c = '0;

        out0_re_c = '0;
        out0_im_c = '0;
        out1_re_c = '0;
        out1_im_c = '0;

        if (state_reg == S_OUT_ALT) begin
            out_valid_c = 1'b1;

            out_idx0_c = out_ptr_reg;
            out_idx1_c = out_ptr_reg + 8'd1;

            if (out_phase_reg == 1'b0) begin
                out_ch_sel_c = 1'b0;

                out0_re_c = ch0_out_re[out_ptr_reg + 0];
                out0_im_c = ch0_out_im[out_ptr_reg + 0];
                out1_re_c = ch0_out_re[out_ptr_reg + 1];
                out1_im_c = ch0_out_im[out_ptr_reg + 1];
            end
            else begin
                out_ch_sel_c = 1'b1;

                out0_re_c = ch1_out_re[out_ptr_reg + 0];
                out0_im_c = ch1_out_im[out_ptr_reg + 0];
                out1_re_c = ch1_out_re[out_ptr_reg + 1];
                out1_im_c = ch1_out_im[out_ptr_reg + 1];

                if (out_ptr_reg == 8'd254)
                    out_last_c = 1'b1;
            end
        end
    end

endmodule
