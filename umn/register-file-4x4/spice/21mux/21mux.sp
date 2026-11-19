** Generated for: hspiceD
** Generated on: Dec  7 00:17:23 2025
** Design library name: Project_3
** Design cell name: 21mux
** Design view name: schematic



** Library name: Project_3
** Cell name: nand
** View name: schematic
.subckt nand a b gnd vdd nandab
xmdut3 nandab b vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 nandab a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 nandab a net5 net5 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut1 net5 b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends nand
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 21mux
** View name: schematic
xi8 s s gnd vdd net3 nand
xi9 i1 s gnd vdd net2 nand
xi10 net3 i0 gnd vdd net1 nand
xi11 net2 net1 gnd vdd muxout nand
.END
