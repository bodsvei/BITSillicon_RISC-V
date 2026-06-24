# BITSillicon_RISC-V
# RV32I 5-Stage Pipelined RISC-V Processor

A fully synthesizable implementation of a 32-bit, 5-stage pipelined RISC-V processor in Verilog, supporting the RV32I base integer instruction set. Developed as a collaborative hardware design project by a 14-member team.

---

## Table of Contents

- [Overview](#overview)
- [Microarchitecture](#microarchitecture)
- [ISA Coverage](#isa-coverage)
- [Features](#features)
- [Repository Structure](#repository-structure)
- [Module Descriptions](#module-descriptions)
- [Getting Started](#getting-started)
- [Running Simulations](#running-simulations)
- [Test Programs](#test-programs)
- [Synthesis](#synthesis)
- [Contributors](#contributors)
- [References](#references)

---

## Overview

This project implements a classic 5-stage in-order scalar pipeline based on the RISC-V RV32I specification. The design targets FPGA implementation (Xilinx Artix-7) and is written in synthesizable Verilog RTL. The pipeline handles all data hazards through a combination of full forwarding and stall insertion, and resolves control hazards using a static not-taken branch predictor with single-cycle flush.

The implementation is based on the Harvard architecture, with separate instruction and data memory interfaces.

---

## Microarchitecture

```
         IF            ID            EX           MEM           WB
   +-----------+  +-----------+  +--------+  +---------+  +--------+
   |  PC + IMem|  |Decode+RegF|  |  ALU   |  |  DMem   |  |  MUX   |
   |           |->|           |->|  Branch|->|Load/Store|->|WriteBack|
   |           |  |  ImmGen   |  |  Unit  |  |         |  |        |
   +-----------+  +-----------+  +--------+  +---------+  +--------+
        |               |                          |
        +---------------+<--------PCSrc------------+
              ^                     ^
              |    Hazard Unit       |
              +---------------------+
              |    Forwarding Unit   |
              +---------------------+
```

**Pipeline Stages:**

- **IF** — Instruction Fetch: PC register, instruction memory, next-PC mux
- **ID** — Instruction Decode: decoder, immediate generator, register file read
- **EX** — Execute: ALU, branch condition evaluation, target address computation
- **MEM** — Memory Access: data memory read/write, load extension
- **WB** — Write Back: result selection mux, register file write

**Pipeline Registers:** IF/ID, ID/EX, EX/MEM, MEM/WB with flush and stall enable inputs.

---

## ISA Coverage

The processor supports the full **RV32I** base integer instruction set (47 instructions):

| Format | Instructions |
|--------|-------------|
| R-type | ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND |
| I-type (arithmetic) | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| I-type (load) | LB, LH, LW, LBU, LHU |
| S-type | SB, SH, SW |
| B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| U-type | LUI, AUIPC |
| J-type | JAL, JALR |
| System | ECALL, EBREAK |

---

## Features

- Full RV32I instruction set coverage
- 5-stage in-order pipeline with CPI approaching 1.0 under low-hazard workloads
- Full forwarding paths: EX-EX and MEM-EX
- Load-use hazard detection with 1-cycle stall insertion
- Control hazard handling: static not-taken predictor with 1-cycle pipeline flush
- Harvard memory architecture: separate instruction ROM and data RAM
- Byte-addressed data memory with LB/LH/LBU/LHU sign/zero extension
- Synchronous write, asynchronous read register file; x0 hardwired to zero
- Parameterized data path widths
- Self-checking testbenches with golden reference comparison

---

## Repository Structure

```
riscv-processor/
├── rtl/
│   ├── top/
│   │   └── riscv_top.v             # Top-level integration
│   ├── if_stage/
│   │   ├── pc_reg.v                # Program counter register
│   │   ├── instr_mem.v             # Instruction memory (ROM)
│   │   └── if_id_reg.v             # IF/ID pipeline register
│   ├── id_stage/
│   │   ├── instr_decoder.v         # Instruction field extraction
│   │   ├── imm_gen.v               # Immediate generator (all 6 formats)
│   │   ├── reg_file.v              # 32x32 register file
│   │   └── id_ex_reg.v             # ID/EX pipeline register
│   ├── control/
│   │   ├── main_decoder.v          # Opcode to control signal decoder
│   │   └── alu_decoder.v           # ALUControl generation
│   ├── ex_stage/
│   │   ├── alu.v                   # 32-bit ALU with flag outputs
│   │   ├── branch_unit.v           # Branch condition + target computation
│   │   └── ex_mem_reg.v            # EX/MEM pipeline register
│   ├── mem_stage/
│   │   ├── data_mem.v              # Data memory (byte-addressed)
│   │   ├── load_extend.v           # Load sign/zero extension
│   │   └── mem_wb_reg.v            # MEM/WB pipeline register
│   ├── wb_stage/
│   │   └── writeback.v             # Result mux and register write
│   └── hazard/
│       ├── hazard_detect.v         # Load-use and control hazard detection
│       └── forward_unit.v          # EX-EX and MEM-EX forwarding
├── tb/
│   ├── unit/
│   │   ├── tb_alu.v
│   │   ├── tb_reg_file.v
│   │   ├── tb_imm_gen.v
│   │   ├── tb_instr_decoder.v
│   │   ├── tb_hazard_detect.v
│   │   ├── tb_forward_unit.v
│   │   └── tb_data_mem.v
│   └── integration/
│       ├── tb_riscv_top.v          # Full processor integration testbench
│       └── expected/               # Golden register/memory state files
├── programs/
│   ├── asm/
│   │   ├── fibonacci.s
│   │   ├── bubble_sort.s
│   │   └── factorial.s
│   └── hex/
│       ├── fibonacci.hex
│       ├── bubble_sort.hex
│       └── factorial.hex
├── constraints/
│   └── artix7.xdc                  # Xilinx Artix-7 pin constraints
├── scripts/
│   ├── run_sim.sh                  # Batch simulation runner
│   └── assemble.py                 # Minimal RV32I assembler
├── docs/
│   ├── microarchitecture.md        # Detailed architecture documentation
│   ├── interface_spec.md           # Inter-module port definitions
│   └── hazard_analysis.md          # Hazard coverage and forwarding paths
└── README.md
```

---

## Module Descriptions

### rtl/top/riscv_top.v
Top-level wrapper instantiating all pipeline stages, hazard detection, and forwarding unit. All inter-module connections are resolved here. Port widths follow the definitions in `docs/interface_spec.md`.

### rtl/if_stage/
Implements the PC register with synchronous reset, the instruction memory initialized from a `.hex` file, the next-PC mux (PC+4 vs branch/jump target), and the IF/ID pipeline register with flush and stall inputs.

### rtl/id_stage/instr_decoder.v
Extracts opcode `[6:0]`, funct3 `[14:12]`, funct7b5 `[30]`, rs1 `[19:15]`, rs2 `[24:20]`, and rd `[11:7]` from the 32-bit instruction word. Feeds raw fields to the control unit and immediate generator.

### rtl/id_stage/imm_gen.v
Generates a 32-bit sign-extended immediate from any of the six RV32I immediate encodings (I, S, B, U, J). Format is selected based on the opcode.

### rtl/id_stage/reg_file.v
Implements the 32 x 32-bit general-purpose register file. Two asynchronous read ports, one synchronous write port. x0 is permanently tied to zero and ignores writes. Write-before-read behaviour on address collision is defined explicitly to avoid simulation ambiguity.

### rtl/control/
Two-level control logic. `main_decoder.v` decodes the opcode into datapath control signals (RegWrite, MemRead, MemWrite, Branch, Jump, ALUSrc, ResultSrc, ImmSrc). `alu_decoder.v` combines opcode, funct3, and funct7b5 to produce `ALUControl[3:0]`.

### rtl/ex_stage/alu.v
Computes all RV32I arithmetic and logic operations. Outputs a 32-bit result plus four condition flags: Zero, Negative, Carry, and Overflow. Flag definitions follow two's complement signed semantics for Carry and Overflow.

### rtl/ex_stage/branch_unit.v
Evaluates all six branch conditions using ALU flags. Computes branch target (PC + B-immediate), JAL target (PC + J-immediate), and JALR target (rs1 + I-immediate, LSB cleared). Drives the PCSrc signal to the IF stage mux.

### rtl/mem_stage/data_mem.v
Byte-addressed synchronous data memory. Supports byte, halfword, and word accesses for both loads and stores. `load_extend.v` applies sign extension for LB and LH, and zero extension for LBU and LHU.

### rtl/wb_stage/writeback.v
Three-input result mux selecting between ALUResult, MemReadData, and PC+4 (used by JAL/JALR for link register write). Drives the write-back path into the register file.

### rtl/hazard/hazard_detect.v
Detects load-use RAW hazards by comparing the EX-stage destination register against the ID-stage source registers when MemRead is asserted. Generates StallF, StallD, and FlushE. Detects branch-taken events and generates FlushD and FlushE for the 1-cycle control hazard penalty.

### rtl/hazard/forward_unit.v
Resolves RAW data hazards without stalling using two forwarding paths. EX-EX forwarding: from the EX/MEM register to the ALU inputs. MEM-EX forwarding: from the MEM/WB register to the ALU inputs. Generates `ForwardA[1:0]` and `ForwardB[1:0]` multiplexer select signals. Load-use hazards that cannot be forwarded are handled by the hazard detection unit.

---

## Getting Started

### Prerequisites

- Verilog simulator: [Icarus Verilog](https://github.com/steveicarus/iverilog) (open-source) or ModelSim / Vivado Simulator
- Waveform viewer: [GTKWave](https://gtkwave.sourceforge.net/)
- Python 3.8+ (for the assembler script)
- GNU RISC-V toolchain (optional, for compiling C to RISC-V assembly)

Installing Icarus Verilog on Ubuntu/Debian:

```bash
sudo apt-get install iverilog gtkwave
```

### Cloning the Repository

```bash
git clone https://github.com/<org>/riscv-processor.git
cd riscv-processor
```

---

## Running Simulations

### Unit Tests

Run a unit testbench for a single module:

```bash
iverilog -o sim_out tb/unit/tb_alu.v rtl/ex_stage/alu.v
vvp sim_out
```

### Integration Test

Run the full processor testbench:

```bash
bash scripts/run_sim.sh
```

This compiles all RTL sources and the integration testbench, loads a program from `programs/hex/`, runs simulation, and compares the final register file state against the expected output in `tb/integration/expected/`.

### Loading a Custom Program

Assemble a `.s` file to a `.hex` file using the included script:

```bash
python3 scripts/assemble.py programs/asm/fibonacci.s -o programs/hex/fibonacci.hex
```

Then set the `HEX_FILE` parameter in `tb/integration/tb_riscv_top.v` to point to the generated file and re-run simulation.

### Viewing Waveforms

To dump a VCD file and open it in GTKWave:

```bash
iverilog -o sim_out -DDUMP_VCD tb/integration/tb_riscv_top.v rtl/**/*.v
vvp sim_out
gtkwave dump.vcd
```

---

## Test Programs

Three programs are included to exercise the full RV32I instruction set and hazard paths:

**fibonacci.s** — Computes the first N Fibonacci numbers iteratively. Exercises I-type arithmetic, loop branches (BLT, BNE), and load/store for array writes. Tests EX-EX and MEM-EX forwarding under sustained back-to-back dependency chains.

**bubble_sort.s** — Sorts an integer array in-place. Exercises indexed load/store (LW, SW with base+offset addressing), nested loops, and BGE/BLT branch conditions. Tests load-use stall insertion in the inner loop.

**factorial.s** — Computes N! using a loop. Exercises MUL if the M extension is present, otherwise uses repeated addition. Tests JAL for function call and JALR for return, verifying link register write and return address forwarding.

---

## Synthesis

The design has been synthesized for the **Xilinx Artix-7 (xc7a35tcpg236-1)** using Vivado 2023.2. Pin assignments are in `constraints/artix7.xdc`.

To synthesize in Vivado:

1. Open Vivado and create a new RTL project
2. Add all files under `rtl/` as design sources
3. Add `constraints/artix7.xdc` as a constraints source
4. Set `rtl/top/riscv_top.v` as the top module
5. Run Synthesis, Implementation, and Generate Bitstream

Target utilization is under 5% of Artix-7 LUT resources for the base RV32I datapath.

---

## Contributors

| Sub-project | Description |
|---|---|
| Architecture Spec + Top Integration | Top-level design and inter-module interface |
| IF Stage | PC register, instruction memory, IF/ID register |
| Instruction Decoder | Field extraction from 32-bit instruction word |
| Immediate Generator | All six RV32I immediate encodings |
| Register File | 32x32 register file with two read ports |
| Control Unit | Main decoder and ALU control logic |
| ALU | All RV32I arithmetic and logic operations |
| Branch and Jump Unit | Condition evaluation and target computation |
| ID/EX Pipeline Register | EX stage mux and pipeline stage boundary |
| EX/MEM Register + MEM Stage | Data memory and load/store extension |
| MEM/WB Register + Write-Back | Result mux and register file write path |
| Hazard Detection Unit | Stall and flush signal generation |
| Forwarding Unit | EX-EX and MEM-EX forwarding paths |
| Verification and Testbench | Unit and integration testbenches, test programs |

---
