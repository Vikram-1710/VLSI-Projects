`timescale 1ns/1ps
module traffic_light_controller #(
    parameter integer YELLOW_CYCLES = 3,
    parameter integer ALL_RED_CYCLES = 2
)(
    output reg [1:0] hwy, cntry,
    input wire X, clock, reset
);
    localparam [1:0] RED=0, YELLOW=1, GREEN=2;
    localparam [2:0] S0=0, S1=1, S2=2, S3=3, S4=4;
    localparam integer MAX_CYCLES = (YELLOW_CYCLES > ALL_RED_CYCLES)
                                   ? YELLOW_CYCLES : ALL_RED_CYCLES;
    localparam integer TIMER_W = (MAX_CYCLES <= 1) ? 1 : $clog2(MAX_CYCLES);
    reg [2:0] state, next_state;
    reg [TIMER_W-1:0] timer;

    // Parameters must be >= 1; X is assumed synchronous to clock.
    always @(posedge clock) begin
        if (reset) begin
            state <= S0;
            timer <= 0;
        end else begin
            state <= next_state;
            if (state != next_state)
                timer <= 0;
            else if ((state == S1) || (state == S2) || (state == S4))
                timer <= timer + 1'b1;
            else
                timer <= 0;
        end
    end

    always @* begin
        next_state = state;
        case (state)
            S0: if (X) next_state = S1;
            S1: if (timer == YELLOW_CYCLES-1) next_state = S2;
            S2: if (timer == ALL_RED_CYCLES-1) next_state = S3;
            S3: if (!X) next_state = S4;
            S4: if (timer == YELLOW_CYCLES-1) next_state = S0;
            default: next_state = S0;
        endcase
    end

    always @* begin
        hwy = RED;
        cntry = RED;
        case (state)
            S0: hwy = GREEN;
            S1: hwy = YELLOW;
            S2: begin hwy = RED; cntry = RED; end
            S3: cntry = GREEN;
            S4: cntry = YELLOW;
            default: begin hwy = RED; cntry = RED; end
        endcase
    end
endmodule
