set TB_NAME tb_fft256

file mkdir ./output

file delete -force ./xsim.dir
file delete -force ./.Xil
file delete -force ./xvlog.log
file delete -force ./xelab.log
file delete -force ./xsim.log

exec xvlog -sv ./rtl/complex_mult_q.sv
exec xvlog -sv ./rtl/bf2_dif.sv
exec xvlog -sv ./rtl/twiddle_rom_512.sv
exec xvlog -sv ./rtl/fft256_core.sv
exec xvlog -sv ./rtl/fft256_top.sv
exec xvlog -sv ./tb/$TB_NAME.sv

exec xelab -debug typical -s top_sim work.$TB_NAME
exec xsim top_sim -runall > ./output/fft256_pipelined_sim_output.log
