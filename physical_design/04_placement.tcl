# ============================================================
#  04_placement.tcl — Standard Cell Placement
#
#  Technology: TSMC 0.18um (CL018G)
# ============================================================

puts "======================================================"
puts " STEP 4: Standard Cell Placement (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ── Placement Controls ───────────────────────────────────────
set_db place_global_place_io_pins false
set_db place_global_timing_effort medium
set_db opt_useful_skew true

# ── Place Standard Cells ─────────────────────────────────────
puts "INFO: Running standard cell placement..."
place_opt_design

puts "INFO: Placement complete."

# ── Check Placement ──────────────────────────────────────────
check_place ${RPT_DIR}/placement_check.rpt

# ── Pre-CTS Optimization ─────────────────────────────────────
puts "INFO: Running pre-CTS optimization..."
opt_design -pre_cts

# ── Generate Reports ──────────────────────────────────────────
report_timing -max_paths 20 > ${RPT_DIR}/post_place_timing.rpt
report_congestion           > ${RPT_DIR}/post_place_congestion.rpt
report_design               > ${RPT_DIR}/post_place_summary.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/04_placement

puts ""
puts "INFO: Placement complete. Saved to: ${SAVE_DIR}/04_placement"
puts ""
