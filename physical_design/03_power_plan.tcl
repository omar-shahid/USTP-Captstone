# ============================================================
#  03_power_plan.tcl — Power Grid Planning for TSMC 0.18um
#
#  6-Metal Stack:
#    - Core Rings: Metal5 (Horizontal) and Metal6 (Vertical)
#    - Power Stripes: Metal5 & Metal6 grid
#    - Macro Power Rings: VDD/VSS routing to RAM/ROM blocks
#    - Standard Cell Rails: Metal1 follow-pins
# ============================================================

puts "======================================================"
puts " STEP 3: Power Planning (TSMC 0.18um 6-Metal)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]

# ── Connect Global Nets ──────────────────────────────────────
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst *
globalNetConnect VSS -type tielo -inst *

puts "INFO: Global nets VDD/VSS connected."

# ── Power Rings (Around Core Boundary) ───────────────────────
# Metal5 (horizontal) and Metal6 (vertical) for low IR drop
addRing -type core_rings \
    -nets {VDD VSS} \
    -width  10.0 \
    -spacing 2.0 \
    -offset  2.0 \
    -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
    -jog_distance 1.0 \
    -threshold 1.0 \
    -follow core

puts "INFO: Core power rings created (Metal5/Metal6, width 10 um)."

# ── Block Rings Around Hard Macros ───────────────────────────
# Adds local VDD/VSS rings around each RAM and ROM block
addRing -type block_rings \
    -nets {VDD VSS} \
    -width 4.0 \
    -spacing 1.5 \
    -offset 2.0 \
    -layer {top Metal5 bottom Metal5 left Metal6 right Metal6} \
    -around each_block

puts "INFO: Block power rings created around RAM and ROM macros."

# ── Vertical Power Stripes (Metal6) ──────────────────────────
addStripe -nets {VDD VSS} \
    -layer Metal6 \
    -direction vertical \
    -width 4.0 \
    -spacing 2.0 \
    -set_to_set_distance 100.0 \
    -start_from left \
    -start_offset 30.0 \
    -switch_layer_over_obs false \
    -pad_core_ring_top_layer_limit Metal6 \
    -pad_core_ring_bottom_layer_limit Metal1

puts "INFO: Vertical power stripes added (Metal6)."

# ── Horizontal Power Stripes (Metal5) ─────────────────────────
addStripe -nets {VDD VSS} \
    -layer Metal5 \
    -direction horizontal \
    -width 4.0 \
    -spacing 2.0 \
    -set_to_set_distance 100.0 \
    -start_from bottom \
    -start_offset 30.0 \
    -switch_layer_over_obs false \
    -pad_core_ring_top_layer_limit Metal6 \
    -pad_core_ring_bottom_layer_limit Metal1

puts "INFO: Horizontal power stripes added (Metal5)."

# ── Special Route (Standard Cell Rails & Macro Pins) ──────────
sroute -connect {blockPin padPin padRing corePin floatingStripe} \
    -layerChangeRange {Metal1 Metal6} \
    -blockPinTarget {nearestTarget} \
    -corePinTarget {firstAfterRowEnd} \
    -floatingStripeTarget {blockRing padRing ring stripe ringPin blockPin followPin} \
    -allowJogging 1 \
    -crossoverViaLayerRange {Metal1 Metal6} \
    -nets {VDD VSS}

puts "INFO: Special routing complete (Standard cell rails & macro power connected)."

# ── Verify Power Connectivity ─────────────────────────────────
set RPT_DIR ${PROJ_ROOT}/physical_design/reports
file mkdir $RPT_DIR
verify_connectivity -type special -nets {VDD VSS} \
    -report ${RPT_DIR}/power_connectivity.rpt

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
save_design ${SAVE_DIR}/03_power_plan.enc

puts ""
puts "INFO: Power planning complete. Saved to: ${SAVE_DIR}/03_power_plan.enc"
puts ""
