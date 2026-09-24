#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p results
for config in '3 2' '1 1' '4 3'; do
    read -r yellow all_red <<< "$config"
    run_dir="results/y${yellow}_r${all_red}"
    mkdir -p "$run_dir"
    iverilog -g2012 -Wall -s traffic_light_controller_tb \
        -Ptraffic_light_controller_tb.YELLOW_CYCLES="$yellow" \
        -Ptraffic_light_controller_tb.ALL_RED_CYCLES="$all_red" \
        -o "$run_dir/simv" rtl/traffic_light_controller.v tb/traffic_light_controller_tb.sv \
        2>&1 | tee "$run_dir/compile.log"
    (cd "$run_dir" && vvp simv 2>&1 | tee simulation.log)
done
# Optional structural synthesis check; no technology mapping or PPA claims.
if command -v yosys >/dev/null 2>&1; then
    yosys -p 'read_verilog rtl/traffic_light_controller.v; hierarchy -check -top traffic_light_controller; proc; opt; check -assert; stat' \
        2>&1 | tee results/synthesis_check.log
fi
