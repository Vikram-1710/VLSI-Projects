`timescale 1ns/1ps
module traffic_light_controller_tb;
    parameter integer YELLOW_CYCLES=3, ALL_RED_CYCLES=2;
    localparam [1:0] RED=0, YELLOW=1, GREEN=2;
    reg clock=0, reset=1, X=0;
    wire [1:0] hwy, cntry;
    integer checks=0, phase, i;
    traffic_light_controller #(
        .YELLOW_CYCLES(YELLOW_CYCLES), .ALL_RED_CYCLES(ALL_RED_CYCLES)
    ) dut (.hwy(hwy), .cntry(cntry), .X(X), .clock(clock), .reset(reset));
    always #5 clock=~clock;

    task automatic step(input bit rst, input bit sensor,
                        input [1:0] expected_hwy, expected_cntry);
        @(negedge clock);
        reset=rst; X=sensor;
        @(posedge clock); #1;
        checks++;
        if ((hwy !== expected_hwy) || (cntry !== expected_cntry))
            $fatal(1,"Check %0d: expected %0d/%0d, got %0d/%0d",
                   checks,expected_hwy,expected_cntry,hwy,cntry);
    endtask

    // Reach a phase using only public inputs and check every intervening cycle.
    task automatic reach_phase(input integer target_phase);
        step(1,0,GREEN,RED);
        step(0,0,GREEN,RED);
        if (target_phase >= 1) step(0,1,YELLOW,RED);
        if (target_phase >= 2) begin
            for (integer n=1;n<YELLOW_CYCLES;n++) step(0,n%2,YELLOW,RED);
            step(0,1,RED,RED);
        end
        if (target_phase >= 3) begin
            for (integer n=1;n<ALL_RED_CYCLES;n++) step(0,n%2,RED,RED);
            step(0,1,RED,GREEN);
        end
        if (target_phase >= 4) step(0,0,RED,YELLOW);
    endtask

    // Independent output invariant, sampled after sequential updates settle.
    always @(posedge clock) begin
        #2;
        if ($isunknown({hwy,cntry}) || hwy>GREEN || cntry>GREEN)
            $fatal(1,"Unknown or illegal output encoding");
        if ((hwy != RED) && (cntry != RED))
            $fatal(1,"Conflicting non-red signals");
    end

    initial begin
        if (YELLOW_CYCLES<1 || ALL_RED_CYCLES<1)
            $fatal(1,"Phase durations must be positive");
        $dumpfile("traffic_light.vcd");
        $dumpvars(0,traffic_light_controller_tb);
        step(1,0,GREEN,RED);
        repeat(4) step(0,0,GREEN,RED);
        reach_phase(3);
        repeat(4) step(0,1,RED,GREEN);
        step(0,0,RED,YELLOW);
        for(i=1;i<YELLOW_CYCLES;i++) step(0,i%2,RED,YELLOW);
        step(0,0,GREEN,RED);
        // A second request after completion exercises repeated service.
        reach_phase(4);
        for(i=1;i<YELLOW_CYCLES;i++) step(0,1,RED,YELLOW);
        step(0,1,GREEN,RED);
        step(0,1,YELLOW,RED);
        // Reset has priority over a simultaneous sensor request in every phase.
        for(phase=0;phase<5;phase++) begin
            reach_phase(phase);
            step(1,1,GREEN,RED);
            step(0,0,GREEN,RED);
        end
        $display("PASS: %0d output checks; yellow=%0d all-red=%0d",
                 checks,YELLOW_CYCLES,ALL_RED_CYCLES);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Watchdog timeout");
    end
endmodule
