`timescale 1ns/1ps

//=====================================================
// tb_fp16_fpfma_top : tabular TB with best/worst cases
//=====================================================
module tb_fp16_fpfma_top;

    reg         clk;
    reg         rst_n;
    reg         valid_in;
    reg         acc_clear;
    reg  [15:0] a_fp16;
    reg  [15:0] b_fp16;

    wire        acc_sign;
    wire [95:0] acc_mag;   // WIN_W 80 + EXTRA_HEAD 16 = 96 bits
    wire        overflow;

    integer     step;
    real        golden_acc;   // running ideal sum in real

    // DUT
    fp16_fpfma_top #(
        .ACC_FRAC   (48),
        .WIN_W      (80),
        .MANT_W     (7),    // change here (e.g., 9) to try reduced mantissa multiplier
        .EXTRA_HEAD (16)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .acc_clear (acc_clear),
        .a_fp16    (a_fp16),
        .b_fp16    (b_fp16),
        .acc_sign  (acc_sign),
        .acc_mag   (acc_mag),
        .overflow  (overflow)
    );

    // ---------------- Clock ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;    // 100 MHz
    end

    // ---------------- Stimulus ----------------
    initial begin
        // init
        rst_n      = 1'b0;
        valid_in   = 1'b0;
        acc_clear  = 1'b0;
        a_fp16     = 16'd0;
        b_fp16     = 16'd0;
        step       = 0;
        golden_acc = 0.0;

        // reset
        #20;
        rst_n = 1'b1;

        // ==== SCENARIO 1: SIMPLE CHECK (already used) ====
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 1: simple mix (+1,+1) (+2,0.5) (-1,1)  ==> final = +1.0");
        print_header;

        // 1) 1.0 * 1.0
        send_pair(16'h3C00, 16'h3C00,  1.0,  1.0);

        // 2) 2.0 * 0.5
        send_pair(16'h4000, 16'h3800,  2.0,  0.5);

        // 3) -1.0 * 1.0
        send_pair(16'hBC00, 16'h3C00, -1.0,  1.0);

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 1) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        // ==== SCENARIO 2: STRONG CANCELLATION (sign-flip worst case) ====
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 2: cancellation  (+1*1) 5x and (-1*1) 4x  ==> final = +1.0");
        print_header;

        // Do 5 times (+1 * +1)
        repeat (5) begin
            send_pair(16'h3C00, 16'h3C00, 1.0, 1.0);
        end

        // Do 4 times (-1 * +1)
        repeat (4) begin
            send_pair(16'hBC00, 16'h3C00, -1.0, 1.0);
        end

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 2) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        // ==== SCENARIO 3: LARGE MAGNITUDE (dynamic range) ====
        // max finite FP16 ≈ 65504 (0x7BFF)
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 3: large magnitude (max_fp16 * max_fp16) 4x");
        $display("           max_fp16 ≈ 65504.0  => product ≈ 4.29e9 each");
        print_header;

        // 4 products of max*max  (still tiny vs 2^80 range)
        repeat (4) begin
            send_pair(16'h7BFF, 16'h7BFF, 65504.0, 65504.0);
        end

        $display("--------------------------------------------------------------------");
        $display("Golden sum (Scenario 3) ≈ %e,  HW acc_sign=%0d, acc_mag=%h",
                 golden_acc, acc_sign, acc_mag);
        $display("====================================================================");

        // ==== SCENARIO 4: [TEST v1] mantissa precision sensitivity ====
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 4 [TEST v1]: mid-precision mantissas to stress MANT_W setting");
        print_header;

        // [TEST v1] Case 1: mantissas with many non-zero LSBs
        // This case is most sensitive to truncation of low-order mantissa bits.
        send_pair(16'h3C55, 16'h3955,  1.0419921875, 0.70703125);

        // [TEST v1] Case 2: mantissas with mostly zero LSBs
        // Reduced mantissa width should alter the result less for this pair.
        send_pair(16'h3C10, 16'h3890,  1.0078125,    0.5625);

        $display("--------------------------------------------------------------------");
        $display("End SCENARIO 4 [TEST v1], HW acc_sign=%0d, acc_mag=%h, golden_acc=%e",
                 acc_sign, acc_mag, golden_acc);
        $display("====================================================================");

        $finish;
    end

    // -------------- Task: reset accumulator + golden model --------------
    task clear_accumulator;
    begin
        @(negedge clk);
        acc_clear  <= 1'b1;
        golden_acc <= 0.0;
        step       <= 0;

        @(negedge clk);
        acc_clear  <= 1'b0;

        @(negedge clk); // let DUT settle
    end
    endtask

    // -------------- Task: send pair + print row --------------
    task send_pair;
        input [15:0] a_val;
        input [15:0] b_val;
        input real   a_real;
        input real   b_real;
        real prod_real;
    begin
        @(negedge clk);
        valid_in <= 1'b1;
        a_fp16   <= a_val;
        b_fp16   <= b_val;

        prod_real = a_real * b_real;
        golden_acc  = golden_acc + prod_real;

        @(negedge clk);
        valid_in <= 1'b0;

        // wait one more cycle so accumulator updates
        @(negedge clk);

        $display("%0d    %h    %h    %f    %f      %0d      %h",
                 step, a_val, b_val,
                 prod_real, golden_acc,
                 acc_sign, acc_mag);

        step = step + 1;
    end
    endtask

    // -------------- Simple header print --------------
    task print_header;
    begin
        $display("Step  A_fp16  B_fp16   prod(real)   golden_sum(real)  acc_sign  acc_mag(hex)");
        $display("--------------------------------------------------------------------");
    end
    endtask

endmodule

