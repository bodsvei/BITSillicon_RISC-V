# BITSilicon RV32I 5-Stage Pipelined RISC-V Processor

![Language](https://img.shields.io/badge/Language-Verilog-blue.svg)
![ISA](https://img.shields.io/badge/ISA-RV32I-yellow.svg)
![Platform](https://img.shields.io/badge/FPGA-Xilinx%20Artix--7-orange.svg)
![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)
![Tests](https://img.shields.io/badge/Tests-Passed-success.svg)
![Simulation](https://img.shields.io/badge/Simulator-Icarus%20Verilog-blueviolet.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Welcome to the **BITSilicon** repository! This is a fully synthesizable implementation of a 32-bit, 5-stage pipelined RISC-V processor written in Verilog. It supports the RV32I base integer instruction set and was developed as a collaborative hardware design project by a 12-member team.

Whether you're a student learning computer architecture, or a developer exploring RISC-V implementations on FPGA, this project provides a clean, well-documented, and easy-to-understand codebase.

---

## Table of Contents

- [Overview](#-overview)
- [Microarchitecture](#-microarchitecture)
- [ISA Coverage](#-isa-coverage)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Running Simulations](#-running-simulations)
- [Test Programs](#-test-programs)
- [Synthesis](#-synthesis)
- [Repository Structure](#-repository-structure)
- [Module Descriptions](#-module-descriptions)

---

## Overview

This project implements a classic 5-stage in-order scalar pipeline based on the RISC-V RV32I specification. The design targets FPGA implementation (specifically the Xilinx Artix-7) and is written in synthesizable Verilog RTL.

It strictly adheres to a **Harvard architecture**, utilizing separate instruction and data memory interfaces. The pipeline effortlessly handles all data hazards through a robust combination of full forwarding and stall insertion. It also resolves control hazards using a static not-taken branch predictor with a single-cycle flush.

---

## Microarchitecture

```text
         IF            ID            EX           MEM           WB
   +-----------+  +-----------+  +--------+  +---------+   +---------+
   |  PC + IMem|  |Decode+RegF|  |  ALU   |  |  DMem   |   |   MUX   |
   |           |->|           |->|  Branch|->|Load/Store|->|WriteBack|
   |           |  |  ImmGen   |  |  Unit  |  |         |   |         |
   +-----------+  +-----------+  +--------+  +---------+   +---------+
        |               |                          |
        +---------------+<--------PCSrc------------+
              ^                     ^
              |    Hazard Unit       |
              +---------------------+
              |    Forwarding Unit   |
              +---------------------+
```

**Pipeline Stages:**
- **IF (Instruction Fetch):** PC register, instruction memory, next-PC mux.
- **ID (Instruction Decode):** Decoder, immediate generator, register file read.
- **EX (Execute):** ALU, branch condition evaluation, target address computation.
- **MEM (Memory Access):** Data memory read/write, load extension.
- **WB (Write Back):** Result selection mux, register file write.

**Pipeline Registers:** IF/ID, ID/EX, EX/MEM, MEM/WB with flush and stall enable inputs.

---

## ISA Coverage

The processor supports the full **RV32I** base integer instruction set (47 instructions).

| Format | Instructions |
|--------|-------------|
| **R-type** | `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` |
| **I-type (arithmetic)** | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI` |
| **I-type (load)** | `LB`, `LH`, `LW`, `LBU`, `LHU` |
| **S-type** | `SB`, `SH`, `SW` |
| **B-type** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| **U-type** | `LUI`, `AUIPC` |
| **J-type** | `JAL`, `JALR` |
| **System** | `ECALL`, `EBREAK`, Custom `HALT` (mapped to `0xFFFFFFFF`) |

---

## Features

- **Full RV32I coverage:** 100% compliant with the base integer instruction set.
- **5-Stage Pipeline:** In-order execution with CPI approaching 1.0 under low-hazard workloads.
- **Advanced Forwarding:** Full forwarding paths (EX-EX and MEM-EX) to minimize stalls.
- **Hazard Handling:** Intelligent load-use hazard detection with 1-cycle stall insertion.
- **Branch Prediction:** Static not-taken predictor with a clean 1-cycle pipeline flush on taken branches.
- **Memory Architecture:** Byte-addressed Harvard architecture with LB/LH/LBU/LHU sign/zero extensions.
- **Simplified Registers:** Synchronous write, asynchronous read register file with `x0` permanently hardwired to zero.
- **Verified:** Fully self-checking testbenches with golden reference comparison included.

---

## Quick Start

### Prerequisites

To get up and running, you will need the following installed on your machine:
- **Verilog Simulator:** [Icarus Verilog](https://github.com/steveicarus/iverilog) (open-source) or ModelSim / Vivado Simulator.
- **Waveform Viewer:** [GTKWave](https://gtkwave.sourceforge.net/) for visualizing `.vcd` files.
- **Python:** Python 3.8+ (for running the assembler script).
- *(Optional)* GNU RISC-V toolchain (for compiling C to RISC-V assembly).

### Cloning the Repository

Grab a copy of the codebase and jump right in!
```bash
git clone https://github.com/bodsvei/BITSillicon_RISC-V.git
cd BITSillicon_RISC-V
```

---

## Running Simulations

We make testing easy! You can either run targeted unit tests on individual modules or execute full integration tests across the entire CPU.

### Full Integration Test (Recommended)
This runs the full processor testbench natively via our Makefile:
```bash
make sim
```
> **What this does:** Compiles all RTL sources and the testbench, assembles the default programs in `programs/asm/` to `.hex`, runs the simulation, and automatically compares the final register/memory state to verify the CPU is calculating correctly!

### Unit Tests
To run a unit testbench for a single module:
```bash
iverilog -o sim_out tb/unit/tb_alu.v rtl/ex_stage/alu.v
vvp sim_out
```

### Loading a Custom Program
You can use the included Python assembler to compile your own `.s` programs:
```bash
python3 scripts/assemble.py programs/asm/fibonacci.s -o programs/hex/fibonacci.hex
```
*Note: Make sure to update the `HEX_FILE` parameter in `tb/integration/tb_riscv_top.v` to point to your new file.*

### Viewing Waveforms
Generate a `.vcd` file and visualize the pipeline stages using GTKWave:
```bash
make wave PROG=fibonacci
```
*(Alternative manual command)*:
```bash
iverilog -Wall -Wno-timescale -DDUMP_VCD -o sim_out -P tb_riscv_top.DUT.IMEM.HEX_FILE=\"programs/hex/fibonacci.hex\" tb/integration/tb_riscv_top.v rtl/**/*.v
vvp sim_out
gtkwave dump.vcd
```

---

## Test Programs

Three robust assembly programs are included to exercise the full RV32I instruction set and test all pipeline hazard pathways:

1. **`fibonacci.s`** — Computes the first N Fibonacci numbers iteratively. Exercises I-type arithmetic, loop branches (BLT, BNE), and array load/store logic. Severely tests EX-EX and MEM-EX forwarding.
2. **`bubble_sort.s`** — Sorts an integer array in-place. Exercises indexed load/store (LW, SW with base+offset addressing), nested loops, and branch conditions. Actively tests load-use stall insertion in the inner loop.
3. **`factorial.s`** — Computes N! via loop-based repeated addition. Tests JAL for function calls and JALR for returns, verifying link register writes and return address forwarding.

---

## Synthesis

The design has been synthesized for the **Xilinx Artix-7 (xc7a35tcpg236-1)** using Vivado 2023.2. Hardware constraints are located in `constraints/artix7.xdc`.

**To synthesize in Vivado:**
1. Open Vivado and create a new RTL project.
2. Add all files under `rtl/` as design sources.
3. Add `constraints/artix7.xdc` as a constraints source.
4. Set `rtl/top/riscv_top.v` as the **top module**.
5. Run Synthesis, Implementation, and Generate Bitstream.

> **Target utilization is extremely efficient, utilizing under 5% of Artix-7 LUT resources for the base RV32I datapath.**

---

## Repository Structure

```text
riscv-processor/
├── rtl/                        # Synthesizable Verilog Hardware Files
│   ├── top/                    # Top-level integration (riscv_top.v)
│   ├── if_stage/               # PC, Instruction Memory (ROM), IF/ID reg
│   ├── id_stage/               # Decoder, Immediate Gen, Register File, ID/EX reg
│   ├── control/                # Main decoder and ALU control logic
│   ├── ex_stage/               # ALU, Branch Unit, EX/MEM reg
│   ├── mem_stage/              # Data Memory (RAM), Load Extender, MEM/WB reg
│   ├── wb_stage/               # Writeback Mux
│   └── hazard/                 # Hazard Detection & Forwarding Unit
├── tb/                         # Testbenches
│   ├── unit/                   # Individual module testbenches
│   └── integration/            # Full processor testbenches (fibonacci, sort, etc.)
├── programs/                   # Assembly programs for testing
│   ├── asm/                    # Source `.s` files
│   └── hex/                    # Compiled hexadecimal files
├── constraints/                # Xilinx Artix-7 constraints (.xdc)
├── scripts/                    # Utilities (Assembler, Sim runners)
└── docs/                       # Specifications and Architecture docs
```

---

## Module Descriptions

- **`riscv_top.v`**: The top-level wrapper that instantiates all pipeline stages, hazard detection, and forwarding units. It contains *only* `clk` and `rst` as external inputs, acting as a true standalone processor.
- **`if_stage/`**: Handles the PC register with synchronous reset, Instruction ROM, and Next-PC muxing.
- **`id_stage/`**: Contains the Instruction Decoder (extracting opcodes, registers, and functs), Immediate Generator, and the 32x32-bit General Purpose Register File.
- **`control/`**: Uses a two-level approach where `main_decoder.v` governs datapath signals and `alu_decoder.v` dictates ALU operations.
- **`ex_stage/`**: Executes arithmetic operations in the ALU and computes branch target addresses via the Branch Unit.
- **`mem_stage/`**: Handles byte-addressed synchronous data memory (loads and stores) along with sign/zero extensions.
- **`wb_stage/`**: Selects the final result to write back into the Register File.
- **`hazard/`**: The brain for pipeline control. It resolves RAW hazards through forwarding (EX-EX, MEM-EX) and injects stalls/flushes when necessary (e.g., load-use stalls, branch flushes).
