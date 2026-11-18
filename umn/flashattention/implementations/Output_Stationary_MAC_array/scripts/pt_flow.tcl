set COMMENTED_OUT [list ]

###################################################################
set DESIGN_NAME flash_attention_top

###################################################################
# Setup
puts "Hostnme : [info hostname]"

################################
# Directory housekeeping
foreach dir "outputs reports" {
  if {![file isdirectory $dir]} {
    file mkdir $dir
  }
  sh rm -rf $dir/*  
}

redirect -file /dev/null {set start_time [clock seconds]}

################################
# Read gate-level netlist obtained after synthesis
if {[file exists ./inputs/${DESIGN_NAME}.vg]} {
  puts "==>INFORMATION: Reading the gate-level netlist."
  read_verilog ./inputs/${DESIGN_NAME}.vg
} else {
  puts "==>FATAL: ${DESIGN_NAME}.vg synthesized gate-level netlist does not exist in ./inputs/ area. Exiting..."
}

###############################
# Setting the current design
enable_primetime_icc_consistency_settings

# current_design full_chip_${DESIGN_NAME}
current_design ${DESIGN_NAME}
link_design ${DESIGN_NAME}

set default_groups [get_path_groups]

###############################
# Read the constraint file
if {[file exists ./inputs/${DESIGN_NAME}.sdc] } {
  puts "==>INFORMATION: Reading the constraints file."
  read_sdc ./inputs/${DESIGN_NAME}.sdc
} else {
  puts "==>FATAL: ${DESIGN_NAME}.sdc does not exist in ./inputs/ area. Exiting..."
}

###############################
# Post-layout only: SDF not needed for pre-layout STA
# if {[file exists ./inputs/${DESIGN_NAME}.sdf] } {
#   puts "==>INFORMATION: Reading the delay file."
#   read_sdf -analysis_type bc_wc ./inputs/${DESIGN_NAME}.sdf
# } else {
#   puts "==>FATAL: ${DESIGN_NAME}.sdf does not exist in ./inputs/ area. Exiting..."
# }

#############################
# Power analysis not needed now
# set power_enable_analysis true

##############################
# SAIF not needed now
# if {[file exists ./inputs/${DESIGN_NAME}.saif] } {
#   puts "==>INFORMATION: Reading the switching activity file."
#   read_saif ./inputs/${DESIGN_NAME}.saif -strip_path full_chip_${DESIGN_NAME}
# } else {
#   puts "==>FATAL: ${DESIGN_NAME}.saif does not exist in ./inputs/ area. Exiting..."
# }

###############################
# SPEF not needed now
# if {([file exists ./inputs/${DESIGN_NAME}.spef.max.gz]) && ([file exists ./inputs/${DESIGN_NAME}.spef.min.gz])} {
#   puts "==>INFORMATION: Reading the parasitics files."
#   read_parasitics -format SPEF ./inputs/${DESIGN_NAME}.spef.max.gz
# } else {
#   puts "==>FATAL: ${DESIGN_NAME}.spef.max or ${DESIGN_NAME}.spef.min parasitics does not exist in ./inputs/ area. Exiting..."
# }

###############################
# Setting the operating conditions
set_operating_conditions -max tt0p8v25c -min tt0p8v25c 

###############################
# Path group setup
group_path -name inputs -from [all_inputs]
group_path -name output -to [all_outputs]
group_path -name comb -from [all_inputs] -to [all_outputs]
group_path -name reg2reg -from [all_registers -clock_pins] -to [all_registers -data_pins]

###############################
# Setup timing report
redirect -file ./reports/${DESIGN_NAME}.timing_setup_top5.rpt {
  report_timing -delay_type max -max_paths 5 -nosplit
}

###############################
# Hold timing report
redirect -file ./reports/${DESIGN_NAME}.timing_hold_top5.rpt {
  report_timing -delay_type min -max_paths 5 -nosplit
}

###############################
# QoR report
redirect -file ./reports/${DESIGN_NAME}.qor.rpt {
  report_qor
}

###############################
# Post-layout / power / SI / noise sections commented out for pre-layout STA

# remove_annotated_parasitics -all
# read_parasitics -format SPEF ./inputs/${DESIGN_NAME}.spef.min.gz
# read_parasitics -keep_capacitive_coupling -format SPEF ./inputs/${DESIGN_NAME}.spef.max.gz
# set power_analysis_mode averaged
# redirect -file ./reports/${DESIGN_NAME}.power.rpt {report_power}
# redirect -file ./reports/${DESIGN_NAME}.power_vth.rpt {report_threshold_voltage_group}
# redirect -file ./reports/${DESIGN_NAME}.power_leakage_vth.rpt {report_power -threshold_voltage_group}
# redirect -file ./reports/${DESIGN_NAME}.power_clock_gating.rpt {report_clock_gate_savings}
# set_operating_conditions -analysis_type on_chip_variation -max tt0p8v25c -min tt0p8v25c
# set_timing_derate -cell_delay -early 0.9
# set_timing_derate -cell_delay -late 1.05
# set_timing_derate -net_delay -early 0.95
# set_timing_derate -net_delay -early 1.1
# set_app_var si_enable_analysis true
# set timing_save_pin_arrival_and_slack true
# redirect -append -file ./reports/${DESIGN_NAME}.si_analysis.rpt {report_si_bottleneck}
# set_noise_parameters -include_beyond_rails -enable_propagation -analysis_type all
# check_noise -beyond_rail
# redirect -append -file ./reports/${DESIGN_NAME}.check_noise.rpt {check_noise -beyond_rail}
# redirect -append -file ./reports/${DESIGN_NAME}.noise.rpt {report_noise}

###############################
# Saving the session
puts "Saving the session to ./outputs"
save_session ./outputs/${DESIGN_NAME}.session

set elapsed_time [expr { ([clock seconds] - $start_time) / 60.0} ]
puts [format "##### Done. Runtime: %.2f mins, Memory Used: %.1f GB #####" $elapsed_time [expr [mem] / 1000000.0]]
