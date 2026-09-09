# ==============================================================================
#  06_route.tcl — Detail Routing & Filler Insertion
#
#  Technology: TSMC 0.18um (6-Metal)
#  Routing Layers: Metal1 to Metal6
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/stylus_scripts/innovus_config.tcl
#    Innovus_Block_Design/FPR/work/scripts/flow/innovus_steps.tcl
#    Lab Manual Module 16/17: route_opt_design
# ==============================================================================

puts "======================================================"
puts " STEP 6: Detail Routing (TSMC 0.18um 6-Metal)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ------------------------------------------------------------------------------
#  Routing Attributes
#    Reference: set_db route_design_detail_use_multi_cut_via_effort
#    from Innovus_Block_Design/FPR/work reference
# ------------------------------------------------------------------------------
set_db route_design_detail_use_multi_cut_via_effort medium

# ------------------------------------------------------------------------------
#  SI-Driven & Timing-Driven Routing
# ------------------------------------------------------------------------------
set_db delaycal_enable_si true
set_db extract_rc_engine  post_route

# ------------------------------------------------------------------------------
#  Optimization Prefix
# ------------------------------------------------------------------------------
set_db opt_new_inst_prefix "routeopt_"

# ------------------------------------------------------------------------------
#  Run Detail Routing with Optimization (route_opt_design)
#    Unified route + post-route optimization command (Stylus Common UI)
#    This replaces legacy route_design + opt_design -post_route
# ------------------------------------------------------------------------------
puts "INFO: Running detail routing (route_opt_design)..."
route_opt_design

puts "INFO: Detail routing complete."

# ------------------------------------------------------------------------------
#  Filler Cell Insertion
#    Reference: set_db add_fillers_cells from innovus_config.tcl
# ------------------------------------------------------------------------------
set_db add_fillers_cells "FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1"
add_fillers

puts "INFO: Filler cells inserted."

# ------------------------------------------------------------------------------
#  Post-Route Reports
# ------------------------------------------------------------------------------
time_design -post_route       > ${RPT_DIR}/post_route_setup.rpt
time_design -post_route -hold > ${RPT_DIR}/post_route_hold.rpt

report_timing -max_paths 20        > ${RPT_DIR}/post_route_timing_setup.rpt
report_timing -max_paths 20 -early > ${RPT_DIR}/post_route_timing_hold.rpt

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/06_route

puts ""
puts "INFO: Routing complete. Saved to: ${SAVE_DIR}/06_route"
puts ""
