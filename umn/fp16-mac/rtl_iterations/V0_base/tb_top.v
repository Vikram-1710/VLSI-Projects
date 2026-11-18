`timescale 1ns/1ps
//=====================================================
// tb_fp16_fpfma_top : tabular TB with best/worst cases
//  - Shows A, B in hex + binary (S EEEEE FFFFFFFFFF)
//  - acc_sign and acc_mag printed as before (hex)
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
    real        prod_real;    // current A*B in real

    // ---------------- DUT ----------------
    fp16_fpfma_top #(
        .ACC_FRAC   (48),
        .WIN_W      (80),
        .EXTRA_HEAD (16),
        .ACC_W      (96)
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

        #20;
        rst_n = 1'b1;

        // ==== SCENARIO 1: SIMPLE CHECK ====
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 1: simple mix (+1,+1) (+2,0.5) (-1,1)  ==> final = +1.0");
        print_header;

        // 1) 1.0 * 1.0   (3C00, 3C00)
        send_pair(16'h3C00, 16'h3C00,  1.0,  1.0);

        // 2) 2.0 * 0.5   (4000, 3800)
        send_pair(16'h4000, 16'h3800,  2.0,  0.5);

        // 3) -1.0 * 1.0  (BC00, 3C00)
        send_pair(16'hBC00, 16'h3C00, -1.0,  1.0);

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 1) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        // ==== SCENARIO 2: STRONG CANCELLATION ====
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 2: cancellation  (+1*1) 5x and (-1*1) 4x  ==> final = +1.0");
        print_header;

        // +1 * +1 five times
        repeat (5) begin
            send_pair(16'h3C00, 16'h3C00, 1.0, 1.0);
        end

        // -1 * +1 four times
        repeat (4) begin
            send_pair(16'hBC00, 16'h3C00, -1.0, 1.0);
        end

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 2) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        // ==== SCENARIO 3: LARGE MAGNITUDE ====
        // max finite FP16 ≈ 65504 (0x7BFF)
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 3: large magnitude (max_fp16 * max_fp16) 4x");
        $display("           max_fp16 ≈ 65504.0  => product ≈ 4.29e9 each");
        print_header;

        repeat (4) begin
            send_pair(16'h7BFF, 16'h7BFF, 65504.0, 65504.0);
        end

        $display("--------------------------------------------------------------------");
        $display("Golden sum (Scenario 3) ≈ %e,  HW acc_sign=%0d, acc_mag=%h",
                 golden_acc, acc_sign, acc_mag);
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

    // -------------- Task: send pair + print one row --------------
    task send_pair;
        input [15:0] a_val;
        input [15:0] b_val;
        input real   a_real;
        input real   b_real;
    begin
        // drive inputs for one cycle
        @(negedge clk);
        a_fp16   <= a_val;
        b_fp16   <= b_val;
        valid_in <= 1'b1;

        @(negedge clk);
        valid_in <= 1'b0;

        // update golden model: ACC += A*B
        prod_real   = a_real * b_real;
        golden_acc  = golden_acc + prod_real;

        // wait one more cycle so accumulator updates
        @(negedge clk);

        // print one table row
        // FP16 format: S EEEEE FFFFFFFFFF for A and B
        $display("%2d    %4h  %1b %05b %010b      %4h  %1b %05b %010b    %8f   %8f      %1d   %024h",
         step,
         a_val, a_val[15], a_val[14:10], a_val[9:0],
         b_val, b_val[15], b_val[14:10], b_val[9:0],
         prod_real,
         golden_acc,
         acc_sign,
         acc_mag);

        step = step + 1;
    end
    endtask

    // -------------- Header print --------------
	task print_header;
	begin
	    $display("Step  Ahex  A(S EEEEE FFFFFFFFFF)      Bhex  B(S EEEEE FFFFFFFFFF)    prod(real)   golden(real)   acc_s  acc_mag(hex)");
	    $display("------------------------------------------------------------------------------------------------------------------------");
	end
endtask


endmodule


