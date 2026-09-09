# ============================================================
#  run_genus.tcl — Cadence Genus Synthesis Script
#
#  Design:     RISC-V SoC (risc_v) with RAM and ROM Hard Macros
#  Technology: TSMC 0.18um (CL018G / tsmc18)
#  Hard Macros:
#    - 2x rom_512x16A (Instruction ROM, 2 KB) from .lib
#    - 2x ram_128x16A (Data RAM, 512 B) from .lib
#
#  Usage:      genus -f synthesis/run_genus.tcl
# ============================================================

puts "======================================================"
puts " GENUS SYNTHESIS — RISC-V SoC (TSMC 0.18um + Hard Macros)"
puts "======================================================"

# ── Project Root ──────────────────────────────────────────────
set PROJ_ROOT [file normalize [file dirname [info script]]/..]

# ── Technology / Library Paths ────────────────────────────────
set LEF_DIR    ${PROJ_ROOT}/lef
set LIB_DIR    ${PROJ_ROOT}/lib
set RTL_DIR    ${PROJ_ROOT}
set SDC_FILE   ${PROJ_ROOT}/constraints/constraints.sdc
set OUTPUT_DIR ${PROJ_ROOT}/synthesis/output

file mkdir ${OUTPUT_DIR}
file mkdir ${OUTPUT_DIR}/reports

# ── Set Library Search Paths ──────────────────────────────────
set_db init_lib_search_path [list ${LIB_DIR}]
set_db init_hdl_search_path [list ${RTL_DIR}]

# ── Read Physical Libraries (LEF) ─────────────────────────────
# all.lef contains technology rules, standard cells, and memory macros
set_db lef_library [list \
    ${LEF_DIR}/all.lef \
]

# ── Read Timing Libraries ─────────────────────────────────────
# Slow corner: standard cells + RAM macro + ROM macro
# Hard macros are recognized as leaf black-box cells from their .lib
set_db library [list \
    ${LIB_DIR}/slow.lib \
    ${LIB_DIR}/ram_128x16A_slow_syn.lib \
    ${LIB_DIR}/rom_512x16A_slow_syn.lib \
]

# ── Read RTL Design ───────────────────────────────────────────
# NOTE: Do NOT read macro_models/*.v here!
# Hard macros must remain unelaborated leaf cells linked directly to .lib
puts "INFO: Reading RTL source files..."

read_hdl -v2001 [list \
    ${RTL_DIR}/mux.v \
    ${RTL_DIR}/adder.v \
    ${RTL_DIR}/pc.v \
    ${RTL_DIR}/alu.v \
    ${RTL_DIR}/alu_control.v \
    ${RTL_DIR}/control_unit.v \
    ${RTL_DIR}/cu.v \
    ${RTL_DIR}/reg_file.v \
    ${RTL_DIR}/imm_ext.v \
    ${RTL_DIR}/instr_mem.v \
    ${RTL_DIR}/data_mem.v \
    ${RTL_DIR}/clk_div.v \
    ${RTL_DIR}/uart_tx.v \
    ${RTL_DIR}/uart_rx.v \
    ${RTL_DIR}/uart_regs.v \
    ${RTL_DIR}/pwm_regs.v \
    ${RTL_DIR}/spi_reg.v \
    ${RTL_DIR}/risc_v.v \
]

# ── Elaborate Design ──────────────────────────────────────────
puts "INFO: Elaborating top-level module: risc_v"
elaborate risc_v

# Check for unresolved instances (RAM and ROM macros resolve to .lib)
check_design -unresolved

# ── Set Top Module ────────────────────────────────────────────
current_design risc_v

# ── Read Timing Constraints (SDC) ─────────────────────────────
puts "INFO: Reading SDC constraints: ${SDC_FILE}"
read_sdc ${SDC_FILE}

# ── Synthesis Effort ──────────────────────────────────────────
set_db syn_generic_effort medium
set_db syn_map_effort     medium
set_db syn_opt_effort     medium

# ── Run Synthesis ─────────────────────────────────────────────
puts "INFO: Running syn_generic..."
syn_generic

puts "INFO: Running syn_map..."
syn_map

puts "INFO: Running syn_opt..."
syn_opt

# ── Generate Reports ──────────────────────────────────────────
puts "INFO: Generating synthesis reports..."

report_timing > ${OUTPUT_DIR}/reports/timing_report.rpt
report_timing -max_paths 20 -max_slack 0.0 > ${OUTPUT_DIR}/reports/timing_violations.rpt
report_area > ${OUTPUT_DIR}/reports/area_report.rpt
report_power > ${OUTPUT_DIR}/reports/power_report.rpt
report_gates > ${OUTPUT_DIR}/reports/gates_report.rpt
report_qor > ${OUTPUT_DIR}/reports/qor_report.rpt

# ── Write Outputs ─────────────────────────────────────────────
puts "INFO: Writing outputs..."

write_hdl -mapped > ${OUTPUT_DIR}/risc_v_netlist.v
write_sdc > ${OUTPUT_DIR}/risc_v_constraints.sdc
write_sdf -timescale ns -nonegchecks -recrem split -setuphold split > ${OUTPUT_DIR}/risc_v.sdf
write_design -base_name ${OUTPUT_DIR}/risc_v_genus
catch { write_do_lec -golden_design risc_v -revised_design ${OUTPUT_DIR}/risc_v_netlist.v -logfile ${PROJ_ROOT}/lec/reports/genus_lec.log > ${PROJ_ROOT}/lec/run_lec_auto.do }

puts ""
puts "======================================================"
puts " SYNTHESIS COMPLETE"
puts " Netlist:     ${OUTPUT_DIR}/risc_v_netlist.v"
puts " Innovus DB:  ${OUTPUT_DIR}/risc_v_genus.*"
puts " Reports:     ${OUTPUT_DIR}/reports/"
puts "======================================================"

exit
