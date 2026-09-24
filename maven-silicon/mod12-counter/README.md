# MOD-12 Counter — RTL and SystemVerilog Verification

4-bit loadable up/down counter with synchronous active-high reset, reset-over-load priority, and wraparound over legal states 0–11. The combined source contains the RTL and a class-based testbench with generator, driver, monitors, reference model, scoreboard, mailboxes, virtual interfaces, and functional coverage. This is custom SystemVerilog, not UVM.

## Verified results

The September 23, 2026 Synopsys VCS S-2021.09-SP2-7 run passed 259/259 comparisons (59 directed + 200 random), with zero failures and 100% of defined functional coverage. Simulation duration: 2.595 µs. Coverage describes the implemented functional bins, not code coverage or exhaustive proof. Loads of 12–15 are outside the tested scope.

## Run

```bash
vcs -full64 -sverilog mod12_counter_fixed.sv -top top -o simv_fixed -l compile_fixed.log
./simv_fixed -l simulation_fixed.log
```

## Evidence

Results were recorded from the supplied VCS transcript in the master portfolio. Original simulation/compile log files and the architecture image will be added when organized. Do not confuse the earlier five-transaction baseline with this corrected source.
