// ============================================================================
// PE + Matmul Unit for flash_attention_top.sv
// -----------------------------------------------------------------------------
// Interface matches the existing top-level instantiations exactly:
//   A      : [ROWS][INNER]
//   B      : [COLS][INNER]
//   result : [ROWS][COLS]
//
// Computation performed:
//   result[r][c] = sum_k (A[r][k] * B[c][k]) >>> 8
//
// This supports:
//   QK: A=Qi[Br][D],      B=Kj[Bc][D]       => Qi @ Kj^T
//   PV: A=P_tilde[Br][Bc], B=Vjt[D][Bc]     => P_tilde @ Vj
//
// Fixed-point:
//   A and B are signed Q8.8.
//   Product is Q16.16, shifted right by 8 to return to Q*.8 accumulation.
//   Accumulator/result width is ACC_W, matching the top module.
// ============================================================================

module pe_unit #(
    parameter DATA_W = 16,
    parameter ACC_W  = 36
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         clear,
    input  wire                         en,
    input  wire signed [DATA_W-1:0]     a,
    input  wire signed [DATA_W-1:0]     b,
    output reg  signed [ACC_W-1:0]      acc_out
);

    wire signed [(2*DATA_W)-1:0] mult_full;
    wire signed [ACC_W-1:0]      mult_scaled;

    assign mult_full   = a * b;
    assign mult_scaled = {{(ACC_W-DATA_W){mult_full[(2*DATA_W)-1]}}, mult_full[(2*DATA_W)-1:DATA_W-8]};
    // Equivalent to signed Q8.8 product scaling: (a*b) >>> 8,
    // written as a bit slice/sign extension for synthesis-friendly hardware.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= {ACC_W{1'b0}};
        end else if (clear) begin
            acc_out <= {ACC_W{1'b0}};
        end else if (en) begin
            acc_out <= acc_out + mult_scaled;
        end
    end

endmodule


module matmul_unit #(
    parameter ROWS        = 4,
    parameter INNER       = 4,
    parameter COLS        = 8,
    parameter DATA_W      = 16,
    parameter ACC_W       = 36,
    parameter TRANSPOSE_B = 1
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         start,
    output reg                          done,

    input  wire signed [DATA_W-1:0]     A      [0:ROWS-1][0:INNER-1],
    input  wire signed [DATA_W-1:0]     B      [0:COLS-1][0:INNER-1],
    output wire signed [ACC_W-1:0]      result [0:ROWS-1][0:COLS-1]
);

    localparam K_W = (INNER <= 1) ? 1 : $clog2(INNER);

    reg [K_W-1:0] k_idx;
    reg           running;
    reg           clear_acc;
    reg           mac_en;

    genvar gr, gc;
    generate
        for (gr = 0; gr < ROWS; gr = gr + 1) begin : GEN_ROW
            for (gc = 0; gc < COLS; gc = gc + 1) begin : GEN_COL
                pe_unit #(
                    .DATA_W(DATA_W),
                    .ACC_W (ACC_W)
                ) u_pe (
                    .clk    (clk),
                    .rst_n  (rst_n),
                    .clear  (clear_acc),
                    .en     (mac_en),
                    .a      (A[gr][k_idx]),
                    .b      (B[gc][k_idx]),
                    .acc_out(result[gr][gc])
                );
            end
        end
    endgenerate

    // Control behavior:
    //   start pulse: clear all output-stationary accumulators.
    //   next INNER cycles: accumulate one k-term per cycle across all PEs.
    //   done pulses for one cycle after the final k-term has been accumulated.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_idx     <= {K_W{1'b0}};
            running   <= 1'b0;
            clear_acc <= 1'b0;
            mac_en    <= 1'b0;
            done      <= 1'b0;
        end else begin
            clear_acc <= 1'b0;
            mac_en    <= 1'b0;
            done      <= 1'b0;

            if (start && !running) begin
                clear_acc <= 1'b1;
                running   <= 1'b1;
                k_idx     <= {K_W{1'b0}};
            end else if (running) begin
                mac_en <= 1'b1;

                if (k_idx == INNER-1) begin
                    running <= 1'b0;
                    done    <= 1'b1;
                    k_idx   <= {K_W{1'b0}};
                end else begin
                    k_idx <= k_idx + {{(K_W-1){1'b0}}, 1'b1};
                end
            end
        end
    end

endmodule
