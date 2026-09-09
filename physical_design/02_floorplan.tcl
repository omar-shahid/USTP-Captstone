# ==============================================================================
#  02_floorplan.tcl — Floorplanning with Macro Placement
#
#  Technology: TSMC 0.18um (SITE tsm3site: 0.66 x 5.04 um)
#
#  Syntax reference:
#    Innovus_Block_Design/FPR/work/stylus_scripts/design_config.tcl
#    Innovus_Block_Design/FPR/work/relative_fp.tcl
# ==============================================================================

puts "======================================================"
puts " STEP 2: Floorplanning & Macro Placement (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..] 

# ------------------------------------------------------------------------------
#  Floorplan Geometry
#    Die size: 1500 um x 1200 um
#    Core margin: 20 um on all sides
#    Core size:  1460 um x 1160 um
# ------------------------------------------------------------------------------
create_floorplan -site tsm3site \
    -die_size {1500.0 1200.0 20.0 20.0 20.0 20.0}

puts "INFO: Die created: 1500 x 1200 um (Core margin: 20 um)."

# ------------------------------------------------------------------------------
#  Macro Placement
#    Place RAM macros along the top edge, ROM along the bottom.
#    Uses set_db instance attribute syntax from reference.
# ------------------------------------------------------------------------------
puts "INFO: Placing memory hard macros..."

# -- RAM blocks (top of core) --
set ram_lo [get_db insts *ram_data_lo]
if {$ram_lo ne ""} {
    set_db $ram_lo .location {80.0 950.0}
    set_db $ram_lo .orient R0
    set_db $ram_lo .place_status fixed
}

set ram_hi [get_db insts *ram_data_hi]
if {$ram_hi ne ""} {
    set_db $ram_hi .location {750.0 950.0}
    set_db $ram_hi .orient R0
    set_db $ram_hi .place_status fixed
}

# -- ROM blocks (bottom of core) --
set rom_lo [get_db insts *rom_inst_lo]
if {$rom_lo ne ""} {
    set_db $rom_lo .location {120.0 80.0}
    set_db $rom_lo .orient R0
    set_db $rom_lo .place_status fixed
}

set rom_hi [get_db insts *rom_inst_hi]
if {$rom_hi ne ""} {
    set_db $rom_hi .location {750.0 80.0}
    set_db $rom_hi .orient R0
    set_db $rom_hi .place_status fixed
}

puts "INFO: Hard macros placed and fixed."

# ------------------------------------------------------------------------------
#  Placement Halos Around Macros
#    Reference: create_place_halo -halo_deltas {30 30 30 30} from dtmf reference
#    Using 10 um halo for this design size
# ------------------------------------------------------------------------------
set block_insts [get_db insts -if {.is_block == true}]
if {$block_insts ne ""} {
    create_place_halo -halo_deltas {10.0 10.0 10.0 10.0} -insts $block_insts
    puts "INFO: 10 um placement halos added to all macro blocks."
}

# ------------------------------------------------------------------------------
#  Pin Placement
# ------------------------------------------------------------------------------
edit_pin -pin {clk reset rx} -side left -layer Metal3 -spread_type side

edit_pin -pin {tx uart_rx_ready \
              uart_rx_data[0] uart_rx_data[1] uart_rx_data[2] uart_rx_data[3] \
              uart_rx_data[4] uart_rx_data[5] uart_rx_data[6] uart_rx_data[7]} \
    -side right -layer Metal3 -spread_type side

edit_pin -pin {pwm_out tach_in pwm_stall_irq spi_sclk spi_mosi spi_miso spi_cs} \
    -side top -layer Metal4 -spread_type side

edit_pin -pin {result_src memwrite alu_src regwrite pc_src \
              imm_src[0] imm_src[1]} \
    -side bottom -layer Metal4 -spread_type side

# ------------------------------------------------------------------------------
#  Finish Floorplan
#    Reference: finish_floorplan -fill_place_blockage soft 20.0
#    From Innovus_Block_Design/FPR/work/stylus_scripts/design_config.tcl
# ------------------------------------------------------------------------------
finish_floorplan -fill_place_blockage soft 20.0

# ------------------------------------------------------------------------------
#  Save Checkpoint
# ------------------------------------------------------------------------------
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
file mkdir $SAVE_DIR

write_db ${SAVE_DIR}/02_floorplan

puts ""
puts "INFO: Floorplan complete. Saved to: ${SAVE_DIR}/02_floorplan"
puts ""
