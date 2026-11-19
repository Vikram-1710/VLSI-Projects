*******************************************************
* 4x4 RF TB - RE to DATA_OUT Delay
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

* Clock: only needed for the preload write
* Rising edges ~50ps, 250ps
VCLK clk 0 PULSE(0 0.8 50p 17p 22p 100p 200p)

* -------------------------------------------------
* WRITE preload only, then turn off
* Write row1 = 1010
* [data_in3 data_in2 data_in1 data_in0] = 1 0 1 0
* -------------------------------------------------
VWE we 0 PWL(
+ 0p    0.8
+ 320p  0.8
+ 337p  0.0
+ 1200p 0.0
)

* RE toggles later for delay measurement
VRE re 0 PWL(
+ 0p    0.0
+ 700p  0.0
+ 717p  0.8
+ 1200p 0.8
)

* Fixed write address = row1 = 01
VWR0 addr_wr0 0 0.0
VWR1 addr_wr1 0 0.8

* Fixed read address = row1 = 01
* valid long before RE toggles
VRD0 addr_rd0 0 0.0
VRD1 addr_rd1 0 0.8

* Fixed data word = 1010
VDIN0 data_in0 0 0.0
VDIN1 data_in1 0 0.8
VDIN2 data_in2 0 0.0
VDIN3 data_in3 0 0.8

* Output loads
* COUT1 data_out1 0 2f
* COUT3 data_out3 0 2f

* Probes
.PROBE TRAN V(clk) V(we) V(re)
.PROBE TRAN V(addr_wr1) V(addr_wr0) V(addr_rd1) V(addr_rd0)
.PROBE TRAN V(wr1)
.PROBE TRAN V(net22) V(net19)
.PROBE TRAN V(data_out1) V(data_out3)

* Auto measurements
.MEASURE TRAN t_RE_to_DOUT1 TRIG V(re) VAL=0.4 RISE=1 TARG V(data_out1) VAL=0.4 RISE=1
.MEASURE TRAN t_RE_to_DOUT3 TRIG V(re) VAL=0.4 RISE=1 TARG V(data_out3) VAL=0.4 RISE=1

.OP
.TRAN 0.1p 1.2ns

.END
