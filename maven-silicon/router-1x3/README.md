# 📦 1x3 Router – RTL Design & UVM-Based Verification

This project implements a **1x3 packet-based router** using Verilog HDL, with **UVM-based verification in progress** in SystemVerilog. The design routes incoming 8-bit data to one of three output ports based on header information. It implements custom flow control using `pkt_valid`/`busy` on the input and `vld_out`/`read_enb` on each output. A fully testbench-driven environment with reusable UVM components remains part of the verification scope.

**Status:** RTL implementation structurally complete; design debugging and verification in progress. All major RTL blocks are present and connected. Reset/recovery corrections and simulation validation remain outstanding.

---

## 📘 Project Overview

- **Router Type**: 1 input → 3 outputs
- **Header**: 2-bit destination field determines routing path; header bits `[7:2]` encode payload length
- **Design Language**: Verilog HDL
- **Verification**: UVM (SystemVerilog) — in progress
- **Tools Used**: Xilinx ISE (RTL), Siemens QuestaSim (Simulation), as listed in the original project documentation; supporting run reports remain pending. Synopsys VCS is the intended tool for the next validation run.

---

## 🧠 Key Features

- **FSM-based packet decoder:** implemented as an eight-state controller; validation in progress.
- **Each output port has internal buffering (FIFO-style logic):** three 16-entry FIFOs, each storing 8 data bits and a header-marker bit.
- **Ready/Valid handshake protocol:** retained as the original feature label; specifically, this design uses custom `pkt_valid`/`busy` and `vld_out`/`read_enb` flow control, not a standard ready/valid bus protocol.
- **Full UVM-based environment — in progress:**
  - Sequence, Driver, Monitor, Agent, Scoreboard, Environment.
  - The SystemVerilog interface with source/destination clocking blocks and modports is available; UVM component files and testbench integration remain to be reviewed.
- **Random and directed test generation — in progress.**
- **Assertion-based checking — in progress.**
- **100% functional and code coverage — target; coverage closure in progress.** No coverage report currently establishes this result. Functional and code coverage must be reported separately after measurement.

## RTL Architecture

| File | Responsibility |
|---|---|
| `router_top.v` | Connects the controller, register block, routing control, and three FIFO instances. |
| `router_fifo.v` | 16×9-bit storage, read/write pointers, full/empty detection, and header tracking. |
| `router_fsm.v` | Eight-state packet loading, FIFO stall/recovery, and parity-control sequencing. |
| `router_reg.v` | Header and stalled-byte storage, XOR parity accumulation, and error indication. |
| `router_sync.v` | Destination selection, FIFO write enables, output-valid signals, and timeout reset generation. |
| `router_if.sv` | Source/destination driver and monitor clocking blocks and modports. |

Routing uses destination codes 0, 1, and 2. The design uses a synchronous active-low reset and includes a 30-cycle unread-output timeout mechanism. These are implementation characteristics, not yet verified results.

## Design Corrections — In Progress

- Reset the FIFO read pointer as well as the write pointer during soft reset; review packet-counter/header-marker reset behavior.
- Initialize and consistently deassert all soft-reset outputs so they form controlled pulses.
- Use the captured packet destination for FSM timeout recovery instead of live payload bits.
- Validate packet transfer, parity, FIFO full/recovery behavior, and timeout recovery after the corrections.

## Verification and Completion — In Progress

Retain the existing verification scope: reusable UVM components, directed and randomized traffic, assertions, functional coverage, and code coverage. Required checks include all three destinations, packet-length boundaries, correct/incorrect parity, FIFO backpressure, simultaneous reads/writes, resets, and timeout recovery.

Keep final RTL, interface, UVM sources, testbench top/package, verification plan, compile/run scripts, simulation logs, and coverage reports together. Completion requires passing tests and measured coverage; the current project has no supported pass-count or coverage percentage.
