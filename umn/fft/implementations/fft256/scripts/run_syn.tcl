# Author: Vikram Raghavan
# Email: ragha084@umn.edu
# Date: 05/02/2026
# Description: TCL script to run synthesis for 256-point FFT in Vivado

#
# STEP#0: define top design name and output directory.
#
set TOP_NAME fft256_top
set DESIGN_NAME fft256
set outputDir ./output
file mkdir $outputDir
file mkdir ${outputDir}/post_synth

#
# STEP#1: read RTL sources and constraints
#
read_verilog -sv ./rtl/fft256_stage_scaled.sv
read_verilog -sv ./rtl/fft256_core.sv
read_verilog -sv ./rtl/fft256_top.sv

read_xdc ./xdc/$DESIGN_NAME.xdc

#
# STEP#2: run synthesis
#
synth_design -top $TOP_NAME -part xc7a200tfbg676-2

#
# STEP#3: write checkpoint
#
write_checkpoint -force $outputDir/post_synth/${DESIGN_NAME}_post_synth.dcp

#
# STEP#4: generate reports
#
report_timing_summary \
    -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_timing_summary.rpt

report_timing \
    -sort_by group \
    -max_paths 10 \
    -delay_type max \
    -significant_digits 2 \
    -input_pins \
    -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_timing.rpt

report_utilization \
    -hierarchical \
    -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_util_hier.rpt

report_utilization \
    -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_util.rpt

report_power \
    -file $outputDir/post_synth/${DESIGN_NAME}_post_synth_power.rpt
