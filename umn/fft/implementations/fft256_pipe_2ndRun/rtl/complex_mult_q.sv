`timescale 1ns/1ps

module complex_mult_q #(
    parameter int DATA_W = 16,
    parameter int FRAC_W = 15
)(
    input  logic signed [DATA_W-1:0] ar,
    input  logic signed [DATA_W-1:0] ai,
    input  logic signed [DATA_W-1:0] br,
    input  logic signed [DATA_W-1:0] bi,
    output logic signed [DATA_W-1:0] pr,
    output logic signed [DATA_W-1:0] pi
);

    logic signed [2*DATA_W-1:0] mult_rr, mult_ii, mult_ri, mult_ir;
    logic signed [2*DATA_W:0]   tmp_r, tmp_i;

    always_comb begin
        mult_rr = ar * br;
        mult_ii = ai * bi;
        mult_ri = ar * bi;
        mult_ir = ai * br;

        tmp_r = mult_rr - mult_ii;
        tmp_i = mult_ri + mult_ir;

        pr = tmp_r >>> FRAC_W;
        pi = tmp_i >>> FRAC_W;
    end

endmodule
