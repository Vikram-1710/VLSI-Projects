#!/usr/bin/env python3
"""
generate_tb.py

Python script to generate HSPICE testbenches
for a given custom digital top-level netlist (e.g. "top" from project3).

Features:
- Reads a HSPICE netlist file.
- Finds the LAST .subckt definition and treats it as the top-level.
- Detects pins: clk, out<*>, t<*>, x<*>.
- Asks user for:
    - netlist path
    - clock period in ps in integer (TPER, e.g. "1000" for 1ns)
    - number of cycles until output is valid (N_CYC) (e.g. 1 if you only have 
        ffs at the input and output)
- Generates:
    - One HSPICE testbench per input vector (worst-case + several others).
    - One sweep testbench for theta=15, x=0..32 (students can inspect).
- Runs HSPICE on each per-vector testbench.
- Parses .mt0 files to recover measured output bits.
- Computes golden functional result in Python (Q8.3).
- Compares SPICE vs golden, prints detailed debug info.

Requirements:
- Python 3
- HSPICE in PATH
"""

import os
import re
import sys
import shutil
import random
import subprocess
from pathlib import Path

###########################################################################
# Utility: debug print helpers
###########################################################################

def debug(msg: str):
    print(f"[DBG ] {msg}")

def info(msg: str):
    print(f"[INFO] {msg}")

def warn(msg: str):
    print(f"[WARN] {msg}")

def error(msg: str):
    print(f"[ERR ] {msg}")


###########################################################################
# Step 1: Parse netlist and find top-level subckt and pins
###########################################################################

SUBCKT_RE = re.compile(r'^\s*\.subckt\s+(\S+)\s+(.*)$', re.IGNORECASE)

def parse_top_subckt(netlist_path: Path):
    """
    Parse the netlist and return:
      - top_name: name of last .subckt
      - pins: list of pin names (in order)
    """
    info(f"Parsing netlist: {netlist_path}")
    lines = netlist_path.read_text().splitlines()

    subckt_defs = []
    for line in lines:
        m = SUBCKT_RE.match(line)
        if m:
            name = m.group(1)
            pin_str = m.group(2).strip()
            pins = pin_str.split()
            subckt_defs.append((name, pins))

    if not subckt_defs:
        error("No .subckt definitions found in netlist!")
        sys.exit(1)

    # Last subckt = top
    top_name, top_pins = subckt_defs[-1]
    info(f"Detected top-level subckt: {top_name}")
    debug(f"Top-level pins ({len(top_pins)}): {top_pins}")
    return top_name, top_pins


###########################################################################
# Step 2: Categorize pins by naming convention
###########################################################################

OUT_RE = re.compile(r'^out<(\d+)>$', re.IGNORECASE)
T_RE   = re.compile(r'^t<(\d+)>$', re.IGNORECASE)
X_RE   = re.compile(r'^x<(\d+)>$', re.IGNORECASE)

def categorize_pins(pins):
    clk_pin = None
    out_pins = {}  # bit_index -> pin_name
    t_pins = {}    # bit_index -> pin_name
    x_pins = {}    # bit_index -> pin_name

    for p in pins:
        if p.lower() == "clk":
            clk_pin = p
        else:
            mo = OUT_RE.match(p)
            if mo:
                idx = int(mo.group(1))
                out_pins[idx] = p
                continue
            mt = T_RE.match(p)
            if mt:
                idx = int(mt.group(1))
                t_pins[idx] = p
                continue
            mx = X_RE.match(p)
            if mx:
                idx = int(mx.group(1))
                x_pins[idx] = p
                continue

    if clk_pin is None:
        warn("No 'clk' pin detected! Script assumes one exists.")
    if not out_pins:
        warn("No out<*> pins detected!")
    if not t_pins:
        warn("No t<*> pins detected!")
    if not x_pins:
        warn("No x<*> pins detected!")

    # sort bit indices
    out_bits = sorted(out_pins.keys())
    t_bits   = sorted(t_pins.keys())
    x_bits   = sorted(x_pins.keys())

    info(f"Detected clk pin: {clk_pin}")
    info(f"Detected out pins: {[(i, out_pins[i]) for i in out_bits]}")
    info(f"Detected t pins: {[(i, t_pins[i]) for i in t_bits]}")
    info(f"Detected x pins: {[(i, x_pins[i]) for i in x_bits]}")

    return clk_pin, out_pins, t_pins, x_pins


###########################################################################
# Step 3: Golden model for top-level function (Q8.3)
###########################################################################

def compute_golden_q83(x: int, t: int):
    """
    Compute golden Q8.3 code and float result for given (x, t).

    TLReLU Functional spec:
    - If x > t: f(x) = x (raw path, shift left 3 for Q8.3)
    - If x <= t: f(x) = (1/8)(x-t) + t = (x + 7*t)/8 (computed path)
    
    Q8.3 representation:
    - If x > t (raw path):     code = x << 3
    - If x <= t (computed path): code = x + 7*t
    
    Final real value is code / 8.
    
    Note: For x with MSB bits set (x >= 16), we only compare LSB 4 bits.
    If x >= 16, then x_low might be < t, but we treat it based on full x value.
    Actually, based on project spec, we compare full x with t directly.
    """
    assert 0 <= x <= 255
    assert 0 <= t <= 15

    # Compare x with t
    if x > t:
        # Raw path: x > t means output = x (in Q8.3: x << 3)
        code = x << 3
    else:
        # Computed path: x <= t means output = x + 7*t (already in Q8.3 format)
        code = x + 7 * t

    # Q8.3: real value = code / 8
    real_value = code / 8.0

    return code, real_value


###########################################################################
# Step 4: Test vector generation
###########################################################################

def generate_test_vectors():
    """
    Generate a list of (x, t) test vectors.

    Includes:
    - Worst-case: (x=1, t=9) where 7t = 63 = 0b111111 (maximum carry propagation)
    - Adder stress: (x=1, t=15)
    - Boundary cases: (x=0, t=15), threshold transitions
    - Random sampling for coverage
    """
    vectors = []

    # Worst case: x=1, t=9 gives 7t=63 (all 1s in low bits)
    vectors.append((1, 9))
    
    # Additional worst cases
    vectors.append((1, 15))
    vectors.append((0, 15))

    # t = 14, x from {0, 5, 10, 15, 16, 20}
    for x in [0, 5, 10, 15, 16, 20]:
        vectors.append((x, 14))

    # Corner cases
    vectors.append((0, 0))
    vectors.append((255, 0))
    vectors.append((255, 15))

    # Deterministic random sampling
    random.seed(1234)
    for _ in range(8):
        x = random.randint(0, 255)
        t = random.randint(0, 15)
        vectors.append((x, t))

    # Deduplicate while preserving order
    seen = set()
    unique = []
    for x, t in vectors:
        if (x, t) not in seen:
            seen.add((x, t))
            unique.append((x, t))

    info(f"Generated {len(unique)} unique test vectors.")
    return unique


###########################################################################
# Step 5: HSPICE deck generation for a single (x, t) vector
###########################################################################

LIB_LINE = (
    ".lib /soft/ece_soft_2/TSMCHOME/Executable_Package/Collaterals/Tech/SPICE/"
    "N16ADFP_SPICE_MODEL/n16adfp_spice_model_v1d0_usage.l TTMacro_MOS_MOSCAP"
)

def bit(value: int, idx: int) -> int:
    """Return bit idx of value (0 or 1)."""
    return (value >> idx) & 1


def generate_single_vector_deck(
    deck_path: Path,
    netlist_path: Path,
    top_name: str,
    clk_pin: str,
    out_pins: dict,
    t_pins: dict,
    x_pins: dict,
    period_str: str,
    n_cycles: int,
    x_val: int,
    t_val: int,
):
    """
    Generate one HSPICE deck (.sp) for a single input vector (x_val, t_val).
    """
    info(f"Generating deck: {deck_path.name}  for x={x_val}, t={t_val}")
    out_bits = sorted(out_pins.keys())
    t_bits = sorted(t_pins.keys())
    x_bits = sorted(x_pins.keys())

    # We'll use param TPER and N_CYC so we can write expressions for times
    lines = []
    lines.append(f"** Auto-generated testbench for {top_name}, x={x_val}, t={t_val}")
    lines.append(".TEMP 25")
    lines.append(".OPTION POST")
    lines.append(LIB_LINE)
    lines.append(f".INCLUDE \"{netlist_path}\"")
    lines.append("")
    lines.append(f".param TPER = {period_str}")
    lines.append(f".param N_CYC = {n_cycles}")
    lines.append("")
    lines.append("* Power supply")
    lines.append("VDD vdd! 0 0.8")
    lines.append("VSS vss! 0 0")
    lines.append("")
    lines.append("* Clock source: PULSE(0 0.8 20p 20p 20p TPER/2 TPER)")
    if clk_pin is not None:
        lines.append(f"VCLK {clk_pin} 0 PULSE(0 0.8 20p 20p 20p 'TPER/2' 'TPER')")
    else:
        warn("No clk pin; skipping clock source.")

    lines.append("")
    lines.append("* DC sources for theta t<*>")
    for i in t_bits:
        pin = t_pins[i]
        val = bit(t_val, i)
        v = "0.8" if val == 1 else "0"
        lines.append(f"VT{i} {pin} 0 {v}")

    lines.append("")
    lines.append("* DC sources for x x<*>")
    for i in x_bits:
        pin = x_pins[i]
        val = bit(x_val, i)
        v = "0.8" if val == 1 else "0"
        lines.append(f"VX{i} {pin} 0 {v}")

    lines.append("")
    lines.append("* Instantiate DUT")
    # Build instance line for top-level
    # .subckt name pins...
    # We'll pass pins in the same order as subckt's pin list to avoid mismatch.
    # Here, we assume the netlist's .subckt top line is exactly what we parsed earlier.
    # But we don't have the original full pin order here, only categories.
    # We'll re-parse and store original pin order in main().
    lines.append("* DUT instantiation will be inserted by caller (we'll fill below)")
    # We'll placeholder and replace later in caller (for clarity we modify before writing).

    # We'll fill with the actual instance line in the caller where we know full pin order.
    # For now just return lines; caller will inject XU0 line and .measure statements
    return lines


def append_dut_and_measures(
    lines,
    top_name: str,
    top_pins: list,
    out_pins: dict,
):
    """
    Append DUT instantiation and .MEASURE statements to the deck lines.
    """
    # Instance line: XU0 <all pins in order> top_name
    pins_str = " ".join(top_pins)
    lines.append("")
    lines.append("* DUT instance")
    lines.append(f"XU0 {pins_str} {top_name}")
    lines.append("")

    # .TRAN and measures
    lines.append("* Transient analysis")
    # step = TPER/50, stop = TPER*(N_CYC+1)
    lines.append(".TRAN 'TPER/50' 'TPER*(N_CYC+1)'")
    lines.append("")

    # SAMPLE TIME: T_SAMPLE = TPER*N_CYC + TPER/2
    lines.append("* Measures of output bits at final sample time")
    out_bits = sorted(out_pins.keys())
    for i in out_bits:
        pin = out_pins[i]
        mname = f"m_out{i}"
        lines.append(
            f".MEASURE TRAN {mname} FIND V({pin}) AT='TPER*N_CYC + TPER/2'"
        )

    lines.append("")
    lines.append(".END")
    return lines


###########################################################################
# Step 6: Run HSPICE and parse .mt0 results
###########################################################################

MEAS_RE = re.compile(r'^\s*(\S+)\s*=\s*([Ee0-9\+\-\.]+)')

def run_hspice(deck_path: Path):
    """
    Run HSPICE on the given deck and wait for completion.

    FIXES for:
    - Python 3.6 (no text=...)
    - HSPICE must run in deck directory
    - Deck filename passed, not full path
    - Proper log capture
    """
    deck_dir = deck_path.parent
    deck_name = deck_path.name
    log_path = deck_path.with_suffix(".log")

    info(f"Running HSPICE on {deck_name} in directory {deck_dir} ...")

    # Ensure we run inside the directory where tb.sp exists
    with log_path.open("w") as logf:
        proc = subprocess.run(
            ["hspice", deck_name],
            cwd=str(deck_dir),
            stdout=logf,
            stderr=subprocess.STDOUT,
            universal_newlines=True   # Python 3.6 safe replacement for text=True
        )

    if proc.returncode != 0:
        error(f"HSPICE run failed for {deck_name}. See log file: {log_path}")
    else:
        info(f"HSPICE run completed for {deck_name}")


def parse_mt0(deck_path: Path):
    """
    Parse HSPICE table-format .mt0 files.
    Returns dict: {measure_name: float_value}
    
    FIXED: Handles multi-line headers and values properly.
    """
    mt0_path = deck_path.with_suffix(".mt0")

    if not mt0_path.exists():
        error(f".mt0 file not found: {mt0_path}")
        return {}

    measures = {}

    with mt0_path.open() as f:
        lines = [ln.strip() for ln in f if ln.strip()]

    # Filter out metadata lines and split into header/data sections
    clean_lines = []
    for line in lines:
        if line.startswith("$"):
            continue
        if "SOURCE=" in line or "DATA1" in line:
            continue
        if line.lower().startswith(".title"):
            continue
        clean_lines.append(line)

    if len(clean_lines) < 2:
        warn("MT0 file does not contain sufficient data.")
        return {}

    # Find where headers end and data begins
    # Headers are strings (measure names), data are numbers
    header_lines = []
    data_lines = []
    in_data_section = False
    
    for line in clean_lines:
        # Check if line starts with a number or minus sign (data line)
        tokens = line.split()
        if not tokens:
            continue
            
        # If first token looks like a number, we're in data section
        try:
            float(tokens[0])
            in_data_section = True
            data_lines.append(line)
        except ValueError:
            # Not a number - still in headers (or alter# marker)
            if line.lower().startswith("alter"):
                # alter# marks end of headers
                in_data_section = True
                continue
            if not in_data_section:
                header_lines.append(line)

    if not header_lines or not data_lines:
        warn("Could not separate MT0 headers from data.")
        debug(f"Clean lines: {clean_lines}")
        return {}

    # Combine multi-line headers into one list
    all_headers = []
    for line in header_lines:
        all_headers.extend(line.split())

    # Combine multi-line data into one list
    all_values = []
    for line in data_lines:
        all_values.extend(line.split())

    debug(f"MT0 headers found: {len(all_headers)}: {all_headers}")
    debug(f"MT0 values found: {len(all_values)}: {all_values[:15] if len(all_values) > 15 else all_values}")

    # Match headers to values
    for i, name in enumerate(all_headers):
        if i >= len(all_values):
            warn(f"No value for header '{name}'")
            measures[name] = None
            continue
            
        try:
            measures[name] = float(all_values[i])
        except (ValueError, IndexError):
            warn(f"Could not parse value for '{name}': {all_values[i] if i < len(all_values) else 'N/A'}")
            measures[name] = None

    return measures


def decode_output_bits_from_measures(measures: dict, threshold: float = 0.4):
    """
    From measure dict (m_out0, m_out1, ...), decode integer code and bit vector.
    
    Threshold logic for HSPICE:
    - Values >= 0.4V → logic 1
    - Values < 0.4V → logic 0
    
    Note: HSPICE often produces small negative values (e.g., -2e-4) for 0V 
    due to numerical noise. These are treated as logic 0, not errors.
    """
    bits = {}
    
    for name, val in measures.items():
        if not name.startswith("m_out"):
            continue
        idx = int(name[len("m_out"):])
        
        if val is None:
            warn(f"Measurement {name} is None (simulation may have failed)")
            bits[idx] = 0  # Default to 0
        else:
            # Threshold: >= 0.4V is logic 1, otherwise logic 0
            bit_val = 1 if val >= threshold else 0
            bits[idx] = bit_val
            
            # Warn only for values in threshold region
            if 0.3 < val < 0.5:
                warn(f"  {name}: {val:.6f}V → bit={bit_val} (NEAR THRESHOLD!)")

    if not bits:
        warn("No m_out* measures found in mt0; returning empty result.")
        return 0, {}

    # Build integer from bits
    code = 0
    for i, b in bits.items():
        code |= (b << i)

    return code, bits


###########################################################################
# Step 7: Sweep deck for theta=15, x=0..32 (single simulation)
###########################################################################

def generate_sweep_deck(
    deck_path: Path,
    netlist_path: Path,
    top_name: str,
    top_pins: list,
    clk_pin: str,
    out_pins: dict,
    t_pins: dict,
    x_pins: dict,
    period_str: str,
    n_cycles: int,
    max_x: int = 32,
):
    """
    Generate a sweep testbench where:
    - theta = 15 constant
    - x goes from 0 to max_x over successive time windows.

    Uses PWL sources (more compatible than .STEP)
    Each x value gets its own time window.
    """

    info(f"Generating sweep deck: {deck_path.name} for theta=15, x=0..{max_x}")

    out_bits = sorted(out_pins.keys())
    t_bits = sorted(t_pins.keys())
    x_bits = sorted(x_pins.keys())
    
    # Convert period string to float in nanoseconds
    try:
        period_str_clean = period_str.strip()
        
        if period_str_clean.endswith('ps'):
            period_ns = float(period_str_clean[:-2]) / 1000.0
        elif period_str_clean.endswith('p'):
            period_ns = float(period_str_clean[:-1]) / 1000.0
        elif period_str_clean.endswith('ns'):
            period_ns = float(period_str_clean[:-2])
        elif period_str_clean.endswith('n'):
            period_ns = float(period_str_clean[:-1])
        elif period_str_clean.endswith('us'):
            period_ns = float(period_str_clean[:-2]) * 1000.0
        elif period_str_clean.endswith('u'):
            period_ns = float(period_str_clean[:-1]) * 1000.0
        else:
            period_ns = float(period_str_clean)
    except (ValueError, AttributeError) as e:
        warn(f"Could not parse period '{period_str}': {e}, defaulting to 1ns")
        period_ns = 1.0
    
    info(f"Parsed period: {period_str} → {period_ns}ns")

    lines = []
    lines.append("** Sweep testbench: theta=15, x=0..{} (time-based sweep)".format(max_x))
    lines.append(".TEMP 25")
    lines.append(".OPTION POST")
    lines.append(LIB_LINE)
    lines.append(f".INCLUDE \"{netlist_path}\"")
    lines.append("")
    lines.append(f".param TPER = {period_str}")
    lines.append(f".param N_CYC = {n_cycles}")
    lines.append("")
    lines.append("* Power supply")
    lines.append("VDD vdd! 0 0.8")
    lines.append("")

    if clk_pin is not None:
        lines.append("* Clock source")
        lines.append(f"VCLK {clk_pin} 0 PULSE(0 0.8 20p 20p 20p 'TPER/2' 'TPER')")
    lines.append("")

    # Theta = 15 (1111)
    lines.append("* Theta = 15 constant")
    for i in t_bits:
        pin = t_pins[i]
        val = (15 >> i) & 1
        v = "0.8" if val == 1 else "0"
        lines.append(f"VT{i} {pin} 0 {v}")

    lines.append("")
    lines.append("* X driven by PWL - sweeps from 0 to {} over time".format(max_x))
    lines.append("* Inputs change in middle of clock cycle with 20ps transitions")
    
    time_per_test = (n_cycles + 1) * period_ns
    input_offset = period_ns / 2.0
    transition_time = 0.020
    
    for bit_idx in x_bits:
        pin = x_pins[bit_idx]
        lines.append(f"VX{bit_idx} {pin} 0 PWL(")
        
        initial_bit = (0 >> bit_idx) & 1
        current_voltage = "0.8" if initial_bit else "0"
        lines.append(f"+ 0n {current_voltage}")
        
        prev_bit_value = initial_bit
        
        for x_val in range(max_x + 1):
            # Time when this input changes
            change_time = x_val * time_per_test + input_offset
            
            # Bit value for this x
            bit_value = (x_val >> bit_idx) & 1
            
            if bit_value != prev_bit_value:
                # Transition with 20ps rise/fall time
                old_voltage = "0.8" if prev_bit_value else "0"
                new_voltage = "0.8" if bit_value else "0"
                
                lines.append(f"+ {change_time:.6f}n {old_voltage}")
                lines.append(f"+ {(change_time + transition_time):.6f}n {new_voltage}")
                
                prev_bit_value = bit_value
        
        time_end = (max_x + 1) * time_per_test + input_offset
        final_voltage = "0.8" if prev_bit_value else "0"
        lines.append(f"+ {time_end:.6f}n {final_voltage})")
        lines.append("")

    lines.append("* DUT instance")
    pins_str = " ".join(top_pins)
    lines.append(f"XU0 {pins_str} {top_name}")
    lines.append("")
    
    # Total simulation time: cover all tests plus extra margin
    total_time = (max_x + 1) * time_per_test + 2 * period_ns
    lines.append("* Transient analysis")
    lines.append(f".TRAN {period_ns/50:.6f}n {total_time:.6f}n")
    lines.append("")
    
    # Add measurements for each x value
    lines.append(f"* Measurements after (N_CYC+1) clock cycles from input change")
    lines.append(f"* Input changes at TPER/2, measure at TPER/2 + (N_CYC+1)*TPER")
    for x_val in range(max_x + 1):
        # Measurement timing:
        # - Input changes at: x_val * time_per_test + TPER/2
        # - Circuit needs (N_CYC+1) complete clock cycles to process
        # - Measure at: change_time + (N_CYC+1)*TPER
        base_time = x_val * time_per_test
        change_time = base_time + input_offset
        processing_time = (n_cycles + 1) * period_ns
        meas_time = change_time + processing_time
        
        for bit_idx in out_bits:
            pin = out_pins[bit_idx]
            mname = f"m_out{bit_idx}_x{x_val}"
            lines.append(f".MEASURE TRAN {mname} FIND V({pin}) AT={meas_time:.6f}n")
    
    lines.append("")
    lines.append(".END")

    deck_path.write_text("\n".join(lines))
    info(f"Sweep deck written to {deck_path}")


def parse_mt0_sweep(deck_path: Path):
    """
    Parse HSPICE .mt0 file from a PWL time-based sweep simulation.
    Returns list of dicts: [{measure_name: float_value}, ...]
    Each dict corresponds to one sweep step (x value).
    
    Measurements are named: m_out<bit>_x<value>
    Example: m_out0_x5, m_out1_x5, ..., m_out10_x5
    """
    mt0_path = deck_path.with_suffix(".mt0")

    if not mt0_path.exists():
        error(f".mt0 file not found: {mt0_path}")
        return []

    with mt0_path.open() as f:
        lines = [ln.strip() for ln in f if ln.strip()]

    # Filter metadata
    clean_lines = []
    for line in lines:
        if line.startswith("$"):
            continue
        if "SOURCE=" in line or "DATA1" in line:
            continue
        if line.lower().startswith(".title"):
            continue
        clean_lines.append(line)

    # Separate headers from data
    header_lines = []
    data_lines = []
    in_data_section = False
    
    for line in clean_lines:
        tokens = line.split()
        if not tokens:
            continue
        
        try:
            float(tokens[0])
            in_data_section = True
            data_lines.append(line)
        except ValueError:
            if line.lower().startswith("alter"):
                in_data_section = True
                continue
            if not in_data_section:
                header_lines.append(line)

    if not header_lines or not data_lines:
        warn("Could not separate MT0 headers from data.")
        return []

    # Combine multi-line headers
    all_headers = []
    for line in header_lines:
        all_headers.extend(line.split())

    # Combine multi-line data
    all_values = []
    for line in data_lines:
        all_values.extend(line.split())

    debug(f"Sweep MT0 headers ({len(all_headers)}): {all_headers[:20]}...")  # Show first 20
    debug(f"Sweep MT0 values: {len(all_values)}")

    # Parse all measurements
    all_measures = {}
    for i, name in enumerate(all_headers):
        if i < len(all_values):
            try:
                all_measures[name] = float(all_values[i])
            except (ValueError, IndexError):
                warn(f"Could not parse {name}")
                all_measures[name] = None
        else:
            all_measures[name] = None

    # Group measurements by x value
    # Measurement format: m_out<bit>_x<value>
    x_values = set()
    for name in all_measures.keys():
        if name.startswith("m_out") and "_x" in name:
            # Extract x value from name like "m_out0_x5"
            try:
                x_part = name.split("_x")[1]
                x_val = int(x_part)
                x_values.add(x_val)
            except (IndexError, ValueError):
                pass

    x_values = sorted(x_values)
    debug(f"Found measurements for x values: {x_values}")

    # Create one dict per x value
    all_results = []
    for x_val in x_values:
        measures_for_x = {}
        for bit_idx in range(11):  # out<0> to out<10>
            meas_name = f"m_out{bit_idx}_x{x_val}"
            if meas_name in all_measures:
                # Store with simplified name for compatibility
                measures_for_x[f"m_out{bit_idx}"] = all_measures[meas_name]
            else:
                measures_for_x[f"m_out{bit_idx}"] = None
        
        all_results.append(measures_for_x)

    info(f"Parsed {len(all_results)} sweep steps from MT0")
    return all_results


def verify_sweep_results(deck_path: Path, out_pins: dict, max_x: int):
    """
    Run and verify sweep simulation results.
    Returns (total_tests, passed, failed)
    """
    info("=" * 70)
    info("SWEEP VERIFICATION: theta=15, x=0..{}".format(max_x))
    info("=" * 70)
    
    # Run HSPICE
    run_hspice(deck_path)
    
    # Parse all sweep results
    all_measures = parse_mt0_sweep(deck_path)
    
    if not all_measures:
        error("No sweep results found!")
        return 0, 0, 0
    
    if len(all_measures) != max_x + 1:
        warn(f"Expected {max_x + 1} sweep steps, got {len(all_measures)}")
    
    # Verify each step
    passed = 0
    failed = 0
    
    for x_val in range(min(max_x + 1, len(all_measures))):
        measures = all_measures[x_val]
        t_val = 15  # theta is constant at 15
        
        # Decode measured output
        code_meas, bits_meas = decode_output_bits_from_measures(measures, threshold=0.4)
        real_meas = code_meas / 8.0
        
        # Golden
        code_gold, real_gold = compute_golden_q83(x_val, t_val)
        
        # Compare
        match = (code_meas == code_gold)
        
        if match:
            passed += 1
            print(f"[PASS] x={x_val:3d}, t={t_val:2d}  Meas=0x{code_meas:03X} ({real_meas:6.3f})  Gold=0x{code_gold:03X}")
        else:
            failed += 1
            print(f"[FAIL] x={x_val:3d}, t={t_val:2d}")
            print(f"       Measured: code=0x{code_meas:03X} ({real_meas:6.3f})")
            print(f"       Golden  : code=0x{code_gold:03X} ({real_gold:6.3f})")
            
            # Show bit differences
            max_bit = max(out_pins.keys()) if out_pins else 10
            print("       Bit    Meas  Gold")
            for b in range(max_bit + 1):
                mb = (code_meas >> b) & 1
                gb = (code_gold >> b) & 1
                sym = "✓" if mb == gb else "✗"
                print(f"       {b:2d}      {mb}     {gb}   {sym}")
    
    total = passed + failed
    info("=" * 70)
    info(f"SWEEP RESULTS: {passed}/{total} PASSED, {failed}/{total} FAILED")
    info("=" * 70)
    
    return total, passed, failed




def main():
    print("=== HSPICE Testbench Generator for 'top' Circuit ===")

    # Ask user for inputs (Option B)
    netlist_str = input("Enter path to HSPICE netlist (e.g. project3_top.sp): ").strip()
    period_ps_str = input("Enter clock period in picoseconds (e.g., 1000, 200): ").strip()
    n_cycles_str = input("Enter number of cycles until output is valid (e.g. 5): ").strip()

    try:
        period_ps = int(period_ps_str)
        period_str = f"{period_ps}p"  # Convert to string format for internal use
    except ValueError:
        error("Clock period must be an integer in picoseconds.")
        sys.exit(1)
    
    try:
        n_cycles = int(n_cycles_str)
    except ValueError:
        error("Number of cycles must be an integer.")
        sys.exit(1)

    netlist_path = Path(netlist_str).resolve()
    if not netlist_path.exists():
        error(f"Netlist file not found: {netlist_path}")
        sys.exit(1)

    # Prepare output directory
    out_root = netlist_path.parent / "tb_runs"
    if not out_root.exists():
        out_root.mkdir()
    info(f"All testbench runs will be in: {out_root}")

    # Step 1: Find top subckt and pins
    top_name, top_pins = parse_top_subckt(netlist_path)

    # Step 2: Categorize pins
    clk_pin, out_pins, t_pins, x_pins = categorize_pins(top_pins)

    # Step 3: Generate test vectors
    vectors = generate_test_vectors()

    # Step 4: For each test vector, generate deck, run HSPICE, compare results
    summary_results = []

    for idx, (x_val, t_val) in enumerate(vectors):
        sim_dir = out_root / f"test_{idx:02d}_x{x_val}_t{t_val}"
        sim_dir.mkdir(exist_ok=True)

        deck_path = sim_dir / "tb.sp"

        # Generate deck skeleton
        tb_lines = generate_single_vector_deck(
            deck_path=deck_path,
            netlist_path=netlist_path,
            top_name=top_name,
            clk_pin=clk_pin,
            out_pins=out_pins,
            t_pins=t_pins,
            x_pins=x_pins,
            period_str=period_str,
            n_cycles=n_cycles,
            x_val=x_val,
            t_val=t_val,
        )

        # Append DUT & measures
        tb_lines = append_dut_and_measures(tb_lines, top_name, top_pins, out_pins)

        # Write final deck
        deck_path.write_text("\n".join(tb_lines))

        # Run HSPICE
        run_hspice(deck_path)

        # Parse measures
        measures = parse_mt0(deck_path)
        if not measures:
            warn(f"No measures parsed for test #{idx}, x={x_val}, t={t_val}")
            summary_results.append((x_val, t_val, None, None, None))
            continue

        code_meas, bits_meas = decode_output_bits_from_measures(measures, threshold=0.4)
        real_meas = code_meas / 8.0

        # Golden
        code_gold, real_gold = compute_golden_q83(x_val, t_val)

        # Compare
        match = (code_meas == code_gold)
        info(f"==== Test #{idx}: x={x_val}, t={t_val} ====")
        debug(f"Measured integer code : {code_meas} (0x{code_meas:X})")
        debug(f"Golden integer code   : {code_gold} (0x{code_gold:X})")
        debug(f"Measured Q8.3 real    : {real_meas}")
        debug(f"Golden Q8.3 real      : {real_gold}")

        if match:
            print(f"[PASS] x={x_val:3d}, t={t_val:2d}  Meas=0x{code_meas:03X} ({real_meas:.3f})")
        else:
            print(f"[FAIL] x={x_val:3d}, t={t_val:2d}")
            print(f"       Measured: code=0x{code_meas:03X} ({real_meas:.3f})")
            print(f"       Golden  : code=0x{code_gold:03X} ({real_gold:.3f})")

            # Show bitwise diff for extra debug
            max_bit = max(out_pins.keys()) if out_pins else 10
            print("       Bit    Meas  Gold")
            for b in range(max_bit + 1):
                mb = (code_meas >> b) & 1
                gb = (code_gold >> b) & 1
                sym = "✓" if mb == gb else "✗"
                print(f"       {b:2d}      {mb}     {gb}   {sym}")

        summary_results.append((x_val, t_val, code_meas, code_gold, match))

    # Step 5: Generate sweep deck for theta=15, x=0..32
    info("\n" + "=" * 70)
    info("Generating sweep testbench")
    info("=" * 70)
    
    sweep_dir = out_root / "sweep_theta15_x0_32"
    sweep_dir.mkdir(exist_ok=True)
    sweep_deck = sweep_dir / "tb_sweep.sp"
    generate_sweep_deck(
        deck_path=sweep_deck,
        netlist_path=netlist_path,
        top_name=top_name,
        top_pins=top_pins,
        clk_pin=clk_pin,
        out_pins=out_pins,
        t_pins=t_pins,
        x_pins=x_pins,
        period_str=period_str,
        n_cycles=n_cycles,
        max_x=32,
    )
    
    # Run and verify sweep simulation
    sweep_total, sweep_passed, sweep_failed = verify_sweep_results(
        sweep_deck, out_pins, max_x=32
    )

    print("\n" + "=" * 70)
    print("=== FINAL SUMMARY ===")
    print("=" * 70)
    print(f"\nClock Period Used: {period_str} ({period_ps} ps)")
    total = len([r for r in summary_results if r[4] is not None])
    passed = len([r for r in summary_results if r[4]])
    print(f"\nIndividual Tests: {passed}/{total} PASSED, {total - passed}/{total} FAILED")
    print(f"Sweep Test:       {sweep_passed}/{sweep_total} PASSED, {sweep_failed}/{sweep_total} FAILED")
    print(f"\nOverall:          {passed + sweep_passed}/{total + sweep_total} PASSED")
    print("=" * 70)
    print(f"\nSweep deck written to: {sweep_deck}")
    print("You can view sweep waveforms at: {}/tb_sweep.tr0 &".format(sweep_dir))
    print("=" * 70)

if __name__ == "__main__":
    main()