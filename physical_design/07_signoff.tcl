# ============================================================
#  07_signoff.tcl — Signoff Checks (TSMC 0.18um)
#
#  Signoff parasitic extraction with QRC t018s6mm.tch
# ============================================================

puts "======================================================"
puts " STEP 7: Signoff Checks (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ── Signoff Parasitic Extraction (QRC) ────────────────────────
puts "INFO: Running signoff RC extraction..."
set_db extract_rc_engine post_route
set_db extract_rc_effort_level signoff
extract_rc

# ── Setup Timing Analysis (Slow Corner: 1.62V, 125°C) ─────────
puts "INFO: Running setup timing analysis (view_slow)..."
set_analysis_view -setup [list view_slow] -hold [list view_fast]

report_timing -max_paths 50 -path_type full_clock \
    > ${RPT_DIR}/signoff_timing_setup.rpt

report_timing -max_paths 50 -path_type full_clock -late -max_slack 0.0 \
    > ${RPT_DIR}/signoff_timing_violations_setup.rpt

# ── Hold Timing Analysis (Fast Corner: 1.98V, 0°C) ───────────
puts "INFO: Running hold timing analysis (view_fast)..."
report_timing -max_paths 50 -path_type full_clock -early \
    > ${RPT_DIR}/signoff_timing_hold.rpt

report_timing -max_paths 50 -path_type full_clock -early -max_slack 0.0 \
    > ${RPT_DIR}/signoff_timing_violations_hold.rpt

# ── Overall Timing Summary ───────────────────────────────────
time_design -post_route > ${RPT_DIR}/signoff_timing_summary.rpt

# ── DRC & Connectivity Checks ─────────────────────────────────
puts "INFO: Running signoff DRC and connectivity checks..."
check_drc -limit 1000      -report ${RPT_DIR}/signoff_drc.rpt
check_connectivity -type all -report ${RPT_DIR}/signoff_connectivity.rpt
check_process_antenna        -report ${RPT_DIR}/signoff_antenna.rpt

# ── Power & Area Reports ──────────────────────────────────────
report_power -view view_slow > ${RPT_DIR}/signoff_power_slow.rpt
report_power -view view_fast > ${RPT_DIR}/signoff_power_fast.rpt
report_area                  > ${RPT_DIR}/signoff_area.rpt
report_design                > ${RPT_DIR}/signoff_design_summary.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/07_signoff

puts ""
puts "INFO: Signoff complete. Reports written to: ${RPT_DIR}/"
puts "INFO: Checkpoint saved to: ${SAVE_DIR}/07_signoff"
puts ""
