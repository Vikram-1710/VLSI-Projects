# Author: Vikram Raghavan
# Email: ragha084@umn.edu
# Date: 01/23/2026
# Description: This is the tcl script to run functional simulation in Vivado


# 1. Set Testbench name
set TB_NAME tb_fft16

# 2. Compile Source Files
exec xvlog -sv [glob ./rtl/*.sv]

# 3. Compile the Testbench
exec xvlog -sv ./tb/$TB_NAME.sv

# 4. Elaborate the design
exec xelab -debug typical -s top_sim work.$TB_NAME 

# 5. Run the Simulation
# exec xsim top_sim -gui

exec xsim top_sim -runall > ./output/fft16_sim_output.log
