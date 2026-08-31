# ModelSim / Questa do-file for RISC-V + UART - ALL TESTS
# Run with: vsim -c -do run_all_tests.do

echo "=========================================="
echo "RISC-V Processor & UART Verification Suite"
echo "=========================================="

if {![file exists work]} {
    vlib work
    vmap work work
}

set SRC_DIR "D:/ic_design/RISC_V"

# Compile all modules and testbenches in a single pass
echo ""
echo "--- Compiling RTL Modules & Testbenches ---"
vlog -timescale 1ns/1ps -work work -sv \
    "$SRC_DIR/adder.v" \
    "$SRC_DIR/alu.v" \
    "$SRC_DIR/alu_control.v" \
    "$SRC_DIR/clk_div.v" \
    "$SRC_DIR/control_unit.v" \
    "$SRC_DIR/cu.v" \
    "$SRC_DIR/data_mem.v" \
    "$SRC_DIR/imm_ext.v" \
    "$SRC_DIR/instr_mem.v" \
    "$SRC_DIR/mux.v" \
    "$SRC_DIR/pc.v" \
    "$SRC_DIR/reg_file.v" \
    "$SRC_DIR/uart_tx.v" \
    "$SRC_DIR/uart_rx.v" \
    "$SRC_DIR/uart_regs.v" \
    "$SRC_DIR/risc_v.v" \
    "$SRC_DIR/risc_v_isa_tb.v" \
    "$SRC_DIR/uart_edge_tb.v" \
    "$SRC_DIR/risc_v_uart_tb.v" \
    "$SRC_DIR/uart_loopback_tb.v" \
    "$SRC_DIR/risc_v_uart_full_tb.v"

# Test 1: RISC-V ISA Instruction & Unit Tests
echo ""
echo "=========================================="
echo "TEST 1: RISC-V ISA & Unit Tests"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.risc_v_isa_tb
run -all

# Test 2: UART Edge Case & MMIO Tests
echo ""
echo "=========================================="
echo "TEST 2: UART Edge Case & MMIO Tests"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.uart_edge_tb
run -all

# Test 3: RISC-V UART Serial Transmission
echo ""
echo "=========================================="
echo "TEST 3: RISC-V UART Serial Transmission"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.risc_v_uart_tb
run -all

# Test 4: Direct Loopback Test
echo ""
echo "=========================================="
echo "TEST 4: Direct Loopback Test"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.uart_loopback_tb
run -all

# Test 5: Full Integration & Reset Recovery Test
echo ""
echo "=========================================="
echo "TEST 5: Full Integration & Reset Recovery"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.risc_v_uart_full_tb
run -all

echo ""
echo "=========================================="
echo "ALL TEST SUITES EXECUTED SUCCESSFULLY"
echo "=========================================="

quit -f
