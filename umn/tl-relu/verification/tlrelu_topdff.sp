** Generated for: hspiceD
** Generated on: Dec  7 19:59:13 2025
** Design library name: Project_3
** Design cell name: tlrelu_topdff
** Design view name: schematic
.GLOBAL vdd!


** Library name: Project_3
** Cell name: dff
** View name: schematic
.subckt dff clk d gnd q vdd
xmdut23 net45 clk gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut22 net43 clk net44 net44 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut20 net50 net45 net44 net44 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut14 q net44 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut11 net43 net46 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut10 net50 q gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut9 net49 net45 net47 net47 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut7 net48 clk net47 net47 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut4 net46 net47 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 net49 d gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 net48 net46 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut24 net45 clk vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut21 net43 net45 net44 net44 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut19 net50 clk net44 net44 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut15 q net44 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut13 net43 net46 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut12 net50 q vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 net49 clk net47 net47 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 net48 net45 net47 net47 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut5 net46 net47 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 net49 d vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut1 net48 net46 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends dff
** End of subcircuit definition.

** Library name: Project_3
** Cell name: x_bank
** View name: schematic
.subckt x_bank clk gnd vdd x0 x1 x2 x3 x4 x5 x6 x7 xout_0 xout_1 xout_2 xout_3 xout_4 xout_5 xout_6 xout_7
xi7 clk x7 gnd xout_7 vdd dff
xi6 clk x6 gnd xout_6 vdd dff
xi5 clk x5 gnd xout_5 vdd dff
xi4 clk x4 gnd xout_4 vdd dff
xi3 clk x3 gnd xout_3 vdd dff
xi2 clk x2 gnd xout_2 vdd dff
xi1 clk x1 gnd xout_1 vdd dff
xi0 clk x0 gnd xout_0 vdd dff
.ends x_bank
** End of subcircuit definition.

** Library name: Project_3
** Cell name: t_bank
** View name: schematic
.subckt t_bank clk gnd vdd t0 t1 t2 t3 tout_0 tout_1 tout_2 tout_3
xi0 clk t0 gnd tout_0 vdd dff
xi1 clk t1 gnd tout_1 vdd dff
xi2 clk t2 gnd tout_2 vdd dff
xi3 clk t3 gnd tout_3 vdd dff
.ends t_bank
** End of subcircuit definition.

** Library name: Project_3
** Cell name: nor
** View name: schematic
.subckt nor a b gnd vdd norab
xmdut3 net1 a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 norab b net1 net1 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut1 norab b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 norab a gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends nor
** End of subcircuit definition.

** Library name: Project_3
** Cell name: inv
** View name: schematic
.subckt inv gnd vdd i i__
xmdut7 i__ i gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 i__ i vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends inv
** End of subcircuit definition.

** Library name: Project_3
** Cell name: or
** View name: schematic
.subckt or a b gnd vdd orab
xi0 a b gnd vdd net1 nor
xi1 gnd vdd net1 orab inv
.ends or
** End of subcircuit definition.

** Library name: Project_3
** Cell name: fast_path
** View name: schematic
.subckt fast_path a0 a1 b0 b1 gnd vdd fast_path_sel
xi2 net1 net4 gnd vdd fast_path_sel or
xi1 a1 b1 gnd vdd net4 or
xi0 a0 b0 gnd vdd net1 or
.ends fast_path
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

** Library name: Project_3
** Cell name: 21mux
** View name: schematic
.subckt Project_3_21mux_schematic gnd s vdd i0 i1 muxout
xi8 s s gnd vdd net3 nand
xi9 i1 s gnd vdd net2 nand
xi10 net3 i0 gnd vdd net1 nand
xi11 net2 net1 gnd vdd muxout nand
.ends Project_3_21mux_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 7_1mux
** View name: schematic
.subckt Project_3_7_1mux_schematic n0i_0 n0i_1 n0i_2 n0i_3 n0i_4 n0i_5 n0i_6 n1i_0 n1i_1 n1i_2 n1i_3 n1i_4 n1i_5 n1i_6 gnd s vdd m0 m1 m2 m3 m4 m5 m6
xi0 gnd s vdd n0i_0 n1i_0 m0 Project_3_21mux_schematic
xi1 gnd s vdd n0i_1 n1i_1 m1 Project_3_21mux_schematic
xi7 gnd s vdd n0i_2 n1i_2 m2 Project_3_21mux_schematic
xi6 gnd s vdd n0i_3 n1i_3 m3 Project_3_21mux_schematic
xi11 gnd s vdd n0i_4 n1i_4 m4 Project_3_21mux_schematic
xi8 gnd s vdd n0i_5 n1i_5 m5 Project_3_21mux_schematic
xi10 gnd s vdd n0i_6 n1i_6 m6 Project_3_21mux_schematic
.ends Project_3_7_1mux_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 1bit_fulladd
** View name: schematic
.subckt Project_3_1bit_fulladd_schematic a b ci co gnd s vdd
xmdut25 s net110 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut17 net110 net111 net112 net112 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut8 net111 a net116 net116 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut7 net111 ci net114 net114 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut21 net110 ci net107 net107 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut22 net107 a net106 net106 nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut9 net116 b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut6 net114 b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut0 net114 a gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut27 co net111 gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut20 net112 ci gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut19 net112 b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut18 net112 a gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut23 net106 b gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut13 net109 a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut24 s net110 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut16 net113 ci vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut11 net113 a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut10 net113 b vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut4 net117 b vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut2 net115 b vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut1 net115 a vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut12 net108 b net109 net109 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut5 net111 a net117 net117 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut15 net110 ci net108 net108 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut14 net110 net111 net113 net113 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 net111 ci net115 net115 pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut26 co net111 vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends Project_3_1bit_fulladd_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 4bit_sub
** View name: schematic
.subckt Project_3_4bit_sub_schematic a0 a1 a2 a3 b0 b1 b2 b3 co d0 d1 d2 d3 gnd vdd
xi3 a3 net4 net6 co gnd d3 vdd Project_3_1bit_fulladd_schematic
xi2 a2 net2 net7 net6 gnd d2 vdd Project_3_1bit_fulladd_schematic
xi1 a1 net5 net1 net7 gnd d1 vdd Project_3_1bit_fulladd_schematic
xi0 a0 net3 vdd net1 gnd d0 vdd Project_3_1bit_fulladd_schematic
xi7 gnd vdd b3 net4 inv
xi6 gnd vdd b2 net2 inv
xi5 gnd vdd b1 net5 inv
xi4 gnd vdd b0 net3 inv
.ends Project_3_4bit_sub_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 6bit_add
** View name: schematic
.subckt Project_3_6bit_add_schematic a0 a1 a2 a3 a4 a5 b0 b1 b2 b3 b4 b5 ci co gnd s0 s1 s2 s3 s4 s5 vdd
xi1 a5 b5 net22 co gnd s5 vdd Project_3_1bit_fulladd_schematic
xi11 a3 b3 net25 net21 gnd s3 vdd Project_3_1bit_fulladd_schematic
xi10 a2 b2 net24 net25 gnd s2 vdd Project_3_1bit_fulladd_schematic
xi9 a1 b1 net23 net24 gnd s1 vdd Project_3_1bit_fulladd_schematic
xi8 a0 b0 ci net23 gnd s0 vdd Project_3_1bit_fulladd_schematic
xi0 a4 b4 net21 net22 gnd s4 vdd Project_3_1bit_fulladd_schematic
.ends Project_3_6bit_add_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 4bit_add
** View name: schematic
.subckt Project_3_4bit_add_schematic a0 a1 a2 a3 b0 b1 b2 b3 ci co gnd s0 s1 s2 s3 vdd
xi11 a3 b3 net3 co gnd s3 vdd Project_3_1bit_fulladd_schematic
xi10 a2 b2 net1 net3 gnd s2 vdd Project_3_1bit_fulladd_schematic
xi9 a1 b1 net2 net1 gnd s1 vdd Project_3_1bit_fulladd_schematic
xi8 a0 b0 ci net2 gnd s0 vdd Project_3_1bit_fulladd_schematic
.ends Project_3_4bit_add_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 5bit_add
** View name: schematic
.subckt Project_3_5bit_add_schematic a0 a1 a2 a3 a4 b0 b1 b2 b3 b4 ci co gnd s0 s1 s2 s3 s4 vdd
xi0 a4 b4 net20 co gnd s4 vdd Project_3_1bit_fulladd_schematic
xi11 a3 b3 net19 net20 gnd s3 vdd Project_3_1bit_fulladd_schematic
xi10 a2 b2 net18 net19 gnd s2 vdd Project_3_1bit_fulladd_schematic
xi9 a1 b1 net17 net18 gnd s1 vdd Project_3_1bit_fulladd_schematic
xi8 a0 b0 ci net17 gnd s0 vdd Project_3_1bit_fulladd_schematic
.ends Project_3_5bit_add_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: critical_path_2
** View name: schematic
.subckt critical_path_2 gnd vdd f0 f1 f2 f3 f4 f5 f6 t0 t1 t2 t3 x0 x1 x2 x3
xi5 net1 net2 net3 net4 net5 net6 gnd gnd t0 t1 t2 t3 gnd f6 gnd f0 f1 f2 f3 f4 f5 vdd Project_3_6bit_add_schematic
xi3 x0 x1 x2 x3 t0 t1 t2 t3 gnd net7 gnd net8 net9 net10 net11 vdd Project_3_4bit_add_schematic
xi4 net8 net9 net10 net11 net7 gnd t0 t1 t2 t3 gnd net6 gnd net1 net2 net3 net4 net5 vdd Project_3_5bit_add_schematic
.ends critical_path_2
** End of subcircuit definition.

** Library name: Project_3
** Cell name: 11_1mux
** View name: schematic
.subckt Project_3_11_1mux_schematic n0i_0 n0i_1 n0i_10 n0i_2 n0i_3 n0i_4 n0i_5 n0i_6 n0i_7 n0i_8 n0i_9 n1i_0 n1i_1 n1i_10 n1i_2 n1i_3 n1i_4 n1i_5 n1i_6 n1i_7 n1i_8 n1i_9 gnd s vdd m0 m1 m10 m2 m3 m4 m5 m6 m7 m8 m9
xi14 gnd s vdd n0i_10 n1i_10 m10 Project_3_21mux_schematic
xi13 gnd s vdd n0i_8 n1i_8 m8 Project_3_21mux_schematic
xi12 gnd s vdd n0i_9 n1i_9 m9 Project_3_21mux_schematic
xi11 gnd s vdd n0i_4 n1i_4 m4 Project_3_21mux_schematic
xi10 gnd s vdd n0i_6 n1i_6 m6 Project_3_21mux_schematic
xi9 gnd s vdd n0i_7 n1i_7 m7 Project_3_21mux_schematic
xi8 gnd s vdd n0i_5 n1i_5 m5 Project_3_21mux_schematic
xi7 gnd s vdd n0i_2 n1i_2 m2 Project_3_21mux_schematic
xi6 gnd s vdd n0i_3 n1i_3 m3 Project_3_21mux_schematic
xi1 gnd s vdd n0i_1 n1i_1 m1 Project_3_21mux_schematic
xi0 gnd s vdd n0i_0 n1i_0 m0 Project_3_21mux_schematic
.ends Project_3_11_1mux_schematic
** End of subcircuit definition.

** Library name: Project_3
** Cell name: dff_bank11
** View name: schematic
.subckt dff_bank11 clk gnd vdd x0 x1 x10 x2 x3 x4 x5 x6 x7 x8 x9 xout_0 xout_1 xout_10 xout_2 xout_3 xout_4 xout_5 xout_6 xout_7 xout_8 xout_9
xi10 clk x10 gnd xout_10 vdd dff
xi9 clk x9 gnd xout_9 vdd dff
xi8 clk x8 gnd xout_8 vdd dff
xi0 clk x0 gnd xout_0 vdd dff
xi1 clk x1 gnd xout_1 vdd dff
xi2 clk x2 gnd xout_2 vdd dff
xi3 clk x3 gnd xout_3 vdd dff
xi4 clk x4 gnd xout_4 vdd dff
xi5 clk x5 gnd xout_5 vdd dff
xi6 clk x6 gnd xout_6 vdd dff
xi7 clk x7 gnd xout_7 vdd dff
.ends dff_bank11
** End of subcircuit definition.

** Library name: Project_3
** Cell name: load_inv
** View name: schematic
.subckt load_inv gnd vdd i i__
xmdut7 i__ i gnd gnd nch_svt_mac l=16e-9 nfin=16 w=730e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
xmdut3 i__ i vdd vdd pch_svt_mac l=16e-9 nfin=16 w=730e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ends load_inv
** End of subcircuit definition.

** Library name: Project_3
** Cell name: load_bank
** View name: schematic
.subckt load_bank gnd vdd x0 x1 x10 x2 x3 x4 x5 x6 x7 x8 x9
xi31 gnd vdd x0 gnd load_inv
xi30 gnd vdd x1 gnd load_inv
xi29 gnd vdd x2 gnd load_inv
xi28 gnd vdd x3 gnd load_inv
xi27 gnd vdd x4 gnd load_inv
xi26 gnd vdd x5 gnd load_inv
xi25 gnd vdd x6 gnd load_inv
xi24 gnd vdd x7 gnd load_inv
xi23 gnd vdd x8 gnd load_inv
xi22 gnd vdd x9 gnd load_inv
xi21 gnd vdd x10 gnd load_inv
.ends load_bank
** End of subcircuit definition.

** Library name: Project_3
** Cell name: tlrelu_topdff
** View name: schematic
.subckt tlrelu_topdff clk d0 d1 d2 d3 gnd t<0> t<1> t<2> t<3> vdd! x<0> x<1> x<2> x<3> x<4> x<5> x<6> x<7> out<0> out<1> out<2> out<3> out<4> out<5> out<6> out<7> out<8> out<9> out<10>
xi0 clk gnd vdd! x<0> x<1> x<2> x<3> x<4> x<5> x<6> x<7> net16 net15 net14 net13 net12 net11 net10 net9 x_bank
xi1 clk gnd vdd! t<0> t<1> t<2> t<3> net27 net26 net25 net24 t_bank
xi2 net9 net11 net10 net12 gnd vdd! net35 fast_path
xi11 x<0> x<1> x<2> x<3> x<4> x<5> x<6> net44 net43 net42 net41 net40 net39 net38 gnd net59 vdd! net58 net57 net56 net55 net3 net2 net1 Project_3_7_1mux_schematic
xi6 net27 net26 net25 net24 net16 net15 net14 net13 net59 d0 d1 d2 d3 gnd vdd! Project_3_4bit_sub_schematic
xi9 gnd vdd! net44 net43 net42 net41 net40 net39 net38 t<0> t<1> t<2> t<3> x<0> x<1> x<2> x<3> critical_path_2
xi12 net58 net57 gnd net56 net55 net3 net2 net1 gnd gnd gnd gnd gnd x<7> gnd x<0> x<1> x<2> x<3> x<4> x<5> x<6> gnd net35 vdd! net18 net17 net19 net8 net7 net6 net5 net4 net22 net21 net20 Project_3_11_1mux_schematic
xi14 clk gnd vdd! net18 net17 net19 net8 net7 net6 net5 net4 net22 net21 net20 out<0> out<1> out<10> out<2> out<3> out<4> out<5> out<6> out<7> out<8> out<9> dff_bank11
xi15 gnd vdd! net18 net17 net19 net8 net7 net6 net5 net4 net22 net21 net20 load_bank
.ends tlrelu_topdff
** End of subcircuit definition.
.END
