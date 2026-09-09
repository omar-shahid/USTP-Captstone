# ============================================================
#  06_route.tcl — Signal Routing for TSMC 0.18um (6-Metal)
#
#  Routing Layers: Metal1 to Metal5 (Signal), Metal6 (Top)
#  Filler Cells:   FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64
# ============================================================

puts "======================================================"
puts " STEP 6: Signal Routing (TSMC 0.18um 6-Metal)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ── Routing Layer Limits ──────────────────────────────────────
set_db route_design_bottom_routing_layer 1
set_db route_design_top_routing_layer    6

set_db route_design_with_timing_driven   true
set_db route_design_with_si_driven       true

# ── Run NanoRoute ─────────────────────────────────────────────
puts "INFO: Running detailed routing (route_design)..."
route_design

puts "INFO: Detailed routing complete."

# ── Post-Route Optimization ──────────────────────────────────
puts "INFO: Running post-route optimization..."
opt_design -post_route
opt_design -post_route -hold

# ── Fix DRC Violations ───────────────────────────────────────
puts "INFO: Running DRC-aware ECO routing..."
route_eco -fix_drc

# ── Filler Cell Insertion ─────────────────────────────────────
puts "INFO: Inserting filler cells..."
set_db add_fillers_cells {FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1}
add_fillers

puts "INFO: Filler cells inserted."

# ── Post-Route Reports ───────────────────────────────────────
report_timing -max_paths 20        > ${RPT_DIR}/post_route_timing_setup.rpt
report_timing -max_paths 20 -early > ${RPT_DIR}/post_route_timing_hold.rpt
report_route                       > ${RPT_DIR}/route_summary.rpt
verify_drc -report                   ${RPT_DIR}/post_route_drc.rpt
verify_connectivity -report          ${RPT_DIR}/post_route_connectivity.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
save_design ${SAVE_DIR}/06_route.enc

puts ""
puts "INFO: Routing complete. Saved to: ${SAVE_DIR}/06_route.enc"
puts ""
