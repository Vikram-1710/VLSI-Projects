*******************************************************
* 4x4 RF TB -write one fixed word then read that word - 0 0 0 1
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

* Slower clock: 100ns period
VCLK clk 0 PULSE(0 0.8 0n 17p 22p 50n 100n)

* One write window only
VWE we 0 PULSE(0 0.8 40n 17p 22p 100n 1000n)

* Read starts later
VRE re 0 PULSE(0 0.8 250n 17p 22p 450n 1000n)

* Fixed write address = row1 = 01
VWR0 addr_wr0 0 0
VWR1 addr_wr1 0 0.8

* Read address pulses later
* starts at row1 = 01, then scans
VRD0 addr_rd0 0 PULSE(0   0.8 300n 17p 22p 100n 200n)
VRD1 addr_rd1 0 PULSE(0.8 0   250n 17p 22p 50n 100n)

* Write one fixed word only: data_in0..3 = 0 0 0 1
VDIN0 data_in0 0 0
VDIN1 data_in1 0 0
VDIN2 data_in2 0 0
VDIN3 data_in3 0 0.8

.probe tran v(clk) v(we) v(re)
.probe tran v(addr_wr0) v(addr_wr1) v(addr_rd0) v(addr_rd1)
.probe tran v(data_in0) v(data_in1) v(data_in2) v(data_in3)
.probe tran v(wr0) v(wr1) v(wr2) v(wr3)
.probe tran v(data_out0) v(data_out1) v(data_out2) v(data_out3)
.probe tran v(net37) v(net22) v(net7) v(net19)

.tran 1n 800n
.END
