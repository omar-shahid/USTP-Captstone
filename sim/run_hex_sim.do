# ============================================================
# ModelSim / Questa do-file for RISC-V Hex Simulation
# Run in CLI:  vsim -c -do sim/run_hex_sim.do
# Run in GUI:  vsim -do sim/run_hex_sim.do
# ============================================================

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"

# ── Compile Source Files & Testbench ───────────────────────────
vlog -timescale 1ns/1ps -work work -sv \
    "$ROOT_DIR/adder.v" \
    "$ROOT_DIR/alu.v" \
    "$ROOT_DIR/alu_control.v" \
    "$ROOT_DIR/clk_div.v" \
    "$ROOT_DIR/control_unit.v" \
    "$ROOT_DIR/cu.v" \
    "$ROOT_DIR/data_mem.v" \
    "$ROOT_DIR/imm_ext.v" \
    "$ROOT_DIR/instr_mem.v" \
    "$ROOT_DIR/mux.v" \
    "$ROOT_DIR/pc.v" \
    "$ROOT_DIR/reg_file.v" \
    "$ROOT_DIR/uart_tx.v" \
    "$ROOT_DIR/uart_rx.v" \
    "$ROOT_DIR/uart_regs.v" \
    "$ROOT_DIR/risc_v.v" \
    "$TB_DIR/risc_v_hex_tb.v"

# ── Launch Simulation ──────────────────────────────────────────
# Default to program.hex unless an argument is passed (e.g. do sim/run_hex_sim.do path/to/file.hex)
set hex_target "program.hex"
if {[info exists 1]} {
    set hex_target "$1"
}
vsim -t 1ns -voptargs=+acc work.risc_v_hex_tb +HEX=$hex_target

# ── Waveform Signals & Configuration ───────────────────────────

# 1. Clocks & Reset
add wave -noupdate -divider "Clocks & Reset"
add wave -noupdate -color "Cyan"       /risc_v_hex_tb/clk
add wave -noupdate -color "Magenta"    /risc_v_hex_tb/reset
add wave -noupdate -color "Cyan"       /risc_v_hex_tb/DUT/clk_d

# 2. Instruction Fetch & PC
add wave -noupdate -divider "Instruction Fetch & PC"
add wave -noupdate -radix hexadecimal -color "Yellow" /risc_v_hex_tb/pc
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/pc_next
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/pc_4
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/pc_target
add wave -noupdate -radix hexadecimal -color "Orange" /risc_v_hex_tb/inst

# 3. Control Unit
add wave -noupdate -divider "Control Unit"
add wave -noupdate                                    /risc_v_hex_tb/regwrite
add wave -noupdate                                    /risc_v_hex_tb/memwrite
add wave -noupdate                                    /risc_v_hex_tb/alu_src
add wave -noupdate                                    /risc_v_hex_tb/result_src
add wave -noupdate                                    /risc_v_hex_tb/pc_src
add wave -noupdate -radix binary                      /risc_v_hex_tb/imm_src
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/alu_control

# 4. Datapath & Register File
add wave -noupdate -divider "Datapath & Registers"
add wave -noupdate -radix unsigned                    /risc_v_hex_tb/DUT/RF/rs1
add wave -noupdate -radix unsigned                    /risc_v_hex_tb/DUT/RF/rs2
add wave -noupdate -radix unsigned                    /risc_v_hex_tb/DUT/RF/rd
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/rd1
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/rd2
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/imm_ext
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/src_b
add wave -noupdate -radix hexadecimal -color "Green"  /risc_v_hex_tb/alu_result
add wave -noupdate                                    /risc_v_hex_tb/DUT/zero
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/result
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/RF/regs

# 5. Memory & MMIO Bus
add wave -noupdate -divider "Memory & MMIO Bus"
add wave -noupdate                                    /risc_v_hex_tb/DUT/sel_uart
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/alu_result
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/wd
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/rd
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/dmem_rd
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/uart_rd

# 6. UART Subsystem
add wave -noupdate -divider "UART Subsystem"
add wave -noupdate -color "Orange"                    /risc_v_hex_tb/tx
add wave -noupdate -color "Yellow"                    /risc_v_hex_tb/rx
add wave -noupdate                                    /risc_v_hex_tb/DUT/UART/tx_start
add wave -noupdate -radix hexadecimal                 /risc_v_hex_tb/DUT/UART/tx_byte
add wave -noupdate -radix ascii                       /risc_v_hex_tb/DUT/UART/tx_byte
add wave -noupdate                                    /risc_v_hex_tb/DUT/UART/tx_busy
add wave -noupdate                                    /risc_v_hex_tb/uart_rx_ready
add wave -noupdate -radix ascii                       /risc_v_hex_tb/uart_rx_data
add wave -noupdate -radix ascii                       /risc_v_hex_tb/captured_byte

# ── Formatting & Execution ─────────────────────────────────────
if {![batch_mode]} {
    configure wave -namecolwidth  220
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
