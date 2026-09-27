# RISC-V Assembly Test Suite

This directory contains assembly test programs (.s) and pre-assembled 32-bit machine code (.hex) for the single-cycle RISC-V processor with memory-mapped UART.

## Memory Map

| Address Range | Device / Register | Description |
| :--- | :--- | :--- |
| `0x00 - 0x3F` | **Data RAM** | 64-byte internal data memory |
| `0x80` | **UART_TX_DATA** | (Write) Byte to transmit via serial TX |
| `0x84` | **UART_TX_STATUS** | (Read) Bit 0 = 1 when TX is idle/ready |
| `0x88` | **UART_RX_DATA** | (Read) Last received byte from serial RX |
| `0x8C` | **UART_RX_STATUS** | (Read) Bit 0 = 1 when RX byte is available |

## Assembly Test Programs

### 1. `cpu_arithmetic_logic.s` (`.hex`)
- **Focus**: ALU & Immediate arithmetic/logic validation.
- **Instructions Tested**: `ADD`, `SUB`, `AND`, `OR`, `SLT`, `SLL`, `SRL`, `SRA`, `ADDI`, `SW`.
- **Validation**: Verifies signed negative numbers, shift boundaries, sign extension, and writes results to data memory (`0x00` - `0x14`).

### 2. `cpu_branches_loops.s` (`.hex`)
- **Focus**: Conditional branching & loop counters.
- **Instructions Tested**: `BEQ`, `BNE`, `ADDI`, `ADD`, `SW`.
- **Validation**: Implements an iterative sum (1 + 2 + 3 + 4 + 5 = 15) using `BNE` for backward loop jumps and `BEQ` for forward branch validation. Stores `15` to `mem[0x00]`.

### 3. `cpu_memory_access.s` (`.hex`)
- **Focus**: Data Memory RAM operations.
- **Instructions Tested**: `SW`, `LW`, `ADD`, `ADDI`.
- **Validation**: Stores multiple 32-bit words at offsets `0x00`, `0x04`, `0x08`, `0x0C`, loads them back into new registers, accumulates the sum (100 + 200 + 300 + 400 = 1000), and writes the total to `mem[0x10]`.

### 4. `uart_tx_hello.s` (`.hex`)
- **Focus**: MMIO UART Serial Output.
- **Instructions Tested**: `ADDI`, `LW`, `BEQ`, `SW`.
- **Validation**: Polls `UART_TX_STATUS` (`0x84`) for ready status and sequentially transmits the string `"Hello, RISC-V!
"` through `UART_TX_DATA` (`0x80`).

### 5. `uart_echo_loopback.s` (`.hex`)
- **Focus**: MMIO UART RX Polling & TX Echo.
- **Instructions Tested**: `ADDI`, `LW`, `BEQ`, `SW`.
- **Validation**: Polls `UART_RX_STATUS` (`0x8C`). When a character arrives, reads it from `UART_RX_DATA` (`0x88`), polls `UART_TX_STATUS` (`0x84`), and writes it to `UART_TX_DATA` (`0x80`).

### 6. `full_soc_test.s` (`.hex`)
- **Focus**: Comprehensive End-to-End System Integration.
- **Validation**: Performs arithmetic computation (15 + 25 = 40), stores to RAM `mem[0x00]`, reads back to verify, and transmits `"OK\n"` via UART TX if passed (or `"F"` if failed).

### 7. `spi_temp_test.s` (`.hex`)
- **Focus**: SPI Master, Virtual Temperature Sensor & PWM MMIO Verification.
- **Validation**: Configures SPI Clock Divider (`0x110`), enables SPI master (`0x100`), triggers SPI transfer to query the virtual temperature sensor, reads back temperature telemetry (25 C / `0x19`) via `SPI_RXDATA` (`0x108`), verifies PWM MMIO write/readback, stores results to data RAM (`mem[0x00]` = 25, `mem[0x04]` = 1), and transmits `"SPI TEMP 25C OK\n"` over UART TX.

### 8. `fan_test.s` (`.hex`)
- **Focus**: Virtual Fan Model, PWM Duty Control & Tachometer Feedback.
- **Validation**: Configures `PWM_CTRL` (`0xC0`) = 5 (EN + TACH_EN), sets `PWM_DUTY` (`0xC4`) to 80% (4800 RPM), polls `PWM_TACH_PERIOD` (`0xCC`) until period reaches 1250 cycles, stores to `mem[0x00]`, throttles duty to 40% (2400 RPM), polls until period adjusts to 2500 cycles, stores to `mem[0x04]`, sets pass flag `mem[0x08] = 1`, and transmits `"FAN TACH OK\n"` over UART TX.

### 9. `temp_sensor_test.s` (`.hex`)
- **Focus**: Dynamic Temperature Sensing & Multi-Transfer SPI Master Verification.
- **Validation**: Configures `SPI_CLKDIV` (`0x110`) = 4, enables SPI master, reads initial sensor temperature (25 C / `0x19`), stores to `mem[0x00]`, pauses for testbench driver dynamic temperature stimulus (75 C / `0x4B`), performs second SPI transfer, reads and validates updated temperature, stores to `mem[0x04]`, sets pass flag `mem[0x08] = 1`, and transmits `"TEMP 25C 75C OK\n"` over UART TX.

## Loading Programs in Simulation

Use the dedicated hex-loader testbench `tb/risc_v_hex_tb.v`:
```bash
# Load specific hex file in simulation
vsim -c -do "run -all; quit -f" work.risc_v_hex_tb +HEX=assembly_codes/full_soc_test.hex
```
