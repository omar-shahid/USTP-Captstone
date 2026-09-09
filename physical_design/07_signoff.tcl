# ==============================================================================
#  07_signoff.tcl — Signoff Verification & Reports
#
#  Technology: TSMC 0.18um
#  Parasitic extraction using QRC t018s6mm.tch
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/scripts/flow_config.tcl (report steps)
#    Lab Manual Module 19: check_drc, check_connectivity
# ==============================================================================

puts "======================================================"
puts " STEP 7: Signoff Checks (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ------------------------------------------------------------------------------
#  Signoff Parasitic Extraction (QRC)
# ------------------------------------------------------------------------------
puts "INFO: Running signoff RC extraction..."
set_db extract_rc_engine      post_route
set_db extract_rc_effort_level signoff
extract_rc

# ------------------------------------------------------------------------------
#  Signoff Timing Analysis
# ------------------------------------------------------------------------------
puts "INFO: Running signoff timing analysis..."
time_design -post_route       > ${RPT_DIR}/signoff_timing_setup.rpt
time_design -post_route -hold > ${RPT_DIR}/signoff_timing_hold.rpt

# -- Detailed setup paths (reference: flow_config.tcl report_late_paths) --
report_timing -max_paths 5   -nworst 1 -path_type endpoint        > ${RPT_DIR}/signoff_setup_endpoint.rpt
report_timing -max_paths 1   -nworst 1 -path_type full_clock -net > ${RPT_DIR}/signoff_setup_worst.rpt
report_timing -max_paths 500 -nworst 1 -path_type full_clock      > ${RPT_DIR}/signoff_setup_gba.rpt

# -- Detailed hold paths (reference: flow_config.tcl report_early_paths) --
report_timing -early -max_paths 5   -nworst 1 -path_type endpoint        > ${RPT_DIR}/signoff_hold_endpoint.rpt
report_timing -early -max_paths 1   -nworst 1 -path_type full_clock -net > ${RPT_DIR}/signoff_hold_worst.rpt
report_timing -early -max_paths 500 -nworst 1 -path_type full_clock      > ${RPT_DIR}/signoff_hold_gba.rpt

# ------------------------------------------------------------------------------
#  DRC & Connectivity Checks
#    Reference: Lab Manual Module 19
# ------------------------------------------------------------------------------
puts "INFO: Running signoff DRC and connectivity checks..."
check_drc                    > ${RPT_DIR}/signoff_drc.rpt
check_connectivity -type all > ${RPT_DIR}/signoff_connectivity.rpt
check_process_antenna        > ${RPT_DIR}/signoff_antenna.rpt

# ------------------------------------------------------------------------------
#  Power & Area Reports
# ------------------------------------------------------------------------------
report_power -view view_setup > ${RPT_DIR}/signoff_power_slow.rpt
report_power -view view_hold  > ${RPT_DIR}/signoff_power_fast.rpt
report_area                   > ${RPT_DIR}/signoff_area.rpt
report_design                 > ${RPT_DIR}/signoff_design_summary.rpt

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/07_signoff

puts ""
puts "INFO: Signoff complete. Reports written to: ${RPT_DIR}/"
puts "INFO: Checkpoint saved to: ${SAVE_DIR}/07_signoff"
puts ""
