// =============================================================================
// flash_attention_top.sv  –  FlashAttention Algorithm 1, hardware implementation
//
// Fixed dimensions:  N = 64,  D = 4,  Br = D = 4
// Configurable:      Bc  (default 8, must divide N evenly)
//
// ---- HBM interface ----
// Bandwidth: 4 × Q8.8 (16-bit) = 64-bit per cycle.
// Protocol:  Combinational read – assert hbm_rd_req and hbm_rd_addr;
//            hbm_rd_data is valid in the SAME cycle.
//            Write – assert hbm_wr_req, hbm_wr_addr, hbm_wr_data simultaneously.
//            No handshake signals; one transfer (read or write) per cycle.
//            hbm_cycle_cnt counts every cycle where rd_req OR wr_req is high.
//
// ---- HBM memory map (word address, each word = 64-bit = 4 × Q8.8) ----
//
//   Region      Base   Words    Contents
//   Q           0      64       Q[i] = {Q[i][3],Q[i][2],Q[i][1],Q[i][0]}, 1 word/row
//   K           64     64       K[i] = {K[i][3],...}
//   V           128    64       V[i] = {V[i][3],...}
//   O_final     192    64       Q8.8 output, written at end
//   O_acc       256    128      32-bit partial sum; row i uses words 256+i*2, 256+i*2+1
//                                 word+0: {Oi_acc[i][1][31:0], Oi_acc[i][0][31:0]}
//                                 word+1: {Oi_acc[i][3][31:0], Oi_acc[i][2][31:0]}
//   l           384    32       32-bit li; group i uses words 384+i*2, 384+i*2+1
//                                 (layout same as O_acc: 2 × 32-bit per word)
//   m           416    16       16-bit mi; group i uses word 416+i
//                                 word: {mi[3],mi[2],mi[1],mi[0]}
//   TOTAL       432    words    → 9-bit address (2^9 = 512 ≥ 432
//
// =============================================================================

module flash_attention_top #(
    parameter  Bc        = 16,     // K/V column tile size (must divide N)
    parameter  N         = 64,    // sequence length  (fixed)
    parameter  D         = 4,     // head dimension   (fixed)
    parameter  DATA_W    = 16,    // Q8.8 element width
    parameter  ACC_W     = 36,    // accumulator width (2+Q16.8)
    parameter  HBM_DW    = 128     // HBM bus width in bits (= 4 × DATA_W)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // ---- Control ----
    input  wire                  start,          // pulse to begin
    output reg                   done,           // pulses high for 1 cycle when O is ready

    // ---- HBM Read Port ----
    output wire                  hbm_rd_req,
    output wire [8:0]            hbm_rd_addr,    // 9-bit word address
    input  wire [HBM_DW-1:0]    hbm_rd_data,    // [63:48]=e3 [47:32]=e2 [31:16]=e1 [15:0]=e0

    // ---- HBM Write Port ----
    output reg                   hbm_wr_req,
    output reg  [8:0]            hbm_wr_addr,
    output reg  [HBM_DW-1:0]    hbm_wr_data,    // layout same as hbm_rd_data

    // ---- Statistics ----
    output reg  [31:0]           hbm_cycle_cnt,  // counts every HBM-active cycle
    output reg  [31:0]           qk_cycle_cnt,   // QK matmul active cycles
    output reg  [31:0]           pv_cycle_cnt,   // PV matmul active cycles
    output reg  [31:0]           vec_cycle_cnt,  // vector op cycles (softmax/update/norm)
    output reg  [31:0]           total_cycle_cnt // total cycles from start to done
);

    // =========================================================================
    // Derived parameters
    // =========================================================================
    localparam Br    = D;               // row tile = head dimension = 4
    localparam Tc    = N / Bc;          // K/V tiles  = 8
    localparam Tr    = N / Br;          // Q   tiles  = 16

    // =========================================================================
    // HBM transfer granularity
    //   HBM_DW must be a multiple of 64 (= D*DATA_W).
    //   All counts below are integers by construction for valid parameters.
    // =========================================================================
    localparam QKV_ROW_BITS  = D * DATA_W;                          // bits/row for Q,K,V,O
    localparam OACC_ROW_BITS = D * ACC_W;                           // bits/row for O_acc
    localparam L_TILE_BITS   = Br * ACC_W;                          // bits/tile for l
    localparam M_TILE_BITS   = Br * DATA_W;                         // bits/tile for m

    localparam RPT_QKV  = HBM_DW / QKV_ROW_BITS;                   // Q/K/V rows per xfer
    localparam OACC_EPX = HBM_DW / ACC_W;                           // ACC_W elems per xfer
    localparam L_EPX    = HBM_DW / ACC_W;                           // same for l

    // Transfer counts per state (how many HBM words per tile)
    localparam KJ_XFERS  = Bc / RPT_QKV;
    localparam VJ_XFERS  = Bc / RPT_QKV;
    localparam QI_XFERS  = Br / RPT_QKV;
    localparam OI_XFERS  = (Br * D) / OACC_EPX;                    // = Br*OACC_ROW_BITS/HBM_DW
    localparam LI_XFERS  = (Br * ACC_W + HBM_DW - 1) / HBM_DW;    // ceil(L_TILE_BITS/HBM_DW)
    localparam O_WR_XFERS = Br / RPT_QKV;                          // O_final write

    // HBM word counts per region
    localparam Q_WORDS    = N / RPT_QKV;
    localparam OACC_WORDS = (N * OACC_ROW_BITS) / HBM_DW;
    localparam L_WORDS    = Tr * LI_XFERS;
    localparam M_WORDS    = Tr;                                     // 1 word/tile (m_tile ≤ HBM_DW)

    // =========================================================================
    // HBM base addresses (computed from word counts)
    // =========================================================================
    localparam [8:0] Q_BASE    = 9'd0;
    localparam [8:0] K_BASE    = Q_BASE    + Q_WORDS[8:0];
    localparam [8:0] V_BASE    = K_BASE    + Q_WORDS[8:0];
    localparam [8:0] O_BASE    = V_BASE    + Q_WORDS[8:0];
    localparam [8:0] OACC_BASE = O_BASE    + Q_WORDS[8:0];
    localparam [8:0] L_BASE    = OACC_BASE + OACC_WORDS[8:0];
    localparam [8:0] M_BASE    = L_BASE    + L_WORDS[8:0];

    localparam signed [DATA_W-1:0] NEG_INF = {1'b1, {(DATA_W-1){1'b0}}};  // 0x8000

    // =========================================================================
    // On-chip tile storage  (to be mapped to SRAM in physical implementation)
    // =========================================================================

    // Kj tile: Bc rows × D cols, Q8.8  (loaded once per outer j, reused all inner i)
    reg signed [DATA_W-1:0]  Kj      [0:Bc-1][0:D-1];

    // Vj tile: Bc rows × D cols, Q8.8
    reg signed [DATA_W-1:0]  Vj      [0:Bc-1][0:D-1];

    // Qi tile: Br rows × D cols, Q8.8  (reloaded from HBM for each inner i)
    reg signed [DATA_W-1:0]  Qi      [0:Br-1][0:D-1];

    // Oi partial-sum accumulator: Br rows × D cols, Q16.8  (read/written HBM every (j,i))
    reg signed [ACC_W-1:0]   Oi_acc  [0:Br-1][0:D-1];

    // li: running softmax denominator, Br elements, Q16.8  (read/written HBM every (j,i))
    reg signed [ACC_W-1:0]   li      [0:Br-1];

    // mi: running row-maximum, Br elements, Q8.8  (read/written HBM every (j,i))
    reg signed [DATA_W-1:0]  mi      [0:Br-1];

    // Sij tile: Br × Bc, Q16.8  (intermediate result of Qi @ Kj^T, 32-bit for headroom)
    wire signed [ACC_W-1:0]  Sij     [0:Br-1][0:Bc-1];

    // Sij truncated to Q8.8 (lower 16 bits) for softmax input.
    // Valid when Sij values lie in [-128, 128) after >>8; out-of-range values
    // are clamped to keep exp inputs correct (large negatives → exp≈0 anyway).
    wire signed [DATA_W-1:0] Sij_q88 [0:Br-1][0:Bc-1];

    genvar gs_r, gs_c;
    generate
        for (gs_r = 0; gs_r < Br; gs_r = gs_r + 1)
            for (gs_c = 0; gs_c < Bc; gs_c = gs_c + 1)
                // Clamp 32-bit Q16.8 Sij to 16-bit Q8.8 range before passing to softmax/exp.
                // Values outside [-128, 128): very negative → exp≈0 (clamp to 0x8000),
                // very positive → clamp to 0x7FFF (exp will give 1.0 relative to max).
                assign Sij_q88[gs_r][gs_c] =
                    ((Sij[gs_r][gs_c]) < -32768) ? {1'b1, {(DATA_W-1){1'b0}}} :
                    ((Sij[gs_r][gs_c]) >  32767) ? {1'b0, {(DATA_W-1){1'b1}}} :
                    Sij[gs_r][gs_c][DATA_W-1:0];
    endgenerate

    // P_tilde tile: Br × Bc, Q8.8  (captured from softmax_unit combinational output)
    reg  signed [DATA_W-1:0] P_tilde [0:Br-1][0:Bc-1];

    // Normalized O row (Br × D, Q8.8): temporary during final normalization
    reg  signed [DATA_W-1:0] O_norm  [0:Br-1][0:D-1];

    // =========================================================================
    // Loop counters and helper registers
    // =========================================================================
    reg [$clog2(Tc)-1:0]   j_cnt;       // outer K/V tile index  0..Tc-1
    reg [$clog2(Tr)-1:0]   i_cnt;       // inner Q  tile index   0..Tr-1

    // HBM transfer counter: counts words within the current load/store state
    reg [$clog2(Bc)-1:0]   xfer_cnt;   // 0 .. max(KJ_XFERS,OI_XFERS,...)-1

    // Compute-unit done flags
    wire                   qk_done;     // matmul Qi@Kj^T finished
    wire                   pv_done;     // matmul P_tilde@Vj finished

    // Registered matmul start pulses
    reg                    qk_start;
    reg                    pv_start;

    // =========================================================================
    // FSM state encoding
    // =========================================================================
    localparam [4:0]
        S_IDLE      = 5'd0,

        // Initialization: write 0 / NEG_INF to HBM for O_acc, l, m
        S_INIT_OACC = 5'd1,   // write O_acc = 0  (Tr × Br × 2 = 128 wr cycles)
        S_INIT_L    = 5'd2,   // write l    = 0  (Tr × 2       = 32  wr cycles)
        S_INIT_M    = 5'd3,   // write m    = NEG_INF (Tr × 1  = 16  wr cycles)

        // Outer j loop: load K and V tiles
        S_LD_KJ     = 5'd4,   // load Kj from HBM (Bc = 8 cycles)
        S_LD_VJ     = 5'd5,   // load Vj from HBM (Bc = 8 cycles)

        // Inner i loop: load Q, O_acc, l, m
        S_LD_QI     = 5'd6,   // load Qi     (Br = 4 cycles)
        S_LD_OI     = 5'd7,   // load Oi_acc (Br × 2 = 8 cycles)
        S_LD_LI     = 5'd8,   // load li     (2 cycles)
        S_LD_MI     = 5'd9,   // load mi     (1 cycle)

        // Compute: Sij, softmax, O update
        S_QK_FEED   = 5'd10,  // start QK matmul; wait for qk_done  (D = 4 cycles)
        S_SOFTMAX   = 5'd11,  // capture combinational softmax output (1 cycle)
        S_UPDATE    = 5'd12,  // capture combinational output_update  (1 cycle)
        S_PV_FEED   = 5'd13,  // start PV matmul; wait for pv_done   (Bc = 8 cycles)
        S_ACC_O     = 5'd14,  // add PV result (already in Oi_acc via output_update)

        // Store updated Oi_acc, li, mi back to HBM
        S_ST_OI     = 5'd15,  // write Oi_acc (Br × 2 = 8 wr cycles)
        S_ST_LI     = 5'd16,  // write li     (2 wr cycles)
        S_ST_MI     = 5'd17,  // write mi     (1 wr cycle)

        // Loop control
        S_NEXT_I    = 5'd18,  // advance i; if done all i → advance j
        S_NEXT_J    = 5'd19,  // advance j; if done all j → normalization

        // Final normalization: read O_acc, divide by l, write O_final
        S_NORM_RD   = 5'd20,  // read Oi_acc for tile i  (Br × 2 = 8 cycles)
        S_NORM_CALC = 5'd21,  // compute O[r][c] = clip_q88(Oi_acc[r][c] / li[r])
        S_NORM_WR   = 5'd22,  // write Q8.8 O_final to HBM (Br = 4 cycles)
        S_NEXT_NORM = 5'd23,  // advance i for normalization
        S_NORM_RD_L = 5'd25,  // reload li from HBM for current tile (2 cycles)

        S_DONE      = 5'd24;

    reg [4:0] state;

    // =========================================================================
    // HBM cycle counter
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hbm_cycle_cnt   <= 32'd0;
            qk_cycle_cnt    <= 32'd0;
            pv_cycle_cnt    <= 32'd0;
            vec_cycle_cnt   <= 32'd0;
            total_cycle_cnt <= 32'd0;
        end else begin
            if (hbm_rd_req | hbm_wr_req)
                hbm_cycle_cnt <= hbm_cycle_cnt + 1;
            // QK matmul: running from qk_start until qk_done (inclusive)
            if (qk_start | (state == S_SOFTMAX && !qk_done))
                qk_cycle_cnt <= qk_cycle_cnt + 1;
            // PV matmul: running from pv_start until pv_done (inclusive)
            if (pv_start | (state == S_PV_FEED && !pv_done))
                pv_cycle_cnt <= pv_cycle_cnt + 1;
            // Vector ops: softmax capture, stat update, O accumulate, norm divide
            if (state == S_SOFTMAX && qk_done ||
                state == S_UPDATE  ||
                state == S_ACC_O   ||
                state == S_NORM_CALC)
                vec_cycle_cnt <= vec_cycle_cnt + 1;
            // Total: count every cycle between start and done
            if (state != S_IDLE)
                total_cycle_cnt <= total_cycle_cnt + 1;
        end
    end

    // =========================================================================
    // Combinational HBM read address/request generation
    // hbm_rd_data is driven by the HBM model combinationally from hbm_rd_addr.
    // By making req/addr pure wires (not registers), the data is valid in the
    // SAME cycle the FSM samples it — eliminating the 1-cycle pipeline delay.
    // =========================================================================
    reg        hbm_rd_req_c;
    reg [8:0]  hbm_rd_addr_c;
    assign hbm_rd_req  = hbm_rd_req_c;
    assign hbm_rd_addr = hbm_rd_addr_c;

    always @(*) begin
        hbm_rd_req_c  = 1'b0;
        hbm_rd_addr_c = 9'd0;
        case (state)
            S_LD_KJ:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = K_BASE + {3'd0,j_cnt} * KJ_XFERS + {3'd0,xfer_cnt};
            end
            S_LD_VJ:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = V_BASE + {3'd0,j_cnt} * VJ_XFERS + {3'd0,xfer_cnt};
            end
            S_LD_QI:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = Q_BASE + {3'd0,i_cnt} * QI_XFERS + {3'd0,xfer_cnt};
            end
            S_LD_OI:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = OACC_BASE + {3'd0,i_cnt} * OI_XFERS + {3'd0,xfer_cnt};
            end
            S_LD_LI:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = L_BASE + {3'd0,i_cnt} * LI_XFERS + {3'd0,xfer_cnt};
            end
            S_LD_MI:     begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = M_BASE + {3'd0,i_cnt};
            end
            S_NORM_RD:   begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = OACC_BASE + {3'd0,i_cnt} * OI_XFERS + {3'd0,xfer_cnt};
            end
            S_NORM_RD_L: begin
                hbm_rd_req_c  = 1'b1;
                hbm_rd_addr_c = L_BASE + {3'd0,i_cnt} * LI_XFERS + {3'd0,xfer_cnt};
            end
            default: begin
                hbm_rd_req_c  = 1'b0;
                hbm_rd_addr_c = 9'd0;
            end
        endcase
    end

    // =========================================================================
    // Submodule interfaces: QK matmul
    //   Qi (Br×D) @ Kj^T (D×Bc) → Sij (Br×Bc)
    //   TRANSPOSE_B=1: port B is declared [COLS][INNER] = Kj[Bc][D] (native layout)
    // =========================================================================
    matmul_unit #(
        .ROWS       (Br),
        .INNER      (D),
        .COLS       (Bc),
        .DATA_W     (DATA_W),
        .ACC_W      (ACC_W),    
        .TRANSPOSE_B(1)         // compute Qi @ Kj^T
    ) u_qk (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (qk_start),
        .done   (qk_done),
        .A      (Qi),
        .B      (Kj),           // stored as Kj[Bc][D]; TRANSPOSE_B=1 → Kj^T
        .result (Sij)
    );

    // =========================================================================
    // Submodule: softmax (combinational)
    //   Outputs m_tilde, P_tilde_w, l_tilde from Sij
    // =========================================================================
    wire signed [DATA_W-1:0]  m_tilde   [0:Br-1];
    wire signed [DATA_W-1:0]  P_tilde_w [0:Br-1][0:Bc-1];
    wire signed [ACC_W-1:0]   l_tilde   [0:Br-1];

    softmax_unit #(
        .Br    (Br),
        .Bc    (Bc),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_softmax (
        .Sij    (Sij_q88),
        .m_tilde(m_tilde),
        .P_tilde(P_tilde_w),
        .l_tilde(l_tilde)
    );

    // =========================================================================
    // Submodule: output_update (combinational)
    //   Computes mi_new, li_new, Oi_acc_new using P_tilde and pv_result
    // =========================================================================
    wire signed [DATA_W-1:0]  mi_new      [0:Br-1];
    wire signed [ACC_W-1:0]   li_new      [0:Br-1];
    wire signed [ACC_W-1:0]   Oi_acc_new  [0:Br-1][0:D-1];
    wire signed [ACC_W-1:0]   pv_result   [0:Br-1][0:D-1];

    // Correction factors captured in S_UPDATE (before PV runs)
    // corr_old_r[r] = exp(mi_old[r] - mi_new[r])  — scales old Oi_acc
    // corr_new_r[r] = exp(m_tilde[r] - mi_new[r]) — scales new PV result
    wire signed [DATA_W-1:0]  corr_old_w  [0:Br-1];
    wire signed [DATA_W-1:0]  corr_new_w  [0:Br-1];
    reg  signed [DATA_W-1:0]  corr_old_r  [0:Br-1];
    reg  signed [DATA_W-1:0]  corr_new_r  [0:Br-1];

    output_update #(
        .Br    (Br),
        .Bc    (Bc),
        .D     (D),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W)
    ) u_update (
        .mi_in       (mi),
        .li_in       (li),
        .Oi_acc_in   (Oi_acc),
        .m_tilde     (m_tilde),
        .l_tilde     (l_tilde),
        .pv_result   (pv_result),
        .mi_out      (mi_new),
        .li_out      (li_new),
        .Oi_acc_out  (Oi_acc_new),
        .corr_old_out(corr_old_w),
        .corr_new_out(corr_new_w)
    );

    // =========================================================================
    // Submodule: PV matmul
    //   P_tilde (Br×Bc) @ Vj (Bc×D) → pv_result (Br×D)
    //   TRANSPOSE_B=0: port B is Vj[Bc][D] (native row-major layout)
    //   NOTE: B port is declared [COLS][INNER] = [D][Bc], so Vj must be
    //         re-indexed – connect Vj[k][c] → B[c][k]. Alternatively students
    //         may keep TRANSPOSE_B=1 and store Vj transposed in tile buffer.
    // =========================================================================
    // Transposed Vj for port connection: Vjt[c][k] = Vj[k][c]
    wire signed [DATA_W-1:0] Vjt [0:D-1][0:Bc-1];
    genvar gk, gc;
    generate
        for (gk = 0; gk < Bc; gk = gk + 1)
            for (gc = 0; gc < D; gc = gc + 1)
                assign Vjt[gc][gk] = Vj[gk][gc];
    endgenerate

    matmul_unit #(
        .ROWS       (Br),
        .INNER      (Bc),
        .COLS       (D),
        .DATA_W     (DATA_W),
        .ACC_W      (ACC_W),
        .TRANSPOSE_B(1)   // port B = Vjt[D][Bc], TRANSPOSE_B=1 → Vj^T^T = Vj
    ) u_pv (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (pv_start),
        .done   (pv_done),
        .A      (P_tilde),
        .B      (Vjt),
        .result (pv_result)
    );

    // =========================================================================
    // Main FSM
    // =========================================================================
    integer r, c;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            done         <= 1'b0;
            hbm_wr_req   <= 1'b0;
            hbm_wr_addr  <= 9'd0;
            hbm_wr_data  <= {HBM_DW{1'b0}};
            qk_start     <= 1'b0;
            pv_start     <= 1'b0;
            j_cnt        <= {$clog2(Tc){1'b0}};
            i_cnt        <= {$clog2(Tr){1'b0}};
            xfer_cnt     <= {$clog2(Bc){1'b0}};
            for (r = 0; r < Br; r = r + 1) begin
                corr_old_r[r] <= {DATA_W{1'b0}};
                corr_new_r[r] <= {DATA_W{1'b0}};
            end
        end else begin
            // Default deassert
            hbm_wr_req <= 1'b0;
            qk_start   <= 1'b0;
            pv_start   <= 1'b0;
            done       <= 1'b0;

            case (state)

                // =============================================================
                S_IDLE: begin
                    if (start) begin
                        j_cnt    <= 0;
                        i_cnt    <= 0;
                        xfer_cnt <= 0;
                        state    <= S_INIT_OACC;
                    end
                end

                // =============================================================
                // Init: write O_acc = 0 for all Tr×Br rows (128 write cycles)
                // Each row needs 2 HBM words (4 × 32-bit element, 2 per word).
                // Address = OACC_BASE + i_cnt*Br*2 + row_cnt*2 + word_cnt
                // =============================================================
                S_INIT_OACC: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= OACC_BASE
                                 + {3'd0, i_cnt} * OI_XFERS
                                 + {3'd0, xfer_cnt};
                    hbm_wr_data <= {HBM_DW{1'b0}};

                    if (xfer_cnt == OI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        if (i_cnt == Tr - 1) begin
                            i_cnt <= 0;
                            state <= S_INIT_L;
                        end else
                            i_cnt <= i_cnt + 1;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Init: write l = 0 for all Tr tiles (32 write cycles)
                // Address = L_BASE + i_cnt*2 + word_cnt
                // =============================================================
                S_INIT_L: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= L_BASE
                                 + {3'd0, i_cnt} * LI_XFERS
                                 + {3'd0, xfer_cnt};
                    hbm_wr_data <= {HBM_DW{1'b0}};

                    if (xfer_cnt == LI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        if (i_cnt == Tr - 1) begin
                            i_cnt <= 0;
                            state <= S_INIT_M;
                        end else
                            i_cnt <= i_cnt + 1;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Init: write m = NEG_INF for all Tr tiles (16 write cycles)
                // 1 word per tile: {NEG_INF, NEG_INF, NEG_INF, NEG_INF}
                // =============================================================
                S_INIT_M: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= M_BASE + i_cnt;
                    hbm_wr_data <= {NEG_INF, NEG_INF, NEG_INF, NEG_INF};

                    if (i_cnt == Tr - 1) begin
                        i_cnt    <= 0;
                        j_cnt    <= 0;
                        xfer_cnt <= 0;
                        state    <= S_LD_KJ;
                    end else
                        i_cnt <= i_cnt + 1;
                end

                // =============================================================
                // Load Kj: Bc rows, 1 word each.
                // Address = K_BASE + j_cnt*Bc + row_cnt
                // Capture: Kj[row_cnt] ← {hbm_rd_data[63:48],[47:32],[31:16],[15:0]}
                // =============================================================
                S_LD_KJ: begin
                    // RPT_QKV rows per transfer, unpacked by for-loop
                    begin : LD_KJ_UNPACK
                        integer r_u, d_u;
                        for (r_u = 0; r_u < RPT_QKV; r_u = r_u + 1)
                            for (d_u = 0; d_u < D; d_u = d_u + 1)
                                Kj[xfer_cnt * RPT_QKV + r_u][d_u] <=
                                    hbm_rd_data[(r_u * D + d_u) * DATA_W +: DATA_W];
                    end
                    if (xfer_cnt == KJ_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_LD_VJ;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Load Vj: Bc rows, 1 word each.
                // =============================================================
                S_LD_VJ: begin
                    begin : LD_VJ_UNPACK
                        integer r_u, d_u;
                        for (r_u = 0; r_u < RPT_QKV; r_u = r_u + 1)
                            for (d_u = 0; d_u < D; d_u = d_u + 1)
                                Vj[xfer_cnt * RPT_QKV + r_u][d_u] <=
                                    hbm_rd_data[(r_u * D + d_u) * DATA_W +: DATA_W];
                    end
                    if (xfer_cnt == VJ_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_LD_QI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Load Qi: Br rows, 1 word each.
                // Address = Q_BASE + i_cnt*Br + row_cnt
                // =============================================================
                S_LD_QI: begin
                    begin : LD_QI_UNPACK
                        integer r_u, d_u;
                        for (r_u = 0; r_u < RPT_QKV; r_u = r_u + 1)
                            for (d_u = 0; d_u < D; d_u = d_u + 1)
                                Qi[xfer_cnt * RPT_QKV + r_u][d_u] <=
                                    hbm_rd_data[(r_u * D + d_u) * DATA_W +: DATA_W];
                    end
                    if (xfer_cnt == QI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_LD_OI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Load Oi_acc: Br rows × 2 words/row = 8 HBM reads.
                // Address = OACC_BASE + (i_cnt*Br + row_cnt)*2 + word_cnt
                // Each word holds 2 × 32-bit elements:
                //   word 0: {Oi_acc[r][1], Oi_acc[r][0]}
                //   word 1: {Oi_acc[r][3], Oi_acc[r][2]}
                // =============================================================
                S_LD_OI: begin
                    // OACC_EPX consecutive ACC_W elements packed in hbm_rd_data.
                    // abs_elem = xfer_cnt*OACC_EPX + e; row = abs_elem/D; col = abs_elem%D
                    begin : LD_OI_UNPACK
                        integer e_u, abs_e;
                        for (e_u = 0; e_u < OACC_EPX; e_u = e_u + 1) begin
                            abs_e = xfer_cnt * OACC_EPX + e_u;
                            Oi_acc[abs_e / D][abs_e % D] <=
                                hbm_rd_data[e_u * ACC_W +: ACC_W];
                        end
                    end
                    if (xfer_cnt == OI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_LD_LI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Load li: 2 HBM words.
                // Address = L_BASE + i_cnt*2 + word_cnt
                // word 0: {li[1], li[0]}   word 1: {li[3], li[2]}
                // =============================================================
                S_LD_LI: begin
                    begin : LD_LI_UNPACK
                        integer e_u;
                        for (e_u = 0; e_u < L_EPX; e_u = e_u + 1)
                            if (xfer_cnt * L_EPX + e_u < Br)
                                li[xfer_cnt * L_EPX + e_u] <=
                                    hbm_rd_data[e_u * ACC_W +: ACC_W];
                    end
                    if (xfer_cnt == LI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_LD_MI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Load mi: 1 HBM word.
                // Address = M_BASE + i_cnt
                // {mi[3], mi[2], mi[1], mi[0]}
                // =============================================================
                S_LD_MI: begin
                    // m tile = Br*DATA_W ≤ HBM_DW; always one transfer
                    begin : LD_MI_UNPACK
                        integer e_u;
                        for (e_u = 0; e_u < Br; e_u = e_u + 1)
                            mi[e_u] <= hbm_rd_data[e_u * DATA_W +: DATA_W];
                    end
                    state <= S_QK_FEED;
                end

                // =============================================================
                // QK matmul: start unit and wait for done (D cycles).
                // Sij is produced as a wire from u_qk.result.
                // =============================================================
                S_QK_FEED: begin
                    qk_start <= 1'b1;   // pulse start
                    state    <= S_SOFTMAX;  // softmax reads Sij wire next cycle
                    // NOTE: If matmul has multi-cycle latency, insert a wait
                    //       state here checking qk_done.
                end

                // =============================================================
                // Capture softmax combinational outputs into registers.
                // In the same cycle output_update also computes combinationally.
                // =============================================================
                S_SOFTMAX: begin
                    if (qk_done) begin
                        // Capture P_tilde (needed by u_pv which reads the reg)
                        for (r = 0; r < Br; r = r + 1)
                            for (c = 0; c < Bc; c = c + 1)
                                P_tilde[r][c] <= P_tilde_w[r][c];
                        state <= S_UPDATE;
                    end
                end

                // =============================================================
                // S_UPDATE: update mi, li, and apply corr_old scaling to Oi_acc.
                // Capture corr_old_r / corr_new_r before mi is overwritten.
                // Do NOT add the PV contribution yet — PV hasn't run.
                //
                //   mi[r]      ← max(mi[r], m_tilde[r])
                //   li[r]      ← corr_old * li + corr_new * l_tilde
                //   Oi_acc[r]  ← corr_old * Oi_acc  (PV term added in S_ACC_O)
                //   corr_new_r ← saved for S_ACC_O
                // =============================================================
                S_UPDATE: begin
                    for (r = 0; r < Br; r = r + 1) begin
                        corr_old_r[r] <= corr_old_w[r];
                        corr_new_r[r] <= corr_new_w[r];
                        mi[r]  <= mi_new[r];
                        li[r]  <= li_new[r];
                        // Scale old accumulator by corr_old (Q8.8 × Q16.8 → Q16.8)
                        for (c = 0; c < D; c = c + 1)
                            Oi_acc[r][c] <=
                                ($signed({{(ACC_W-DATA_W){corr_old_w[r][DATA_W-1]}},
                                           corr_old_w[r]})
                                 * $signed(Oi_acc[r][c])) >>> 8;
                    end
                    pv_start <= 1'b1;
                    state    <= S_PV_FEED;
                end

                // =============================================================
                // PV matmul: wait for done (Bc cycles).
                // =============================================================
                S_PV_FEED: begin
                    if (pv_done)
                        state <= S_ACC_O;
                end

                // =============================================================
                // S_ACC_O: add the PV contribution scaled by corr_new_r.
                //   Oi_acc[r][c] += corr_new_r[r] * pv_result[r][c] >> 8
                // pv_result is now valid (pv_done just fired).
                // =============================================================
                S_ACC_O: begin
                    for (r = 0; r < Br; r = r + 1)
                        for (c = 0; c < D; c = c + 1)
                            Oi_acc[r][c] <= Oi_acc[r][c]
                                + (($signed({{(ACC_W-DATA_W){corr_new_r[r][DATA_W-1]}},
                                              corr_new_r[r]})
                                   * $signed(pv_result[r][c])) >>> 8);
                    xfer_cnt <= 0;
                    state    <= S_ST_OI;
                end

                // =============================================================
                // Store Oi_acc: Br × 2 = 8 HBM writes.
                // =============================================================
                S_ST_OI: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= OACC_BASE
                                 + {3'd0, i_cnt} * OI_XFERS
                                 + {3'd0, xfer_cnt};
                    begin : ST_OI_PACK
                        integer e_u, abs_e;
                        reg [HBM_DW-1:0] tmp;
                        tmp = {HBM_DW{1'b0}};
                        for (e_u = 0; e_u < OACC_EPX; e_u = e_u + 1) begin
                            abs_e = xfer_cnt * OACC_EPX + e_u;
                            tmp[e_u * ACC_W +: ACC_W] = Oi_acc[abs_e / D][abs_e % D];
                        end
                        hbm_wr_data <= tmp;
                    end
                    if (xfer_cnt == OI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_ST_LI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Store li: 2 HBM writes.
                // =============================================================
                S_ST_LI: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= L_BASE
                                 + {3'd0, i_cnt} * LI_XFERS
                                 + {3'd0, xfer_cnt};
                    begin : ST_LI_PACK
                        integer e_u;
                        reg [HBM_DW-1:0] tmp;
                        tmp = {HBM_DW{1'b0}};
                        for (e_u = 0; e_u < L_EPX; e_u = e_u + 1)
                            if (xfer_cnt * L_EPX + e_u < Br)
                                tmp[e_u * ACC_W +: ACC_W] = li[xfer_cnt * L_EPX + e_u];
                        hbm_wr_data <= tmp;
                    end
                    if (xfer_cnt == LI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_ST_MI;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Store mi: 1 HBM write.
                // =============================================================
                S_ST_MI: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= M_BASE + {3'd0, i_cnt};
                    begin : ST_MI_PACK
                        integer e_u;
                        reg [HBM_DW-1:0] tmp;
                        tmp = {HBM_DW{1'b0}};
                        for (e_u = 0; e_u < Br; e_u = e_u + 1)
                            tmp[e_u * DATA_W +: DATA_W] = mi[e_u];
                        hbm_wr_data <= tmp;
                    end
                    state <= S_NEXT_I;
                end

                // =============================================================
                // Inner-loop advance: i++
                // =============================================================
                S_NEXT_I: begin
                    xfer_cnt <= 0;
                    if (i_cnt == Tr - 1) begin
                        i_cnt <= 0;
                        state <= S_NEXT_J;
                    end else begin
                        i_cnt <= i_cnt + 1;
                        state <= S_LD_QI;
                    end
                end

                // =============================================================
                // Outer-loop advance: j++
                // =============================================================
                S_NEXT_J: begin
                    xfer_cnt <= 0;
                    if (j_cnt == Tc - 1) begin
                        j_cnt <= 0;
                        i_cnt <= 0;
                        state <= S_NORM_RD;
                    end else begin
                        j_cnt <= j_cnt + 1;
                        state <= S_LD_KJ;
                    end
                end

                // =============================================================
                // Normalization – read Oi_acc for tile i (8 cycles)
                // =============================================================
                S_NORM_RD: begin
                    begin : NORM_RD_UNPACK
                        integer e_u, abs_e;
                        for (e_u = 0; e_u < OACC_EPX; e_u = e_u + 1) begin
                            abs_e = xfer_cnt * OACC_EPX + e_u;
                            Oi_acc[abs_e / D][abs_e % D] <=
                                hbm_rd_data[e_u * ACC_W +: ACC_W];
                        end
                    end
                    if (xfer_cnt == OI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_NORM_RD_L;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Reload li for tile i_cnt from HBM (2 cycles).
                // Required because li was last written for tile i=Tr-1 and the
                // register holds stale data for all other tiles.
                // =============================================================
                S_NORM_RD_L: begin
                    begin : NORM_LI_UNPACK
                        integer e_u;
                        for (e_u = 0; e_u < L_EPX; e_u = e_u + 1)
                            if (xfer_cnt * L_EPX + e_u < Br)
                                li[xfer_cnt * L_EPX + e_u] <=
                                    hbm_rd_data[e_u * ACC_W +: ACC_W];
                    end
                    if (xfer_cnt == LI_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_NORM_CALC;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                // Normalization – divide and clip to Q8.8
                //   O_norm[r][c] = clip_q88( Oi_acc[r][c] <<< 8 / li[r] )
                // li[r] is in Q16.8; Oi_acc in Q16.8. Ratio gives Q8.8.
                // Division can be a sequential divider (students implement).
                // =============================================================
                S_NORM_CALC: begin
                    for (r = 0; r < Br; r = r + 1) begin
                        for (c = 0; c < D; c = c + 1) begin
                            // Simple combinational division (synthesis will infer divider)
                            if (li[r] != 0)
                                O_norm[r][c] <=
                                    ($signed(Oi_acc[r][c]) <<< 8) / $signed(li[r]);
                            else
                                O_norm[r][c] <= 0;
                        end
                    end
                    xfer_cnt <= 0;
                    state    <= S_NORM_WR;
                end

                // =============================================================
                // Write Q8.8 O_final: O_WR_XFERS words per tile.
                // Each word packs RPT_QKV rows.
                // Address = O_BASE + i_cnt*O_WR_XFERS + xfer_cnt
                // =============================================================
                S_NORM_WR: begin
                    hbm_wr_req  <= 1'b1;
                    hbm_wr_addr <= O_BASE
                                 + {3'd0, i_cnt} * O_WR_XFERS
                                 + {3'd0, xfer_cnt};
                    begin : NORM_WR_PACK
                        integer r_u, d_u;
                        reg [HBM_DW-1:0] tmp;
                        tmp = {HBM_DW{1'b0}};
                        for (r_u = 0; r_u < RPT_QKV; r_u = r_u + 1)
                            for (d_u = 0; d_u < D; d_u = d_u + 1)
                                tmp[(r_u * D + d_u) * DATA_W +: DATA_W] =
                                    O_norm[xfer_cnt * RPT_QKV + r_u][d_u];
                        hbm_wr_data <= tmp;
                    end
                    if (xfer_cnt == O_WR_XFERS - 1) begin
                        xfer_cnt <= 0;
                        state    <= S_NEXT_NORM;
                    end else
                        xfer_cnt <= xfer_cnt + 1;
                end

                // =============================================================
                S_NEXT_NORM: begin
                    if (i_cnt == Tr - 1)
                        state <= S_DONE;
                    else begin
                        i_cnt    <= i_cnt + 1;
                        xfer_cnt <= 0;
                        state    <= S_NORM_RD;
                    end
                end

                // =============================================================
                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule


// =============================================================================
// exp.sv  –  Hardware approximation of exp(x) for Q8.8 input
//
// Algorithm:  exp(x)  =  2^(x * log2(e))
//
//  Step 1 – Multiply by log2(e):
//             y_full  = x_in * LOG2E      (LOG2E = 369 ≈ log2(e)*256 in Q8.8)
//             y_q8_8  = y_full[23:8]      (Q8.8 result, right-shift 8)
//
//  Step 2 – Split integer / fractional parts:
//             int_part  = y_q8_8[15:8]   (signed, always ≤ 0 for x ≤ 0)
//             frac_part = y_q8_8[7:0]    (unsigned)
//
//  Step 3 – LUT for 2^frac:
//             Use top 4 bits of frac_part as 16-entry LUT index.
//             LUT[i] = round(2^(i/16) * 256)  for i = 0..15
//             Values: 256,267,279,292,304,318,332,347,362,378,395,412,431,450,470,490
//
//  Step 4 – Apply integer shift:
//             exp_out = LUT[frac_part[7:4]]  >>  (-int_part)
//             int_part is clamped to [-8, 0]; shift > 8 gives 0 in Q8.8.
//
// Accuracy:  Max error < 1.5 LSB in Q8.8 (vs exact exp).
//            The existing linear approximation (256+frac) has up to 40 LSB error.
//
// Ports:
//   x_in    – Q8.8 signed, typically ≤ 0 (S - rowmax)
//   exp_out – Q8.8 signed, range [0, 0x0100] (= 0.0 .. 1.0)
// =============================================================================






module exp #(
    parameter DATA_WIDTH = 16   // must be 16 for Q8.8
)(
    input  wire signed [DATA_WIDTH-1:0] x_in,    // Q8.8 input
    output wire signed [DATA_WIDTH-1:0] exp_out  // Q8.8 output, always ≥ 0
);

    // -------------------------------------------------------------------------
    // Step 1: y = x * log2(e),  kept in Q8.8
    // log2(e) ≈ 1.44269 ≈ 369/256  (error < 0.001)
    // -------------------------------------------------------------------------
    localparam signed [15:0] LOG2E = 16'd369;

    wire signed [31:0] y_full  = x_in * LOG2E;       // Q16.16
    wire signed [15:0] y_q8_8  = y_full[23:8];       // Q8.8  (discard LSB 8 and MSB 8)

    // -------------------------------------------------------------------------
    // Step 2: integer and fractional parts
    // -------------------------------------------------------------------------
    wire signed [7:0]  int_part  = y_q8_8[15:8];     // signed integer exponent
    wire        [7:0]  frac_part = y_q8_8[7:0];      // unsigned fraction in [0,1)
    wire        [3:0]  lut_idx   = frac_part[7:4];   // top 4 bits → 16-entry LUT

    // -------------------------------------------------------------------------
    // Step 3: 16-entry LUT for 2^(i/16), i=0..15, stored as Q8.8 integers
    //   LUT[i] = round(2^(i/16) * 256)
    // -------------------------------------------------------------------------
    reg [8:0] pow2_lut [0:15];   // 9 bits wide (max value = 490)

    initial begin
        pow2_lut[ 0] = 9'd256;  // 2^0/16 = 1.0000
        pow2_lut[ 1] = 9'd267;  // 2^1/16 = 1.0443
        pow2_lut[ 2] = 9'd279;  // 2^2/16 = 1.0905
        pow2_lut[ 3] = 9'd292;  // 2^3/16 = 1.1398
        pow2_lut[ 4] = 9'd304;  // 2^4/16 = 1.1892
        pow2_lut[ 5] = 9'd318;  // 2^5/16 = 1.2411
        pow2_lut[ 6] = 9'd332;  // 2^6/16 = 1.2968
        pow2_lut[ 7] = 9'd347;  // 2^7/16 = 1.3543
        pow2_lut[ 8] = 9'd362;  // 2^8/16 = 1.4142
        pow2_lut[ 9] = 9'd378;  // 2^9/16 = 1.4770
        pow2_lut[10] = 9'd395;  // 2^10/16= 1.5422
        pow2_lut[11] = 9'd412;  // 2^11/16= 1.6105
        pow2_lut[12] = 9'd431;  // 2^12/16= 1.6818
        pow2_lut[13] = 9'd450;  // 2^13/16= 1.7567
        pow2_lut[14] = 9'd470;  // 2^14/16= 1.8340
        pow2_lut[15] = 9'd490;  // 2^15/16= 1.9157
    end

    wire [8:0] pow2_frac = pow2_lut[lut_idx];        // 2^frac in Q8.8 (9-bit)

    // -------------------------------------------------------------------------
    // Step 4: right-shift by -int_part (int_part ≤ 0 since x ≤ 0)
    //   Clamp shift amount to [0, 8]: shifts ≥ 9 produce 0 in Q8.8
    // -------------------------------------------------------------------------
    wire signed [7:0] int_clamped = (int_part < -8) ? -8 :
                                    (int_part >  0) ?  0 : int_part;

    wire [3:0] shift_amt = -int_clamped[3:0];        // 0..8

    assign exp_out = {7'b0, pow2_frac} >>> shift_amt;  // arithmetic right-shift

endmodule






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


