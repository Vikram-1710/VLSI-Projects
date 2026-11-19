# Author: Vikram Raghavan
# Description: Run 256-point FFT functional simulation in Vivado

# 1. Set Testbench name
set TB_NAME tb_fft256

# 2. Create output folder
file mkdir ./output

# 3. Clean old Vivado simulation logs/files
file delete -force ./xsim.dir
file delete -force ./.Xil
file delete -force ./xvlog.log
file delete -force ./xelab.log
file delete -force ./xsim.log

# 4. Compile RTL files in dependency order
exec xvlog -sv ./rtl/fft256_stage_scaled.sv
exec xvlog -sv ./rtl/fft256_core.sv
exec xvlog -sv ./rtl/fft256_top.sv

# 5. Compile testbench
exec xvlog -sv ./tb/$TB_NAME.sv

# 6. Elaborate
exec xelab -debug typical -s top_sim work.$TB_NAME

# 7. Run simulation
exec xsim top_sim -runall > ./output/fft256_sim_output.log
