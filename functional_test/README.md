# Functional Test: Closed-Loop Thermal PWM & UART Telemetry

This directory contains the self-contained functional test suite for verifying closed-loop temperature-driven PWM fan regulation and real-time serial telemetry on the single-cycle RISC-V SoC.

---

## 1. Directory Contents

| File | Description |
| :--- | :--- |
| `run_temp_pwm_sim.do` | ModelSim / Questa DO script (compilation, waveforms, execution) |
| `risc_v_temp_pwm_tb.v` | Dedicated top-level testbench with virtual temperature sensor |
| `pwm_temp_control.s` | RISC-V RV32I assembly program implementing closed-loop control |
| `pwm_temp_control.hex` | Compiled 32-bit hex machine code for ROM loading |

---

## 2. Test Description & Closed-Loop Dynamics

The testbench verifies autonomous embedded closed-loop thermal control:
1. **SPI Sensor Telemetry**: The RISC-V core polls the external SPI temperature sensor (`virtual_temp_sensor.v`) via MMIO SPI registers (`0x100 - 0x110`).
2. **Initial State (Normal Load)**: Software commands PWM duty cycle to **80%** (target heating state).
3. **Over-temperature Throttle**: When temperature reaches >= 75 C, software throttles the PWM fan duty cycle down to **40%** to cool down.
4. **Thermal Recovery**: When temperature drops to <= 50 C, software restores the PWM fan duty cycle back to **80%**.
5. **UART ASCII Telemetry**: Live temperature readings are converted to ASCII decimal strings and transmitted out of UART TX (`0x80`).

---

## 3. How to Run

### Command-Line (Headless)
```powershell
vsim -c -do functional_test/run_temp_pwm_sim.do
```

### ModelSim / Questa GUI with Waveforms
```powershell
vsim -do functional_test/run_temp_pwm_sim.do
```

### Full Regression Suite
```powershell
.\sim\run_tests.ps1
```
