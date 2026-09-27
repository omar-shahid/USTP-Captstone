# ModelSim / Questa do-file for RISC-V UART simulation
# Run with: vsim -c -do sim/run_uart_sim.do

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"

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
    "$ROOT_DIR/rtl/risc_v.v" \
    "$TB_DIR/risc_v_uart_tb.v"

vsim -t 1ns -voptargs=+acc work.risc_v_uart_tb
run -all
quit -f
