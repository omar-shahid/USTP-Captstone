# ============================================================
#  03_power_plan.tcl — Power Grid Planning for TSMC 0.18um
#
#  6-Metal Stack:
#    - Core Rings: Metal5 (Horizontal) and Metal6 (Vertical)
#    - Power Stripes: Metal6 vertical grid
#    - Macro Power Rings: VDD/VSS routing to RAM/ROM blocks
#    - Standard Cell Rails: Metal1 follow-pins
# ============================================================

puts "======================================================"
puts " STEP 3: Power Planning (TSMC 0.18um 6-Metal)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]

# ── Connect Global Nets ──────────────────────────────────────
connect_global_net VDD -type pg_pin -pin VDD -inst *
connect_global_net VSS -type pg_pin -pin VSS -inst *
connect_global_net VDD -type tie_hi
connect_global_net VSS -type tie_lo

puts "INFO: Global nets VDD/VSS connected."

# ── Power Ring Attributes ────────────────────────────────────
set_db add_rings_stacked_via_top_layer    Metal6
set_db add_rings_stacked_via_bottom_layer Metal1

# ── Core Power Rings (Around Core Boundary) ──────────────────
# Metal5 (horizontal) and Metal6 (vertical) for low IR drop
# Per-side width/spacing/offset to avoid VDD/VSS overlap
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

# ── Block Rings Around Hard Macros ───────────────────────────
# Adds local VDD/VSS rings around each RAM and ROM block
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

# ── Stripe Attributes ────────────────────────────────────────
set_db add_stripes_stacked_via_top_layer    Metal6
set_db add_stripes_stacked_via_bottom_layer Metal1

# ── Vertical Power Stripes (Metal6) ──────────────────────────
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

puts "INFO: Vertical power stripes added (Metal6, width 8 um, spacing 1 um)."

# ── Special Route (Standard Cell Rails & Macro Pins) ──────────
set_db route_special_via_connect_to_shape { stripe }
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

puts "INFO: Special routing complete (Standard cell rails & macro power connected)."

# ── Verify Power Connectivity ─────────────────────────────────
set RPT_DIR ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR
check_connectivity -type special -nets {VDD VSS} \
    > ${RPT_DIR}/power_connectivity.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
write_db ${SAVE_DIR}/03_power_plan

puts ""
puts "INFO: Power planning complete. Saved to: ${SAVE_DIR}/03_power_plan"
puts ""
