`timescale 1ns/1ps

module twiddle_rom_512 #(
    parameter int DATA_W = 16,
    parameter int FRAC_W = 15
)(
    input  logic [8:0] addr,
    output logic signed [DATA_W-1:0] wr,
    output logic signed [DATA_W-1:0] wi
);

    // For 256-point FFT, core sends even 512-ROM addresses:
    // addr = {twiddle_addr_256, 1'b0}
    // Therefore addr[8:1] maps directly to W256^k.

    always_comb begin
        case (addr[8:1])
            8'd0:   begin wr = 16'sd32767;  wi = 16'sd0;      end
            8'd1:   begin wr = 16'sd32758;  wi = -16'sd804;   end
            8'd2:   begin wr = 16'sd32729;  wi = -16'sd1608;  end
            8'd3:   begin wr = 16'sd32679;  wi = -16'sd2411;  end
            8'd4:   begin wr = 16'sd32610;  wi = -16'sd3212;  end
            8'd5:   begin wr = 16'sd32522;  wi = -16'sd4011;  end
            8'd6:   begin wr = 16'sd32413;  wi = -16'sd4808;  end
            8'd7:   begin wr = 16'sd32286;  wi = -16'sd5602;  end
            8'd8:   begin wr = 16'sd32138;  wi = -16'sd6393;  end
            8'd9:   begin wr = 16'sd31972;  wi = -16'sd7180;  end
            8'd10:  begin wr = 16'sd31786;  wi = -16'sd7962;  end
            8'd11:  begin wr = 16'sd31581;  wi = -16'sd8740;  end
            8'd12:  begin wr = 16'sd31357;  wi = -16'sd9512;  end
            8'd13:  begin wr = 16'sd31114;  wi = -16'sd10279; end
            8'd14:  begin wr = 16'sd30853;  wi = -16'sd11039; end
            8'd15:  begin wr = 16'sd30572;  wi = -16'sd11793; end
            8'd16:  begin wr = 16'sd30274;  wi = -16'sd12540; end
            8'd17:  begin wr = 16'sd29957;  wi = -16'sd13279; end
            8'd18:  begin wr = 16'sd29622;  wi = -16'sd14010; end
            8'd19:  begin wr = 16'sd29269;  wi = -16'sd14733; end
            8'd20:  begin wr = 16'sd28899;  wi = -16'sd15447; end
            8'd21:  begin wr = 16'sd28511;  wi = -16'sd16151; end
            8'd22:  begin wr = 16'sd28106;  wi = -16'sd16846; end
            8'd23:  begin wr = 16'sd27684;  wi = -16'sd17531; end
            8'd24:  begin wr = 16'sd27246;  wi = -16'sd18205; end
            8'd25:  begin wr = 16'sd26791;  wi = -16'sd18868; end
            8'd26:  begin wr = 16'sd26320;  wi = -16'sd19520; end
            8'd27:  begin wr = 16'sd25833;  wi = -16'sd20160; end
            8'd28:  begin wr = 16'sd25330;  wi = -16'sd20788; end
            8'd29:  begin wr = 16'sd24812;  wi = -16'sd21403; end
            8'd30:  begin wr = 16'sd24279;  wi = -16'sd22006; end
            8'd31:  begin wr = 16'sd23732;  wi = -16'sd22595; end
            8'd32:  begin wr = 16'sd23170;  wi = -16'sd23170; end
            8'd33:  begin wr = 16'sd22595;  wi = -16'sd23732; end
            8'd34:  begin wr = 16'sd22006;  wi = -16'sd24279; end
            8'd35:  begin wr = 16'sd21403;  wi = -16'sd24812; end
            8'd36:  begin wr = 16'sd20788;  wi = -16'sd25330; end
            8'd37:  begin wr = 16'sd20160;  wi = -16'sd25833; end
            8'd38:  begin wr = 16'sd19520;  wi = -16'sd26320; end
            8'd39:  begin wr = 16'sd18868;  wi = -16'sd26791; end
            8'd40:  begin wr = 16'sd18205;  wi = -16'sd27246; end
            8'd41:  begin wr = 16'sd17531;  wi = -16'sd27684; end
            8'd42:  begin wr = 16'sd16846;  wi = -16'sd28106; end
            8'd43:  begin wr = 16'sd16151;  wi = -16'sd28511; end
            8'd44:  begin wr = 16'sd15447;  wi = -16'sd28899; end
            8'd45:  begin wr = 16'sd14733;  wi = -16'sd29269; end
            8'd46:  begin wr = 16'sd14010;  wi = -16'sd29622; end
            8'd47:  begin wr = 16'sd13279;  wi = -16'sd29957; end
            8'd48:  begin wr = 16'sd12540;  wi = -16'sd30274; end
            8'd49:  begin wr = 16'sd11793;  wi = -16'sd30572; end
            8'd50:  begin wr = 16'sd11039;  wi = -16'sd30853; end
            8'd51:  begin wr = 16'sd10279;  wi = -16'sd31114; end
            8'd52:  begin wr = 16'sd9512;   wi = -16'sd31357; end
            8'd53:  begin wr = 16'sd8740;   wi = -16'sd31581; end
            8'd54:  begin wr = 16'sd7962;   wi = -16'sd31786; end
            8'd55:  begin wr = 16'sd7180;   wi = -16'sd31972; end
            8'd56:  begin wr = 16'sd6393;   wi = -16'sd32138; end
            8'd57:  begin wr = 16'sd5602;   wi = -16'sd32286; end
            8'd58:  begin wr = 16'sd4808;   wi = -16'sd32413; end
            8'd59:  begin wr = 16'sd4011;   wi = -16'sd32522; end
            8'd60:  begin wr = 16'sd3212;   wi = -16'sd32610; end
            8'd61:  begin wr = 16'sd2411;   wi = -16'sd32679; end
            8'd62:  begin wr = 16'sd1608;   wi = -16'sd32729; end
            8'd63:  begin wr = 16'sd804;    wi = -16'sd32758; end
            8'd64:  begin wr = 16'sd0;      wi = -16'sd32768; end
            8'd65:  begin wr = -16'sd804;   wi = -16'sd32758; end
            8'd66:  begin wr = -16'sd1608;  wi = -16'sd32729; end
            8'd67:  begin wr = -16'sd2411;  wi = -16'sd32679; end
            8'd68:  begin wr = -16'sd3212;  wi = -16'sd32610; end
            8'd69:  begin wr = -16'sd4011;  wi = -16'sd32522; end
            8'd70:  begin wr = -16'sd4808;  wi = -16'sd32413; end
            8'd71:  begin wr = -16'sd5602;  wi = -16'sd32286; end
            8'd72:  begin wr = -16'sd6393;  wi = -16'sd32138; end
            8'd73:  begin wr = -16'sd7180;  wi = -16'sd31972; end
            8'd74:  begin wr = -16'sd7962;  wi = -16'sd31786; end
            8'd75:  begin wr = -16'sd8740;  wi = -16'sd31581; end
            8'd76:  begin wr = -16'sd9512;  wi = -16'sd31357; end
            8'd77:  begin wr = -16'sd10279; wi = -16'sd31114; end
            8'd78:  begin wr = -16'sd11039; wi = -16'sd30853; end
            8'd79:  begin wr = -16'sd11793; wi = -16'sd30572; end
            8'd80:  begin wr = -16'sd12540; wi = -16'sd30274; end
            8'd81:  begin wr = -16'sd13279; wi = -16'sd29957; end
            8'd82:  begin wr = -16'sd14010; wi = -16'sd29622; end
            8'd83:  begin wr = -16'sd14733; wi = -16'sd29269; end
            8'd84:  begin wr = -16'sd15447; wi = -16'sd28899; end
            8'd85:  begin wr = -16'sd16151; wi = -16'sd28511; end
            8'd86:  begin wr = -16'sd16846; wi = -16'sd28106; end
            8'd87:  begin wr = -16'sd17531; wi = -16'sd27684; end
            8'd88:  begin wr = -16'sd18205; wi = -16'sd27246; end
            8'd89:  begin wr = -16'sd18868; wi = -16'sd26791; end
            8'd90:  begin wr = -16'sd19520; wi = -16'sd26320; end
            8'd91:  begin wr = -16'sd20160; wi = -16'sd25833; end
            8'd92:  begin wr = -16'sd20788; wi = -16'sd25330; end
            8'd93:  begin wr = -16'sd21403; wi = -16'sd24812; end
            8'd94:  begin wr = -16'sd22006; wi = -16'sd24279; end
            8'd95:  begin wr = -16'sd22595; wi = -16'sd23732; end
            8'd96:  begin wr = -16'sd23170; wi = -16'sd23170; end
            8'd97:  begin wr = -16'sd23732; wi = -16'sd22595; end
            8'd98:  begin wr = -16'sd24279; wi = -16'sd22006; end
            8'd99:  begin wr = -16'sd24812; wi = -16'sd21403; end
            8'd100: begin wr = -16'sd25330; wi = -16'sd20788; end
            8'd101: begin wr = -16'sd25833; wi = -16'sd20160; end
            8'd102: begin wr = -16'sd26320; wi = -16'sd19520; end
            8'd103: begin wr = -16'sd26791; wi = -16'sd18868; end
            8'd104: begin wr = -16'sd27246; wi = -16'sd18205; end
            8'd105: begin wr = -16'sd27684; wi = -16'sd17531; end
            8'd106: begin wr = -16'sd28106; wi = -16'sd16846; end
            8'd107: begin wr = -16'sd28511; wi = -16'sd16151; end
            8'd108: begin wr = -16'sd28899; wi = -16'sd15447; end
            8'd109: begin wr = -16'sd29269; wi = -16'sd14733; end
            8'd110: begin wr = -16'sd29622; wi = -16'sd14010; end
            8'd111: begin wr = -16'sd29957; wi = -16'sd13279; end
            8'd112: begin wr = -16'sd30274; wi = -16'sd12540; end
            8'd113: begin wr = -16'sd30572; wi = -16'sd11793; end
            8'd114: begin wr = -16'sd30853; wi = -16'sd11039; end
            8'd115: begin wr = -16'sd31114; wi = -16'sd10279; end
            8'd116: begin wr = -16'sd31357; wi = -16'sd9512;  end
            8'd117: begin wr = -16'sd31581; wi = -16'sd8740;  end
            8'd118: begin wr = -16'sd31786; wi = -16'sd7962;  end
            8'd119: begin wr = -16'sd31972; wi = -16'sd7180;  end
            8'd120: begin wr = -16'sd32138; wi = -16'sd6393;  end
            8'd121: begin wr = -16'sd32286; wi = -16'sd5602;  end
            8'd122: begin wr = -16'sd32413; wi = -16'sd4808;  end
            8'd123: begin wr = -16'sd32522; wi = -16'sd4011;  end
            8'd124: begin wr = -16'sd32610; wi = -16'sd3212;  end
            8'd125: begin wr = -16'sd32679; wi = -16'sd2411;  end
            8'd126: begin wr = -16'sd32729; wi = -16'sd1608;  end
            8'd127: begin wr = -16'sd32758; wi = -16'sd804;   end

            default: begin
                wr = 16'sd32767;
                wi = 16'sd0;
            end
        endcase
    end

endmodule
