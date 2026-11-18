`timescale 1ns/1ps

module tb_fp16_fpfma_top;

    reg         clk;
    reg         rst_n;
    reg         valid_in;
    reg         acc_clear;
    reg  [15:0] a_fp16;
    reg  [15:0] b_fp16;

    wire        acc_sign;
    wire [95:0] acc_mag;
    wire        overflow;

    integer     step;
    real        golden_acc;
    real        prod_real;

    // DUT
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

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n      = 1'b0;
        valid_in   = 1'b0;
        acc_clear  = 1'b0;
        a_fp16     = 16'd0;
        b_fp16     = 16'd0;
        step       = 0;
        golden_acc = 0.0;

        #20;
        rst_n = 1'b1;

        //==================================================
        // SCENARIO 1
        //==================================================
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 1: (+1*+1), (+2*0.5), (-1*+1)  ==> final = +1.0");
        print_header;

        send_pair(16'h3C00, 16'h3C00,  1.0,  1.0);
        send_pair(16'h4000, 16'h3800,  2.0,  0.5);
        send_pair(16'hBC00, 16'h3C00, -1.0,  1.0);

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 1) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        //==================================================
        // SCENARIO 2
        //==================================================
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 2: (+1*+1) 5x and (-1*+1) 4x  ==> final = +1.0");
        print_header;

        repeat (5) send_pair(16'h3C00, 16'h3C00,  1.0,  1.0);
        repeat (4) send_pair(16'hBC00, 16'h3C00, -1.0,  1.0);

        $display("--------------------------------------------------------------------");
        $display("Expected golden sum (Scenario 2) = 1.0,  HW acc_sign=%0d, acc_mag=%h",
                 acc_sign, acc_mag);
        $display("");

        //==================================================
        // SCENARIO 3
        //==================================================
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 3: max_fp16 * max_fp16 4x");
        $display("           max_fp16 ≈ 65504.0  => product ≈ 4.29e9 each");
        print_header;

        repeat (4) send_pair(16'h7BFF, 16'h7BFF, 65504.0, 65504.0);

        $display("--------------------------------------------------------------------");
        $display("Golden sum (Scenario 3) ≈ %e,  HW acc_sign=%0d, acc_mag=%h",
                 golden_acc, acc_sign, acc_mag);
        $display("====================================================================");

        //==================================================
        // SCENARIO 4
        //==================================================
        clear_accumulator;
        $display("====================================================================");
        $display("SCENARIO 4: mid-precision mantissas");
        print_header;

        send_pair(16'h3C55, 16'h3955,  1.0419921875, 0.70703125);
        send_pair(16'h3C10, 16'h3890,  1.0078125,    0.5625    );

        $display("--------------------------------------------------------------------");
        $display("End SCENARIO 4, HW acc_sign=%0d, acc_mag=%h, golden_acc=%e",
                 acc_sign, acc_mag, golden_acc);
        $display("====================================================================");

        $finish;
    end

    // reset accumulator + golden model
    task clear_accumulator;
    begin
        @(posedge clk);
        acc_clear  <= 1'b1;
        golden_acc <= 0.0;
        step       <= 0;

        @(posedge clk);
        acc_clear  <= 1'b0;

        @(posedge clk);
    end
    endtask

    // send one pair (iterative multiplier ⇒ wait enough cycles)
    task send_pair;
        input [15:0] a_val;
        input [15:0] b_val;
        input real   a_real;
        input real   b_real;
        integer k;
    begin
        @(posedge clk);
        valid_in <= 1'b1;
        a_fp16   <= a_val;
        b_fp16   <= b_val;

        prod_real  = a_real * b_real;
        golden_acc = golden_acc + prod_real;

        @(posedge clk);
        valid_in <= 1'b0;

        // FSM multiplier: needs ~12–13 cycles -> wait 20 to be safe
        repeat (20) @(posedge clk);

        $display("%0d    %h    %h    %f    %f      %0d      %h",
                 step, a_val, b_val,
                 prod_real, golden_acc,
                 acc_sign, acc_mag);

        step = step + 1;
    end
    endtask

    task print_header;
    begin
        $display("Step  A_fp16  B_fp16   prod(real)   golden_sum(real)  acc_sign  acc_mag(hex)");
        $display("--------------------------------------------------------------------");
    end
    endtask

endmodule

