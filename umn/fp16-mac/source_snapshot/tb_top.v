module tb_fp16_fpfma_top;

    reg         clk;
    reg         rst_n;
    reg         valid_in;
    reg         acc_clear;
    reg  [15:0] a_fp16;
    reg  [15:0] b_fp16;

    wire        acc_sign;
    wire [87:0] acc_mag;  // ACC_W = 80 + EXTRA_HEAD(8) = 88 bits
    wire        overflow;

    integer     step;
    real        golden_acc;
    real        prod_real;
    integer     cycle_count;

    // Test parameters (as they are used within the DUT)
    localparam ACC_FRAC   = 48;
    localparam WIN_W      = 80;
    localparam EXTRA_HEAD = 8;
    localparam MANT_W     = 11;  // Default mantissa width for the first run
    localparam ACC_W      = WIN_W + EXTRA_HEAD;

    // DUT instantiation with parameterized values
    fp16_fpfma_top #(
        .ACC_FRAC   (ACC_FRAC),
        .WIN_W      (WIN_W),
        .EXTRA_HEAD (EXTRA_HEAD),
        .MANT_W     (MANT_W),
        .ACC_W      (ACC_W)
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

    // clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Reset and signal initialization
    initial begin
        rst_n      = 1'b0;
        valid_in   = 1'b0;
        acc_clear  = 1'b0;
        a_fp16     = 16'h3C00;  // Example FP16 values
        b_fp16     = 16'h4000;
        cycle_count = 0;
        #100 rst_n = 1'b1;  // De-assert reset after some time
    end

    // Testbench scenario for MANT_W = 11 and MANT_W = 9
    initial begin
        // Test with MANT_W = 11
        valid_in = 1'b1;
        #10 valid_in = 1'b0;
        #100;  // Wait for completion

        // Output number of cycles for MANT_W=11
        $display("Number of cycles for MANT_W=11: %d", cycle_count);
        
        // Reset for next test
        #20;
        valid_in = 1'b0;
        cycle_count = 0;

        // Test with MANT_W = 9
        fp16_fpfma_top #(
            .ACC_FRAC   (48),
            .WIN_W      (80),
            .EXTRA_HEAD (8),
            .MANT_W     (9),  // Test with MANT_W=9
            .ACC_W      (88)
        ) dut_9 (
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
        
        valid_in = 1'b1;
        #10 valid_in = 1'b0;
        #100;  // Wait for completion

        // Output number of cycles for MANT_W=9
        $display("Number of cycles for MANT_W=9: %d", cycle_count);
        
        $finish;
    end

    // Count the number of cycles for multiplication completion
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cycle_count <= 0;
        end else if (valid_in && (cycle_count < 1000)) begin
            cycle_count <= cycle_count + 1;
        end
    end

endmodule

