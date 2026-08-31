# Project Guidelines: Single-Cycle RISC-V with UART MMIO

## 1. Environment & Command Execution

The agent runs in a **WSL (Linux)** environment, while EDA tools (**ModelSim / QuestaSim**, **Intel Quartus Prime**) are installed on the Windows host (`D:\ic_design\RISC_V`).

### Running Windows Commands from WSL

All Windows EDA binaries must be executed through `powershell.exe` from WSL:

```bash
# Example syntax
powershell.exe "command"

# Check tool availability / paths
powershell.exe "Get-Command vsim"
powershell.exe "Get-Command quartus_sh"
```

### Path Conventions

- **WSL path**: `/mnt/d/ic_design/RISC_V`
- **Windows / ModelSim DO-script path**: `D:/ic_design/RISC_V` or `D:\ic_design\RISC_V`

---

## 2. Project Architecture & Overview

This repository implements a 32-bit single-cycle RISC-V (RV32I subset) processor integrated with a memory-mapped I/O (MMIO) UART controller.

### Memory Map

| Address Range | Target Device    | Description                                    |
| :------------ | :--------------- | :--------------------------------------------- |
| `0x00 – 0x3F` | `data_mem`       | 64-byte internal data RAM                      |
| `0x80`        | `UART_TX_DATA`   | (Write) Byte to transmit over UART             |
| `0x84`        | `UART_TX_STATUS` | (Read) Bit 0 = 1 when TX is idle/ready         |
| `0x88`        | `UART_RX_DATA`   | (Read) Last received byte                      |
| `0x8C`        | `UART_RX_STATUS` | (Read) Bit 0 = 1 when RX byte is ready/waiting |

### Address Decode

- `addr[7] == 1'b0`: Routes to Data Memory (`0x00 – 0x7F`)
- `addr[7] == 1'b1`: Routes to UART MMIO registers (`0x80 – 0xFF`)

---

## 3. Directory & Module Map

### Core Processor Modules

- `risc_v.v`: Top-level integration (CPU Core + UART MMIO + Clock Divider)
- `instr_mem.v`: ROM instruction memory
- `data_mem.v`: RAM data memory
- `pc.v`: Program counter register
- `adder.v`: Address computation (PC+4, Branch/Jump targets)
- `reg_file.v`: 32x32-bit register file (x0 hardwired to 0)
- `imm_ext.v`: Immediate generator (I, S, B, U, J types)
- `alu.v`: Arithmetic Logic Unit
- `alu_control.v`: ALU decoder based on `funct3`, `funct7`, and `alu_op`
- `control_unit.v` / `cu.v`: Main control unit decoder
- `mux.v`: Multiplexers for datapath routing
- `clk_div.v`: Clock division for core execution

### UART Subsystem

- `uart_tx.v`: UART transmitter with configurable baud rate
- `uart_rx.v`: UART receiver with sampling logic and start/stop bit validation
- `uart_regs.v`: MMIO register interface connecting CPU bus to UART TX/RX

### Testbenches & Simulation Scripts

- `risc_v_isa_tb.v`: RV32I instruction verification suite
- `risc_v_uart_tb.v`: Basic CPU-to-UART transmission testbench
- `risc_v_uart_full_tb.v`: Full end-to-end CPU + UART loopback & integration test
- `uart_loopback_tb.v`: Standalone UART TX-to-RX loopback test
- `uart_edge_tb.v`: UART edge cases (framing errors, baud mismatch, back-to-back bytes)
- `run_all_tests.do`: ModelSim batch script to run all test suites
- `run_uart_sim.do`: ModelSim script for UART testbench
- `run_loopback.do`: ModelSim script for loopback test

---

## 4. Verification & Simulation Commands

Simulations are run using ModelSim / QuestaSim CLI via PowerShell.

### Run All Testbenches (Batch Mode)

```bash
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; vsim -c -do run_all_tests.do"
```

### Run Specific Simulation DO-files

```bash
# UART Simulation
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; vsim -c -do run_uart_sim.do"

# Loopback Simulation
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; vsim -c -do run_loopback.do"
```

### Manual Compile & Run Individual Testbench

```bash
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; vlog -timescale 1ns/1ps -work work -sv risc_v.v risc_v_isa_tb.v; vsim -c -do 'run -all; quit -f' work.risc_v_isa_tb"
```

---

## 5. Intel Quartus Prime Synthesis / Build Commands

When targeting FPGA boards (e.g. Cyclone IV / DE-series / MAX 10):

### Full Compilation via Quartus CLI

```bash
# Run analysis & synthesis
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; quartus_map <project_name>"

# Run fitter (place & route)
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; quartus_fit <project_name>"

# Run timing analysis
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; quartus_sta <project_name>"

# Run assembler (generate bitstream .sof/.pof)
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; quartus_asm <project_name>"

# Complete build flow in one command
powershell.exe "Set-Location 'D:\ic_design\RISC_V'; quartus_sh --flow compile <project_name>"
```

---

## 6. Coding & Hardware Design Guidelines

1. **SystemVerilog / Verilog-2001**: Use consistent timescale (`1ns/1ps`) across all source and testbench files.
2. **Synchronous Design**:
   - Use active-high synchronous/asynchronous reset consistently according to `reset` polarity in `risc_v.v`.
   - Keep non-blocking assignments (`<=`) in sequential `always @(posedge clk)` blocks and blocking assignments (`=`) in combinational `always @(*)` blocks.
3. **Register File Rules**: `x0` must always read as zero.
4. **Memory Mapping**: Avoid address collision when extending memory map or adding new peripherals. Check `sel_uart` decode bits in `risc_v.v`.
