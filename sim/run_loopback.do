# ModelSim / Questa do-file for UART Loopback simulation
# Run with: vsim -c -do sim/run_loopback.do

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"

vlog -timescale 1ns/1ps -work work -sv \
    "$ROOT_DIR/uart_tx.v" \
    "$ROOT_DIR/uart_rx.v" \
    "$ROOT_DIR/uart_regs.v" \
    "$TB_DIR/uart_loopback_tb.v"

vsim -t 1ns -voptargs=+acc work.uart_loopback_tb
run -all
quit -f
