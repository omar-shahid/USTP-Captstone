# ModelSim do-file for uart_loopback_tb
if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

set SRC_DIR "D:/ic_design/RISC_V"

# Compile all modules
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

# Compile testbench
vlog -timescale 1ns/1ps -work work -sv "$SRC_DIR/uart_loopback_tb.v"

# Run simulation
vsim -t 1ps -voptargs=+acc work.uart_loopback_tb

run -all
