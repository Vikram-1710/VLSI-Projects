`timescale 1ns/1ps

module fft256_core #(
    parameter int DATA_W = 16,
    parameter int N      = 256,
    parameter int FRAC_W = 15
)(
    input  logic clk_i,
    input  logic resetn_i,

    input  logic start_i,
    input  logic signed [DATA_W-1:0] in_re [0:N-1],
    input  logic signed [DATA_W-1:0] in_im [0:N-1],

    output logic done_o,
    output logic signed [DATA_W-1:0] out_re [0:N-1],
    output logic signed [DATA_W-1:0] out_im [0:N-1]
);

    typedef enum logic [1:0] {
        C_IDLE  = 2'd0,
        C_RUN   = 2'd1,
        C_DRAIN = 2'd2,
        C_DONE  = 2'd3
    } core_state_t;

    core_state_t state_reg;

    logic signed [DATA_W-1:0] mem_re [0:N-1];
    logic signed [DATA_W-1:0] mem_im [0:N-1];

    logic [3:0] stage_reg;
    logic [7:0] bfly_cnt_reg;

    integer half_span;
    integer tw_step;
    integer j_idx;
    integer grp_idx;
    integer i0_idx;
    integer i1_idx;

    logic [7:0] issue_i0;
    logic [7:0] issue_i1;
    logic [7:0] issue_tw_addr;

    logic [8:0] rom_addr;
    logic signed [DATA_W-1:0] wr;
    logic signed [DATA_W-1:0] wi;

    twiddle_rom_512 #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_twiddle (
        .addr(rom_addr),
        .wr(wr),
        .wi(wi)
    );

    always_comb begin
        half_span = 128 >> stage_reg;
        tw_step   = 1 << stage_reg;

        j_idx   = bfly_cnt_reg % half_span;
        grp_idx = (bfly_cnt_reg / half_span) * (2 * half_span);

        i0_idx = grp_idx + j_idx;
        i1_idx = i0_idx + half_span;

        issue_i0      = i0_idx[7:0];
        issue_i1      = i1_idx[7:0];
        issue_tw_addr = (j_idx * tw_step) & 8'hFF;
    end

    logic pa_valid;
    logic [7:0] pa_i0, pa_i1, pa_tw_addr;

    logic p0_valid;
    logic [7:0] p0_i0, p0_i1;
    logic signed [DATA_W-1:0] p0_xr, p0_xi, p0_yr, p0_yi;
    logic signed [DATA_W-1:0] p0_wr, p0_wi;

    logic p1_valid;
    logic [7:0] p1_i0, p1_i1;
    logic signed [DATA_W-1:0] p1_sum_r, p1_sum_i;
    logic signed [DATA_W-1:0] p1_diff_r, p1_diff_i;
    logic signed [DATA_W-1:0] p1_wr, p1_wi;

    logic p2_valid;
    logic [7:0] p2_i0, p2_i1;
    logic signed [DATA_W-1:0] p2_sum_r, p2_sum_i;
    logic signed [2*DATA_W-1:0] p2_rr, p2_ii, p2_ri, p2_ir;

    logic p3_valid;
    logic [7:0] p3_i0, p3_i1;
    logic signed [DATA_W-1:0] p3_sum_r, p3_sum_i;
    logic signed [DATA_W-1:0] p3_mult_r, p3_mult_i;

    logic signed [DATA_W-1:0] p1_sum_raw_r;
    logic signed [DATA_W-1:0] p1_sum_raw_i;
    logic signed [DATA_W-1:0] p1_diff_raw_r;
    logic signed [DATA_W-1:0] p1_diff_raw_i;

    logic signed [2*DATA_W:0] p3_tmp_r;
    logic signed [2*DATA_W:0] p3_tmp_i;

    assign rom_addr = {pa_tw_addr, 1'b0};

    always_comb begin
        p1_sum_raw_r  = p0_xr + p0_yr;
        p1_sum_raw_i  = p0_xi + p0_yi;
        p1_diff_raw_r = p0_xr - p0_yr;
        p1_diff_raw_i = p0_xi - p0_yi;

        p3_tmp_r = p2_rr - p2_ii;
        p3_tmp_i = p2_ri + p2_ir;
    end

    always_ff @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            state_reg    <= C_IDLE;
            stage_reg    <= 4'd0;
            bfly_cnt_reg <= 8'd0;

            pa_valid <= 1'b0;
            p0_valid <= 1'b0;
            p1_valid <= 1'b0;
            p2_valid <= 1'b0;
            p3_valid <= 1'b0;

            pa_i0 <= '0; pa_i1 <= '0; pa_tw_addr <= '0;
            p0_i0 <= '0; p0_i1 <= '0;
            p1_i0 <= '0; p1_i1 <= '0;
            p2_i0 <= '0; p2_i1 <= '0;
            p3_i0 <= '0; p3_i1 <= '0;

            p0_xr <= '0; p0_xi <= '0; p0_yr <= '0; p0_yi <= '0;
            p0_wr <= '0; p0_wi <= '0;

            p1_sum_r  <= '0;
            p1_sum_i  <= '0;
            p1_diff_r <= '0;
            p1_diff_i <= '0;
            p1_wr     <= '0;
            p1_wi     <= '0;

            p2_sum_r <= '0;
            p2_sum_i <= '0;
            p2_rr    <= '0;
            p2_ii    <= '0;
            p2_ri    <= '0;
            p2_ir    <= '0;

            p3_sum_r  <= '0;
            p3_sum_i  <= '0;
            p3_mult_r <= '0;
            p3_mult_i <= '0;

            for (int k = 0; k < N; k++) begin
                mem_re[k] <= '0;
                mem_im[k] <= '0;
            end
        end
        else begin

            if (p3_valid) begin
                mem_re[p3_i0] <= p3_sum_r;
                mem_im[p3_i0] <= p3_sum_i;

                mem_re[p3_i1] <= p3_mult_r >>> 1;
                mem_im[p3_i1] <= p3_mult_i >>> 1;
            end

            p3_valid  <= p2_valid;
            p3_i0     <= p2_i0;
            p3_i1     <= p2_i1;
            p3_sum_r  <= p2_sum_r;
            p3_sum_i  <= p2_sum_i;
            p3_mult_r <= p3_tmp_r >>> FRAC_W;
            p3_mult_i <= p3_tmp_i >>> FRAC_W;

            p2_valid <= p1_valid;
            p2_i0    <= p1_i0;
            p2_i1    <= p1_i1;
            p2_sum_r <= p1_sum_r;
            p2_sum_i <= p1_sum_i;

            p2_rr <= p1_diff_r * p1_wr;
            p2_ii <= p1_diff_i * p1_wi;
            p2_ri <= p1_diff_r * p1_wi;
            p2_ir <= p1_diff_i * p1_wr;

            p1_valid  <= p0_valid;
            p1_i0     <= p0_i0;
            p1_i1     <= p0_i1;

            p1_sum_r  <= p1_sum_raw_r >>> 1;
            p1_sum_i  <= p1_sum_raw_i >>> 1;
            p1_diff_r <= p1_diff_raw_r;
            p1_diff_i <= p1_diff_raw_i;
            p1_wr     <= p0_wr;
            p1_wi     <= p0_wi;

            p0_valid <= pa_valid;
            p0_i0    <= pa_i0;
            p0_i1    <= pa_i1;

            p0_xr <= mem_re[pa_i0];
            p0_xi <= mem_im[pa_i0];
            p0_yr <= mem_re[pa_i1];
            p0_yi <= mem_im[pa_i1];

            p0_wr <= wr;
            p0_wi <= wi;

            pa_valid   <= 1'b0;
            pa_i0      <= '0;
            pa_i1      <= '0;
            pa_tw_addr <= '0;

            case (state_reg)

                C_IDLE: begin
                    stage_reg    <= 4'd0;
                    bfly_cnt_reg <= 8'd0;

                    pa_valid <= 1'b0;
                    p0_valid <= 1'b0;
                    p1_valid <= 1'b0;
                    p2_valid <= 1'b0;
                    p3_valid <= 1'b0;

                    if (start_i) begin
                        for (int k = 0; k < N; k++) begin
                            mem_re[k] <= in_re[k];
                            mem_im[k] <= in_im[k];
                        end

                        stage_reg    <= 4'd0;
                        bfly_cnt_reg <= 8'd0;
                        state_reg    <= C_RUN;
                    end
                end

                C_RUN: begin
                    pa_valid   <= 1'b1;
                    pa_i0      <= issue_i0;
                    pa_i1      <= issue_i1;
                    pa_tw_addr <= issue_tw_addr;

                    if (bfly_cnt_reg == 8'd127) begin
                        bfly_cnt_reg <= 8'd0;
                        state_reg    <= C_DRAIN;
                    end
                    else begin
                        bfly_cnt_reg <= bfly_cnt_reg + 8'd1;
                    end
                end

                C_DRAIN: begin
                    if (!pa_valid && !p0_valid && !p1_valid && !p2_valid && !p3_valid) begin
                        if (stage_reg == 4'd7) begin
                            state_reg <= C_DONE;
                        end
                        else begin
                            stage_reg    <= stage_reg + 4'd1;
                            bfly_cnt_reg <= 8'd0;
                            state_reg    <= C_RUN;
                        end
                    end
                end

                C_DONE: begin
                    if (start_i) begin
                        for (int k = 0; k < N; k++) begin
                            mem_re[k] <= in_re[k];
                            mem_im[k] <= in_im[k];
                        end

                        stage_reg    <= 4'd0;
                        bfly_cnt_reg <= 8'd0;

                        pa_valid <= 1'b0;
                        p0_valid <= 1'b0;
                        p1_valid <= 1'b0;
                        p2_valid <= 1'b0;
                        p3_valid <= 1'b0;

                        state_reg <= C_RUN;
                    end
                    else begin
                        state_reg <= C_IDLE;
                    end
                end

                default: begin
                    state_reg <= C_IDLE;
                end

            endcase
        end
    end

    assign done_o = (state_reg == C_DONE);

    always_comb begin
        for (int k = 0; k < N; k++) begin
            out_re[k] = mem_re[k];
            out_im[k] = mem_im[k];
        end
    end

endmodule
