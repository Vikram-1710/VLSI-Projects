# FP16 Multiply–Accumulate — 16 nm ASIC Implementation

Verilog datapath development, Design Compiler synthesis, ICC2 physical implementation, and post-route PrimeTime analysis. University of Minnesota, Fall 2025.

## Architecture

The datapath unpacks FP16 operands, performs iterative significand multiplication, aligns products into an 80-bit fixed-point window, and accumulates into an 88-bit magnitude with a separate sign. The default accumulator has 48 fractional bits. Significand width is configurable at elaboration. Subnormals, infinities, and NaNs are outside the implemented arithmetic scope.

## Headline results

User-reported reductions are **21.78% in synthesis area** and **28% in estimated power**. Matching baseline/configuration reports for these percentages remain to be identified. The archived 11-bit versus 9-bit comparison below yields different percentages.

## Synthesis comparison

The two archived core synthesis runs use a 5 ns target.

| Configuration | Cell area | Estimated total power |
|---|---:|---:|
| 11-bit significand | 824.41 µm² | 115.0 µW |
| 9-bit significand | 801.91 µm² | 108.7 µW |

Reductions are 2.73% in area and 5.48% in estimated power. See `synthesis_experiments/Synthesis_Report_3_Final` and `Synthesis_Report_3_Final_Comparison`. Numerical error from precision reduction remains unquantified.

## Physical implementation and timing

A separate 1 ns full-chip implementation completed floorplanning, placement, CTS, and routing in ICC2. The routed report lists 3,691 leaf cells and 1,592.01 µm² cell area. ICC2 reports register-to-register setup slack of -1.21 ns. The test-output path has an extreme load and approximately -2126 ns slack requiring constraint/load review.

`flows/signoff` includes the PrimeTime script and setup, hold, OCV, derated timing, and power reports. Setup violations remain. The archive establishes post-route analysis, with GDSII export and physical signoff closure unconfirmed. Estimated power depends on limited switching activity annotation.

## Files

- `source_snapshot/` — archived root RTL, testbench, Python reference, and VCS setup.
- `rtl_iterations/` — baseline and successive implementation experiments.
- `archived_rtl/` — earlier sources including split modules.
- `synthesis_experiments/` — synthesis scripts, inputs, and comparison reports.
- `flows/dc/`, `flows/dc_topo/` — synthesis and topographical resynthesis.
- `flows/dp/` — floorplanning, power planning, placement, CTS/routing scripts and reports.
- `flows/fv/` — archived DFT-related synthesis work.
- `flows/signoff/` — PrimeTime analysis scripts and reports.

## Verification status

The preserved root/V3_FINAL testbench contains a module instantiation inside an initial block and requires repair before compilation. Stimulus also begins during reset and two instances share outputs. The Python reference uses numerical uint16-to-float16 conversion instead of bit reinterpretation. Product alignment has a documented factor-of-two concern under the declared fractional scale. These sources are historical work in progress. No new passing simulation or EDA run is claimed for this upload.

## Reproduction requirements

Flows require licensed Synopsys tools and separately obtained N16ADFP technology libraries. Scripts retain original directory assumptions and must be configured for the local environment. Match each RTL snapshot to its constraints and reports. The reduced repository omits technology libraries, tool databases, generated netlists/parasitics, caches, and bulk execution logs. Original report timestamps and source contents are preserved.

The uploaded review ZIP also retains project reports, screenshots, presentation, execution logs and extracted outputs for later selection. No license for third-party technology material is granted by this repository.
