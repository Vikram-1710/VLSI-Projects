# FlashAttention hardware — RTL to PrimeTime

Fixed-point attention hardware developed at the University of Minnesota, with output-stationary MAC-array and WeightedPE implementation variants. Includes SystemVerilog RTL, self-checking testbenches, Python reference code, test vectors, Design Compiler scripts, and PrimeTime analysis.

## Saved synthesis and timing results

| Implementation | DC clock target | Sequential cells | DC cell area (µm²) | DC reg-to-reg slack | PrimeTime setup slack |
|---|---:|---:|---:|---:|---:|
| Output_Stationary_MAC_array | 2 ns | 7,578 | 117,257.62 | 0.00 ns | −0.02 ns |
| WeightedPE_output_stationary_SYSARR | 1.5 ns | 13,820 | 130,271.85 | −0.40 ns | −0.42 ns |

Sources: each implementation's `reports/flash_attention_top.area.rpt`, `reports/flash_attention_top.qor.rpt`, `inputs/constraints/flash_attention_top.constraints.tcl`, and `pt_run/reports/flash_attention_top.timing_setup.rpt`. DC reports are dated May 10–11, 2026, using U-2022.12-SP5 and the N16ADFP typical-corner library.

These runs use different constraints; their differences are not a controlled PPA improvement comparison. PrimeTime setup violations remain. This archive demonstrates RTL → synthesis → PrimeTime analysis, not completed physical implementation or signoff closure.

## Simulation evidence

The saved [TC1](implementations/WeightedPE_output_stationary_SYSARR/run_tc1.log) and [TC2](implementations/WeightedPE_output_stationary_SYSARR/run_tc2.log) logs each report 256 passing output comparisons with a 3-LSB tolerance. Each records 3,855 HBM-transfer cycles, 2,304 QK cycles, 2,304 PV cycles, 400 vector-operation cycles, and 9,273 total start-to-done cycles.

These are historical runs. The saved testbench currently selects TC3, and a matching TC3 run log is absent. Folder placement does not establish that the present RTL generated TC1/TC2 logs. No new simulation, synthesis, or STA was run during repository preparation.

## Source variants and configuration

- `implementations/Output_Stationary_MAC_array/`: root simulation RTL differs from `inputs/rtl/` used by the synthesis flow; preserve both. In particular, product rounding and matmul logic differ.
- `implementations/WeightedPE_output_stationary_SYSARR/`: root and synthesis RTL are byte-identical in the supplied archive.
- `reference_and_vectors/`: Python references, TC1–TC3 data, and modular RTL alternatives. Do not compile these alternatives together with the monolithic implementation.
- Saved testbenches use N=64, D=4, Bc=8, Br=4, and HBM_DW=64. Root tops default to Bc=16 and HBM_DW=128; do not assume simulation and synthesis configurations match.
- Root `scripts/pt_flow.tcl` and `pt_run/scripts/pt_flow.tcl` are distinct flows. Current and archived report directories remain separate.

## Running a simulation

With licensed VCS available, from this project directory:

```sh
cd implementations/WeightedPE_output_stationary_SYSARR
cp ../../reference_and_vectors/fa_tc*.txt .
vcs -full64 -sverilog flash_attention_top.sv tb_flash_attention_top.v -top tb_flash_attention_top -o simv
./simv | tee rerun_tc3.log
```

This is a suggested rerun command, not a newly validated result. To run TC1/TC2, change the testbench's Q_FILE, K_FILE, V_FILE, and O_FILE parameters consistently.

DC/PrimeTime scripts retain original server paths and library assumptions. Configure those paths and licensed libraries locally, regenerate synthesis outputs, and inspect the selected PrimeTime script's dependencies before running it.

## Archive scope

Selected source, constraints, flow scripts, compact reports, and historical simulation logs are retained. Large generated netlists/SDC/SAIF, verbose logs, reports over 100 KB, PDFs/chat exports, and earlier duplicate source archives are omitted from this GitHub selection; the original uploaded ZIP retains them. Technology libraries are not included. This is a curated evidence archive, not a standalone reproduction of every historical run.
