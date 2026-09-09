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

if {[info exists PROJ_ROOT]} {
    set BASE_DIR $PROJ_ROOT
} else {
    set BASE_DIR [file normalize [file dirname [info script]]/..]
}

# ── Library Paths ─────────────────────────────────────────────
set LIB_DIR  ${BASE_DIR}/lib
set QRC_FILE ${BASE_DIR}/QRC/t018s6mm.tch
set CAP_TBL  ${BASE_DIR}/QRC/t018s6mm.CapTbl
set SDC_FILE ${BASE_DIR}/constraints/constraints.sdc

# ── 1. Create Library Sets ────────────────────────────────────
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

# ── 2. Create Timing Conditions ───────────────────────────────
create_timing_condition -name tc_slow \
    -library_sets [list lib_slow]

create_timing_condition -name tc_fast \
    -library_sets [list lib_fast]

# ── 3. Create RC Corners ──────────────────────────────────────
create_rc_corner -name rc_slow \
    -pre_route_res 1.0 \
    -post_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_cap 1.0 \
    -post_route_cross_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -temperature 125 \
    -qrc_tech $QRC_FILE \
    -cap_table $CAP_TBL

create_rc_corner -name rc_fast \
    -pre_route_res 1.0 \
    -post_route_res 1.0 \
    -pre_route_cap 1.0 \
    -post_route_cap 1.0 \
    -post_route_cross_cap 1.0 \
    -pre_route_clock_res 0.0 \
    -pre_route_clock_cap 0.0 \
    -temperature 0 \
    -qrc_tech $QRC_FILE \
    -cap_table $CAP_TBL

# ── 4. Create Delay Corners ───────────────────────────────────
create_delay_corner -name dc_slow \
    -timing_condition {tc_slow} \
    -rc_corner rc_slow

create_delay_corner -name dc_fast \
    -timing_condition {tc_fast} \
    -rc_corner rc_fast

# ── 5. Create Constraint Mode ─────────────────────────────────
create_constraint_mode -name func_mode \
    -sdc_files [list $SDC_FILE]

# ── 6. Create Analysis Views ──────────────────────────────────
create_analysis_view -name view_slow \
    -constraint_mode func_mode \
    -delay_corner dc_slow

create_analysis_view -name view_fast \
    -constraint_mode func_mode \
    -delay_corner dc_fast

# ── 7. Set Active Analysis Views ──────────────────────────────
set_analysis_view \
    -setup [list view_slow] \
    -hold  [list view_fast]

puts "INFO: MMMC setup complete."
puts "INFO:   Setup view: view_slow (1.62V, 125°C, slow corner)"
puts "INFO:   Hold view:  view_fast (1.98V,   0°C, fast corner)"
