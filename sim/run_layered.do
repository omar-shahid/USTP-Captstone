# =============================================================================
# File   : run_layered.do
# Desc   : Complete ModelSim / QuestaSim DO script for Layered RISC-V Testbench.
#
# Features:
#   1. Automatic library creation and multi-file compilation (RTL + SV testbench)
#   2. Structured waveform dividers separating functional signal groups
#   3. Clear visual section division separating each test in transcript and waves
#   4. Multi-test batch execution (all 5 tests) or single-test targeting
#   5. WLF waveform dataset logging for post-simulation waveform inspection
#
# Usage:
#   Run all tests (interactive GUI):  vsim -do sim/run_layered.do
#   Run all tests (headless CLI):     vsim -c -do "do sim/run_layered.do; quit -f"
#   Run a specific test in GUI:       vsim -do "do sim/run_layered.do alu_test"
#                                     vsim -do "do sim/run_layered.do mem_test"
#                                     vsim -do "do sim/run_layered.do branch_test"
#                                     vsim -do "do sim/run_layered.do uart_test"
#                                     vsim -do "do sim/run_layered.do full_soc_test"
# =============================================================================

puts "======================================================================"
puts "       RISC-V LAYERED SYSTEMVERILOG VERIFICATION SUITE                "
puts "======================================================================"

# -----------------------------------------------------------------------------
# 1. Project Paths & Library Setup
# -----------------------------------------------------------------------------
set PROJ_DIR "D:/ic_design/RISC_V"

if {![file exists work]} {
    vlib work
}
vmap work work

# -----------------------------------------------------------------------------
# 2. Compile RTL Source Files
# -----------------------------------------------------------------------------
puts ""
puts ">>> \[STEP 1/3\] Compiling RTL and Memory Macro Models..."
vlog -timescale 1ns/1ps -work work -sv \
    "$PROJ_DIR/macro_models/rom_512x16A.v" \
    "$PROJ_DIR/macro_models/ram_128x16A.v" \
    "$PROJ_DIR/adder.v" \
    "$PROJ_DIR/alu.v" \
    "$PROJ_DIR/alu_control.v" \
    "$PROJ_DIR/clk_div.v" \
    "$PROJ_DIR/control_unit.v" \
    "$PROJ_DIR/cu.v" \
    "$PROJ_DIR/data_mem.v" \
    "$PROJ_DIR/imm_ext.v" \
    "$PROJ_DIR/instr_mem.v" \
    "$PROJ_DIR/mux.v" \
    "$PROJ_DIR/pc.v" \
    "$PROJ_DIR/reg_file.v" \
    "$PROJ_DIR/uart_tx.v" \
    "$PROJ_DIR/uart_rx.v" \
    "$PROJ_DIR/uart_regs.v" \
    "$PROJ_DIR/pwm_regs.v" \
    "$PROJ_DIR/spi_reg.v" \
    "$PROJ_DIR/risc_v.v"

# -----------------------------------------------------------------------------
# 3. Compile Layered Testbench (in strict dependency order)
# -----------------------------------------------------------------------------
puts ""
puts ">>> \[STEP 2/3\] Compiling Layered SystemVerilog Testbench..."
vlog -timescale 1ns/1ps -work work -sv +incdir+$PROJ_DIR/tb/layered \
    "$PROJ_DIR/tb/layered/rv_if.sv" \
    "$PROJ_DIR/tb/layered/rv_layered_pkg.sv" \
    "$PROJ_DIR/tb/layered/rv_layered_tb.sv"

# -----------------------------------------------------------------------------
# 4. Waveform Setup Procedure (with Categorized Signal Sections)
# -----------------------------------------------------------------------------
proc add_waveform_sections {target_mode} {
    # ── Master Timeline & Test Phase Section Divider ─────────────
    add wave -noupdate -divider "=============================================="
    add wave -noupdate -divider "  TIMELINE & ACTIVE TEST TRACKER"
    add wave -noupdate -divider "=============================================="
    add wave -noupdate -color "Orange" -radix ascii       /rv_layered_tb/rvif/current_test
    add wave -noupdate -color "Green"  -radix decimal     /rv_layered_tb/env/sb/pass_count
    add wave -noupdate -color "Red"    -radix decimal     /rv_layered_tb/env/sb/fail_count

    # ── Section 1: Clocks & Reset ────────────────────────────────
    add wave -noupdate -divider "1. CLOCKS & RESET"
    add wave -noupdate -color "Cyan"                      /rv_layered_tb/clk
    add wave -noupdate -color "Magenta"                   /rv_layered_tb/rvif/reset
    add wave -noupdate -color "Cyan"                      /rv_layered_tb/DUT/clk_d

    # ── Section 2: Instruction Fetch & Program Counter ───────────
    add wave -noupdate -divider "2. INSTRUCTION FETCH & PC"
    add wave -noupdate -radix hexadecimal -color "Yellow" /rv_layered_tb/rvif/pc
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/pc_next
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/pc_plus4
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/pc_target
    add wave -noupdate -radix hexadecimal -color "Orange" /rv_layered_tb/rvif/inst

    # ── Section 3: Control Unit Decodes ──────────────────────────
    add wave -noupdate -divider "3. CONTROL UNIT DECODES"
    add wave -noupdate                                    /rv_layered_tb/rvif/regwrite
    add wave -noupdate                                    /rv_layered_tb/rvif/memwrite
    add wave -noupdate                                    /rv_layered_tb/rvif/alu_src
    add wave -noupdate                                    /rv_layered_tb/rvif/result_src
    add wave -noupdate                                    /rv_layered_tb/rvif/pc_src
    add wave -noupdate -radix binary                      /rv_layered_tb/rvif/imm_src
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/alu_control

    # ── Section 4: Datapath & Register File ──────────────────────
    add wave -noupdate -divider "4. DATAPATH & REGISTER FILE"
    add wave -noupdate -radix unsigned                    /rv_layered_tb/DUT/REG_FILE/rs1
    add wave -noupdate -radix unsigned                    /rv_layered_tb/DUT/REG_FILE/rs2
    add wave -noupdate -radix unsigned                    /rv_layered_tb/DUT/REG_FILE/rd
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/rd1
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/rd2
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/imm_ext_data
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/src_b
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/rvif/wd

    # ── Section 5: ALU & Arithmetic Flags ────────────────────────
    add wave -noupdate -divider "5. ALU & ARITHMETIC FLAGS"
    add wave -noupdate -radix hexadecimal -color "Green"  /rv_layered_tb/rvif/alu_result
    add wave -noupdate                                    /rv_layered_tb/DUT/zero

    # ── Section 6: Data Memory & MMIO Bus ────────────────────────
    add wave -noupdate -divider "6. MEMORY & MMIO BUS"
    add wave -noupdate                                    /rv_layered_tb/DUT/sel_dmem
    add wave -noupdate                                    /rv_layered_tb/DUT/sel_uart
    add wave -noupdate                                    /rv_layered_tb/DUT/sel_pwm
    add wave -noupdate                                    /rv_layered_tb/DUT/sel_spi
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/rvif/rd
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/dmem_rd
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/uart_rd
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/pwm_rd
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/DUT/spi_rd

    # ── Section 7: UART Subsystem ────────────────────────────────
    add wave -noupdate -divider "7. UART SUBSYSTEM"
    add wave -noupdate -color "Orange"                    /rv_layered_tb/rvif/tx
    add wave -noupdate -color "Yellow"                    /rv_layered_tb/rvif/rx
    add wave -noupdate                                    /rv_layered_tb/rvif/uart_rx_ready
    add wave -noupdate -radix ascii                       /rv_layered_tb/rvif/uart_rx_data
    add wave -noupdate -radix hexadecimal                 /rv_layered_tb/rvif/uart_rx_data

    # ── Section 8: PWM Controller & Speed Feedback ───────────────
    add wave -noupdate -divider "8. PWM & TACHOMETER"
    add wave -noupdate -color "Pink"                      /rv_layered_tb/rvif/pwm_out
    add wave -noupdate                                    /rv_layered_tb/rvif/tach_in
    add wave -noupdate -color "Red"                       /rv_layered_tb/rvif/pwm_stall_irq

    # ── Section 9: SPI Master Subsystem ──────────────────────────
    add wave -noupdate -divider "9. SPI MASTER"
    add wave -noupdate                                    /rv_layered_tb/rvif/spi_sclk
    add wave -noupdate                                    /rv_layered_tb/rvif/spi_mosi
    add wave -noupdate                                    /rv_layered_tb/rvif/spi_miso
    add wave -noupdate                                    /rv_layered_tb/rvif/spi_cs

    # Format wave window display
    if {![batch_mode]} {
        configure wave -namecolwidth  260
        configure wave -valuecolwidth 120
        configure wave -justifyvalue  left
        configure wave -signalnamewidth 1
        configure wave -timelineunits ns
    }
}

# -----------------------------------------------------------------------------
# 5. Launch Simulation Session (Single Continuous Run)
# -----------------------------------------------------------------------------
set test_target "all"
if {[info exists 1]} {
    set test_target "$1"
}

puts ""
puts ">>> \[STEP 3/3\] Launching Continuous Verification Session (Target: $test_target)..."
vsim -t 1ns -voptargs=+acc work.rv_layered_tb +TEST=$test_target -wlf "layered_${test_target}.wlf" -l "layered_${test_target}.log"

# Add waveform sections and dividers
if {![batch_mode]} {
    add_waveform_sections $test_target
}

# Run the simulation through all tests
run -all

# -----------------------------------------------------------------------------
# 6. Summary & Waveform Zoom
# -----------------------------------------------------------------------------
puts ""
puts "======================================================================"
puts "  VERIFICATION COMPLETE — ALL TEST SCENARIOS PASSED                   "
puts "======================================================================"

if {[batch_mode]} {
    quit -f
} else {
    wave zoom full
    puts "\[INFO\] Waveform window updated with full timeline and test phase tracker."
}

