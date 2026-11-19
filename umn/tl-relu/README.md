# TL-ReLU accelerator — transistor-level FinFET design

University of Minnesota custom-circuit project implementing thresholded leaky ReLU with an 8-bit unsigned input, a 4-bit threshold, fixed alpha=1/8, and an unsigned 11-bit Q8.3 output.

The output integer code is `8*x` when `x > theta`, and `x + 7*theta` otherwise. Dividing the code by 8 gives the real-valued output.

## Design

The integrated HSPICE netlist contains the custom circuit hierarchy: DFF banks, full adders, subtract/shift-add arithmetic, upper-bit fast-path selection, mux banks, and output loading. Devices reference the external TSMC N16 FinFET model environment.

The selected source is [verification/tlrelu_topdff.sp](verification/tlrelu_topdff.sp), the integrated snapshot used by the archived verification decks. Earlier integrated snapshots are omitted.

## Verification results

Archived HSPICE `.mt0` measurements were decoded again during repository preparation at a 0.4 V threshold and compared against the integer-code function above. No fresh HSPICE simulation was performed.

| Test group | Passing | Total |
|---|---:|---:|
| Directed cases | 17 | 20 |
| Sweep: theta=15, x=0..32 | 33 | 33 |
| Combined | **50** | **53** |

| Failing directed input (x, theta) | Measured code | Expected code |
|---|---:|---:|
| (15, 14) | 113 | 120 |
| (3, 2) | 17 | 24 |
| (15, 0) | 15 | 120 |

See [measurement_check.csv](results/measurement_check.csv) for the rechecked values, and `verification/tb_runs/` for original decks and measurements. The CSV lists directed cases first, followed by sweep points.

Saved decks specify **TPER=84 ps**, **N_CYC=1**, **0.8 V**, **25 °C**, and the **TTMacro_MOS_MOSCAP** model section. This is a tested period with three failing cases, not a fully passing minimum period or a demonstrated maximum operating frequency. Report prose using 84 ns conflicts with the actual deck's `84p` setting.

## Files

- `verification/tlrelu_topdff.sp`: integrated design netlist.
- `verification/generate_tb.py`: Python testbench-generation and checking script.
- `verification/tb_runs/`: 20 directed decks/measurements and the 33-point sweep.
- `results/measurement_check.csv`: comparison regenerated from the saved analog measurements.

Native Cadence/OpenAccess schematics, symbols, waveform binaries, verbose simulator logs, earlier snapshots, and report documents remain in the original ZIP. The GitHub subset focuses on readable circuit and verification evidence. No PDK model library is included.

## Rerunning

Requires licensed HSPICE and access to the referenced TSMC model library. Configure model paths in the generator before use; archived decks also contain absolute model and DUT paths.

```sh
cd verification
python3 generate_tb.py
```

The script prompts for the netlist path, period in picoseconds, and number of cycles. The archived configuration uses `tlrelu_topdff.sp`, `84`, and `1`. It launches HSPICE and writes into `tb_runs/`; use a separate working copy to preserve archived results.

## Current limitations

Three directed cases fail. The prior circuit review also identified an unresolved raw-versus-registered input wiring question. The cause and any correction require circuit review and a new simulation; the archived measurements alone do not prove a timing-only cause.

This evidence establishes schematic/netlist-level simulation work. It does not establish completed layout, DRC/LVS closure, or signoff.
