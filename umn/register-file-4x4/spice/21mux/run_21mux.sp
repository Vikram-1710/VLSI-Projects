** Run 2_1_mux file


.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 21mux.sp

* ========= Optional: dynamic pattern (commented) =========
*Vi0 i0 0 PULSE(0 0.8 0p 20p 20p 200p 400p)
*Vi1 i1 0 PULSE(0 0.8 0p 20p 20p 400p 800p)
*Vs  s  0 PULSE(0 0.8 0p 20p 20p 600p 1200p)

* ========= Static test vector (edit these for each case) =========
* Example 1: i0=0, i1=1, s=0  → muxout should be 0 (selects i0)
Vi0 i0 0 0.8
Vi1 i1 0 0
Vs  s  0 0

* Supplies
VDD vdd 0 0.8V
VGND gnd 0 0V

* Small load cap on the output
Cload muxout 0 2fF

.OP
.TRAN 0.5p 3n

* Example propagation delay measures from select to output
.MEASURE TRAN tpd_s_out_rise TRIG V(s) VAL=0.4 RISE=1 TARG V(muxout) VAL=0.4 RISE=1
.MEASURE TRAN tpd_s_out_fall TRIG V(s) VAL=0.4 FALL=1 TARG V(muxout) VAL=0.4 FALL=1

.END

