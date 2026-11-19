`timescale 1ns/1ps

module tb_fft256;

    localparam int DATA_W     = 16;
    localparam int N          = 256;
    localparam int IDX_W      = 8;
    localparam int CLK_PERIOD = 10;
    localparam int TOL        = 0;

    logic clk_i;
    logic resetn_i;

    logic frame_start_i;
    logic in_valid_i;
    logic in_ch_sel_i;

    logic signed [DATA_W-1:0] in0_re_i;
    logic signed [DATA_W-1:0] in0_im_i;
    logic signed [DATA_W-1:0] in1_re_i;
    logic signed [DATA_W-1:0] in1_im_i;

    logic out_valid_o;
    logic out_ch_sel_o;
    logic out_last_o;

    logic [IDX_W-1:0] out_idx0_o;
    logic [IDX_W-1:0] out_idx1_o;

    logic signed [DATA_W-1:0] out0_re_o;
    logic signed [DATA_W-1:0] out0_im_o;
    logic signed [DATA_W-1:0] out1_re_o;
    logic signed [DATA_W-1:0] out1_im_o;

    integer ch0_re [0:N-1];
    integer ch0_im [0:N-1];
    integer ch1_re [0:N-1];
    integer ch1_im [0:N-1];

    integer exp_ch0_re [0:N-1];
    integer exp_ch0_im [0:N-1];
    integer exp_ch1_re [0:N-1];
    integer exp_ch1_im [0:N-1];

    integer got_ch0_re [0:N-1];
    integer got_ch0_im [0:N-1];
    integer got_ch1_re [0:N-1];
    integer got_ch1_im [0:N-1];

    integer i;
    integer fd;
    integer status;
    integer errors;
    integer total_errors;
    integer timeout_count;

    string line;
    string test_name;

    fft256_top #(
        .DATA_W(DATA_W),
        .N(N),
        .IDX_W(IDX_W)
    ) dut (
        .clk_i(clk_i),
        .resetn_i(resetn_i),

        .frame_start_i(frame_start_i),
        .in_valid_i(in_valid_i),
        .in_ch_sel_i(in_ch_sel_i),

        .in0_re_i(in0_re_i),
        .in0_im_i(in0_im_i),
        .in1_re_i(in1_re_i),
        .in1_im_i(in1_im_i),

        .out_valid_o(out_valid_o),
        .out_ch_sel_o(out_ch_sel_o),
        .out_last_o(out_last_o),

        .out_idx0_o(out_idx0_o),
        .out_idx1_o(out_idx1_o),

        .out0_re_o(out0_re_o),
        .out0_im_o(out0_im_o),
        .out1_re_o(out1_re_o),
        .out1_im_o(out1_im_o)
    );

    initial begin
        clk_i = 1'b0;
    end

    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    function integer abs_int(input integer x);
        begin
            if (x < 0)
                abs_int = -x;
            else
                abs_int = x;
        end
    endfunction

    task drive_idle;
        begin
            frame_start_i = 1'b0;
            in_valid_i    = 1'b0;
            in_ch_sel_i   = 1'b0;

            in0_re_i = '0;
            in0_im_i = '0;
            in1_re_i = '0;
            in1_im_i = '0;
        end
    endtask

    task do_reset;
        begin
            resetn_i = 1'b0;
            drive_idle();

            repeat (5) @(posedge clk_i);

            @(negedge clk_i);
            resetn_i = 1'b1;

            @(posedge clk_i);
        end
    endtask

    task clear_arrays;
        begin
            for (i = 0; i < N; i = i + 1) begin
                ch0_re[i] = 0;
                ch0_im[i] = 0;
                ch1_re[i] = 0;
                ch1_im[i] = 0;

                exp_ch0_re[i] = 0;
                exp_ch0_im[i] = 0;
                exp_ch1_re[i] = 0;
                exp_ch1_im[i] = 0;

                got_ch0_re[i] = 0;
                got_ch0_im[i] = 0;
                got_ch1_re[i] = 0;
                got_ch1_im[i] = 0;
            end
        end
    endtask

    task load_input_file;
        input string fname;

        integer idx;
        integer a;
        integer b;
        integer c;
        integer d;

        begin
            fd = $fopen(fname, "r");

            if (fd == 0) begin
                $display("ERROR: Cannot open input file: %s", fname);
                $finish;
            end

            idx = 0;

            while (!$feof(fd)) begin
                line = "";
                void'($fgets(line, fd));

                if (line.len() != 0 && line.substr(0,0) != "#") begin
                    status = $sscanf(line, "%d %d %d %d", a, b, c, d);

                    if (status == 4 && idx < N) begin
                        ch0_re[idx] = a;
                        ch0_im[idx] = b;
                        ch1_re[idx] = c;
                        ch1_im[idx] = d;
                        idx = idx + 1;
                    end
                end
            end

            $fclose(fd);

            if (idx != N) begin
                $display("ERROR: Input file %s has %0d samples, expected %0d", fname, idx, N);
                $finish;
            end
        end
    endtask

    task load_expected_file;
        input string fname;

        integer eidx;
        integer a;
        integer b;
        integer c;
        integer d;

        begin
            fd = $fopen(fname, "r");

            if (fd == 0) begin
                $display("ERROR: Cannot open expected file: %s", fname);
                $finish;
            end

            while (!$feof(fd)) begin
                line = "";
                void'($fgets(line, fd));

                if (line.len() != 0 && line.substr(0,0) != "#") begin
                    status = $sscanf(line, "%d %d %d %d %d", eidx, a, b, c, d);

                    if (status == 5 && eidx >= 0 && eidx < N) begin
                        exp_ch0_re[eidx] = a;
                        exp_ch0_im[eidx] = b;
                        exp_ch1_re[eidx] = c;
                        exp_ch1_im[eidx] = d;
                    end
                end
            end

            $fclose(fd);
        end
    endtask

    task send_frames;
        integer k;
        begin
            for (k = 0; k < N; k = k + 2) begin
                @(negedge clk_i);

                in_valid_i    = 1'b1;
                in_ch_sel_i   = 1'b0;
                frame_start_i = (k == 0);

                in0_re_i = ch0_re[k];
                in0_im_i = ch0_im[k];
                in1_re_i = ch0_re[k+1];
                in1_im_i = ch0_im[k+1];
            end

            for (k = 0; k < N; k = k + 2) begin
                @(negedge clk_i);

                in_valid_i    = 1'b1;
                in_ch_sel_i   = 1'b1;
                frame_start_i = 1'b0;

                in0_re_i = ch1_re[k];
                in0_im_i = ch1_im[k];
                in1_re_i = ch1_re[k+1];
                in1_im_i = ch1_im[k+1];
            end

            @(negedge clk_i);
            drive_idle();
        end
    endtask

    always_ff @(posedge clk_i) begin
        if (resetn_i && out_valid_o) begin
            if (out_ch_sel_o == 1'b0) begin
                got_ch0_re[out_idx0_o] <= out0_re_o;
                got_ch0_im[out_idx0_o] <= out0_im_o;

                got_ch0_re[out_idx1_o] <= out1_re_o;
                got_ch0_im[out_idx1_o] <= out1_im_o;
            end else begin
                got_ch1_re[out_idx0_o] <= out0_re_o;
                got_ch1_im[out_idx0_o] <= out0_im_o;

                got_ch1_re[out_idx1_o] <= out1_re_o;
                got_ch1_im[out_idx1_o] <= out1_im_o;
            end
        end
    end

    task compare_results;
        begin
            errors = 0;

            $display("");
            $display("====================================================");
            $display("Comparing test: %s", test_name);
            $display("====================================================");

            for (i = 0; i < N; i = i + 1) begin
                if ((abs_int(got_ch0_re[i] - exp_ch0_re[i]) > TOL) ||
                    (abs_int(got_ch0_im[i] - exp_ch0_im[i]) > TOL)) begin
                    $display("MISMATCH CH0[%0d]: RTL=(%0d,%0d), MATLAB=(%0d,%0d)",
                        i,
                        got_ch0_re[i],
                        got_ch0_im[i],
                        exp_ch0_re[i],
                        exp_ch0_im[i]
                    );
                    errors = errors + 1;
                end

                if ((abs_int(got_ch1_re[i] - exp_ch1_re[i]) > TOL) ||
                    (abs_int(got_ch1_im[i] - exp_ch1_im[i]) > TOL)) begin
                    $display("MISMATCH CH1[%0d]: RTL=(%0d,%0d), MATLAB=(%0d,%0d)",
                        i,
                        got_ch1_re[i],
                        got_ch1_im[i],
                        exp_ch1_re[i],
                        exp_ch1_im[i]
                    );
                    errors = errors + 1;
                end
            end

            if (errors == 0)
                $display("PASS: %s", test_name);
            else
                $display("FAIL: %s, mismatches = %0d", test_name, errors);

            total_errors = total_errors + errors;
        end
    endtask

    task run_test;
        input string tname;
        input string ifile;
        input string efile;

        begin
            test_name = tname;

            clear_arrays();

            load_input_file(ifile);
            load_expected_file(efile);

            do_reset();

            fork
                begin
                    send_frames();
                end

                begin
                    timeout_count = 0;

                    while (!out_last_o && timeout_count < 5000) begin
                        @(posedge clk_i);
                        timeout_count = timeout_count + 1;
                    end

                    if (timeout_count >= 5000) begin
                        $display("ERROR: Timeout waiting for out_last_o in test %s", test_name);
                        $finish;
                    end
                end
            join

            repeat (4) @(posedge clk_i);

            compare_results();
        end
    endtask

    initial begin
        $display("");
        $display("====================================================");
        $display(" MATLAB Vector Comparison TB");
        $display(" 256-point 2-channel 2-parallel contiguous DIF FFT");
        $display("====================================================");

        total_errors = 0;

        drive_idle();
        resetn_i = 1'b0;

        run_test("zero",    "fft256_input_zero.txt",    "fft256_expected_zero.txt");
        run_test("impulse", "fft256_input_impulse.txt", "fft256_expected_impulse.txt");
        run_test("cosine",  "fft256_input_cosine.txt",  "fft256_expected_cosine.txt");
        run_test("random",  "fft256_input_random.txt",  "fft256_expected_random.txt");

        $display("");
        $display("====================================================");

        if (total_errors == 0)
            $display("ALL MATLAB VECTOR TESTS PASSED");
        else
            $display("SOME TESTS FAILED: total mismatches = %0d", total_errors);

        $display("====================================================");

        #20;
        $finish;
    end

endmodule
