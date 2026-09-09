# ============================================================
#  01_init_design.tcl — Initialize Innovus Design
#
#  Design:     RISC-V SoC with RAM and ROM Macros
#  Technology: TSMC 0.18um (all.lef)
#  UI Mode:    Stylus Common UI & Legacy UI Compatible
# ============================================================

puts "======================================================"
puts " STEP 1: Initialize Design (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]

set NETLIST    ${PROJ_ROOT}/synthesis/output/risc_v_netlist.v
set LEF_FILE   ${PROJ_ROOT}/lef/all.lef
set MMMC_FILE  ${PROJ_ROOT}/physical_design/mmmc_setup.tcl
set DESIGN_NAME risc_v

foreach f [list $NETLIST $LEF_FILE $MMMC_FILE] {
    if {![file exists $f]} {
        puts "ERROR: File not found: $f"
        puts "       Please run Genus synthesis first."
        return -code error "Missing input file: $f"
    }
}

# ── Power & Ground Nets ───────────────────────────────────────
catch {set_db init_power_nets {VDD}}
catch {set_db init_ground_nets {VSS}}

# ── Initialize Design (Stylus Common UI / Legacy UI) ──────────
if {[info commands read_mmmc] ne ""} {
    puts "INFO: Running in Innovus Stylus Common UI mode..."

    # 1. Read Multi-Mode Multi-Corner timing definition
    puts "INFO: Reading MMMC file: $MMMC_FILE"
    read_mmmc $MMMC_FILE

    # 2. Read Physical LEF libraries
    puts "INFO: Reading Physical LEF: $LEF_FILE"
    read_physical -lef [list $LEF_FILE]

    # 3. Read gate-level netlist
    puts "INFO: Reading Netlist: $NETLIST (top: $DESIGN_NAME)"
    read_netlist $NETLIST -top $DESIGN_NAME

    # 4. Initialize design
    puts "INFO: Initializing design..."
    init_design

} else {
    puts "INFO: Running in Legacy Innovus UI mode..."

    set init_verilog            $NETLIST
    set init_design_netlisttype Verilog
    set init_design_settop      1
    set init_top_cell           $DESIGN_NAME
    set init_lef_file           [list $LEF_FILE]
    set init_mmmc_file          $MMMC_FILE
    set init_pwr_net            VDD
    set init_gnd_net            VSS

    init_design
}

# ── Set Process Node ──────────────────────────────────────────
catch {set_db design_process_node 180}

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
file mkdir $SAVE_DIR

if {[info commands write_db] ne ""} {
    catch {write_db -basename ${SAVE_DIR}/01_init}
} else {
    catch {save_design ${SAVE_DIR}/01_init.enc}
}

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
