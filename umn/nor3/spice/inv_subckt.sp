* Inverter subcircuit wrapper for FO4 load
* Pins: (input) (output) (vdd) (gnd)

.SUBCKT inv i o vdd gnd
Mn o i gnd gnd nch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
Mp o i vdd vdd pch_svt_mac l=16e-9 nfin=4 w=154e-9 multi=1 nf=1 sa=90e-9 sb=90e-9
.ENDS inv

