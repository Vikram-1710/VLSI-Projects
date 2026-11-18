###############################################
# Clock Definition
create_clock -name CLK -period 2 [get_ports clk]

###############################################
# Input Constraints
set_driving_cell -lib_cell BUFFD2BWP20P90 \
  -input_transition_rise 0.1 \
  -input_transition_fall 0.1 \
  [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]

set_input_delay 0.08 -clock [get_clocks CLK] \
  [remove_from_collection [all_inputs] [get_ports {clk rst_n}]]

###############################################
# Output Constraints
set_load [expr [load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4] [all_outputs]
set_output_delay 0.12 -clock [get_clocks CLK] [all_outputs]

###############################################
set_false_path -from [get_ports rst_n]
