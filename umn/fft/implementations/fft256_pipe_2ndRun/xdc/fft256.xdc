####################################################################################
# 256-point FFT timing constraints
####################################################################################


create_clock -name clk -period 8 [get_ports clk_i]

set_input_delay -clock clk 1 [get_ports -filter { NAME !~ "clk_i" && DIRECTION == "IN" }]

set_output_delay -clock clk 1 [get_ports -filter { NAME !~ "clk_i" && DIRECTION == "OUT" }]

current_instance -quiet
