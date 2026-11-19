*******************************************************
* 4x4 RF TB - Bit cell transition
* Address under test = 11,01,00,10 - Customized 
* Required input edges:
* rise = 17ps, fall = 22ps
*******************************************************

.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 4x4RF.sp

* Supplies
VDD vdd 0 0.8
VSS vss 0 0.0

* Two useful clock pulses
VCLK clk 0 PWL(
+ 0p    0.0
+ 50p   0.0
+ 67p   0.8
+ 117p  0.8
+ 139p  0.0
+ 170p  0.0
+ 187p  0.8
+ 237p  0.8
+ 259p  0.0
+ 1000p 0.0
)

* Write enable active across both writes
VWE we 0 PWL(
+ 0p    0.8
+ 260p  0.8
+ 277p  0.0
+ 1000p 0.0
)

* Read disabled
VRE re 0 0.0

* Address case under test
VWR0 addr_wr0 0 0.8
VWR1 addr_wr1 0 0.0

* Read address don't care
VRD0 addr_rd0 0 0.0
VRD1 addr_rd1 0 0.0

* Data: first 0000, then 1111
VDIN0 data_in0 0 PWL(
+ 0p    0.0
+ 150p  0.0
+ 167p  0.8
+ 1000p 0.8
)
VDIN1 data_in1 0 PWL(
+ 0p    0.0
+ 150p  0.0
+ 167p  0.8
+ 1000p 0.8
)
VDIN2 data_in2 0 PWL(
+ 0p    0.0
+ 150p  0.0
+ 167p  0.8
+ 1000p 0.8
)
VDIN3 data_in3 0 PWL(
+ 0p    0.0
+ 150p  0.0
+ 167p  0.8
+ 1000p 0.8
)

* Tiny load only on observed node
CSTOR0 net43 0 1f

.PROBE TRAN V(clk) V(we) V(wr2)
.PROBE TRAN V(addr_wr0) V(addr_wr1)
.PROBE TRAN V(data_in0) V(data_in1) V(data_in2) V(data_in3)
.PROBE TRAN V(net43)

.MEASURE TRAN t_CLK_to_net43 TRIG V(clk) VAL=0.4 RISE=2 TARG V(net43) VAL=0.4 RISE=1

.OP
.TRAN 0.1p 1.0ns

.END
