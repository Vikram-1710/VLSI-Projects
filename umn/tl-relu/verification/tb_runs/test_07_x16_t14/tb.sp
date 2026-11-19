** Auto-generated testbench for tlrelu_topdff, x=16, t=14
.TEMP 25
.OPTION POST
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
.INCLUDE "/home/ragha084/tsmcN16_ragha084/Project_3/tlrelu_verification/tlrelu_topdff.sp"

.param TPER = 84p
.param N_CYC = 1

* Power supply
VDD vdd! 0 0.8
VSS vss! 0 0

* Clock source: PULSE(0 0.8 20p 20p 20p TPER/2 TPER)
VCLK clk 0 PULSE(0 0.8 20p 20p 20p 'TPER/2' 'TPER')

* DC sources for theta t<*>
VT0 t<0> 0 0
VT1 t<1> 0 0.8
VT2 t<2> 0 0.8
VT3 t<3> 0 0.8

* DC sources for x x<*>
VX0 x<0> 0 0
VX1 x<1> 0 0
VX2 x<2> 0 0
VX3 x<3> 0 0
VX4 x<4> 0 0.8
VX5 x<5> 0 0
VX6 x<6> 0 0
VX7 x<7> 0 0

* Instantiate DUT
* DUT instantiation will be inserted by caller (we'll fill below)

* DUT instance
XU0 clk d0 d1 d2 d3 gnd t<0> t<1> t<2> t<3> vdd! x<0> x<1> x<2> x<3> x<4> x<5> x<6> x<7> out<0> out<1> out<2> out<3> out<4> out<5> out<6> out<7> out<8> out<9> out<10> tlrelu_topdff

* Transient analysis
.TRAN 'TPER/50' 'TPER*(N_CYC+1)'

* Measures of output bits at final sample time
.MEASURE TRAN m_out0 FIND V(out<0>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out1 FIND V(out<1>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out2 FIND V(out<2>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out3 FIND V(out<3>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out4 FIND V(out<4>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out5 FIND V(out<5>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out6 FIND V(out<6>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out7 FIND V(out<7>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out8 FIND V(out<8>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out9 FIND V(out<9>) AT='TPER*N_CYC + TPER/2'
.MEASURE TRAN m_out10 FIND V(out<10>) AT='TPER*N_CYC + TPER/2'

.END