** NOR3 with FO4 load

.TEMP 70
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

* Include NOR3 hardware and INV subckt wrapper
.INCLUDE nor3.sp
.INCLUDE inv_subckt.sp

* Supplies
VDD vdd 0 0.8V
VSS gnd 0 0V

* Inputs
VA a 0 PULSE(0 0.8 0p 25p 25p 200p  400p)
VB b 0 PULSE(0 0.8 0p 25p 25p 400p  800p)
VC c 0 PULSE(0 0.8 0p 25p 25p 800p 1600p)

* FO4 load: 4 inverters driven by NOR output (norabc)
XFO1 norabc y1 vdd gnd inv
XFO2 norabc y2 vdd gnd inv
XFO3 norabc y3 vdd gnd inv
XFO4 norabc y4 vdd gnd inv

.TRAN 0.1p 2n
.END

