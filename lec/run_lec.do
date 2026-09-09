// ============================================================
//  run_lec.do — Cadence Conformal LEC Script
//
//  Design:     RISC-V SoC (risc_v)
//  Golden:     RTL source files
//  Revised:    Synthesized Gate-Level Netlist (risc_v_netlist.v)
//  Technology: TSMC 0.18um (CL018G) + Hard Macros
//
//  Usage:
//    Batch Mode: lec -nogui -dofile lec/run_lec.do -logfile lec/reports/lec.log
//    GUI Mode:   lec -gui   -dofile lec/run_lec.do
// ============================================================

// ── Step 1: Set Mode to Setup ────────────────────────────────
set system mode setup

// ── Step 2: Configure Conformal Environment ──────────────────
// Display all warnings and log commands
set log file lec/reports/lec_execution.log -replace
set rule handling -warning

set flatten model -seq_constant
set flatten model -nodff_to_dlat_zero
set flatten model -nodff_to_dlat_feedback

// ── Step 3: Load Libraries (Both Golden and Revised) ─────────
// Conformal reads Liberty timing models to understand cell pin functions,
// inverted outputs, three-state logic, and black-box macro boundaries.
puts "INFO: Loading Liberty cell libraries for Golden and Revised..."

read library -liberty -both \
    lib/slow.lib \
    lib/ram_128x16A_slow_syn.lib \
    lib/rom_512x16A_slow_syn.lib

// ── Step 4: Load Golden Design (RTL) ─────────────────────────
puts "INFO: Loading Golden RTL source files..."

read design \
    mux.v \
    adder.v \
    pc.v \
    alu.v \
    alu_control.v \
    control_unit.v \
    cu.v \
    reg_file.v \
    imm_ext.v \
    instr_mem.v \
    data_mem.v \
    clk_div.v \
    uart_tx.v \
    uart_rx.v \
    uart_regs.v \
    pwm_regs.v \
    spi_reg.v \
    risc_v.v \
    -golden -verilog2k

set root module risc_v -golden

// ── Step 5: Load Revised Design (Gate-Level Netlist) ─────────
puts "INFO: Loading Revised gate-level netlist..."

read design \
    synthesis/output/risc_v_netlist.v \
    -revised -verilog

set root module risc_v -revised

// ── Step 6: Constrain Reset ──────────────────────────────────
// Hold active-high reset inactive (0) during comparison
add pin constraints 0 reset -both

// ── Step 7: Identify Black Boxes ─────────────────────────────
// Hard macros (RAM & ROM) are preserved as black-box cut-points
puts "INFO: Reporting black boxes in both designs..."
report black box

// ── Step 8: Switch to Comparison Mode (LEC) ──────────────────
set system mode lec

// ── Step 8: Map Key Points ───────────────────────────────────
// Maps primary inputs, primary outputs, DFFs, and black-box pins
puts "INFO: Mapping comparison points..."
map key points

// Report unmapped key points (e.g. constant/unreachable registers)
report mapped points
report unmapped points -summary
report unmapped points -extra -unreachable -notmapped

// ── Step 9: Add Compared Points & Run Equivalence Check ──────
puts "INFO: Adding compared points and running formal verification..."
add compared points -all

compare

// ── Step 10: Generate Comprehensive Verification Reports ─────
puts "INFO: Generating LEC verification reports..."

// Non-equivalent points (must be empty for PASS)
report compare data -noneq   > lec/reports/nonequivalent_points.rpt

// Abort points (must be empty for complete proof)
report compare data -abort   > lec/reports/aborted_points.rpt

// Full verification summary
report verification          > lec/reports/verification_summary.rpt
report verification -verbose > lec/reports/verification_verbose.rpt

// Print concise summary to console
report compare data -summary

puts ""
puts "======================================================"
puts " CONFORMAL LEC RUN COMPLETE"
puts " Check reports in: lec/reports/"
puts "======================================================"
puts ""
