`timescale 1ns/1ps

module bf2_dif #(
    parameter int DATA_W = 16,
    parameter int FRAC_W = 15
)(
    input  logic signed [DATA_W-1:0] xr,
    input  logic signed [DATA_W-1:0] xi,
    input  logic signed [DATA_W-1:0] yr,
    input  logic signed [DATA_W-1:0] yi,

    input  logic signed [DATA_W-1:0] wr,
    input  logic signed [DATA_W-1:0] wi,

    output logic signed [DATA_W-1:0] outr,
    output logic signed [DATA_W-1:0] outi,
    output logic signed [DATA_W-1:0] diffr,
    output logic signed [DATA_W-1:0] diffi
);

    logic signed [DATA_W:0] sum_r, sum_i;
    logic signed [DATA_W:0] diff_r, diff_i;

    logic signed [DATA_W-1:0] diff_r_q, diff_i_q;

    always_comb begin
        sum_r = xr + yr;
        sum_i = xi + yi;

        diff_r = xr - yr;
        diff_i = xi - yi;

        outr = sum_r[DATA_W-1:0];
        outi = sum_i[DATA_W-1:0];

        diff_r_q = diff_r[DATA_W-1:0];
        diff_i_q = diff_i[DATA_W-1:0];
    end

    complex_mult_q #(
        .DATA_W(DATA_W),
        .FRAC_W(FRAC_W)
    ) u_cmul (
        .ar(diff_r_q),
        .ai(diff_i_q),
        .br(wr),
        .bi(wi),
        .pr(diffr),
        .pi(diffi)
    );

endmodule
