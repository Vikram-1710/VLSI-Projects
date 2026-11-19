# VLSI Projects — Vikram Raghavan

RTL design, verification, synthesis, and physical implementation projects, with source code, flow scripts, and documented results.

| Project | Scope | Status / results |
|---|---|---|
| [FP16 Multiply–Accumulate — UMN](umn/fp16-mac) | 16 nm RTL, synthesis, ICC2 floorplanning/placement/CTS/routing, and PrimeTime analysis | User-reported reductions of 21.78% in synthesis area and 28% in estimated power (matching baseline reports pending). Routed 3,691-cell design. Verification fixes and timing closure remain open. |
| [FlashAttention — UMN](umn/flashattention) | Fixed-point attention RTL, MAC-array/WeightedPE variants, DC synthesis and PrimeTime STA | Historical TC1/TC2 logs: 256 passing comparisons each; MAC-array PT setup slack −0.02 ns at 2 ns. Source/run reconciliation and timing closure remain open. |
| [C++ STA Engine — UMN](umn/sta-engine) | ISCAS parsing, NLDM interpolation, timing propagation, slack and critical-path reporting | C++17 build verified; finite c17/c7552 results. Known b15_1 numerical limitation documented. |
| [MOD-12 Counter](maven-silicon/mod12-counter) | 4-bit counter; class-based SystemVerilog verification | 259 passing comparisons; 100% of defined functional coverage in VCS |
| [Traffic-Light Controller](maven-silicon/traffic-light-controller) | Five-state FSM; self-checking testbench | 72 passing output checks in VCS |
| [1×3 Packet Router](maven-silicon/router-1x3) | 8-bit datapath; three FIFOs; eight-state FSM | RTL implemented; debugging and UVM verification in progress |

Results describe the specific documented simulation, synthesis, and implementation runs. Each project README distinguishes completed work from pending validation.

## Documentation and evidence

- [Master project portfolio](docs/Vikram_Master_Project_Portfolio.md)
- [Evidence checklist](docs/EVIDENCE_CHECKLIST.md)

Compile and run commands appear in each project README. Simulator installations and generated build outputs are not included.
