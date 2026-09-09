# ==============================================================================
#  01_init_design.tcl — Initialize Innovus Design
#
#  Design:     RISC-V SoC (risc_v)
#  Technology: TSMC 0.18um (all.lef)
#  UI Mode:    Stylus Common UI
#
#  Syntax reference: Innovus_Block_Design/FPR/work/dtmf.setup
# ==============================================================================

puts "======================================================"
puts " STEP 1: Initialize Design (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 

set NETLIST    ${PROJ_ROOT}/synthesis/output/risc_v_netlist.v
set LEF_FILE   ${PROJ_ROOT}/lef/all.lef
set MMMC_FILE  ${PROJ_ROOT}/physical_design/mmmc_setup.tcl
set DESIGN_NAME risc_v

# -- Power & Ground Net Attributes -----------------------------------------
set_db init_power_nets VDD
set_db init_ground_nets VSS

# -- Read MMMC Timing Definition -------------------------------------------
read_mmmc $MMMC_FILE

# -- Read Physical LEF Libraries -------------------------------------------
read_physical -lef [list $LEF_FILE]

# -- Read Gate-Level Netlist ------------------------------------------------
read_netlist $NETLIST -top $DESIGN_NAME

# -- Initialize Design ------------------------------------------------------
init_design

# -- Set Process Node -------------------------------------------------------
set_db design_process_node 180

# -- Save Checkpoint --------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
file mkdir $SAVE_DIR

write_db ${SAVE_DIR}/01_init

puts ""
puts "======================================================"
puts " DESIGN INITIALIZATION COMPLETE"
puts " Top Cell:   $DESIGN_NAME"
puts " LEF:        $LEF_FILE"
puts " MMMC:       $MMMC_FILE"
puts " Netlist:    $NETLIST"
puts " Checkpoint: ${SAVE_DIR}/01_init"
puts "======================================================"
puts ""
