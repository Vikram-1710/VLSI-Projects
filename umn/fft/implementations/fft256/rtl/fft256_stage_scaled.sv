`timescale 1ns/1ps

module fft_stage_scaled #(
    parameter int DATA_W    = 16,
    parameter int N         = 256,
    parameter int HALF_SPAN = 128,
    parameter int TW_STEP   = 1
)(
    input  logic signed [DATA_W-1:0] in_re  [0:N-1],
    input  logic signed [DATA_W-1:0] in_im  [0:N-1],
    output logic signed [DATA_W-1:0] out_re [0:N-1],
    output logic signed [DATA_W-1:0] out_im [0:N-1]
);

    logic signed [DATA_W-1:0] u_re, u_im;
    logic signed [DATA_W-1:0] v_re, v_im;
    logic signed [DATA_W-1:0] d_re, d_im;
    logic signed [DATA_W-1:0] w_re, w_im;
    logic signed [DATA_W-1:0] t_re, t_im;

    logic signed [DATA_W:0] add_re, add_im;

    integer i0;
    integer i1;
    integer full_span;

    task automatic get_twiddle256(
        input  int k,
        output logic signed [DATA_W-1:0] re,
        output logic signed [DATA_W-1:0] im
    );
        begin
            case (k[7:0])
                8'd0: begin re = 16'sd32767; im = 16'sd0; end
                8'd1: begin re = 16'sd32758; im = -16'sd804; end
                8'd2: begin re = 16'sd32729; im = -16'sd1608; end
                8'd3: begin re = 16'sd32679; im = -16'sd2411; end
                8'd4: begin re = 16'sd32610; im = -16'sd3212; end
                8'd5: begin re = 16'sd32522; im = -16'sd4011; end
                8'd6: begin re = 16'sd32413; im = -16'sd4808; end
                8'd7: begin re = 16'sd32286; im = -16'sd5602; end
                8'd8: begin re = 16'sd32138; im = -16'sd6393; end
                8'd9: begin re = 16'sd31972; im = -16'sd7180; end
                8'd10: begin re = 16'sd31786; im = -16'sd7962; end
                8'd11: begin re = 16'sd31581; im = -16'sd8740; end
                8'd12: begin re = 16'sd31357; im = -16'sd9512; end
                8'd13: begin re = 16'sd31114; im = -16'sd10279; end
                8'd14: begin re = 16'sd30853; im = -16'sd11039; end
                8'd15: begin re = 16'sd30572; im = -16'sd11793; end
                8'd16: begin re = 16'sd30274; im = -16'sd12540; end
                8'd17: begin re = 16'sd29957; im = -16'sd13279; end
                8'd18: begin re = 16'sd29622; im = -16'sd14010; end
                8'd19: begin re = 16'sd29269; im = -16'sd14733; end
                8'd20: begin re = 16'sd28899; im = -16'sd15447; end
                8'd21: begin re = 16'sd28511; im = -16'sd16151; end
                8'd22: begin re = 16'sd28106; im = -16'sd16846; end
                8'd23: begin re = 16'sd27684; im = -16'sd17531; end
                8'd24: begin re = 16'sd27246; im = -16'sd18205; end
                8'd25: begin re = 16'sd26791; im = -16'sd18868; end
                8'd26: begin re = 16'sd26320; im = -16'sd19520; end
                8'd27: begin re = 16'sd25833; im = -16'sd20160; end
                8'd28: begin re = 16'sd25330; im = -16'sd20788; end
                8'd29: begin re = 16'sd24812; im = -16'sd21403; end
                8'd30: begin re = 16'sd24279; im = -16'sd22006; end
                8'd31: begin re = 16'sd23732; im = -16'sd22595; end
                8'd32: begin re = 16'sd23170; im = -16'sd23170; end
                8'd33: begin re = 16'sd22595; im = -16'sd23732; end
                8'd34: begin re = 16'sd22006; im = -16'sd24279; end
                8'd35: begin re = 16'sd21403; im = -16'sd24812; end
                8'd36: begin re = 16'sd20788; im = -16'sd25330; end
                8'd37: begin re = 16'sd20160; im = -16'sd25833; end
                8'd38: begin re = 16'sd19520; im = -16'sd26320; end
                8'd39: begin re = 16'sd18868; im = -16'sd26791; end
                8'd40: begin re = 16'sd18205; im = -16'sd27246; end
                8'd41: begin re = 16'sd17531; im = -16'sd27684; end
                8'd42: begin re = 16'sd16846; im = -16'sd28106; end
                8'd43: begin re = 16'sd16151; im = -16'sd28511; end
                8'd44: begin re = 16'sd15447; im = -16'sd28899; end
                8'd45: begin re = 16'sd14733; im = -16'sd29269; end
                8'd46: begin re = 16'sd14010; im = -16'sd29622; end
                8'd47: begin re = 16'sd13279; im = -16'sd29957; end
                8'd48: begin re = 16'sd12540; im = -16'sd30274; end
                8'd49: begin re = 16'sd11793; im = -16'sd30572; end
                8'd50: begin re = 16'sd11039; im = -16'sd30853; end
                8'd51: begin re = 16'sd10279; im = -16'sd31114; end
                8'd52: begin re = 16'sd9512; im = -16'sd31357; end
                8'd53: begin re = 16'sd8740; im = -16'sd31581; end
                8'd54: begin re = 16'sd7962; im = -16'sd31786; end
                8'd55: begin re = 16'sd7180; im = -16'sd31972; end
                8'd56: begin re = 16'sd6393; im = -16'sd32138; end
                8'd57: begin re = 16'sd5602; im = -16'sd32286; end
                8'd58: begin re = 16'sd4808; im = -16'sd32413; end
                8'd59: begin re = 16'sd4011; im = -16'sd32522; end
                8'd60: begin re = 16'sd3212; im = -16'sd32610; end
                8'd61: begin re = 16'sd2411; im = -16'sd32679; end
                8'd62: begin re = 16'sd1608; im = -16'sd32729; end
                8'd63: begin re = 16'sd804; im = -16'sd32758; end
                8'd64: begin re = 16'sd0; im = -16'sd32768; end
                8'd65: begin re = -16'sd804; im = -16'sd32758; end
                8'd66: begin re = -16'sd1608; im = -16'sd32729; end
                8'd67: begin re = -16'sd2411; im = -16'sd32679; end
                8'd68: begin re = -16'sd3212; im = -16'sd32610; end
                8'd69: begin re = -16'sd4011; im = -16'sd32522; end
                8'd70: begin re = -16'sd4808; im = -16'sd32413; end
                8'd71: begin re = -16'sd5602; im = -16'sd32286; end
                8'd72: begin re = -16'sd6393; im = -16'sd32138; end
                8'd73: begin re = -16'sd7180; im = -16'sd31972; end
                8'd74: begin re = -16'sd7962; im = -16'sd31786; end
                8'd75: begin re = -16'sd8740; im = -16'sd31581; end
                8'd76: begin re = -16'sd9512; im = -16'sd31357; end
                8'd77: begin re = -16'sd10279; im = -16'sd31114; end
                8'd78: begin re = -16'sd11039; im = -16'sd30853; end
                8'd79: begin re = -16'sd11793; im = -16'sd30572; end
                8'd80: begin re = -16'sd12540; im = -16'sd30274; end
                8'd81: begin re = -16'sd13279; im = -16'sd29957; end
                8'd82: begin re = -16'sd14010; im = -16'sd29622; end
                8'd83: begin re = -16'sd14733; im = -16'sd29269; end
                8'd84: begin re = -16'sd15447; im = -16'sd28899; end
                8'd85: begin re = -16'sd16151; im = -16'sd28511; end
                8'd86: begin re = -16'sd16846; im = -16'sd28106; end
                8'd87: begin re = -16'sd17531; im = -16'sd27684; end
                8'd88: begin re = -16'sd18205; im = -16'sd27246; end
                8'd89: begin re = -16'sd18868; im = -16'sd26791; end
                8'd90: begin re = -16'sd19520; im = -16'sd26320; end
                8'd91: begin re = -16'sd20160; im = -16'sd25833; end
                8'd92: begin re = -16'sd20788; im = -16'sd25330; end
                8'd93: begin re = -16'sd21403; im = -16'sd24812; end
                8'd94: begin re = -16'sd22006; im = -16'sd24279; end
                8'd95: begin re = -16'sd22595; im = -16'sd23732; end
                8'd96: begin re = -16'sd23170; im = -16'sd23170; end
                8'd97: begin re = -16'sd23732; im = -16'sd22595; end
                8'd98: begin re = -16'sd24279; im = -16'sd22006; end
                8'd99: begin re = -16'sd24812; im = -16'sd21403; end
                8'd100: begin re = -16'sd25330; im = -16'sd20788; end
                8'd101: begin re = -16'sd25833; im = -16'sd20160; end
                8'd102: begin re = -16'sd26320; im = -16'sd19520; end
                8'd103: begin re = -16'sd26791; im = -16'sd18868; end
                8'd104: begin re = -16'sd27246; im = -16'sd18205; end
                8'd105: begin re = -16'sd27684; im = -16'sd17531; end
                8'd106: begin re = -16'sd28106; im = -16'sd16846; end
                8'd107: begin re = -16'sd28511; im = -16'sd16151; end
                8'd108: begin re = -16'sd28899; im = -16'sd15447; end
                8'd109: begin re = -16'sd29269; im = -16'sd14733; end
                8'd110: begin re = -16'sd29622; im = -16'sd14010; end
                8'd111: begin re = -16'sd29957; im = -16'sd13279; end
                8'd112: begin re = -16'sd30274; im = -16'sd12540; end
                8'd113: begin re = -16'sd30572; im = -16'sd11793; end
                8'd114: begin re = -16'sd30853; im = -16'sd11039; end
                8'd115: begin re = -16'sd31114; im = -16'sd10279; end
                8'd116: begin re = -16'sd31357; im = -16'sd9512; end
                8'd117: begin re = -16'sd31581; im = -16'sd8740; end
                8'd118: begin re = -16'sd31786; im = -16'sd7962; end
                8'd119: begin re = -16'sd31972; im = -16'sd7180; end
                8'd120: begin re = -16'sd32138; im = -16'sd6393; end
                8'd121: begin re = -16'sd32286; im = -16'sd5602; end
                8'd122: begin re = -16'sd32413; im = -16'sd4808; end
                8'd123: begin re = -16'sd32522; im = -16'sd4011; end
                8'd124: begin re = -16'sd32610; im = -16'sd3212; end
                8'd125: begin re = -16'sd32679; im = -16'sd2411; end
                8'd126: begin re = -16'sd32729; im = -16'sd1608; end
                8'd127: begin re = -16'sd32758; im = -16'sd804; end
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
        logic signed [2*DATA_W-1:0] p_rr;
        logic signed [2*DATA_W-1:0] p_ii;
        logic signed [2*DATA_W-1:0] p_ri;
        logic signed [2*DATA_W-1:0] p_ir;
        logic signed [2*DATA_W:0]   tmp_re;
        logic signed [2*DATA_W:0]   tmp_im;
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

        for (int idx = 0; idx < N; idx = idx + 1) begin
            out_re[idx] = in_re[idx];
            out_im[idx] = in_im[idx];
        end

        for (int grp = 0; grp < N; grp = grp + full_span) begin
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

                get_twiddle256(j * TW_STEP, w_re, w_im);
                cmul_q15(d_re, d_im, w_re, w_im, t_re, t_im);

                out_re[i0] = add_re >>> 1;
                out_im[i0] = add_im >>> 1;
                out_re[i1] = t_re >>> 1;
                out_im[i1] = t_im >>> 1;
            end
        end
    end

endmodule
