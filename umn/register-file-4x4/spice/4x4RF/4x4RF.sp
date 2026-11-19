** Generated for: hspiceD
** Generated on: Mar 23 15:28:42 2026
** Design library name: VD2_RF
** Design cell name: 4x4RF
** Design view name: schematic


** Library name: VD2_RF
** Cell name: 2x4_Decoder
** View name: schematic
.subckt VD2_RF_2x4_Decoder_schematic vdd vss a b d0 d1 d2 d3
xmdut13 d2 b vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut12 d0 b vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut11 d3 net7 vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 d1 net7 vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 d2 net5 vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut7 d3 net5 vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 d1 a vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut10 d0 a vss vss nch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut14 net5 a vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 net7 b vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut15 d0 vss vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut9 d2 vss vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 d1 vss vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut5 d3 vss vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut4 net5 a vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut1 net7 b vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
.ends VD2_RF_2x4_Decoder_schematic
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: inv
** View name: schematic
.subckt inv vdd vss i i__
xmdut7 i__ i vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 i__ i vdd vdd pch_svt_mac l=16e-9 nfin=2 w=58e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends inv
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: nand2
** View name: schematic
.subckt nand2 a b vdd vss nandab
xmdut3 nandab b vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 nandab a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 nandab a net5 net5 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut1 net5 b vss vss nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends nand2
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: and2
** View name: schematic
.subckt and2 a b vdd vss andab
xi6 vdd vss net1 andab inv
xi5 a b vdd vss net1 nand2
.ends and2
** End of subcircuit definition.

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

** Library name: VD2_RF
** Cell name: 21mux
** View name: schematic
.subckt VD2_RF_21mux_schematic s vdd vss i0 i1 muxout
xi8 s s vss vdd net3 nand
xi9 i1 s vss vdd net2 nand
xi10 net3 i0 vss vdd net1 nand
xi11 net2 net1 vss vdd muxout nand
.ends VD2_RF_21mux_schematic
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: dff_c2mos
** View name: schematic
.subckt dff_c2mos clk d q vdd vss
xmdut5 net3 net7 net2 net2 nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 net2 d vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut10 net65 net3 vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut9 q clk net65 net65 nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut2 net7 clk vss vss nch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut1 net7 clk vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut3 net4 d vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut4 net3 clk net4 net4 pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 q net7 net59 net59 pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
xmdut7 net59 net3 vdd vdd pch_svt_mac l=16e-9 nfin=1 w=10e-9 multi=1 nf=2 sa=90e-9 sb=90e-9
.ends dff_c2mos
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: RF
** View name: schematic
.subckt RF data_in data_out vdd vss we_row clk
xi3 we_row vdd vss data_out data_in net1 VD2_RF_21mux_schematic
xi1 clk net1 data_out vdd vss dff_c2mos
.ends RF
** End of subcircuit definition.

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
.subckt VD2_RF_4x1_TGmux_schematic s0 s1 vdd vss i0 i1 i2 i3 muxout
xi2 net1 net2 s1 vdd vss muxout VD2_RF_2x1_TGmux_schematic
xi1 i2 i3 s0 vdd vss net2 VD2_RF_2x1_TGmux_schematic
xi0 i0 i1 s0 vdd vss net1 VD2_RF_2x1_TGmux_schematic
.ends VD2_RF_4x1_TGmux_schematic
** End of subcircuit definition.

** Library name: VD2_RF
** Cell name: 4x4RF
** View name: schematic
xi0 vdd vss addr_wr0 addr_wr1 net6 net5 net4 net3 VD2_RF_2x4_Decoder_schematic
xi46 net16 re vdd vss data_out3 and2
xi41 net10 re vdd vss data_out2 and2
xi32 net24 re vdd vss data_out1 and2
xi17 net6 we vdd vss wr0 and2
xi22 net57 re vdd vss data_out0 and2
xi21 net4 we vdd vss wr2 and2
xi19 net5 we vdd vss wr1 and2
xi20 net3 we vdd vss wr3 and2
xi50 data_in3 net18 vdd vss wr0 clk RF
xi49 data_in3 net19 vdd vss wr1 clk RF
xi48 data_in3 net12 vdd vss wr2 clk RF
xi47 data_in3 net13 vdd vss wr3 clk RF
xi40 data_in2 net1 vdd vss wr3 clk RF
xi39 data_in2 net2 vdd vss wr2 clk RF
xi38 data_in2 net7 vdd vss wr1 clk RF
xi37 data_in2 net8 vdd vss wr0 clk RF
xi36 data_in1 net23 vdd vss wr0 clk RF
xi35 data_in1 net22 vdd vss wr1 clk RF
xi34 data_in1 net21 vdd vss wr2 clk RF
xi33 data_in1 net20 vdd vss wr3 clk RF
xi8 data_in0 net49 vdd vss wr3 clk RF
xi7 data_in0 net43 vdd vss wr2 clk RF
xi6 data_in0 net37 vdd vss wr1 clk RF
xi5 data_in0 net31 vdd vss wr0 clk RF
xi44 addr_rd0 addr_rd1 vdd vss net18 net19 net12 net13 net16 VD2_RF_4x1_TGmux_schematic
xi43 addr_rd0 addr_rd1 vdd vss net8 net7 net2 net1 net10 VD2_RF_4x1_TGmux_schematic
xi30 addr_rd0 addr_rd1 vdd vss net23 net22 net21 net20 net24 VD2_RF_4x1_TGmux_schematic
xi9 addr_rd0 addr_rd1 vdd vss net31 net37 net43 net49 net57 VD2_RF_4x1_TGmux_schematic
.END

