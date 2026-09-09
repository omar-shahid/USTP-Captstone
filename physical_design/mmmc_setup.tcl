# ==============================================================================
#  mmmc_setup.tcl — Multi-Mode Multi-Corner Setup for Innovus
#
#  Design:     RISC-V SoC (risc_v)
#  Technology: TSMC 0.18um (CL018G / tsmc18)
#
#  Corners:
#    slow — 1.62V, 125°C (setup analysis)
#    fast — 1.98V,   0°C (hold analysis)
#
#  Syntax reference: Innovus_Block_Design/FPR/work/dtmf_syn.mmmc
# ==============================================================================

# ------------------------------------------------------------------------------
#  Library Sets
# ------------------------------------------------------------------------------
create_library_set -name lib_slow\
   -timing\
    [list ../lib/slow.lib\
    ../lib/ram_128x16A_slow_syn.lib\
    ../lib/rom_512x16A_slow_syn.lib]

create_library_set -name lib_fast\
   -timing\
    [list ../lib/fast.lib\
    ../lib/ram_128x16A_fast_syn.lib\
    ../lib/rom_512x16A_fast_syn.lib]

# ------------------------------------------------------------------------------
#  Timing Conditions
# ------------------------------------------------------------------------------
create_timing_condition -name tc_slow\
   -library_sets [list lib_slow]

create_timing_condition -name tc_fast\
   -library_sets [list lib_fast]

# ------------------------------------------------------------------------------
#  RC Corners
# ------------------------------------------------------------------------------
create_rc_corner -name rc_worst -temperature 125\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0\
   -qrc_tech ../QRC/t018s6mm.tch

create_rc_corner -name rc_best -temperature 0\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0\
   -qrc_tech ../QRC/t018s6mm.tch

# ------------------------------------------------------------------------------
#  Delay Corners
# ------------------------------------------------------------------------------
create_delay_corner -name dc_slow\
   -timing_condition {tc_slow}\
   -rc_corner rc_worst

create_delay_corner -name dc_fast\
   -timing_condition {tc_fast}\
   -rc_corner rc_best

# ------------------------------------------------------------------------------
#  Constraint Mode
# ------------------------------------------------------------------------------
create_constraint_mode -name func_mode\
   -sdc_files\
    [list ../constraints/constraints.sdc]

# ------------------------------------------------------------------------------
#  Analysis Views
# ------------------------------------------------------------------------------
create_analysis_view -name view_setup -constraint_mode func_mode -delay_corner dc_slow
create_analysis_view -name view_hold -constraint_mode func_mode -delay_corner dc_fast

set_analysis_view -setup [list view_setup] -hold [list view_hold]
