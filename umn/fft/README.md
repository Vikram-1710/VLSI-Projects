# Fixed-point FFT hardware — 16-point prototype to folded 256-point design

SystemVerilog FFT architecture exploration at the University of Minnesota, with MATLAB reference vectors, self-checking testbenches, and Vivado synthesis analysis.

The primary implementation is [fft256_pipe_2ndRun](implementations/fft256_pipe_2ndRun): a folded iterative radix-2 decimation-in-frequency (DIF) FFT using fixed-point arithmetic, in-place storage, and a reused pipelined butterfly. Its two channels are processed sequentially by one core. Two samples per cycle describes interface/output burst width, not continuous frame throughput.

## Implementations

| Directory | Role |
|---|---|
| `implementations/fft16` | 16-point prototype |
| `implementations/fft256` | Fully unrolled 256-point baseline |
| `implementations/fft256_pipe_2ndRun` | Folded 256-point dual-channel implementation; 8 ns target |

Each version retains its own RTL, testbench, vectors, MATLAB generator, Tcl/XDC, and selected synthesis reports. The filenames `gen_fft16_vectors.m` and `twiddle_rom_512.sv` are historical names; they do not imply the final transform length.

## Verification evidence

The saved final [XSim log](implementations/fft256_pipe_2ndRun/xsim.log) reports PASS for zero, impulse, cosine, and random vector tests. The associated testbench checks real and imaginary outputs on both channels against MATLAB-generated expected values with a ±1 LSB tolerance.

These are archived execution results. No fresh MATLAB, simulation, or synthesis run was performed during GitHub preparation.

## Post-synthesis architecture comparison

| Metric | Unrolled 256-point baseline | Folded 256-point implementation |
|---|---:|---:|
| LUTs | 397,961 | 33,007 |
| Flip-flops | 95,724 | 41,906 |
| DSPs | 740 | 4 |

The folded implementation targets Artix-7 `xc7a200tfbg676-2`. Its saved post-synthesis timing report shows **+1.251 ns setup WNS at an 8 ns (125 MHz) target**, with **−0.032 ns hold slack and 8,192 failing hold endpoints**. This is not full timing closure or a demonstrated routed operating frequency. The baseline exceeds the target device's LUT capacity.

Sources are the version-specific `output/post_synth/*util.rpt` and `*timing_summary.rpt` files. Final folded report names begin `fft256_pipelined_post_synth_`. Resource reduction comes from architectural reuse; it should not be interpreted as equal-throughput performance. Included power reports are vectorless post-synthesis estimates, not measurements.

## Run the final implementation

With Vivado 2020.2 tools on PATH, run from the implementation directory:

```sh
cd implementations/fft256_pipe_2ndRun
vivado -mode batch -source scripts/run_sim.tcl
vivado -mode batch -source scripts/run_syn.tcl
```

The simulation uses the included vector files. To regenerate them, inspect and run `gen_fft16_vectors.m` in MATLAB from the same directory.

These commands follow the supplied scripts and have not been rerun here. Simulation scripts clear local simulator work/cache files and regenerate logs; synthesis replaces generated reports/checkpoints. Preserve archived evidence separately before rerunning.

## Selection

This repository includes source, vectors, scripts, constraints, selected simulation evidence, and synthesis reports for the three versions. Duplicated reports from other versions, intermediate archives, backup logs/journals, tool caches, binaries, course handouts, and presentation/chat material are omitted. Original source files are unchanged.
