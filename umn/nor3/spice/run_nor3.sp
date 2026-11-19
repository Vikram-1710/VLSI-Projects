** Run NOR3 file (functionality)

.TEMP 70
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE nor3.sp

* Voltage sources
VA A 0 PULSE(0 0.8 0p 25p 25p 200p  400p)
VB B 0 PULSE(0 0.8 0p 25p 25p 400p  800p)
VC C 0 PULSE(0 0.8 0p 25p 25p 800p 1600p)

VDD VDD 0 0.8V
VSS GND 0 0V

* Small output capacitance for realistic simulation
C1 norABC 0 2fF

.OP
.TRAN 0.1p 2n

* Optional: first-transition delay checks (pick one clean event)
*.MEASURE TRAN tpd_a_fall TRIG V(A) VAL=0.4 RISE=1 TARG V(norABC) VAL=0.4 FALL=1
*.MEASURE TRAN tpd_a_rise TRIG V(A) VAL=0.4 FALL=1 TARG V(norABC) VAL=0.4 RISE=1

.END

