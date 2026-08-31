# ModelSim / Questa do-file for RISC-V + UART - ALL TESTS
# Run with: vsim -c -do sim/run_all_tests.do

echo "=========================================="
echo "RISC-V Processor & UART Verification Suite"
echo "=========================================="

if {![file exists work]} {
    vlib work
    vmap work work
}

set ROOT_DIR "D:/ic_design/RISC_V"
set TB_DIR   "$ROOT_DIR/tb"

# Compile all RTL modules and testbenches
echo ""
echo "--- Compiling RTL Modules & Testbenches ---"
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
    "$TB_DIR/risc_v_isa_tb.v" \
    "$TB_DIR/uart_edge_tb.v" \
    "$TB_DIR/risc_v_uart_tb.v" \
    "$TB_DIR/uart_loopback_tb.v" \
    "$TB_DIR/risc_v_uart_full_tb.v" \
    "$TB_DIR/risc_v_hex_tb.v"

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

# Test 6: Dynamic Hex-Loader Test (Full SoC / Hello)
echo ""
echo "=========================================="
echo "TEST 6: RISC-V Hex-Loader Program Execution"
echo "=========================================="
vsim -t 1ns -voptargs=+acc work.risc_v_hex_tb +HEX=assembly_codes/uart_tx_hello.hex
run -all

echo ""
echo "=========================================="
echo "ALL TEST SUITES EXECUTED SUCCESSFULLY"
echo "=========================================="

quit -f
