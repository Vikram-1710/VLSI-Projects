set TOP_NAME fft256_top
set DESIGN_NAME fft256_pipelined
set outputDir ./output

file mkdir $outputDir
file mkdir ${outputDir}/post_synth

read_verilog -sv ./rtl/complex_mult_q.sv
read_verilog -sv ./rtl/bf2_dif.sv
read_verilog -sv ./rtl/twiddle_rom_512.sv
read_verilog -sv ./rtl/fft256_core.sv
read_verilog -sv ./rtl/fft256_top.sv

read_xdc ./xdc/fft256.xdc

synth_design -top $TOP_NAME -part xc7a200tfbg676-2

write_checkpoint -force $outputDir/post_synth/${DESIGN_NAME}_post_synth.dcp

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
