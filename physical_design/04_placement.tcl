# ==============================================================================
#  04_placement.tcl — Standard Cell Placement & Pre-CTS Optimization
#
#  Technology: TSMC 0.18um (CL018G)
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/stylus_scripts/innovus_config.tcl
#    Innovus_Block_Design/FPR/work/scripts/flow/innovus_steps.tcl
# ==============================================================================

puts "======================================================"
puts " STEP 4: Standard Cell Placement (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 
set RPT_DIR   ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR

# ------------------------------------------------------------------------------
#  Tieoff Cell Insertion
#    Reference: set_db add_tieoffs_cells from innovus_config.tcl
# ------------------------------------------------------------------------------
set_db add_tieoffs_cells "TIELO TIEHI"

# ------------------------------------------------------------------------------
#  Timing Analysis Type
#    Reference: set_db timing_analysis_type ocv from innovus_config.tcl
# ------------------------------------------------------------------------------
set_db timing_analysis_type ocv

# ------------------------------------------------------------------------------
#  Optimization Prefix
#    Reference: set_db opt_new_inst_prefix from innovus_config.tcl
# ------------------------------------------------------------------------------
set_db opt_new_inst_prefix "placeopt_"

# ------------------------------------------------------------------------------
#  Place Standard Cells (place_opt_design)
#    Unified placement + pre-CTS optimization command (Stylus Common UI)
#    This replaces legacy placeDesign + optDesign -preCTS
# ------------------------------------------------------------------------------
puts "INFO: Running standard cell placement (place_opt_design)..."
place_opt_design

puts "INFO: Placement complete."

# ------------------------------------------------------------------------------
#  Pre-CTS Timing Reports
# ------------------------------------------------------------------------------
time_design -pre_cts      > ${RPT_DIR}/pre_cts_setup.rpt
time_design -pre_cts -hold > ${RPT_DIR}/pre_cts_hold.rpt

report_timing -max_paths 20 > ${RPT_DIR}/post_place_timing.rpt

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/04_placement

puts ""
puts "INFO: Placement complete. Saved to: ${SAVE_DIR}/04_placement"
puts ""
