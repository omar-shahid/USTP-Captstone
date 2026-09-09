# ==============================================================================
#  08_export.tcl — Design Export (TSMC 0.18um)
#
#  Outputs: Post-Route Netlist, DEF, SDF, SPEF, GDSII
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/scripts/flow_config.tcl (write_verilog step)
# ==============================================================================

puts "======================================================"
puts " STEP 8: Design Export (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT  [file normalize [file dirname [info script]]/..] 
set OUTPUT_DIR ${PROJ_ROOT}/physical_design/output
set LAYER_MAP  ${PROJ_ROOT}/QRC/lefdef.layermap
file mkdir $OUTPUT_DIR

# ------------------------------------------------------------------------------
#  Update Names for Verilog Compatibility
#    Reference: flow_config.tcl write_verilog step
# ------------------------------------------------------------------------------
update_names -verilog

# ------------------------------------------------------------------------------
#  Write Post-Route Verilog Netlist
# ------------------------------------------------------------------------------
puts "INFO: Writing post-route netlist..."
write_netlist ${OUTPUT_DIR}/risc_v_post_route.v
puts "INFO: Netlist written: ${OUTPUT_DIR}/risc_v_post_route.v"

# ------------------------------------------------------------------------------
#  Write SDF Timing Annotation
# ------------------------------------------------------------------------------
puts "INFO: Writing SDF for setup and hold views..."
write_sdf -view view_setup ${OUTPUT_DIR}/risc_v_slow.sdf
write_sdf -view view_hold  ${OUTPUT_DIR}/risc_v_fast.sdf
puts "INFO: SDF files written."

# ------------------------------------------------------------------------------
#  Write DEF Layout Data
# ------------------------------------------------------------------------------
puts "INFO: Writing DEF..."
write_def ${OUTPUT_DIR}/risc_v.def
puts "INFO: DEF written: ${OUTPUT_DIR}/risc_v.def"

# ------------------------------------------------------------------------------
#  Write SPEF Parasitic Extraction
# ------------------------------------------------------------------------------
puts "INFO: Writing SPEF..."
write_spef ${OUTPUT_DIR}/risc_v.spef
puts "INFO: SPEF written: ${OUTPUT_DIR}/risc_v.spef"

# ------------------------------------------------------------------------------
#  Write GDSII Layout
# ------------------------------------------------------------------------------
puts "INFO: Writing GDSII stream..."
if {[file exists $LAYER_MAP]} {
    write_stream ${OUTPUT_DIR}/risc_v.gds \
        -map_file $LAYER_MAP \
        -mode ALL \
        -units 2000
} else {
    write_stream ${OUTPUT_DIR}/risc_v.gds \
        -mode ALL \
        -units 2000
}
puts "INFO: GDSII written: ${OUTPUT_DIR}/risc_v.gds"

# ------------------------------------------------------------------------------
#  Save Final Database
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/08_final

puts ""
puts "======================================================"
puts " EXPORT COMPLETE — TSMC 0.18um Deliverables"
puts "   Netlist:  ${OUTPUT_DIR}/risc_v_post_route.v"
puts "   Timing:   ${OUTPUT_DIR}/risc_v_slow.sdf (slow)"
puts "             ${OUTPUT_DIR}/risc_v_fast.sdf (fast)"
puts "   DEF:      ${OUTPUT_DIR}/risc_v.def"
puts "   SPEF:     ${OUTPUT_DIR}/risc_v.spef"
puts "   GDSII:    ${OUTPUT_DIR}/risc_v.gds"
puts "   Database: ${SAVE_DIR}/08_final"
puts "======================================================"
