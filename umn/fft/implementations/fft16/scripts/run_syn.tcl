# Author: Vikram Raghavan
# Email: ragha084@umn.edu
# Date: 05/02/2026
# Description: This is the tcl script to run synthesis in Vivado

#
# STEP#0: define top design name and output directory area.
#
set DESIGN_NAME fft16
set outputDir ./output           
file mkdir $outputDir

#
# STEP#1: setup design sources and constraints
#
read_verilog -sv [glob ./rtl/*.sv]
read_xdc ./xdc/$DESIGN_NAME.xdc

#
# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
#
synth_design -top $DESIGN_NAME -part xc7a200tfbg676-2
# Artix-7 AC701 Evaluation Platform

#
# StEP#3: write checkpoint
#
write_checkpoint -force $outputDir/post_synth

#
# STEP#4: generate reports
#
file mkdir ${outputDir}/post_synth
report_timing_summary -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_timing_summary.rpt
report_timing -sort_by group -max_paths 10 -delay_type max -significant_digits 2 -input_pins -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_timing.rpt
report_utilization -hierarchical -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_util_hier.rpt
report_utilization -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_util.rpt
report_power -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_power.rpt

