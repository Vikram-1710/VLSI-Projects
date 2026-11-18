// =============================================================================
// tb_flash_attention_top.v  –  Testcase 3 verification for flash_attention_top
//
// Reads fa_tc3_Q.txt / fa_tc3_K.txt / fa_tc3_V.txt (Q8.8 hex, one value/line,
// row-major N×D = 64×4 = 256 lines each) and loads them into the HBM model.
// After simulation completes, reads O_final from HBM and compares with
// fa_tc3_O_flash.txt element-by-element, reporting any mismatches.
//
// HBM layout is derived from HBM_DW exactly as flash_attention_top.sv does,
// so changing HBM_DW here automatically adjusts base addresses and packing.
//
// Run from the FlashAttention/ directory:
//   iverilog -g2005-sv -o sim.out tb_flash_attention_top.v \
//       flash_attention_top.sv matmul_unit.sv softmax_unit.sv \
//       output_update.sv exp.sv && vvp sim.out
// =============================================================================

module tb_flash_attention_top;

    // =========================================================================
    // Parameters  (must match flash_attention_top instantiation)
    // =========================================================================
    parameter integer Bc      = 8;
    parameter integer N       = 64;
    parameter integer D       = 4;
    parameter integer DATA_W  = 16;   // Q8.8
    parameter integer ACC_W   = 32;
    parameter integer HBM_DW  = 64;  // must be a multiple of D*DATA_W = 64

    // Derived tile dimensions
    parameter integer Br   = D;        // 4
    parameter integer Tc   = N / Bc;   // 8
    parameter integer Tr   = N / Br;   // 16

    // =========================================================================
    // HBM transfer geometry  (mirrors flash_attention_top.sv localparams exactly)
    // =========================================================================
    localparam RPT_QKV    = HBM_DW / (D * DATA_W);               // rows per Q/K/V/O word
    localparam OACC_EPX   = HBM_DW / ACC_W;                       // ACC_W elems per O_acc word
    localparam LI_XFERS   = (Br * ACC_W + HBM_DW - 1) / HBM_DW;  // l words per tile
    localparam Q_WORDS    = N / RPT_QKV;                          // words per Q/K/V matrix
    localparam OACC_WORDS = (N * D * ACC_W) / HBM_DW;             // words for O_acc
    localparam L_WORDS    = Tr * LI_XFERS;                        // words for l
    localparam M_WORDS    = Tr;                                    // words for m
    localparam O_WR_XFERS = Br / RPT_QKV;                         // words per O_final tile

    // =========================================================================
    // HBM base addresses  (computed the same way as flash_attention_top.sv)
    // =========================================================================
    localparam [8:0] Q_BASE    = 9'd0;
    localparam [8:0] K_BASE    = Q_BASE    + Q_WORDS[8:0];
    localparam [8:0] V_BASE    = K_BASE    + Q_WORDS[8:0];
    localparam [8:0] O_BASE    = V_BASE    + Q_WORDS[8:0];
    localparam [8:0] OACC_BASE = O_BASE    + Q_WORDS[8:0];
    localparam [8:0] L_BASE    = OACC_BASE + OACC_WORDS[8:0];
    localparam [8:0] M_BASE    = L_BASE    + L_WORDS[8:0];

    // =========================================================================
    // Input / reference file paths  (relative to simulation working directory)
    // =========================================================================
    parameter Q_FILE = "fa_tc3_Q.txt";
    parameter K_FILE = "fa_tc3_K.txt";
    parameter V_FILE = "fa_tc3_V.txt";
    parameter O_FILE = "fa_tc3_O_flash.txt";

    // =========================================================================
    // Signals
    // =========================================================================
    reg            clk;
    reg            rst_n;
    reg            start;

    wire           hbm_rd_req;
    wire [8:0]     hbm_rd_addr;
    reg  [HBM_DW-1:0] hbm_rd_data;

    wire           hbm_wr_req;
    wire [8:0]     hbm_wr_addr;
    wire [HBM_DW-1:0] hbm_wr_data;

    wire           done;
    wire [31:0]    hbm_cycle_cnt;
    wire [31:0]    qk_cycle_cnt;
    wire [31:0]    pv_cycle_cnt;
    wire [31:0]    vec_cycle_cnt;
    wire [31:0]    total_cycle_cnt;

    // =========================================================================
    // HBM memory model  (512 words × HBM_DW-bit)
    // =========================================================================
    reg [HBM_DW-1:0] hbm_mem [0:511];

    // Combinational read: data valid in the same cycle as req/addr
    always @(*) begin
        hbm_rd_data = hbm_mem[hbm_rd_addr];
    end

    // Synchronous write
    always @(posedge clk) begin
        if (hbm_wr_req)
            hbm_mem[hbm_wr_addr] <= hbm_wr_data;
    end

    // =========================================================================
    // DUT
    // =========================================================================
    flash_attention_top #(
        .Bc    (Bc),
        .N     (N),
        .D     (D),
        .DATA_W(DATA_W),
        .ACC_W (ACC_W),
        .HBM_DW(HBM_DW)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (start),
        .done         (done),
        .hbm_rd_req   (hbm_rd_req),
        .hbm_rd_addr  (hbm_rd_addr),
        .hbm_rd_data  (hbm_rd_data),
        .hbm_wr_req   (hbm_wr_req),
        .hbm_wr_addr  (hbm_wr_addr),
        .hbm_wr_data  (hbm_wr_data),
        .hbm_cycle_cnt  (hbm_cycle_cnt),
        .qk_cycle_cnt   (qk_cycle_cnt),
        .pv_cycle_cnt   (pv_cycle_cnt),
        .vec_cycle_cnt  (vec_cycle_cnt),
        .total_cycle_cnt(total_cycle_cnt)
    );

    // =========================================================================
    // Clock  (10 ns period)
    // =========================================================================
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // =========================================================================
    // Temporary flat arrays for $readmemh
    // Layout: [row * D + col]  →  Q8.8 value, row-major
    // =========================================================================
    reg [DATA_W-1:0] q_raw [0:N*D-1];
    reg [DATA_W-1:0] k_raw [0:N*D-1];
    reg [DATA_W-1:0] v_raw [0:N*D-1];
    reg [DATA_W-1:0] o_ref [0:N*D-1];

    // =========================================================================
    // Waveform dump  (optional – comment out if not needed)
    // =========================================================================
    initial begin
        $dumpfile("tb_flash_attention_top.vcd");
        $dumpvars(0, tb_flash_attention_top);
    end

    // =========================================================================
    // Main test sequence
    // =========================================================================
    integer row, col, idx;
    integer r_in_word, d_col, word_idx;
    integer errors, total;
    reg [DATA_W-1:0] got_val, exp_val;
    integer diff;

    initial begin
        // ------------------------------------------------------------------
        // 1. Load source matrices from text files
        // ------------------------------------------------------------------
        $readmemh(Q_FILE, q_raw);
        $readmemh(K_FILE, k_raw);
        $readmemh(V_FILE, v_raw);
        $readmemh(O_FILE, o_ref);

        $display("==============================================");
        $display(" FlashAttention tc3 Verification");
        $display(" N=%0d  D=%0d  Br=%0d  Bc=%0d  Tc=%0d  Tr=%0d",
                 N, D, Br, Bc, Tc, Tr);
        $display(" HBM_DW=%0d  RPT_QKV=%0d  Q_BASE=%0d  K_BASE=%0d  V_BASE=%0d  O_BASE=%0d",
                 HBM_DW, RPT_QKV, Q_BASE, K_BASE, V_BASE, O_BASE);
        $display("==============================================");

        // ------------------------------------------------------------------
        // 2. Initialise HBM to zero
        // ------------------------------------------------------------------
        for (idx = 0; idx < 512; idx = idx + 1)
            hbm_mem[idx] = {HBM_DW{1'b0}};

        // ------------------------------------------------------------------
        // 3. Pack Q, K, V into HBM
        //    RPT_QKV rows are packed into each HBM word.
        //    Layout within one word:
        //      bits [(r*D+d)*DATA_W +: DATA_W] = matrix[word_idx*RPT_QKV+r][d]
        // ------------------------------------------------------------------
        for (word_idx = 0; word_idx < N / RPT_QKV; word_idx = word_idx + 1) begin
            for (r_in_word = 0; r_in_word < RPT_QKV; r_in_word = r_in_word + 1)
                for (d_col = 0; d_col < D; d_col = d_col + 1) begin
                    hbm_mem[Q_BASE + word_idx][(r_in_word*D + d_col)*DATA_W +: DATA_W] =
                        q_raw[(word_idx*RPT_QKV + r_in_word)*D + d_col];
                    hbm_mem[K_BASE + word_idx][(r_in_word*D + d_col)*DATA_W +: DATA_W] =
                        k_raw[(word_idx*RPT_QKV + r_in_word)*D + d_col];
                    hbm_mem[V_BASE + word_idx][(r_in_word*D + d_col)*DATA_W +: DATA_W] =
                        v_raw[(word_idx*RPT_QKV + r_in_word)*D + d_col];
                end
        end

        $display("[%8t ns] Q/K/V loaded into HBM (RPT_QKV=%0d rows/word).", $time, RPT_QKV);

        // ------------------------------------------------------------------
        // 4. Reset
        // ------------------------------------------------------------------
        rst_n = 1'b0;
        start = 1'b0;
        repeat (4) @(posedge clk);
        #1 rst_n = 1'b1;
        repeat (2) @(posedge clk);

        // ------------------------------------------------------------------
        // 5. Start
        // ------------------------------------------------------------------
        $display("[%8t ns] Asserting start.", $time);
        #1 start = 1'b1;
        @(posedge clk);
        #1 start = 1'b0;

        // ------------------------------------------------------------------
        // 6. Wait for done
        // ------------------------------------------------------------------
        wait (done === 1'b1);
        @(posedge clk);

        $display("[%8t ns] Done received. HBM transfer cycles = %0d",
                 $time, hbm_cycle_cnt);

        // ------------------------------------------------------------------
        // 7. Compare O_final with reference
        //
        //    O_final is packed with RPT_QKV rows per HBM word:
        //      word address = O_BASE + row / RPT_QKV
        //      bit  offset  = ((row % RPT_QKV) * D + col) * DATA_W
        // ------------------------------------------------------------------
        errors = 0;
        total  = 0;

        for (row = 0; row < N; row = row + 1) begin
            for (col = 0; col < D; col = col + 1) begin
                got_val = hbm_mem[O_BASE + row/RPT_QKV]
                                 [((row % RPT_QKV) * D + col) * DATA_W +: DATA_W];
                exp_val = o_ref[row * D + col];
                total   = total + 1;

                diff = $signed(got_val) - $signed(exp_val);
                if (diff < 0) diff = -diff;

                $display("  [row=%2d][col=%0d]  got=%04h (%7.3f)  exp=%04h (%7.3f)  err=%0d LSB%s",
                    row, col,
                    got_val, $itor($signed(got_val)) / 256.0,
                    exp_val, $itor($signed(exp_val)) / 256.0,
                    diff,
                    (diff >= 3) ? "  <-- FAIL" : "");

                if (diff >= 3)
                    errors = errors + 1;
            end
        end

        // ------------------------------------------------------------------
        // 8. Summary
        // ------------------------------------------------------------------
        $display("----------------------------------------------");
        if (errors == 0) begin
            $display("PASS  –  all %0d elements within 3 LSB of fa_tc3_O_flash.txt", total);
        end else begin
            $display("FAIL  –  %0d / %0d elements exceed 3 LSB error", errors, total);
        end
        $display("----------------------------------------------");
        $display("Cycle breakdown:");
        $display("  HBM transfers      : %0d", hbm_cycle_cnt);
        $display("  QK matmul          : %0d", qk_cycle_cnt);
        $display("  PV matmul          : %0d", pv_cycle_cnt);
        $display("  Vector ops         : %0d", vec_cycle_cnt);
        $display("  Total (start->done): %0d", total_cycle_cnt);
        $display("==============================================");

        $finish;
    end

    // =========================================================================
    // Watchdog: abort after 10 M cycles to prevent infinite loops
    // =========================================================================
    initial begin
        #100_000_000;
        $display("WATCHDOG TIMEOUT at %0t ns – simulation never completed.", $time);
        $finish;
    end

    // =========================================================================
    // Monitor HBM bus activity every 1000 cycles
    // =========================================================================
    integer cycle_cnt_tb;
    initial cycle_cnt_tb = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_cnt_tb = cycle_cnt_tb + 1;
            if (cycle_cnt_tb % 1000 == 0)
                $display("[%8t ns] cycle=%0d  hbm_rd=%b@%0d  hbm_wr=%b@%0d",
                    $time, cycle_cnt_tb,
                    hbm_rd_req, hbm_rd_addr,
                    hbm_wr_req, hbm_wr_addr);
        end
    end

endmodule
