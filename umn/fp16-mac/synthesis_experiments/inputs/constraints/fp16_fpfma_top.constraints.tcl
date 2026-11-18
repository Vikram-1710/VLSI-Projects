###############################################
# Clock Definition
create_clock -name CLK -period 5 [get_ports clk]
###############################################
## Input Constraints
set_driving_cell -lib_cell BUFFD2BWP20P90 -input_transition_rise 0.1 -input_transition_fall 0.1 [all_inputs]
set_input_delay 0.02 -clock [get_clocks CLK] [remove_from_collection [all_inputs] [get_ports clk]]
###############################################
# Output Constraints
set_load [expr [load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4] [all_outputs]
set_output_delay 0.06 -clock [get_clocks CLK] [all_outputs]

###############################################
## Set Max Area Constraint
set_max_area 0
