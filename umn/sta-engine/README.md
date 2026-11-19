# C++ Static Timing Analysis Engine

Academic gate-level timing analysis project from the University of Minnesota. Reads ISCAS-style netlists and a simplified Liberty NLDM library, constructs fan-in/fan-out connectivity, and computes arrival times, output slews, required times, slack, and a reported critical path.

## Contribution and source history

Vikram Raghavan completed work starting from partially implemented code shared by seniors, as confirmed by Vikram during portfolio preparation. This is an extension of shared starter code, not a claim of sole authorship of every line.

The selected implementation was supplied as `reference_sources/Senior_2_Ref/PA1Solution_kumaw010.cpp`. It is preserved byte-for-byte as `src/sta.cpp`; the historical filename is retained here for traceability. The supplied archive does not isolate individual contributors' edits. The Makefile and repository documentation were added during portfolio preparation. Earlier noncompiling variants and course assignment documents are omitted.

## Build and run

Requires GNU Make and a C++17 compiler.

```sh
make
./build/sta examples/NLDM_lib_max2Inp.lib examples/c17.isc
cat ckt_traversal.txt
```

The executable writes `ckt_traversal.txt` in its current directory, replacing any existing report with that name. Substitute `c7552.isc` for the larger combinational example. `b15_1.isc` is retained as a known failure reproducer.

## Reproduced results

The checked-in reports under `results/` were regenerated from the packaged source using `g++ -O2 -std=c++17` during repository preparation.

| Benchmark | Reported circuit delay | Non-finite values | Interpretation |
|---|---:|---:|---|
| c17 | 62.50 ps | 0 | Finite output; golden-reference accuracy not established |
| c7552 | 864.95 ps | 0 | Finite output; golden-reference accuracy not established |
| b15_1 | 0.00 ps | 223 | Invalid timing result; known limitation |

All three processes returned exit code 0, demonstrating why process success alone is insufficient to validate timing results.

## Implementation scope

- Dynamic graph storage using C++ STL containers.
- Topological forward and backward traversals.
- 7 × 7 delay/slew lookup tables and interpolation.
- Arrival, required-time, slack, and path reporting.

The included library declares `sample_45nm_Library`, 1 ns time units, 1 fF capacitance units, nominal 1.10 V and 25 °C. It is an academic sample, not a foundry-qualified timing flow. This project does not use the TSMC 16 nm library from the separate hardware projects.

## Known limitations

Numerical accuracy has not been compared against instructor golden results or a commercial STA tool. The prior source review identified LUT-boundary interpolation problems, incomplete multi-input slew scaling, approximate critical-path predecessor selection, and missing topological/finite-value validation. Larger b-series runs in the supplied archive also contain non-finite results. These are documented limitations, not validated large-design timing performance.

This repository preserves the supplied implementation without algorithm changes. It is an educational STA project, not a signoff timing engine.
