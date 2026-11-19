** Run 2x1_TGmux file


.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 2x1_TGmux.sp

* Functional + delay test case
* a = 0.8
* b = 0
* s toggles 0 -> 0.8
* Expected:
*   s=0 -> muxout = a = 0.8
*   s=1 -> muxout = b = 0

Va   a    vss   0.8
Vb   b    vss   0
Vs   s 	  vss   PULSE(0 0.8 200p 20p 20p 400p 800p)

* Supplies
VDD  vdd  vss   0.8
VSS  vss  0     0

* Output load
Cload muxout vss 2fF

.OP
.TRAN 0.5p 3n

.PROBE V(a) V(b) V(s) V(net2) V(muxout)

* Example propagation delay measures from select to output
.MEASURE TRAN tpd_srise_outfall TRIG V(s) VAL=0.4 RISE=1 TARG V(muxout) VAL=0.4 FALL=1
.MEASURE TRAN tpd_sfall_outrise TRIG V(s) VAL=0.4 FALL=1 TARG V(muxout) VAL=0.4 RISE=1

.END

