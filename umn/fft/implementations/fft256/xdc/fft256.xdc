####################################################################################
# 256-point FFT timing constraints
####################################################################################

# Main clock
create_clock -name clk_i -period 10 [get_ports clk_i]

# Input delays: apply to all inputs except clk_i
set_input_delay -clock clk_i 1 [get_ports -filter { NAME !~ "clk_i" && DIRECTION == "IN" }]

# Output delays: apply to all outputs
set_output_delay -clock clk_i 1 [get_ports -filter { DIRECTION == "OUT" }]

# Reset is asynchronous active-low, so don't time it as normal data
set_false_path -from [get_ports resetn_i]

current_instance -quiet
