# ==============================================================================
#  05_cts.tcl — Clock Tree Synthesis (CCOpt) for TSMC 0.18um
#
#  Clock Domains:
#    clk   — 50 MHz system clock
#    clk_d — 250 KHz CPU clock (generated, divide-by-200)
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/dtmf.ccopt
#    Innovus_Block_Design/FPR/work/stylus_scripts/innovus_config.tcl
#    Innovus_Block_Design/FPR/work/stylus_scripts/design_config.tcl
#    Innovus_Block_Design/FPR/work/scripts/design_config.tcl
# ==============================================================================

puts "======================================================"
puts " STEP 5: Clock Tree Synthesis (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ------------------------------------------------------------------------------
#  CTS Buffer & Inverter Cell Selection
#    Reference: Innovus_Block_Design/FPR/work/dtmf.ccopt
# ------------------------------------------------------------------------------
set_db cts_buffer_cells \
    {CLKBUFX1 CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20 CLKBUFXL}

set_db cts_inverter_cells \
    {CLKINVX1 CLKINVX2 CLKINVX3 CLKINVX4 CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20 CLKINVXL}

# ------------------------------------------------------------------------------
#  Clock Non-Default Routing Rules (NDR)
#    Reference: Innovus_Block_Design/FPR/work/stylus_scripts/design_config.tcl
#    Reference: Innovus_Block_Design/FPR/work/scripts/design_config.tcl
#
#    Spacing: Metal3 0.48, Metal4 0.48, Metal5 0.56, Metal6 0.92
# ------------------------------------------------------------------------------
create_route_rule -name Clock_NDR \
    -spacing {Metal3 0.48 Metal4 0.48 Metal5 0.56 Metal6 0.92}

create_route_type -name leaf \
    -route_rule Clock_NDR

create_route_type -name trunk \
    -route_rule Clock_NDR \
    -top_preferred_layer Metal6 \
    -bottom_preferred_layer Metal4

create_route_type -name top \
    -route_rule Clock_NDR \
    -top_preferred_layer Metal6 \
    -bottom_preferred_layer Metal4

# ------------------------------------------------------------------------------
#  Assign Route Types to CTS
#    Reference: Innovus_Block_Design/FPR/work/stylus_scripts/innovus_config.tcl
# ------------------------------------------------------------------------------
set_db cts_route_type_leaf  leaf
set_db cts_route_type_trunk trunk
set_db cts_route_type_top   top

# ------------------------------------------------------------------------------
#  Run CTS (CCOpt — clock_opt_design)
#    Unified clock tree synthesis + concurrent optimization (Stylus Common UI)
# ------------------------------------------------------------------------------
puts "INFO: Running Clock Concurrent Optimization (clock_opt_design)..."
clock_opt_design

puts "INFO: CTS complete."

# ------------------------------------------------------------------------------
#  Post-CTS Hold Optimization
#    Reference: opt_design -post_cts -hold from lab manual Module 15
# ------------------------------------------------------------------------------
puts "INFO: Running post-CTS hold optimization..."
opt_design -post_cts -hold

# ------------------------------------------------------------------------------
#  Post-CTS Timing Reports
# ------------------------------------------------------------------------------
time_design -post_cts       > ${RPT_DIR}/post_cts_setup.rpt
time_design -post_cts -hold > ${RPT_DIR}/post_cts_hold.rpt

report_clock_trees > ${RPT_DIR}/cts_clock_trees.rpt
report_skew_groups > ${RPT_DIR}/cts_skew_groups.rpt

report_timing -max_paths 20        > ${RPT_DIR}/post_cts_timing_setup.rpt
report_timing -max_paths 20 -early > ${RPT_DIR}/post_cts_timing_hold.rpt

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/05_cts

puts ""
puts "INFO: CTS complete. Saved to: ${SAVE_DIR}/05_cts"
puts ""
