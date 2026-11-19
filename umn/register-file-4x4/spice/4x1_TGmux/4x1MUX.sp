** Generated for: hspiceD
** Generated on: Mar 23 15:16:53 2026
** Design library name: VD2_RF
** Design cell name: 4x1_TGmux
** Design view name: schematic


** Library name: VD2_RF
** Cell name: 2x1_TGmux
** View name: schematic
.subckt VD2_RF_2x1_TGmux_schematic a b s vdd vss muxout
xmdut9 net2 s vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 b s muxout vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 a net2 muxout vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 net2 s vdd vdd pch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut7 muxout s a vdd pch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 muxout net2 b vdd pch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends VD2_RF_2x1_TGmux_schematic
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: 4x1_TGmux
** View name: schematic
xi2 net1 net2 s1 vdd vss muxout VD2_RF_2x1_TGmux_schematic
xi1 i2 i3 s0 vdd vss net2 VD2_RF_2x1_TGmux_schematic
xi0 i0 i1 s0 vdd vss net1 VD2_RF_2x1_TGmux_schematic
.END

