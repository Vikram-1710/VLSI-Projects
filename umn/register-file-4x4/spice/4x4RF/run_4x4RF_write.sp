*******************************************************
* 4x4 RF TB - write first, then read
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

* Supplies
VDD vdd 0 0.8
VSS vss 0 0

* Clock
VCLK clk 0 PULSE(0 0.8 0n 17p 22p 25n 50n)

* Enable split
* 0 to 0.5us   -> write enabled
* 0.5 to 1.0us -> read enabled
VWE we 0 PULSE(0 0.8 0n    17p 22p 499n 1000n)
VRE re 0 PULSE(0 0.8 500n  17p 22p 499n 1000n)

* -------------------------
* Write address pulses
* Similar visual style to senior plot
* -------------------------
VWR0 addr_wr0 0 PULSE(0   0.8 80n 17p 22p 80n 160n)
VWR1 addr_wr1 0 PULSE(0.8 0   40n 17p 22p 40n 80n)

* -------------------------
* Read address pulses
* Same style, active during read half
* -------------------------
VRD0 addr_rd0 0 PULSE(0   0.8 580n 17p 22p 80n 160n)
VRD1 addr_rd1 0 PULSE(0.8 0   540n 17p 22p 40n 80n)

* -------------------------
* Data input pulses
* Chosen to visually resemble senior’s staggered patterns
* -------------------------
VDIN0 data_in0 0 PULSE(0.8 0   140n 17p 22p 140n 280n)
VDIN1 data_in1 0 PULSE(0   0.8 70n  17p 22p 70n  140n)
VDIN2 data_in2 0 PULSE(0.8 0   100n 17p 22p 100n 200n)
VDIN3 data_in3 0 PULSE(0   0.8 120n 17p 22p 120n 240n)

* -------------------------
* Plot/save only critical signals
* Row selects wr0-wr3 exist in your 4x4 top level,
* and outputs are data_out0..3. :contentReference[oaicite:0]{index=0}
* -------------------------
.probe tran v(clk) v(we) v(re)
.probe tran v(addr_wr0) v(addr_wr1) v(addr_rd0) v(addr_rd1)
.probe tran v(data_in0) v(data_in1) v(data_in2) v(data_in3)
.probe tran v(wr0) v(wr1) v(wr2) v(wr3)
.probe tran v(data_out0) v(data_out1) v(data_out2) v(data_out3)

.tran 1n 1000n
