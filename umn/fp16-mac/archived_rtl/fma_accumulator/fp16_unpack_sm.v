//=====================================================
// fp16_unpack_sm
// Unpack IEEE-754 FP16 into sign, unbiased exponent, and 11-bit significand.
// - Normal numbers: sig = {1'b1, frac}, exp_unb = E - 15
// - Others (zero, subnormal, inf, nan) => treated as zero for v1
//=====================================================
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

    assign sign   = s;
    assign exp_unb = normal ? ( {1'b0, e} - 6'd15 ) : 6'd0;
    assign sig_11  = normal ? {1'b1, f}             : 11'd0;
    assign is_zero = (normal == 1'b0) || (f == 10'd0 && e == 5'd0);

endmodule
