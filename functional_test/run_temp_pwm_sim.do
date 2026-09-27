# ============================================================
# ModelSim / Questa do-file for Closed-Loop Thermal PWM & Telemetry
# Run in CLI:  vsim -c -do functional_test/run_temp_pwm_sim.do
# Run in GUI:  vsim -do functional_test/run_temp_pwm_sim.do
# With custom hex: vsim -c -do "do functional_test/run_temp_pwm_sim.do path/to/file.hex"
#
# Protocol Clocks:
#   - CPU Core:   250 kHz (clk_d = 50 MHz / 200)
#   - SPI Clock:  250 kHz (spi_sclk configured via SPI_CLKDIV = 100)
#   - UART Baud:  115.2 kBaud (standard 115200 baud)
# ============================================================

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"
set FUNC_DIR "$ROOT_DIR/functional_test"

# ── Compile Source Files & Dedicated Testbench ─────────────────
# (Note: uart_*.v files are included only to satisfy module instantiation in risc_v.v)
vlog -timescale 1ns/1ps -work work -sv \
    "$ROOT_DIR/macro_models/rom_512x16A.v" \
    "$ROOT_DIR/macro_models/ram_128x16A.v" \
    "$ROOT_DIR/rtl/adder.v" \
    "$ROOT_DIR/rtl/alu.v" \
    "$ROOT_DIR/rtl/alu_control.v" \
    "$ROOT_DIR/rtl/clk_div.v" \
    "$ROOT_DIR/rtl/control_unit.v" \
    "$ROOT_DIR/rtl/cu.v" \
    "$ROOT_DIR/rtl/data_mem.v" \
    "$ROOT_DIR/rtl/imm_ext.v" \
    "$ROOT_DIR/rtl/instr_mem.v" \
    "$ROOT_DIR/rtl/mux.v" \
    "$ROOT_DIR/rtl/pc.v" \
    "$ROOT_DIR/rtl/reg_file.v" \
    "$ROOT_DIR/rtl/uart_tx.v" \
    "$ROOT_DIR/rtl/uart_rx.v" \
    "$ROOT_DIR/rtl/uart_regs.v" \
    "$ROOT_DIR/rtl/pwm_regs.v" \
    "$ROOT_DIR/rtl/spi_reg.v" \
    "$ROOT_DIR/rtl/virtual_temp_sensor.v" \
    "$ROOT_DIR/rtl/virtual_fan.v" \
    "$ROOT_DIR/rtl/risc_v.v" \
    "$FUNC_DIR/risc_v_temp_pwm_tb.v"

# ── Launch Simulation ──────────────────────────────────────────
set hex_target "$FUNC_DIR/pwm_temp_control.hex"
if {[info exists 1]} {
    set hex_target "$1"
}
vsim -t 1ns -voptargs=+acc work.risc_v_temp_pwm_tb +HEX=$hex_target

# ── Waveform Signals (SPI Sensor + PWM Focused) ────────────────

# 1. Clocks & Reset
add wave -noupdate -divider "Clocks & Reset"
add wave -noupdate -color "Cyan"       /risc_v_temp_pwm_tb/clk
add wave -noupdate -color "Magenta"    /risc_v_temp_pwm_tb/reset
add wave -noupdate -color "Cyan"       /risc_v_temp_pwm_tb/DUT/clk_d

# 2. Closed-Loop Thermal Dynamics
add wave -noupdate -divider "Thermal Dynamics (Closed-Loop)"
add wave -noupdate -radix unsigned -color "Red"    /risc_v_temp_pwm_tb/sim_temp
add wave -noupdate -radix unsigned -color "Orange" /risc_v_temp_pwm_tb/DUT/PWM_REGS/duty_reg
add wave -noupdate                                 /risc_v_temp_pwm_tb/seen_init_80
add wave -noupdate                                 /risc_v_temp_pwm_tb/seen_throttle_40
add wave -noupdate                                 /risc_v_temp_pwm_tb/seen_recover_80

# 3. PWM Fan Controller
add wave -noupdate -divider "PWM Fan Controller"
add wave -noupdate -color "Green"                  /risc_v_temp_pwm_tb/pwm_out
add wave -noupdate                                 /risc_v_temp_pwm_tb/DUT/PWM_REGS/ctrl_en
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/PWM_REGS/duty_reg
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/PWM_REGS/compare_val
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/PWM_REGS/pwm_cnt

# 4. Virtual DC Fan & Tachometer
add wave -noupdate -divider "Virtual Fan & Tachometer"
add wave -noupdate -color "Green"                  /risc_v_temp_pwm_tb/FAN_MODEL/pwm_in
add wave -noupdate -color "Yellow"                 /risc_v_temp_pwm_tb/FAN_MODEL/tach_out
add wave -noupdate -radix unsigned -color "Orange" /risc_v_temp_pwm_tb/FAN_MODEL/rpm_actual
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/FAN_MODEL/duty_pct
add wave -noupdate -radix unsigned -color "Cyan"   /risc_v_temp_pwm_tb/DUT/PWM_REGS/period_reg

# 4. SPI Bus & Virtual Temperature Sensor
add wave -noupdate -divider "SPI Temp Sensor Interface"
add wave -noupdate -color "Yellow"                 /risc_v_temp_pwm_tb/spi_sclk
add wave -noupdate -color "Yellow"                 /risc_v_temp_pwm_tb/spi_cs
add wave -noupdate -color "Yellow"                 /risc_v_temp_pwm_tb/spi_mosi
add wave -noupdate -color "Orange"                 /risc_v_temp_pwm_tb/spi_miso
add wave -noupdate -radix unsigned -color "Red"    /risc_v_temp_pwm_tb/TEMP_SENSOR/active_temp
add wave -noupdate -radix hexadecimal              /risc_v_temp_pwm_tb/DUT/SPI_REGS/rx_data
add wave -noupdate                                 /risc_v_temp_pwm_tb/DUT/SPI_REGS/busy

# 5. UART Telemetry Interface
add wave -noupdate -divider "UART Serial Telemetry"
add wave -noupdate -color "Cyan"                   /risc_v_temp_pwm_tb/tx
add wave -noupdate                                 /risc_v_temp_pwm_tb/DUT/UART_REGS/tx_start
add wave -noupdate                                 /risc_v_temp_pwm_tb/DUT/UART_REGS/tx_busy
add wave -noupdate -radix ascii                    /risc_v_temp_pwm_tb/DUT/UART_REGS/tx_byte
add wave -noupdate -radix ascii                    /risc_v_temp_pwm_tb/uart_rx_byte
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/telemetry_count

# 6. CPU Instruction Fetch & PC
add wave -noupdate -divider "CPU Execution"
add wave -noupdate -radix hexadecimal -color "Yellow" /risc_v_temp_pwm_tb/pc
add wave -noupdate -radix hexadecimal -color "Orange" /risc_v_temp_pwm_tb/inst
add wave -noupdate                                    /risc_v_temp_pwm_tb/memwrite
add wave -noupdate -radix hexadecimal                 /risc_v_temp_pwm_tb/alu_result
add wave -noupdate -radix hexadecimal                 /risc_v_temp_pwm_tb/wd
add wave -noupdate -radix hexadecimal                 /risc_v_temp_pwm_tb/rd

# 6. CPU Register File
add wave -noupdate -divider "CPU Registers"
add wave -noupdate -radix unsigned -color "Red"    /risc_v_temp_pwm_tb/DUT/REG_FILE/regs(5)
add wave -noupdate -radix unsigned -color "Green"  /risc_v_temp_pwm_tb/DUT/REG_FILE/regs(6)
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/REG_FILE/regs(7)
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/REG_FILE/regs(14)
add wave -noupdate -radix unsigned                 /risc_v_temp_pwm_tb/DUT/REG_FILE/regs(15)

# ── Formatting & Execution ─────────────────────────────────────
if {![batch_mode]} {
    configure wave -namecolwidth  240
    configure wave -valuecolwidth 100
    configure wave -justifyvalue  left
    configure wave -signalnamewidth 1
    configure wave -timelineunits ns
}

run -all

if {[batch_mode]} {
    quit -f
} else {
    wave zoom full
}
