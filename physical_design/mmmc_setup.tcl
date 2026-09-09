# ============================================================
#  mmmc_setup.tcl — Multi-Mode Multi-Corner Setup for Innovus
#
#  Design:     RISC-V SoC (risc_v) with RAM and ROM Macros
#  Technology: TSMC 0.18um (CL018G / tsmc18)
#
#  Corners:
#    slow — 1.62V, 125°C (setup analysis)
#    fast — 1.98V,   0°C (hold analysis)
# ============================================================

puts "INFO: Configuring MMMC setup for TSMC 0.18um..."

set PROJ_ROOT [file normalize [file dirname [info script]]/..]

# ── Library Paths ─────────────────────────────────────────────
set LIB_DIR  ${PROJ_ROOT}/lib
set QRC_FILE ${PROJ_ROOT}/QRC/t018s6mm.tch
set CAP_TBL  ${PROJ_ROOT}/QRC/t018s6mm.CapTbl
set SDC_FILE ${PROJ_ROOT}/constraints/constraints.sdc

# ── Create Library Sets ───────────────────────────────────────
# Slow corner: Standard cells + RAM + ROM
create_library_set -name lib_slow \
    -timing [list \
        ${LIB_DIR}/slow.lib \
        ${LIB_DIR}/ram_128x16A_slow_syn.lib \
        ${LIB_DIR}/rom_512x16A_slow_syn.lib \
    ]

# Fast corner: Standard cells + RAM + ROM
create_library_set -name lib_fast \
    -timing [list \
        ${LIB_DIR}/fast.lib \
        ${LIB_DIR}/ram_128x16A_fast_syn.lib \
        ${LIB_DIR}/rom_512x16A_fast_syn.lib \
    ]

# ── Create RC Corners ────────────────────────────────────────
create_rc_corner -name rc_slow \
    -qrc_tech $QRC_FILE \
    -cap_table $CAP_TBL \
    -T 125

create_rc_corner -name rc_fast \
    -qrc_tech $QRC_FILE \
    -cap_table $CAP_TBL \
    -T 0

# ── Create Delay Corners ─────────────────────────────────────
create_delay_corner -name dc_slow \
    -library_set lib_slow \
    -rc_corner rc_slow

create_delay_corner -name dc_fast \
    -library_set lib_fast \
    -rc_corner rc_fast

# ── Create Constraint Mode ───────────────────────────────────
create_constraint_mode -name func_mode \
    -sdc_files [list $SDC_FILE]

# ── Create Analysis Views ────────────────────────────────────
create_analysis_view -name view_slow \
    -constraint_mode func_mode \
    -delay_corner dc_slow

create_analysis_view -name view_fast \
    -constraint_mode func_mode \
    -delay_corner dc_fast

# ── Set Active Analysis Views ─────────────────────────────────
set_analysis_view \
    -setup [list view_slow] \
    -hold  [list view_fast]

puts "INFO: MMMC setup complete."
puts "INFO:   Setup view: view_slow (1.62V, 125°C, slow corner)"
puts "INFO:   Hold view:  view_fast (1.98V,   0°C, fast corner)"
