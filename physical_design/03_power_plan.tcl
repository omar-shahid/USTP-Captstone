# ==============================================================================
#  03_power_plan.tcl — Power Grid Planning for TSMC 0.18um
#
#  6-Metal Stack:
#    Core Rings:  Metal5 (Horizontal) and Metal6 (Vertical)
#    Power Stripes: Metal6 vertical grid
#    Standard Cell Rails: Metal1 follow-pins
#
#  Conventions (from reference Innovus_Block_Design/FPR):
#    Ring width:    8 um
#    Ring spacing:  1 um
#    Ring offset:   1 um
#    Stripe width:  8 um
#    Stripe spacing: 1 um
#    Stripe set-to-set distance: 100 um
#    Via stacking: Metal1 to Metal6
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/power.tcl
#    Innovus_Block_Design/FPR/work/global_power.tcl
# ==============================================================================

puts "======================================================"
puts " STEP 3: Power Planning (TSMC 0.18um 6-Metal)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 

# ------------------------------------------------------------------------------
#  Connect Global Nets
#    Exact syntax from reference power.tcl
# ------------------------------------------------------------------------------
connect_global_net VDD -type pg_pin -pin VDD -inst *
connect_global_net VSS -type pg_pin -pin VSS -inst *
connect_global_net VDD -type tie_hi
connect_global_net VSS -type tie_lo
connect_global_net VDD -type tie_hi -pin VDD -inst *
connect_global_net VSS -type tie_lo -pin VSS -inst *

puts "INFO: Global nets VDD/VSS connected."

# ------------------------------------------------------------------------------
#  Via Stacking Attributes for Rings
# ------------------------------------------------------------------------------
set_db add_rings_stacked_via_top_layer    Metal6
set_db add_rings_stacked_via_bottom_layer Metal1

# ------------------------------------------------------------------------------
#  Core Power Rings (Around Core Boundary)
#    Metal5 horizontal, Metal6 vertical
#    Width: 8 um, Spacing: 1 um, Offset: 1 um
# ------------------------------------------------------------------------------
add_rings -nets {VDD VSS} \
    -type core_rings \
    -follow core \
    -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
    -width   {top 8 bottom 8 left 8 right 8} \
    -spacing {top 1 bottom 1 left 1 right 1} \
    -offset  {top 1 bottom 1 left 1 right 1} \
    -center 0 \
    -threshold 0 \
    -jog_distance 0 \
    -snap_wire_center_to_grid none

puts "INFO: Core power rings created (Metal5/Metal6, width 8 um, spacing 1 um)."

# ------------------------------------------------------------------------------
#  Block Rings Around Hard Macros
#    Adds local VDD/VSS rings around each RAM and ROM block
#    Same conventions as core rings
# ------------------------------------------------------------------------------
add_rings -nets {VDD VSS} \
    -type block_rings \
    -around each_block \
    -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
    -width   {top 8 bottom 8 left 8 right 8} \
    -spacing {top 1 bottom 1 left 1 right 1} \
    -offset  {top 1 bottom 1 left 1 right 1} \
    -center 0 \
    -threshold 0 \
    -jog_distance 0 \
    -snap_wire_center_to_grid none

puts "INFO: Block power rings created around RAM and ROM macros."

# ------------------------------------------------------------------------------
#  Via Stacking Attributes for Stripes
# ------------------------------------------------------------------------------
set_db add_stripes_stacked_via_top_layer    Metal6
set_db add_stripes_stacked_via_bottom_layer Metal1

# ------------------------------------------------------------------------------
#  Vertical Power Stripes (Metal6)
#    Width: 8 um, Spacing: 1 um
#    Set-to-set distance: 100 um
#    Start/Stop offset: 100 um
# ------------------------------------------------------------------------------
add_stripes -nets {VDD VSS} \
    -layer Metal6 \
    -direction vertical \
    -width 8 \
    -spacing 1 \
    -set_to_set_distance 100 \
    -start_from left \
    -start_offset 100 \
    -stop_offset 100 \
    -switch_layer_over_obs false \
    -max_same_layer_jog_length 2 \
    -pad_core_ring_top_layer_limit Metal6 \
    -pad_core_ring_bottom_layer_limit Metal1 \
    -block_ring_top_layer_limit Metal6 \
    -block_ring_bottom_layer_limit Metal1

puts "INFO: Vertical power stripes added (Metal6, width 8 um, set-to-set 100 um)."

# ------------------------------------------------------------------------------
#  Special Route (Standard Cell Rails & Macro Power Pins)
#    Follow-pin routing: connect standard cell VDD/VSS pins to power grid
# ------------------------------------------------------------------------------
set_db route_special_via_connect_to_shape {stripe}

route_special \
    -connect core_pin \
    -layer_change_range {Metal1 Metal6} \
    -block_pin_target nearest_target \
    -core_pin_target first_after_row_end \
    -allow_jogging 1 \
    -crossover_via_layer_range {Metal1 Metal6} \
    -nets {VDD VSS} \
    -allow_layer_change 1 \
    -target_via_layer_range {Metal1 Metal6}

puts "INFO: Special routing complete (standard cell rails & macro power connected)."

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/03_power_plan

puts ""
puts "INFO: Power planning complete. Saved to: ${SAVE_DIR}/03_power_plan"
puts ""
