 ** 4x1_RF file

.TEMP 25
*.OPTION INGOLD=2 ARTIST=2 PSF=2 MEASOUT=1 PARHIER=LOCAL PROBE=0 MARCH=2 ACCURACY=1 POST RUNLVL=5
.OPTION POST

* Typical NMOS, typical PMOS process corner model file
.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP
* Slow NMOS, slow PMOS process corner model file
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l SSMacro_MOS_MOSCAP
* Fast NMOS, fast PMOS process corner model file 
*.lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l FFMacro_MOS_MOSCAP

.INCLUDE 4x1_RF.sp

*--------------------------------------------------
* Supplies
*--------------------------------------------------
VDD_SRC vdd 0 0.8
VSS_SRC vss 0 0

*--------------------------------------------------
* Clock
* Rising edges at about:
* 1ns, 3ns, 5ns, 7ns, 9ns, ...
*--------------------------------------------------
VCLK clk 0 PULSE(0 0.8 0.1n 20p 20p 1n 2n)

*--------------------------------------------------
* WRITE ENABLE
* 0-2ns   : low
* 2-4ns   : high   -> write row0 = 1 at ~3ns edge
* 4-8ns   : low
* 8-10ns  : high   -> write row3 = 0 at ~9ns edge
* then low
*--------------------------------------------------
VWE we 0 PWL(
+ 0n   0
+ 2n   0
+ 2.01n 0.8
+ 4n   0.8
+ 4.01n 0
+ 8n   0
+ 8.01n 0.8
+ 10n  0.8
+ 10.01n 0
+ 14n  0
)

*--------------------------------------------------
* READ ENABLE
* 4-6ns   : high   -> read row0
* 10-12ns : high   -> read row3
*--------------------------------------------------
VRE re 0 PWL(
+ 0n   0
+ 4n   0
+ 4.01n 0.8
+ 6n   0.8
+ 6.01n 0
+ 10n  0
+ 10.01n 0.8
+ 12n  0.8
+ 12.01n 0
+ 14n  0
)

*--------------------------------------------------
* DATA INPUT
* First write: 1
* Second write: 0
*--------------------------------------------------
VDIN data_in0 0 PWL(
+ 0n   0
+ 2n   0
+ 2.01n 0.8
+ 6n   0.8
+ 6.01n 0
+ 14n  0
)

*--------------------------------------------------
* WRITE ADDRESS
* First write row0 = 00
* Second write row3 = 11
*--------------------------------------------------
VAW0 addr_wr0 0 PWL(
+ 0n   0
+ 8n   0
+ 8.01n 0.8
+ 14n  0.8
)

VAW1 addr_wr1 0 PWL(
+ 0n   0
+ 8n   0
+ 8.01n 0.8
+ 14n  0.8
)

*--------------------------------------------------
* READ ADDRESS
* First read row0 = 00
* Second read row3 = 11
*--------------------------------------------------
VARD0 addr_rd0 0 PWL(
+ 0n   0
+ 10n  0
+ 10.01n 0.8
+ 14n  0.8
)

VARD1 addr_rd1 0 PWL(
+ 0n   0
+ 10n  0
+ 10.01n 0.8
+ 14n  0.8
)

*--------------------------------------------------
* Small output load
*--------------------------------------------------
COUT data_out0 0 2f

.OP
.TRAN 0.1p 14n

.END
