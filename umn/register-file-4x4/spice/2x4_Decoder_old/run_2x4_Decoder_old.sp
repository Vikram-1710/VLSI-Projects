 ** 2x4_Decoder file

.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 2x4_Decoder.sp

* Supply sources
VDD_SRC vdd 0 0.8V
VSS_SRC vss 0 0V

* Input stimulus
* Let b toggle faster and a toggle slower
* This will cycle through:
* ab = 00, 01, 10, 11 repeatedly

VA a 0 PULSE(0 0.8 0p 20p 20p 800p 1600p)
VB b 0 PULSE(0 0.8 0p 20p 20p 400p 800p)

* Small load caps on outputs
C0 d0 0 2fF
C1 d1 0 2fF
C2 d2 0 2fF
C3 d3 0 2fF

.OP

.TRAN 0.1p 6.4ns

* Optional measurements
*.MEASURE TRAN d0_max MAX V(d0)
*.MEASURE TRAN d1_max MAX V(d1)
*.MEASURE TRAN d2_max MAX V(d2)
*.MEASURE TRAN d3_max MAX V(d3)

.END
