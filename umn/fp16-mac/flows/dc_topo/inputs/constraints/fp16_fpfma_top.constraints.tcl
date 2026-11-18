###############################################
# Clock Definition
#create_clock -name CLK -period 5 clk
create_clock -name CLK -period 1 clk

###############################################
# Input Constraints
#set_driving_cell -lib_cell I1025_EW -from_pin PADIO -input_transition_rise 0.2 -input_transition_fall 0.2 [all_inputs]
#set_input_delay 0.08 -clock [get_clocks CLK] [all_inputs]
set_driving_cell -lib_cell BUFFD2BWP20P90 -input_transition_rise 0.1 -input_transition_fall 0.1 [all_inputs]
set_input_delay 0.02 -clock [get_clocks CLK] [all_inputs]

###############################################
# Output Constraints
# set_load [load_of [get_lib_pins */D4I1025_EW/DIN]] [all_outputs]
# set_output_delay 0.12 -clock [get_clocks CLK] [all_outputs]
set_load [expr [load_of [get_lib_pins */BUFFD2BWP20P90/I]] * 4] [all_outputs]
set_output_delay 0.06 -clock [get_clocks CLK] [all_outputs]

###############################################
# Set Max Area constraint
set_max_area 0

###############################################
# Set Design Constraints (Max Transition / Max Capacitance)
# set_max_transition 1.5 *
# set_max_capacitance 150 *
set_max_transition 0.3 *
set_max_capacitance 30 *

###############################################
# Set Clock Uncertainity & Pre-CTS Network Latency
#set_clock_uncertainty 0.2 [get_clocks CLK]
#set_clock_latency 1.0 [get_clocks CLK]
set_clock_uncertainty 0.05 [get_clocks CLK]
set_clock_latency 0.2 [get_clocks CLK]

###############################################
# Set up constraints for clock gating
#set_clock_gating_check -setup 0.3 -hold 0.3
set_clock_gating_check -setup 0.05 -hold 0.05
