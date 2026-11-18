// =============================================================================
// output_update.sv  –  Update Oi_acc, li, mi after one (j, i) tile pair
//
// Implements Algorithm 1 lines 11–12 for one Q row-tile:
//
//   mi_new[r]  = max( mi[r], m_tilde[r] )
//
//   li_new[r]  = exp(mi[r] - mi_new[r]) * li[r]
//              + exp(m_tilde[r] - mi_new[r]) * l_tilde[r]
//
//   Oi_new[r][c] = diag(li_new)^{-1}
//                × [ exp(mi[r]-mi_new[r]) * diag(li) * Oi_acc[r][c]
//                    + exp(m_tilde[r]-mi_new[r]) * pv_result[r][c] ]
//
// Note: the division by li_new is deferred to the final normalization step.
//       Here we compute the numerator only:
//
//   Oi_num[r][c] = exp(mi[r]-mi_new[r]) * Oi_acc[r][c]
//                + exp(m_tilde[r]-mi_new[r]) * pv_result[r][c]
//
// All multiplications are Q8.8 × Q16.8 → Q24.16, right-shifted by 8 → Q16.8.
//
// Timing: purely combinational; top-level FSM registers outputs in S_UPDATE.
//
// Ports (all _in are current stored values; _out are new values to write back):
//   mi_in      – current row-max,        Br × DATA_W
//   li_in      – current running sum,    Br × ACC_W
//   Oi_acc_in  – current O accumulator,  Br × D × ACC_W
//   m_tilde    – new tile row-max,       Br × DATA_W  (from softmax_unit)
//   l_tilde    – new tile row-sum,       Br × ACC_W   (from softmax_unit)
//   pv_result  – P_tilde @ Vj result,   Br × D × ACC_W (from matmul_unit)
//
//   mi_out     – updated row-max
//   li_out     – updated running sum
//   Oi_acc_out – updated O numerator accumulator
// =============================================================================

module output_update #(
    parameter  Br      = 4,    // row tile size
    parameter  Bc      = 8,    // col tile size (needed for softmax port widths)
    parameter  D       = 4,    // head dimension
    parameter  DATA_W  = 16,   // Q8.8
    parameter  ACC_W   = 32    // Q16.8 accumulator
)(
    // ---- Running statistics (from/to HBM via top FSM) ----
    input  wire signed [DATA_W-1:0]  mi_in      [0:Br-1],
    input  wire signed [ACC_W-1:0]   li_in      [0:Br-1],
    input  wire signed [ACC_W-1:0]   Oi_acc_in  [0:Br-1][0:D-1],

    // ---- New tile contributions (from softmax_unit and matmul_unit) ----
    input  wire signed [DATA_W-1:0]  m_tilde    [0:Br-1],
    input  wire signed [ACC_W-1:0]   l_tilde    [0:Br-1],
    input  wire signed [ACC_W-1:0]   pv_result  [0:Br-1][0:D-1],

    // ---- Updated outputs ----
    output wire signed [DATA_W-1:0]  mi_out      [0:Br-1],
    output wire signed [ACC_W-1:0]   li_out      [0:Br-1],
    output wire signed [ACC_W-1:0]   Oi_acc_out  [0:Br-1][0:D-1],

    // ---- Correction factors (exposed so top FSM can apply them separately) ----
    // corr_old[r] = exp( mi[r]      - mi_new[r] )  captured in S_UPDATE
    // corr_new[r] = exp( m_tilde[r] - mi_new[r] )  used in S_ACC_O after PV done
    output wire signed [DATA_W-1:0]  corr_old_out [0:Br-1],
    output wire signed [DATA_W-1:0]  corr_new_out [0:Br-1]
);

    // -------------------------------------------------------------------------
    // Per-row correction exp values (combinational via exp module)
    //   corr_old[r] = exp( mi[r]      - mi_new[r] )   ∈ (0, 1.0]
    //   corr_new[r] = exp( m_tilde[r] - mi_new[r] )   ∈ (0, 1.0]
    // -------------------------------------------------------------------------
    genvar r, c;

    generate
        for (r = 0; r < Br; r = r + 1) begin : MI_MAX
            // mi_new = max(mi_in, m_tilde)
            assign mi_out[r] = ($signed(mi_in[r]) > $signed(m_tilde[r]))
                               ? mi_in[r] : m_tilde[r];
        end
    endgenerate

    // exp( mi_in[r] - mi_out[r] )  — correction for old statistics
    wire signed [DATA_W-1:0] corr_old [0:Br-1];
    assign corr_old_out = corr_old;

    generate
        for (r = 0; r < Br; r = r + 1) begin : EXP_OLD
            wire signed [DATA_W-1:0] delta_old;
            assign delta_old = $signed(mi_in[r]) - $signed(mi_out[r]);

            exp #(.DATA_WIDTH(DATA_W)) u_exp_old (
                .x_in   (delta_old),
                .exp_out(corr_old[r])
            );
        end
    endgenerate

    // exp( m_tilde[r] - mi_out[r] )  — correction for new tile
    wire signed [DATA_W-1:0] corr_new [0:Br-1];
    assign corr_new_out = corr_new;

    generate
        for (r = 0; r < Br; r = r + 1) begin : EXP_NEW
            wire signed [DATA_W-1:0] delta_new;
            assign delta_new = $signed(m_tilde[r]) - $signed(mi_out[r]);

            exp #(.DATA_WIDTH(DATA_W)) u_exp_new (
                .x_in   (delta_new),
                .exp_out(corr_new[r])
            );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Update li_out  (Algorithm 1, line 11)
    //   li_new = corr_old * li_in  +  corr_new * l_tilde
    // Multiply Q8.8 × Q16.8 → right-shift 8 to stay in Q16.8 (ACC_W)
    // -------------------------------------------------------------------------
    generate
        for (r = 0; r < Br; r = r + 1) begin : L_UPDATE
            assign li_out[r] =
                ( ($signed({{(ACC_W-DATA_W){corr_old[r][DATA_W-1]}}, corr_old[r]})
                   * li_in[r]) >>> 8 )
              + ( ($signed({{(ACC_W-DATA_W){corr_new[r][DATA_W-1]}}, corr_new[r]})
                   * l_tilde[r]) >>> 8 );
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Update Oi_acc_out  (Algorithm 1, line 12 numerator)
    //   Oi_num = corr_old * Oi_acc_in  +  corr_new * pv_result
    // -------------------------------------------------------------------------
    generate
        for (r = 0; r < Br; r = r + 1) begin : O_UPDATE
            for (c = 0; c < D; c = c + 1) begin : O_COL
                assign Oi_acc_out[r][c] =
                    ( ($signed({{(ACC_W-DATA_W){corr_old[r][DATA_W-1]}}, corr_old[r]})
                       * Oi_acc_in[r][c]) >>> 8 )
                  + ( ($signed({{(ACC_W-DATA_W){corr_new[r][DATA_W-1]}}, corr_new[r]})
                       * pv_result[r][c]) >>> 8 );
            end
        end
    endgenerate

endmodule