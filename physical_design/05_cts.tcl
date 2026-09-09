# ============================================================
#  05_cts.tcl — Clock Tree Synthesis for TSMC 0.18um
#
#  Clock Domains:
#    clk   — 50 MHz system clock (UART)
#    clk_d — 250 KHz CPU clock (core, RAM, ROM)
#
#  Clock Cells: Artisan TSMC 0.18um CLKBUFX* and CLKINVX*
# ============================================================

puts "======================================================"
puts " STEP 5: Clock Tree Synthesis (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ── CTS Cell Selection ───────────────────────────────────────
set_db cts_buffer_cells   {CLKBUFX2 CLKBUFX4 CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20}
set_db cts_inverter_cells {CLKINVX2 CLKINVX4 CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20}

# ── CTS Targets ───────────────────────────────────────────────
set_db cts_target_skew                  0.2
set_db cts_target_max_transition_time   0.5

# ── Clock Routing Layers (TSMC18: Metal3 to Metal5) ───────────
set_db cts_route_top_preferred_layer    Metal5
set_db cts_route_bottom_preferred_layer Metal3

# ── Run CTS (CCOpt) ──────────────────────────────────────────
puts "INFO: Running Clock Concurrent Optimization (ccopt_design)..."
ccopt_design

puts "INFO: CTS complete."

# ── Post-CTS Optimization ────────────────────────────────────
puts "INFO: Running post-CTS optimization (setup + hold)..."
opt_design -post_cts
opt_design -post_cts -hold

# ── Reports ──────────────────────────────────────────────────
report_ccopt_clock_trees > ${RPT_DIR}/cts_clock_trees.rpt
report_ccopt_skew_groups > ${RPT_DIR}/cts_skew_groups.rpt
report_timing -max_paths 20        > ${RPT_DIR}/post_cts_timing_setup.rpt
report_timing -max_paths 20 -early > ${RPT_DIR}/post_cts_timing_hold.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
save_design ${SAVE_DIR}/05_cts.enc

puts ""
puts "INFO: CTS complete. Saved to: ${SAVE_DIR}/05_cts.enc"
puts ""
