# ModelSim / Questa FSE do-file for RISC-V + UART simulation
# Run with: vsim -c -do run_uart_sim.do

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

set SRC_DIR "D:/ic_design/RISC_V"

vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/adder.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/alu.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/alu_control.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/clk_div.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/control_unit.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/cu.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/data_mem.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/imm_ext.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/instr_mem.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/mux.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/pc.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/reg_file.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/uart_tx.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/uart_rx.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/uart_regs.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/risc_v.v"
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/risc_v_uart_tb.v"

vsim -t 1ns -voptargs=+acc work.risc_v_uart_tb

set StdArithNoWarnings 1
set NumericStdNoWarnings 1

run -all

quit -f
