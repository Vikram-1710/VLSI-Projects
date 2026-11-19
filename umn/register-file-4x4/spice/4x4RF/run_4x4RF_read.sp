*******************************************************
* 4x4 RF TB - write first, then read - UPDATED FOR ALL ALL 4 WORDLINES
* Address under test = 01
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

* -------------------------------------------------
* Supplies
* -------------------------------------------------
VDD vdd 0 0.8
VSS vss 0 0.0

* -------------------------------------------------
* Clock
* Rise = 17ps, Fall = 22ps
* Rising edges ~ 50ps, 250ps, 450ps, 650ps, ...
* -------------------------------------------------
VCLK clk 0 PULSE(0 0.8 50p 17p 22p 100p 200p)

* -------------------------------------------------
* Phase control
* 0 to 800ps    -> WRITE phase
* 817ps onward  -> READ phase
* -------------------------------------------------
VWE we 0 PWL(
+ 0p    0.8
+ 800p  0.8
+ 817p  0.0
+ 1600p 0.0
)

VRE re 0 PWL(
+ 0p    0.0
+ 800p  0.0
+ 817p  0.8
+ 1600p 0.8
)

* -------------------------------------------------
* WRITE addresses during preload
* 0-200ps   -> row0 = 00
* 200-400ps -> row1 = 01
* 400-600ps -> row2 = 10
* 600-800ps -> row3 = 11
* -------------------------------------------------
VWR0 addr_wr0 0 PWL(
+ 0p    0.0
+ 180p  0.0
+ 197p  0.8
+ 380p  0.8
+ 402p  0.0
+ 580p  0.0
+ 597p  0.8
+ 1600p 0.8
)

VWR1 addr_wr1 0 PWL(
+ 0p    0.0
+ 380p  0.0
+ 397p  0.8
+ 1600p 0.8
)

* Clean READ addresses during read phase
* 817-1000ps  -> 00
* 1017-1200ps -> 01
* 1217-1400ps -> 10
* 1417-1600ps -> 11

VRD0 addr_rd0 0 PWL(
+ 0p     0.0
+ 817p   0.0
+ 1000p  0.0
+ 1017p  0.0
+ 1200p  0.0
+ 1217p  0.8
+ 1400p  0.8
+ 1417p  0.8
+ 1600p  0.8
)

VRD1 addr_rd1 0 PWL(
+ 0p     0.0
+ 817p   0.0
+ 1000p  0.0
+ 1017p  0.8
+ 1200p  0.8
+ 1217p  0.0
+ 1400p  0.0
+ 1417p  0.8
+ 1600p  0.8
)

* -------------------------------------------------
* Data written during write phase
*
* Row 0 (00) -> 0001
* Row 1 (01) -> 1010
* Row 2 (10) -> 0110
* Row 3 (11) -> 1111
*
* Bit order = [data_in3 data_in2 data_in1 data_in0]
* -------------------------------------------------

* data_in0 = 1,0,0,1
VDIN0 data_in0 0 PWL(
+ 0p    0.8
+ 180p  0.8
+ 197p  0.0
+ 1180p 0.0
+ 1197p 0.8
+ 1600p 0.8
)

* data_in1 = 0,1,1,1
VDIN1 data_in1 0 PWL(
+ 0p    0.0
+ 180p  0.0
+ 197p  0.8
+ 1600p 0.8
)

* data_in2 = 0,0,1,1
VDIN2 data_in2 0 PWL(
+ 0p    0.0
+ 380p  0.0
+ 397p  0.8
+ 1600p 0.8
)

* data_in3 = 0,1,0,1
VDIN3 data_in3 0 PWL(
+ 0p    0.0
+ 180p  0.0
+ 197p  0.8
+ 380p  0.8
+ 397p  0.0
+ 1180p 0.0
+ 1197p 0.8
+ 1600p 0.8
)

* -------------------------------------------------
* Output loads
* -------------------------------------------------
COUT0 data_out0 0 2f
COUT1 data_out1 0 2f
COUT2 data_out2 0 2f
COUT3 data_out3 0 2f

* -------------------------------------------------
* Save only required nodes
* -------------------------------------------------
.PROBE TRAN V(clk) V(we) V(re)
.PROBE TRAN V(addr_wr1) V(addr_wr0) V(addr_rd1) V(addr_rd0)
.PROBE TRAN V(data_in3) V(data_in2) V(data_in1) V(data_in0)
.PROBE TRAN V(wr0) V(wr1) V(wr2) V(wr3)
.PROBE TRAN V(data_out3) V(data_out2) V(data_out1) V(data_out0)

.OP
.TRAN 0.1p 1.6ns

.END
