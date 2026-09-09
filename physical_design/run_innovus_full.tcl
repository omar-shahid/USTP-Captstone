# ============================================================
#  run_innovus_full.tcl — Master Innovus Automation Script
#
#  Runs the complete physical design flow end-to-end:
#    01. Init Design
#    02. Floorplanning
#    03. Power Planning
#    04. Placement
#    05. Clock Tree Synthesis
#    06. Routing
#    07. Signoff Checks
#    08. Design Export
#
#  Usage:
#    innovus -files physical_design/run_innovus_full.tcl
#
#  Or interactively:
#    innovus
#    source physical_design/run_innovus_full.tcl
# ============================================================

set FLOW_START [clock seconds]

puts ""
puts "############################################################"
puts "#                                                          #"
puts "#   RISC-V SoC — Full Physical Design Flow (Innovus)       #"
puts "#   Technology: TSMC 0.18um (CL018G / tsmc18)              #"
puts "#                                                          #"
puts "############################################################"
puts ""

set PROJ_ROOT [file normalize [file dirname [info script]]/..]
set PD_DIR    ${PROJ_ROOT}/physical_design

# ── Create Report and Checkpoint Directories ──────────────────
file mkdir ${PD_DIR}/reports
file mkdir ${PD_DIR}/checkpoints
file mkdir ${PD_DIR}/output

# ── Step 1: Initialize Design ────────────────────────────────
puts "\n>>> Sourcing 01_init_design.tcl..."
source ${PD_DIR}/01_init_design.tcl

# ── Step 2: Floorplanning ────────────────────────────────────
puts "\n>>> Sourcing 02_floorplan.tcl..."
source ${PD_DIR}/02_floorplan.tcl

# ── Step 3: Power Planning ───────────────────────────────────
puts "\n>>> Sourcing 03_power_plan.tcl..."
source ${PD_DIR}/03_power_plan.tcl

# ── Step 4: Placement ────────────────────────────────────────
puts "\n>>> Sourcing 04_placement.tcl..."
source ${PD_DIR}/04_placement.tcl

# ── Step 5: Clock Tree Synthesis ─────────────────────────────
puts "\n>>> Sourcing 05_cts.tcl..."
source ${PD_DIR}/05_cts.tcl

# ── Step 6: Routing ──────────────────────────────────────────
puts "\n>>> Sourcing 06_route.tcl..."
source ${PD_DIR}/06_route.tcl

# ── Step 7: Signoff ──────────────────────────────────────────
puts "\n>>> Sourcing 07_signoff.tcl..."
source ${PD_DIR}/07_signoff.tcl

# ── Step 8: Export ───────────────────────────────────────────
puts "\n>>> Sourcing 08_export.tcl..."
source ${PD_DIR}/08_export.tcl

# ── Flow Summary ─────────────────────────────────────────────
set FLOW_END [clock seconds]
set FLOW_TIME [expr {$FLOW_END - $FLOW_START}]
set FLOW_MIN  [expr {$FLOW_TIME / 60}]
set FLOW_SEC  [expr {$FLOW_TIME % 60}]

puts ""
puts "############################################################"
puts "#                                                          #"
puts "#   PHYSICAL DESIGN FLOW COMPLETE                          #"
puts "#                                                          #"
puts "############################################################"
puts ""
puts " Total runtime: ${FLOW_MIN}m ${FLOW_SEC}s"
puts ""
puts " Checkpoints:"
puts "   ${PD_DIR}/checkpoints/01_init.enc"
puts "   ${PD_DIR}/checkpoints/02_floorplan.enc"
puts "   ${PD_DIR}/checkpoints/03_power_plan.enc"
puts "   ${PD_DIR}/checkpoints/04_placement.enc"
puts "   ${PD_DIR}/checkpoints/05_cts.enc"
puts "   ${PD_DIR}/checkpoints/06_route.enc"
puts "   ${PD_DIR}/checkpoints/07_signoff.enc"
puts "   ${PD_DIR}/checkpoints/08_final.enc"
puts ""
puts " Output deliverables:"
puts "   ${PD_DIR}/output/risc_v.gds"
puts "   ${PD_DIR}/output/risc_v_post_route.v"
puts "   ${PD_DIR}/output/risc_v_slow.sdf"
puts "   ${PD_DIR}/output/risc_v_fast.sdf"
puts "   ${PD_DIR}/output/risc_v.def"
puts "   ${PD_DIR}/output/risc_v.spef"
puts ""
puts " Reports: ${PD_DIR}/reports/"
puts ""

# ── Exit Innovus ─────────────────────────────────────────────
# Uncomment the line below for batch mode (no GUI)
# exit
