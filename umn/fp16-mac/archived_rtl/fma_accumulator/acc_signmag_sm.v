//=====================================================
// acc_signmag_sm
// - Sign-magnitude accumulator
// - ACC_W = WIN_W + EXTRA_HEAD
// - Each valid_in cycle: accumulate new product (p_sign, p_mag)
// - If signs match: add magnitudes
// - If signs differ: subtract smaller magnitude from larger;
//   result sign = sign of larger magnitude
// - Overflow when magnitude addition produces carry beyond ACC_W
//=====================================================
module acc_signmag_sm #(
    parameter integer WIN_W      = 80,
    parameter integer EXTRA_HEAD = 16,
    parameter integer ACC_W      = WIN_W + EXTRA_HEAD
) 
(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 valid_in,
    input  wire                 acc_clear,

    input  wire                 p_sign,
    input  wire [WIN_W-1:0]     p_mag,

    output reg                  acc_sign,
    output reg  [ACC_W-1:0]     acc_mag,
    output reg                  overflow
);

    wire [ACC_W-1:0] p_ext;
    wire             p_is_zero;
    wire             acc_is_zero;
    wire             signs_equal;
    wire [ACC_W:0]   sum_full;
    wire [ACC_W:0]   diff_full;
    reg              next_sign;
    reg  [ACC_W-1:0] next_mag;
    reg              next_ovf;

    assign p_ext      = {{EXTRA_HEAD{1'b0}}, p_mag};
    assign p_is_zero  = (p_mag == {WIN_W{1'b0}});
    assign acc_is_zero = (acc_mag == {ACC_W{1'b0}});
    assign signs_equal = (p_sign == acc_sign);

    assign sum_full  = {1'b0, acc_mag} + {1'b0, p_ext};

    // For subtraction: subtract smaller from larger to keep positive magnitude
    // diff_full = |acc_mag - p_ext|
    assign diff_full = (acc_mag >= p_ext) ?
                       ({1'b0, acc_mag} - {1'b0, p_ext}) :
                       ({1'b0, p_ext}   - {1'b0, acc_mag});

    always @(*) begin
        next_sign = acc_sign;
        next_mag  = acc_mag;
        next_ovf  = 1'b0;

        if (acc_clear) begin
            next_sign = 1'b0;
            next_mag  = {ACC_W{1'b0}};
            next_ovf  = 1'b0;
        end else if (valid_in) begin
            if (p_is_zero) begin
                // No change
                next_sign = acc_sign;
                next_mag  = acc_mag;
            end else if (acc_is_zero) begin
                // Accumulator empty, take product directly
                next_sign = p_sign;
                next_mag  = p_ext;
            end else if (signs_equal) begin
                // Same sign: add magnitudes
                next_sign = acc_sign;
                next_mag  = sum_full[ACC_W-1:0];
                next_ovf  = sum_full[ACC_W];  // carry beyond width
            } else begin
                // Different signs: subtract smaller magnitude from larger
                if (acc_mag >= p_ext) begin
                    next_sign = acc_sign;
                end else begin
                    next_sign = p_sign;
                end
                next_mag = diff_full[ACC_W-1:0];
                next_ovf = 1'b0;
            end
        end
    end

    // Sequential part
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_sign  <= 1'b0;
            acc_mag   <= {ACC_W{1'b0}};
            overflow  <= 1'b0;
        end else begin
            acc_sign  <= next_sign;
            acc_mag   <= next_mag;
            overflow  <= overflow | next_ovf; // sticky overflow
        end
    end

endmodule
