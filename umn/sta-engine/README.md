# C++ Static Timing Analysis Engine

University of Minnesota project implementing gate-level static timing analysis using ISCAS-style netlists and a simplified Liberty nonlinear delay model (NLDM).

The engine constructs fan-in/fan-out connectivity, traverses the circuit graph, interpolates delay and slew tables, and reports circuit delay, node slack, and a critical path.

## Features

- C++17 implementation using STL containers.
- Netlist parsing and topological ordering.
- 7 × 7 NLDM delay/slew lookup tables.
- Forward arrival-time and slew propagation.
- Backward required-time propagation and slack calculation.
- Text reports for timing results and critical-path inspection.

## Build and run

Requires GNU Make and a C++17 compiler.

```sh
make
./build/sta examples/NLDM_lib_max2Inp.lib examples/c17.isc
cat ckt_traversal.txt
```

Substitute `examples/c7552.isc` for the larger combinational example. The executable writes `ckt_traversal.txt` in the current directory, overwriting any report with that name.

## Reproduced results

The reports in `results/` were regenerated during repository preparation with `g++ -O2 -std=c++17` from the source included here. The source matches the revised uploaded package.

| Benchmark | Reported circuit delay | Non-finite values | Status |
|---|---:|---:|---|
| c17 | 62.50 ps | 0 | Finite output |
| c7552 | 864.95 ps | 0 | Finite output |
| b15_1 | 0.00 ps | 223 | Known invalid result |

Finite output is not proof of timing accuracy; no instructor golden-output or commercial-tool comparison has been established. All three runs return exit code 0, including the invalid b15_1 case.

## Repository contents

| Path | Contents |
|---|---|
| `src/sta.cpp` | Selected end-to-end STA implementation |
| `Makefile` | Build configuration |
| `examples/` | Sample NLDM library, two combinational examples, and b15_1 failure reproducer |
| `results/` | Reproduced reports for these examples |

## Timing model

The supplied academic library declares `sample_45nm_Library`, with time in ns, capacitance in fF, nominal voltage 1.10 V and temperature 25 °C. These sample declarations do not establish a foundry-qualified process or signoff flow.

## Current limitations

The b15_1 example produces invalid numerical results. Prior review also identified LUT-boundary interpolation issues, incomplete multi-input slew scaling, approximate critical-path predecessor selection, and missing topological/finite-value validation. Larger b-series outputs in the original archive contain non-finite values.

This package preserves the supplied algorithm without repairs. It demonstrates academic STA implementation and analysis; numerical correctness across the full benchmark suite remains to be validated.
