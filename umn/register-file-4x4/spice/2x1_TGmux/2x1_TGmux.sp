** Generated for: hspiceD
** Generated on: Mar 23 13:18:01 2026
** Design library name: VD2_RF
** Design cell name: 2x1_TGmux
** Design view name: schematic


** Library name: VD2_RF
** Cell name: 2x1_TGmux
** View name: schematic
xmdut9 net2 s vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 a s muxout vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 b net2 muxout vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 net2 s vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut7 muxout s b vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 muxout net2 a vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.END
