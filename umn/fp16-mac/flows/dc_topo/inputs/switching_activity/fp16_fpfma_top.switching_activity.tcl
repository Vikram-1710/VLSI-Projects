###################################
# Define the swicthing activity for
# the primary ports
###################################
#set_switching_activity -static_probability 0.01 -toggle_rate 1.5625 -period 1000 [get_ports enable]
#set_switching_activity -static_probability 0.5 -toggle_rate 15.625 -period 1000 [get_ports up]
#set_switching_activity -static_probability 0.995 -toggle_rate 0.015625 -period 1000 [get_ports rst]
#set_switching_activity -static_probability 0 -toggle_rate 0 -period 1000 [get_ports test_se]
#set_switching_activity -static_probability 0 -toggle_rate 0 -period 1000 [get_ports test_si]

set_switching_activity -toggle_rate 1.5625 -static_probability 0.01 [get_ports enable] -period 10
set_switching_activity -toggle_rate 15.625 -static_probability 0.5 [get_ports up] -period 10
set_switching_activity -toggle_rate 0.015625 -static_probability 0.995 [get_ports rst] -period 10
set_switching_activity -static_probability 0 -toggle_rate 0 -period 10 [get_ports test_se]
set_switching_activity -static_probability 0 -toggle_rate 0 -period 10 [get_ports test_si]
