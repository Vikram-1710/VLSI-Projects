# Traffic Light Controller — Counter-Based FSM Revision

Five-state highway/country-road controller with a synchronous active-high reset, sensor input, and parameterized phase durations. The original files are preserved in `original/`.

## Behavior

| State | Highway | Country | Exit condition |
|---|---|---|---|
| S0 | Green | Red | Sensor X high |
| S1 | Yellow | Red | YELLOW_CYCLES elapsed |
| S2 | Red | Red | ALL_RED_CYCLES elapsed |
| S3 | Red | Green | Sensor X low |
| S4 | Red | Yellow | YELLOW_CYCLES elapsed |

Reset selects S0. Defaults are three cycles for each yellow phase and two cycles for the all-red phase. Phase time is counted from the edge entering the state; a duration of one exits on the next rising edge. Sensor changes do not interrupt timed phases. The original five-state sequence is preserved, including direct S4-to-S0 return (no additional all-red phase on that return).

The RTL replaces procedural clock waits with a registered timer and combinational next-state/output logic. Default output decoding selects both red for an invalid state; next-state logic recovers to S0. Inputs are assumed synchronous. This is an educational controller, not a deployment-qualified road safety system.

## Files

- `rtl/traffic_light_controller.v`: revised controller; original port names retained.
- `tb/traffic_light_controller_tb.sv`: self-checking directed testbench.
- `run_checks.sh`: Icarus simulation runs and optional Yosys structural synthesis check.
- `original/`: unchanged original design, testbench, and README.

## Test plan

Tests check highway idle priority, country-road service, exact phase durations, country-green hold, sensor changes during timed phases, repeat requests, reset in all five phases, output encodings, and conflicting non-red outputs. Failures terminate with `$fatal`; successful completion prints a PASS summary. A watchdog prevents indefinite runs. The script selects timing configurations (3,2), (1,1), and (4,3) to cover default, minimum, and unequal durations.

## Run

With Icarus Verilog installed, run from this directory:

```bash
bash run_checks.sh
```

Results go under `results/`, with separate compile logs, simulation logs, and VCD waveforms for each configuration. If Yosys is installed, the script also runs an RTL structural synthesis check at the default configuration.

## Validation status

The default (yellow=3, all-red=2) configuration passed 72 output checks in Synopsys VCS S-2021.09-SP2-7 on September 23, 2026; simulation duration was 726 ns. This result is recorded from the supplied VCS transcript. Original log files remain to be added. The other configurations in `run_checks.sh` and the optional synthesis step are not claimed as executed.

## VCS run

```bash
vcs -full64 -sverilog rtl/traffic_light_controller.v tb/traffic_light_controller_tb.sv -top traffic_light_controller_tb -o simv_traffic -l compile_traffic.log
./simv_traffic -l simulation_traffic.log
```
