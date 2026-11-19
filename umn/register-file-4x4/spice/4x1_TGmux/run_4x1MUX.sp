** Run file for 4to1_mux

.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical corner
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow corner
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast corner
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 4x1MUX.sp

* Supplies
VDD vdd 0 0.8
VSS vss 0 0.0

* Data inputs
* all different so mux mistakes show up clearly
VD0 i0 0 PULSE(0 0.8   0p 17p 22p 100p 200p)
VD1 i1 0 PULSE(0 0.8  40p 17p 22p 150p 300p)
VD2 i2 0 PULSE(0 0.8  80p 17p 22p 200p 400p)
VD3 i3 0 PULSE(0 0.8 120p 17p 22p 250p 500p)

* Select lines
* s0 = LSB, toggles faster
* s1 = MSB, toggles slower
VS0 s0 0 PULSE(0 0.8   0p 17p 22p 200p 400p)
VS1 s1 0 PULSE(0 0.8   0p 17p 22p 400p 800p)

* Output load
C1 muxout 0 2fF

.OP
.TRAN 0.1p 1.6ns

.END
