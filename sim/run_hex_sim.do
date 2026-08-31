# ModelSim / Questa do-file for RISC-V Hex Simulation
# Run with: vsim -c -do sim/run_hex_sim.do

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"

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

vsim -t 1ns -voptargs=+acc work.risc_v_hex_tb +HEX=assembly_codes/uart_tx_hello.hex
run -all
quit -f
