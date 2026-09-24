# =============================================================================
# File   : run_layered.do
# Desc   : QuestaSim DO script for the layered RISC-V testbench.
#
#          1. Creates the work library (if needed)
#          2. Compiles all RTL source files
#          3. Compiles the layered SystemVerilog testbench (in dependency order)
#          4. Runs each test scenario with +TEST= plusarg
# =============================================================================

# ------- Create work library -------
if {![file exists work]} {
    vlib work
}
vmap work work

# ------- Compile RTL -------
vlog -timescale 1ns/1ps -work work -sv \
    macro_models/rom_512x16A.v \
    macro_models/ram_128x16A.v \
    adder.v \
    alu.v \
    alu_control.v \
    clk_div.v \
    control_unit.v \
    cu.v \
    data_mem.v \
    imm_ext.v \
    instr_mem.v \
    mux.v \
    pc.v \
    reg_file.v \
    uart_tx.v \
    uart_rx.v \
    uart_regs.v \
    pwm_regs.v \
    spi_reg.v \
    risc_v.v

# ------- Compile Layered Testbench (order matters) -------
vlog -timescale 1ns/1ps -work work -sv +incdir+tb/layered \
    tb/layered/rv_if.sv \
    tb/layered/rv_layered_pkg.sv \
    tb/layered/rv_layered_tb.sv

# ------- Run Each Test -------
foreach test {alu_test mem_test branch_test uart_test full_soc_test} {
    puts "============================================"
    puts "Running: $test"
    puts "============================================"
    vsim -c work.rv_layered_tb +TEST=$test -l ${test}_sim.log
    run -all
    quit -sim
}

puts ""
puts "============================================"
puts "  All layered tests completed."
puts "============================================"

quit -f
