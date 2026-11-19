*******************************************************
* 4x4 RF TB -Read write concurrent check
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

* Clock
VCLK clk 0 PULSE(0 0.8 0p 17p 22p 100p 200p)

* Always enable both
VWE we 0 0.8
VRE re 0 0.8

* -------------------------------------------------
* WRITE ADDRESS (slow sweep)
* cycles through 00 → 01 → 10 → 11
* -------------------------------------------------
VWR0 addr_wr0 0 PULSE(0 0.8 0p   17p 22p 400p 800p)
VWR1 addr_wr1 0 PULSE(0 0.8 0p   17p 22p 800p 1600p)

* -------------------------------------------------
* READ ADDRESS (different pattern)
* offset so read ≠ write most of the time
* -------------------------------------------------
VRD0 addr_rd0 0 PULSE(0 0.8 200p 17p 22p 400p 800p)
VRD1 addr_rd1 0 PULSE(0 0.8 200p 17p 22p 800p 1600p)

* -------------------------------------------------
* DATA INPUT (constantly changing)
* -------------------------------------------------
VDIN0 data_in0 0 PULSE(0 0.8  50p 17p 22p 200p 400p)
VDIN1 data_in1 0 PULSE(0 0.8 100p 17p 22p 200p 400p)
VDIN2 data_in2 0 PULSE(0 0.8 150p 17p 22p 200p 400p)
VDIN3 data_in3 0 PULSE(0 0.8 200p 17p 22p 200p 400p)

* Output loads
COUT0 data_out0 0 2fF
COUT1 data_out1 0 2fF
COUT2 data_out2 0 2fF
COUT3 data_out3 0 2fF

.OP
.TRAN 0.1p 2ns

.END
