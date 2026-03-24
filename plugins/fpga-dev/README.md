# fpga-dev — FPGA Development Plugin

Expert FPGA development assistant for Vivado, Verilog, VHDL, and hardware design.

## What's Included

### Skills
- **fpga** — Master FPGA skill covering RTL design, timing closure, CDC, AXI, FSMs, pipelines, memory interfaces, FPU design, and verification

### Reference Files
- **patterns.md** — CDC synchronizers, async FIFOs, FSM patterns, pipeline design, BRAM inference, timing constraints
- **sharp_edges.md** — Critical failure modes: metastability, latch inference, timing closure, reset glitches, sim/synth mismatch, resource exhaustion
- **validations.md** — Regex-based lint rules for Verilog/VHDL/XDC files

## Features

- **Simulation-first verification** — mandatory sim before synthesis workflow
- **Context7 MCP integration** — fetches up-to-date docs for Vivado, AXI, RISC-V, IEEE 754
- **Version-aware** — adapts to your Vivado version (2017.x through 2023.x+)
- **Dual-language** — supports both Verilog and VHDL (IEEE 1076-2008)
- **xsim batch simulation** — run testbenches without GUI

## Install

```bash
# From george-plugins marketplace
/plugin install fpga-dev@george-plugins
```

## Supported Topics

- RTL design (Verilog / VHDL / SystemVerilog)
- Xilinx Vivado synthesis and implementation
- Timing closure and XDC constraints
- Clock domain crossing (CDC)
- AXI4 bus interfaces
- Finite state machines (FSM)
- Pipeline design with data forwarding
- Block RAM and distributed RAM inference
- DSP48E1 utilization
- IEEE 754 floating-point unit design
- RISC-V processor implementation
- Simulation and verification (xsim, cocotb)
