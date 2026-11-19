`timescale 1ns/1ps

module fft256_core #(
    parameter int DATA_W = 16,
    parameter int N      = 256
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

    logic signed [DATA_W-1:0] s1_c_re [0:N-1], s1_c_im [0:N-1];
    logic signed [DATA_W-1:0] s2_c_re [0:N-1], s2_c_im [0:N-1];
    logic signed [DATA_W-1:0] s3_c_re [0:N-1], s3_c_im [0:N-1];
    logic signed [DATA_W-1:0] s4_c_re [0:N-1], s4_c_im [0:N-1];
    logic signed [DATA_W-1:0] s5_c_re [0:N-1], s5_c_im [0:N-1];
    logic signed [DATA_W-1:0] s6_c_re [0:N-1], s6_c_im [0:N-1];
    logic signed [DATA_W-1:0] s7_c_re [0:N-1], s7_c_im [0:N-1];
    logic signed [DATA_W-1:0] s8_c_re [0:N-1], s8_c_im [0:N-1];

    logic signed [DATA_W-1:0] s1_r_re [0:N-1], s1_r_im [0:N-1];
    logic signed [DATA_W-1:0] s2_r_re [0:N-1], s2_r_im [0:N-1];
    logic signed [DATA_W-1:0] s3_r_re [0:N-1], s3_r_im [0:N-1];
    logic signed [DATA_W-1:0] s4_r_re [0:N-1], s4_r_im [0:N-1];
    logic signed [DATA_W-1:0] s5_r_re [0:N-1], s5_r_im [0:N-1];
    logic signed [DATA_W-1:0] s6_r_re [0:N-1], s6_r_im [0:N-1];
    logic signed [DATA_W-1:0] s7_r_re [0:N-1], s7_r_im [0:N-1];
    logic signed [DATA_W-1:0] s8_r_re [0:N-1], s8_r_im [0:N-1];

    logic vld1_reg, vld2_reg, vld3_reg, vld4_reg;
    logic vld5_reg, vld6_reg, vld7_reg, vld8_reg;

    logic tag1_reg, tag2_reg, tag3_reg, tag4_reg;
    logic tag5_reg, tag6_reg, tag7_reg, tag8_reg;

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(128), .TW_STEP(1)) u_stage1 (
        .in_re(in_re), .in_im(in_im), .out_re(s1_c_re), .out_im(s1_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(64), .TW_STEP(2)) u_stage2 (
        .in_re(s1_r_re), .in_im(s1_r_im), .out_re(s2_c_re), .out_im(s2_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(32), .TW_STEP(4)) u_stage3 (
        .in_re(s2_r_re), .in_im(s2_r_im), .out_re(s3_c_re), .out_im(s3_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(16), .TW_STEP(8)) u_stage4 (
        .in_re(s3_r_re), .in_im(s3_r_im), .out_re(s4_c_re), .out_im(s4_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(8), .TW_STEP(16)) u_stage5 (
        .in_re(s4_r_re), .in_im(s4_r_im), .out_re(s5_c_re), .out_im(s5_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(4), .TW_STEP(32)) u_stage6 (
        .in_re(s5_r_re), .in_im(s5_r_im), .out_re(s6_c_re), .out_im(s6_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(2), .TW_STEP(64)) u_stage7 (
        .in_re(s6_r_re), .in_im(s6_r_im), .out_re(s7_c_re), .out_im(s7_c_im)
    );

    fft_stage_scaled #(.DATA_W(DATA_W), .N(N), .HALF_SPAN(1), .TW_STEP(128)) u_stage8 (
        .in_re(s7_r_re), .in_im(s7_r_im), .out_re(s8_c_re), .out_im(s8_c_im)
    );

    always_ff @(posedge clk_i or negedge resetn_i) begin
        if (!resetn_i) begin
            vld1_reg <= 1'b0; vld2_reg <= 1'b0; vld3_reg <= 1'b0; vld4_reg <= 1'b0;
            vld5_reg <= 1'b0; vld6_reg <= 1'b0; vld7_reg <= 1'b0; vld8_reg <= 1'b0;

            tag1_reg <= 1'b0; tag2_reg <= 1'b0; tag3_reg <= 1'b0; tag4_reg <= 1'b0;
            tag5_reg <= 1'b0; tag6_reg <= 1'b0; tag7_reg <= 1'b0; tag8_reg <= 1'b0;

            for (int k = 0; k < N; k = k + 1) begin
                s1_r_re[k] <= '0; s1_r_im[k] <= '0;
                s2_r_re[k] <= '0; s2_r_im[k] <= '0;
                s3_r_re[k] <= '0; s3_r_im[k] <= '0;
                s4_r_re[k] <= '0; s4_r_im[k] <= '0;
                s5_r_re[k] <= '0; s5_r_im[k] <= '0;
                s6_r_re[k] <= '0; s6_r_im[k] <= '0;
                s7_r_re[k] <= '0; s7_r_im[k] <= '0;
                s8_r_re[k] <= '0; s8_r_im[k] <= '0;
            end
        end else begin
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

            if (vld4_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s5_r_re[k] <= s5_c_re[k];
                    s5_r_im[k] <= s5_c_im[k];
                end
            end

            if (vld5_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s6_r_re[k] <= s6_c_re[k];
                    s6_r_im[k] <= s6_c_im[k];
                end
            end

            if (vld6_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s7_r_re[k] <= s7_c_re[k];
                    s7_r_im[k] <= s7_c_im[k];
                end
            end

            if (vld7_reg) begin
                for (int k = 0; k < N; k = k + 1) begin
                    s8_r_re[k] <= s8_c_re[k];
                    s8_r_im[k] <= s8_c_im[k];
                end
            end

            vld8_reg <= vld7_reg;
            vld7_reg <= vld6_reg;
            vld6_reg <= vld5_reg;
            vld5_reg <= vld4_reg;
            vld4_reg <= vld3_reg;
            vld3_reg <= vld2_reg;
            vld2_reg <= vld1_reg;
            vld1_reg <= frame_valid_i;

            tag8_reg <= tag7_reg;
            tag7_reg <= tag6_reg;
            tag6_reg <= tag5_reg;
            tag5_reg <= tag4_reg;
            tag4_reg <= tag3_reg;
            tag3_reg <= tag2_reg;
            tag2_reg <= tag1_reg;
            tag1_reg <= frame_tag_i;
        end
    end

    assign out_valid_o = vld8_reg;
    assign out_tag_o   = tag8_reg;

    always_comb begin
        for (int k = 0; k < N; k = k + 1) begin
            out_re[k] = s8_r_re[k];
            out_im[k] = s8_r_im[k];
        end
    end

endmodule
