// =============================================================================
// softmax_unit.sv  –  Combinational online-softmax tile processor
//
// Given a tile Sij (Br×Bc, Q8.8), computes three quantities in parallel:
//
//   m_tilde[r]    = max over c of Sij[r][c]                (Q8.8, Algorithm line 10)
//   P_tilde[r][c] = exp( Sij[r][c] - m_tilde[r] )          (Q8.8, ≤ 1.0)
//   l_tilde[r]    = sum over c of P_tilde[r][c]             (Q16.8 / ACC_W-bit)
//
// All logic is purely combinational – no clock needed.
// The top-level FSM registers the outputs on the next rising edge.
//
// The exp() call uses the hardware exp module (exp.sv).
// Input to exp is (Sij[r][c] - m_tilde[r]) which is always ≤ 0, so output ≤ 1.0.
//
// Ports:
//   Sij      – input tile, Br × Bc, Q8.8 signed
//   m_tilde  – output row-max,  Br elements, Q8.8
//   P_tilde  – output exp tile, Br × Bc, Q8.8
//   l_tilde  – output row-sum,  Br elements, ACC_W-bit
// =============================================================================

module softmax_unit #(
    parameter  Br      = 4,    // row tile size (fixed = D = 4)
    parameter  Bc      = 8,    // column tile size (= parameter from top)
    parameter  DATA_W  = 16,   // Q8.8
    parameter  ACC_W   = 32    // accumulator for l_tilde
)(
    // Sij input tile
    input  wire signed [DATA_W-1:0]  Sij    [0:Br-1][0:Bc-1],

    // Outputs (all combinational)
    output wire signed [DATA_W-1:0]  m_tilde [0:Br-1],
    output wire signed [DATA_W-1:0]  P_tilde [0:Br-1][0:Bc-1],
    output wire signed [ACC_W-1:0]   l_tilde [0:Br-1]
);

    // -------------------------------------------------------------------------
    // Row-max tree for each row  (Algorithm 1, line 10: m̃ij = rowmax(Sij))
    // -------------------------------------------------------------------------
    genvar r, c;

    generate
        for (r = 0; r < Br; r = r + 1) begin : ROWMAX

            // Reduce across Bc columns with a chain of comparators
            wire signed [DATA_W-1:0] rmax [0:Bc-1];
            assign rmax[0] = Sij[r][0];

            for (c = 1; c < Bc; c = c + 1) begin : MAX_CHAIN
                assign rmax[c] = ($signed(Sij[r][c]) > $signed(rmax[c-1]))
                                 ? Sij[r][c] : rmax[c-1];
            end

            assign m_tilde[r] = rmax[Bc-1];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // exp( Sij[r][c] - m_tilde[r] ) for every element  (line 10: P̃ij)
    // The subtraction result is always ≤ 0, so exp output ∈ (0, 1.0].
    // -------------------------------------------------------------------------
    generate
        for (r = 0; r < Br; r = r + 1) begin : EXP_ROW
            for (c = 0; c < Bc; c = c + 1) begin : EXP_COL

                wire signed [DATA_W-1:0] shifted;
                assign shifted = $signed(Sij[r][c]) - $signed(m_tilde[r]);

                exp #(.DATA_WIDTH(DATA_W)) u_exp (
                    .x_in   (shifted),
                    .exp_out(P_tilde[r][c])
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Row-sum of P_tilde  (line 10: l̃ij = rowsum(P̃ij))
    // Sign-extend DATA_W to ACC_W before summing to avoid overflow.
    // Max value: Bc × 1.0 = 8.0 in Q8.8 = 2048 – well within 32 bits.
    // -------------------------------------------------------------------------
    generate
        for (r = 0; r < Br; r = r + 1) begin : ROWSUM

            wire signed [ACC_W-1:0] rsum [0:Bc-1];
            assign rsum[0] = {{(ACC_W-DATA_W){P_tilde[r][0][DATA_W-1]}},
                               P_tilde[r][0]};

            for (c = 1; c < Bc; c = c + 1) begin : SUM_CHAIN
                assign rsum[c] = rsum[c-1]
                               + {{(ACC_W-DATA_W){P_tilde[r][c][DATA_W-1]}},
                                   P_tilde[r][c]};
            end

            assign l_tilde[r] = rsum[Bc-1];
        end
    endgenerate

endmodule