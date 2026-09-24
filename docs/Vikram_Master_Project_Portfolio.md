# Vikram Raghavan — Master Project Portfolio

Technical project descriptions, architecture, implementation details, metrics, and analysis.

## Maven Silicon — Project 01

### MOD-12 Loadable Up/Down Counter — RTL and SystemVerilog Verification

**Status:** Complete for the defined legal-input RTL and functional-verification scope. Validated in Synopsys VCS on September 23, 2026.

### 1. Project files

| ID | File | Contents |
|---|---|---|
| S1 | `Mod12(up_down).sv` | Original combined RTL and layered testbench; baseline. |
| S2 | `Mod12_TB.png` | Verification architecture diagram. |
| S3 | `README.md` | Original overview; simulator and direction-signal naming differ from the validated implementation. |
| S4 | `mod12_counter_fixed.sv` | Corrected testbench with unchanged counter RTL; run source saved as `mod12_counter.sv` on the UMN machine. |
| S5 | `Pasted text(3).txt` | Successful VCS transcript, including scoreboard, coverage, simulator version, and finish time. |

### 2. Purpose and technical description

Designed a 4-bit loadable up/down counter with modulo-12 wraparound over legal states 0–11 and a modular, class-based SystemVerilog verification environment. Synchronous active-high reset clears the count; synchronous load writes the input; otherwise, the counter increments or decrements. Reset takes priority over load, and load over counting.

The verification environment separates stimulus generation, driving, input observation, expected-result calculation, output observation, and comparison. Four typed mailboxes connect transaction-level components. Virtual interfaces, clocking blocks, and modports connect the classes to the DUT. This is custom SystemVerilog verification without a UVM dependency.

### 3. Design specifications

| Item | Specification |
|---|---|
| DUT / top | `counter` / `top` |
| Input / output | `data_in[3:0]` / `data_out[3:0]` |
| Clock | Rising-edge sequential logic; 10 ns testbench period |
| Reset | `rst`, synchronous active high; clears output to zero |
| Load | `load`, synchronous; copies `data_in` |
| Direction | `mode=1`: increment; `mode=0`: decrement |
| Legal states | 0–11 inclusive |
| Wraparound | Up: 11 → 0; down: 0 → 11 |
| Priority | Reset → load → counting |
| Enable / hold | No separate enable; counts when reset and load are low |
| Timescale | 1 ns / 1 ps |

The verification contract restricts loaded values to 0–11. RTL accepts four-bit inputs without a range check; loads of 12–15 are outside the validated scope.

### 4. Verification architecture

| Component | Responsibility |
|---|---|
| `count_trans` | Randomized controls and legal input data, weighted constraints, transaction statistics. |
| `count_gen` | 59 directed and 200 constrained-random transactions. |
| `count_wr_drv` | Drives inputs on falling clock edges with a testbench-only valid marker. |
| `count_wr_mon` | Samples valid input transactions before rising-edge DUT updates. |
| `count_rd_mon` | Samples corresponding outputs after rising-edge nonblocking updates. |
| `count_model` | Calculates expected updated state using blocking assignments. |
| `count_sb` | Checks expected versus observed outputs, rejects unknowns, counts passes/failures, and samples coverage. |
| `env` | Builds components and four mailboxes; coordinates startup, completion, and reporting. |
| `test` | Runs the environment and finishes simulation. |
| `count_if` | Signals, three clocking blocks, and three modports. |
| `top` | Instantiates DUT/interface, generates clock, and provides timeout protection. |

Communication: generator → driver; input monitor → model; model → scoreboard; output monitor → scoreboard. Simulation completes only after all 259 valid transactions are compared.

### 5. Quantitative facts and measured results

| Metric | Result | Evidence / conditions |
|---|---|---|
| Counter width / legal states | 4 bits / 12 states | RTL. [S4] |
| Directed / random transactions | 59 / 200 | Generator sequence. [S4] |
| Checked / passed / failed | **259 / 259 / 0** | Scoreboard. [S5] |
| Defined functional coverage | **100.00%** | `counter_cov.get_inst_coverage()`. [S5] |
| Simulation duration | **2.595 µs** | 2,595,000 ps at finish. [S5] |
| Simulator | **Synopsys VCS S-2021.09-SP2-7, Full64** | Compiler/runtime banner. [S5] |
| Classes / typed mailboxes | 9 / 4 | Source architecture. [S4] |
| Clocking blocks / modports | 3 / 3 | Interface. [S4] |
| Coverage structure | 8 coverpoints + 1 control cross | Reset, load, mode, input values, loaded values, output values, and two wrap indicators. [S4] |
| Randomization weights, 0:1 | Reset 90:10; load 30:30; mode 50:50 | Relative weights, not measured frequencies. [S4] |
| Area / timing / power | Not measured | No synthesis, STA, or power results included. |

Coverage is 100% of the implemented functional model, not code coverage or exhaustive proof. Evidence establishes one successful simulation run; an explicit random seed was not recorded in the supplied transcript.

### 6. Tests, corrections, and technical analysis

**Directed sequence: 59 transactions**

- One initial reset.
- 24 loads: each legal value 0–11 with both direction settings.
- 26 transactions: load 11 and count up for 12 cycles; load 0 and count down for 12 cycles. These exercise all legal count states and both wraparounds.
- Eight transactions: establish a nonzero count and then reset for each of the four load/mode combinations, checking reset priority.

An additional 200 constrained-random transactions exercise mixed operations. All 259 outputs matched the reference model. [S4, S5]

| Original limitation | Correction |
|---|---|
| Output monitor and model both published old state | Falling-edge input driving, blocking model updates, and output sampling after DUT updates align each comparison with its transaction. |
| Startup samples counted toward the five-comparison stop threshold | Valid marker excludes idle samples; completion waits for all 259 driven transactions. |
| Verified count included mismatches | Separate checked/passed/failed totals, unknown-output rejection, and fatal final failure. |
| Five random transactions without an explicit boundary sequence | Added directed load, count-cycle, wraparound, and reset-priority checks, followed by 200 random transactions. |
| Input bins omitted endpoints; wraparound lacked explicit coverage | Individual legal-value bins, loaded/output values, wrap indicators, and control cross coverage. |
| Unspecified time units and no timeout | Explicit timescale, 10 ns clock, and 100 µs fatal timeout. |

Counter RTL behavior was preserved. For illegal states, the model's upward `>=11` test differs from the DUT's `==11`; this does not affect the constrained legal-state scope and is not claimed as verified.

The original README names QuestaSim and `up_down`. The documented validated run uses VCS and the actual direction port `mode`. Its original file is retained as baseline documentation.

### 7. Technical skills

SystemVerilog; sequential RTL; class-based verification; directed testing; constrained randomization; weighted distributions; virtual interfaces; clocking blocks; modports; typed mailboxes; transaction copying; reference modeling; scoreboarding; functional coverage; cross coverage; simulation scheduling; test completion; Synopsys VCS.

### 8. Reusable descriptions

**Detailed portfolio description:**

Designed a 4-bit MOD-12 loadable up/down counter and a layered SystemVerilog verification environment with synchronous reset, load priority, and bidirectional wraparound. Integrated stimulus generation, driver, independent input/output monitors, reference model, scoreboard, typed mailboxes, and virtual interfaces. Corrected model/monitor timing alignment, introduced valid-transaction completion tracking, and added explicit failure reporting. Verified the design in Synopsys VCS using 59 directed and 200 constrained-random transactions, achieving 259 passing comparisons with zero failures and 100% of defined functional coverage.

**Résumé description:**

Developed a class-based SystemVerilog testbench for a MOD-12 up/down counter using directed and constrained-random stimulus, a reference model, and scoreboarding; passed 259 checks in VCS with 100% of defined functional coverage.

**LinkedIn project description:**

Designed and verified a MOD-12 loadable up/down counter using a modular SystemVerilog testbench. Combined directed and constrained-random stimulus, typed mailboxes, virtual interfaces, independent monitors, a reference model, and a self-checking scoreboard. Validated legal loads, counting in both directions, wraparound, and reset priority in Synopsys VCS: 259 comparisons passed, zero failures, and 100% of defined functional coverage.

### 9. Supporting evidence and reproducibility

| File / evidence | Status |
|---|---|
| `mod12_counter_fixed.sv` | Corrected RTL/testbench deliverable; user ran source saved as `mod12_counter.sv`. |
| `Pasted text(3).txt` | Available successful VCS transcript. |
| `simulation_fixed.log` | Log filename shown in the successful command; contents supplied as pasted text. |
| `compile_fixed.log` | Not supplied; retain alongside final source. |
| `Mod12_TB.png` | Available architecture illustration. |
| Original `.sv` and `README.md` | Retained baseline files. |
| Detailed coverage database / waveforms | Not supplied; aggregate coverage is documented by the transcript. |

Reproduction commands using the corrected deliverable filename:

```bash
vcs -full64 -sverilog mod12_counter_fixed.sv -top top -o simv_fixed -l compile_fixed.log
./simv_fixed -l simulation_fixed.log
```

The supplied run reports `mod12_counter.sv` at `$finish`, reflecting the filename used on the UMN machine. Preserve the exact compiled source with its logs.

### 10. Completion scope

The legal-input counter design and defined functional test plan are complete with passing VCS evidence. Synthesis, physical implementation, code-coverage measurement, multiple-seed regression, and illegal-load behavior are outside this completed scope.

---

## Maven Silicon — Project 02

### Traffic-Light Controller — FSM Design and Self-Checking Verification

**Status:** Complete for the implemented RTL and simulation-verification scope. Validated in Synopsys VCS on September 23, 2026.

### 1. Purpose and technical description

Implemented a traffic-light controller using a five-state finite-state machine and a clock-cycle counter to sequence road signals. Refactored the original behavioral implementation by replacing clock waits inside next-state logic with explicit sequential timing logic. Preserved the five-state sequence, with yellow phases configured for three clock cycles and the all-red phase for two clock cycles.

A self-checking SystemVerilog testbench exercises phase timing, repeated requests, reset in each state, and conflicting-light conditions. The completed VCS run reports 72 passing output checks and normal simulation termination.

### 2. Architecture and specifications

| Element | Implementation |
|---|---|
| Controller | Five-state FSM |
| Phase timing | Clock-cycle counter replacing procedural clock waits |
| Yellow interval | 3 clock cycles in the tested configuration |
| All-red interval | 2 clock cycles in the tested configuration |
| Verification | Self-checking SystemVerilog testbench |
| Testbench top | `traffic_light_controller_tb` |
| Simulation tool | Synopsys VCS, Full64 |

The FSM determines the active signal phase; the counter tracks timed-phase duration. This makes timing explicit in clock cycles and separates state progression from simulation-only waiting behavior.

### 3. Improvements and verification analysis

| Initial limitation | Implemented improvement |
|---|---|
| Clock waits embedded in next-state logic | Replaced waits with a hardware-style cycle counter and FSM timing logic. |
| Stimulus without automatic correctness checks | Added self-checking output comparisons. |
| Limited functional stimulus outside reset | Added phase progression, repeated-request, and reset-in-each-state scenarios. |
| Phase durations not automatically checked | Added checks for three-cycle yellow and two-cycle all-red intervals. |
| No automatic completion | Added a pass summary and simulation finish. |
| Conflicting lights not automatically checked | Added safety checks for conflicting signal conditions. |

### 4. Measured results

| Metric | Result | Evidence / conditions |
|---|---|---|
| Output checks | **72 passed** | VCS transcript: `PASS: 72 output checks; yellow=3 all-red=2`. |
| Yellow / all-red timing | **3 / 2 clock cycles** | Tested configuration reported by the pass summary. |
| Simulation duration | **726 ns** | VCS reports `726000 ps`. |
| Simulator version | **S-2021.09-SP2-7_Full64** | Compiler and runtime banner. |
| Run date | **September 23, 2026** | Supplied simulation transcript. |
| Completion | Normal `$finish` | `tb/traffic_light_controller_tb.sv`, line 74 in the tested source. |

The 72 checks are output comparisons, not 72 independent test scenarios. The supplied transcript establishes a successful run of the implemented testbench; it does not provide a functional-coverage or code-coverage percentage. No synthesis, area, timing-analysis, or power results are claimed.

### 5. Technical skills

Verilog RTL; finite-state machines; sequential logic; cycle counters; traffic-signal sequencing; SystemVerilog self-checking testbenches; directed testing; reset verification; phase-duration checks; safety checks; Synopsys VCS.

### 6. Reusable descriptions

**Detailed portfolio description:**

Implemented and verified a five-state traffic-light controller with cycle-counted phase timing. Replaced behavioral clock waits with explicit FSM and counter logic, preserving three-cycle yellow and two-cycle all-red phases. Developed a self-checking SystemVerilog testbench to exercise phase durations, repeated requests, reset in every state, and conflicting-light conditions. Validated the controller in Synopsys VCS with 72 passing output checks over a 726 ns simulation.

**Résumé description:**

Implemented a five-state traffic-light FSM with cycle-counted phase timing and a self-checking SystemVerilog testbench; passed 72 output checks in Synopsys VCS for phase sequencing, reset behavior, and signal safety.

**LinkedIn project description:**

Designed and verified a five-state traffic-light controller using Verilog and SystemVerilog. Replaced behavioral timing waits with a clock-cycle counter and added automatic checks for phase timing, repeated requests, resets, and conflicting lights. Completed a successful Synopsys VCS simulation with 72 passing output checks, using three-cycle yellow and two-cycle all-red phases.

### 7. Project files and reproducibility

| File | Role |
|---|---|
| `rtl/traffic_light_controller.v` | Improved FSM and cycle-counter implementation. |
| `tb/traffic_light_controller_tb.sv` | Self-checking testbench used for the successful run. |
| `simulation_traffic.log` | Simulation log; successful output supplied in the conversation. |
| `compile_traffic.log` | Compilation evidence to retain with the final source. |
| `Traffic_Light_Controller_Improved.zip` | Prepared project package containing the revised files and preserved originals. |

Run from the project directory:

```bash
vcs -full64 -sverilog rtl/traffic_light_controller.v tb/traffic_light_controller_tb.sv -top traffic_light_controller_tb -o simv_traffic -l compile_traffic.log
./simv_traffic -l simulation_traffic.log
```

Retain the exact compiled RTL and testbench with both logs. The measured results above are grounded in the supplied VCS transcript.

### 8. Completion scope

The improved controller and implemented simulation test plan are complete with passing VCS evidence. Synthesis and physical implementation are outside this completed scope.

---

## Maven Silicon — Project 03

### 1×3 Packet Router — RTL Design and UVM Verification

**Project period:** May–June 2025, as shown in the project listing.

**Status:** RTL implementation structurally complete; design debugging and verification in progress.

### 1. Purpose and technical description

Implemented a modular Verilog packet router with one 8-bit input and three 8-bit output ports. Header-based destination decoding selects an output FIFO, while an eight-state FSM coordinates header loading, payload transfer, parity handling, and FIFO backpressure. A register block stores the header and a stalled byte and calculates XOR parity. Per-port control generates valid indications and timeout-driven soft resets.

The verification scope includes a reusable UVM environment, directed and randomized tests, assertions, functional coverage, and code coverage. The available SystemVerilog interface supplies source/destination clocking blocks and modports. Verification remains in progress; no passing regression or achieved coverage percentage is recorded.

### 2. Architecture and source-derived specifications

| Item | Implementation |
|---|---|
| Ports / data width | One input, three outputs; 8-bit data |
| Header destination | Bits `[1:0]`; output codes 0, 1, and 2 |
| Header length | Six-bit field `[7:2]` used by FIFO packet tracking |
| Output buffering | Three 16×9-bit FIFOs: 8-bit data plus header marker |
| Total FIFO storage | 432 bits including markers; structural capacity, not synthesis area |
| FIFO pointers | 5-bit read/write pointers including wrap bit |
| FSM | Eight states, encoded in 3 bits |
| Reset | Synchronous active-low `resetn` |
| Error checking | XOR parity accumulator and received-parity comparison |
| Timeout | Counter threshold intended to trigger after 30 unread valid-output cycles |
| Flow control | Custom `pkt_valid`/`busy` input and `vld_out`/`read_enb` output signaling |
| Verification interface | Four clocking blocks and four modports |

This is header-based packet routing with a custom interface. OSI is not the implemented protocol. Specifications above describe the source; timeout and recovery behavior still require correction and testing.

### 3. RTL blocks and supporting files

| File | Role |
|---|---|
| `router_top.v` | Top-level integration and three FIFO instances |
| `router_fifo.v` | Storage, pointers, flags, and packet tracking |
| `router_fsm.v` | Packet sequencing and stall/recovery control |
| `router_reg.v` | Header/data registers and parity/error logic |
| `router_sync.v` | Destination selection, write enables, valid flags, timeout counters |
| `router_if.sv` | Testbench signal access through clocking blocks/modports |
| `README_router.md` | Project overview and current implementation/verification status |

### 4. Technical analysis and outstanding corrections

| Finding | Required change / validation |
|---|---|
| FIFO soft reset resets the write pointer but not the read pointer | Reset both pointers coherently and verify flush/reuse; review packet metadata reset. |
| Soft-reset outputs lack reset assignment and unconditional deassertion paths | Initialize outputs and generate bounded reset pulses. |
| FSM selects timeout recovery using live input destination bits | Use the captured packet destination so payload bits cannot select recovery. |
| Full/recovery and parity paths have no supplied test results | Exercise stalled payload/parity transfers and compare complete output packets. |

All major design blocks are present and connected. Structural completeness does not establish functional correctness or synthesis validation. RTL corrections have not yet been applied.

### 5. Verification scope and results

UVM verification is in progress. The retained scope includes sequences, drivers, monitors, agents, scoreboard, environment, directed/random stimulus, and assertions. UVM source files, integration top/package, test plan, simulation results, and coverage reports remain outstanding for review.

The test plan should validate all destinations, packet-length boundaries, parity errors, full/empty behavior, simultaneous reads/writes, backpressure recovery, resets, and timeout recovery. The original 100% functional/code-coverage claim is retained as a target, not an achieved metric. No simulation check count, coverage percentage, area, timing, or power result is currently supported.

### 6. Tools and technical skills

**Languages:** Verilog and SystemVerilog. **Original documented tools:** Xilinx ISE and Siemens QuestaSim; supporting reports pending. **Next validation tool:** Synopsys VCS.

Implemented skills include modular RTL integration, finite-state machines, FIFO design, packet decoding, parity logic, backpressure control, and verification interfaces. UVM, constrained-random testing, assertions, and coverage closure remain part of the verification work in progress.

### 7. Reusable descriptions

**Portfolio / LinkedIn description:**

Implemented a 1×3 packet router in Verilog with an 8-bit datapath, three 16-entry output FIFOs, an eight-state controller, header-based destination selection, and XOR parity checking. Integrated FIFO backpressure and timeout-recovery logic with a SystemVerilog verification interface. RTL debugging and UVM-based verification are in progress, including directed/random traffic, assertions, and coverage measurement.

**Résumé description:**

Implemented an 8-bit 1×3 packet router with three 16-entry FIFOs, an eight-state FSM, and parity checking; design debugging and UVM verification in progress.

### 8. Supporting evidence and completion requirements

Retain all six RTL/interface files and the README. Add the UVM component sources, testbench top/package, verification plan, compile/run scripts, simulation logs, and functional/code-coverage reports when available. Useful waveforms should demonstrate packet routing, FIFO stalls, parity errors, and timeout recovery.

The portfolio entry is documented at its current stage. Engineering completion remains pending the identified RTL corrections and successful verification; it is not yet a completed, validated router project.
