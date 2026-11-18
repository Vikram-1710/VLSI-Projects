`timescale 1ns/1ps

//=====================================================
// tb_fp16_fpfma_top
// Simple testbench for fp16_fpfma_top
//=====================================================
module tb_fp16_fpfma_top;

    reg         clk;
    reg         rst_n;
    reg         valid_in;
    reg         acc_clear;
    reg  [15:0] a_fp16;
    reg  [15:0] b_fp16;

    wire        acc_sign;
    wire [95:0] acc_mag;   // 80 + 16 headroom = 96
    wire        overflow;

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

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;   // 100 MHz
    end

    // Reset and basic stimulus
    initial begin
        rst_n     = 1'b0;
        valid_in  = 1'b0;
        acc_clear = 1'b0;
        a_fp16    = 16'd0;
        b_fp16    = 16'd0;

        #20;
        rst_n = 1'b1;

        // Clear accumulator
        @(negedge clk);
        acc_clear = 1'b1;
        @(negedge clk);
        acc_clear = 1'b0;

        // Example 1: A = 1.0, B = 1.0 (FP16 0x3C00)
        send_pair(16'h3C00, 16'h3C00);

        // Example 2: A = 2.0, B = 0.5 (FP16 0x4000, 0x3800)
        send_pair(16'h4000, 16'h3800);

        // Example 3: A = -1.0, B = 1.0 (FP16 0xBC00, 0x3C00)
        send_pair(16'hBC00, 16'h3C00);

        // Wait some cycles
        repeat (10) @(negedge clk);

        // Print final accumulator state
        $display("===================================================");
        $display(" Final ACC:");
        $display("   sign = %0d", acc_sign);
        $display("   mag  = %h", acc_mag);
        $display("   overflow = %0d", overflow);
        $display("===================================================");

        $finish;
    end

    // Task to send one (A,B) pair with valid_in=1 for 1 cycle
    task send_pair;
        input [15:0] a_val;
        input [15:0] b_val;
    begin
        @(negedge clk);
        a_fp16   <= a_val;
        b_fp16   <= b_val;
        valid_in <= 1'b1;

        @(negedge clk);
        valid_in <= 1'b0;
    end
    endtask

endmodule
