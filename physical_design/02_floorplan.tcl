# ============================================================
#  02_floorplan.tcl — Floorplanning with Macro Placement
#
#  Technology: TSMC 0.18um (SITE tsm3site: 0.66 x 5.04 um)
#
#  Hard Macros:
#    - 2x rom_512x16A (368.17 x 186.85 um each) — Instruction Memory
#    - 2x ram_128x16A (593.82 x 168.995 um each) — Data Memory
# ============================================================

puts "======================================================"
puts " STEP 2: Floorplanning & Macro Placement (TSMC 0.18um)"
puts "======================================================"

set PROJ_ROOT [file normalize [file dirname [info script]]/..]

# ── Floorplan Geometry ────────────────────────────────────────
# Die size: 1500 um x 1200 um
# Core margin: 20 um on all sides
# Core size: 1460 um x 1160 um
floorPlan -site tsm3site \
    -s 1500.0 1200.0 \
    20.0 20.0 20.0 20.0

puts "INFO: Die created: 1500 x 1200 um (Core margin: 20 um)."

# ── Macro Placement ───────────────────────────────────────────
# Place RAM macros along the top edge of the core
# Place ROM macros along the bottom edge of the core
# Leave the central region open for standard cell logic and routing

puts "INFO: Placing memory hard macros..."

# RAM Macro 0 (Lower halfword): Top-left
dbSet [dbGet -p top.insts.name *ram_data_lo].pStatus fixed
dbSet [dbGet -p top.insts.name *ram_data_lo].pt {80.0 950.0}
dbSet [dbGet -p top.insts.name *ram_data_lo].orient R0

# RAM Macro 1 (Upper halfword): Top-right
dbSet [dbGet -p top.insts.name *ram_data_hi].pStatus fixed
dbSet [dbGet -p top.insts.name *ram_data_hi].pt {750.0 950.0}
dbSet [dbGet -p top.insts.name *ram_data_hi].orient R0

# ROM Macro 0 (Lower halfword): Bottom-left
dbSet [dbGet -p top.insts.name *rom_inst_lo].pStatus fixed
dbSet [dbGet -p top.insts.name *rom_inst_lo].pt {120.0 80.0}
dbSet [dbGet -p top.insts.name *rom_inst_lo].orient R0

# ROM Macro 1 (Upper halfword): Bottom-right
dbSet [dbGet -p top.insts.name *rom_inst_hi].pStatus fixed
dbSet [dbGet -p top.insts.name *rom_inst_hi].pt {750.0 80.0}
dbSet [dbGet -p top.insts.name *rom_inst_hi].orient R0

puts "INFO: Hard macros placed and fixed."

# ── Add Placement Halos Around Macros ─────────────────────────
# Prevents standard cells from being placed too close to macros (10 um halo)
addHaloToBlock 10.0 10.0 10.0 10.0 -all_blocks

puts "INFO: 10 um placement halos added to all macro blocks."

# ── Pin Placement ─────────────────────────────────────────────
# Left edge: Clock, reset, and UART RX
editPin -pin {clk reset rx} \
    -side LEFT -layer Metal3 -spreadType SIDE

# Right edge: UART TX and UART status/data
editPin -pin {tx uart_rx_ready \
              uart_rx_data[0] uart_rx_data[1] uart_rx_data[2] uart_rx_data[3] \
              uart_rx_data[4] uart_rx_data[5] uart_rx_data[6] uart_rx_data[7]} \
    -side RIGHT -layer Metal3 -spreadType SIDE

# Top edge: Control status and memory debug pins
editPin -pin {result_src memwrite alu_src regwrite pc_src \
              imm_src[0] imm_src[1]} \
    -side TOP -layer Metal4 -spreadType SIDE

# Bottom edge: Debug buses
editPin -pin {pc[0] pc[1] pc[2] pc[3] pc[4] pc[5] pc[6] pc[7] \
              pc[8] pc[9] pc[10] pc[11] pc[12] pc[13] pc[14] pc[15] \
              pc[16] pc[17] pc[18] pc[19] pc[20] pc[21] pc[22] pc[23] \
              pc[24] pc[25] pc[26] pc[27] pc[28] pc[29] pc[30] pc[31]} \
    -side BOTTOM -layer Metal4 -spreadType SIDE

editPin -pin {alu_result[0] alu_result[1] alu_result[2] alu_result[3] \
              alu_result[4] alu_result[5] alu_result[6] alu_result[7] \
              alu_result[8] alu_result[9] alu_result[10] alu_result[11] \
              alu_result[12] alu_result[13] alu_result[14] alu_result[15] \
              alu_result[16] alu_result[17] alu_result[18] alu_result[19] \
              alu_result[20] alu_result[21] alu_result[22] alu_result[23] \
              alu_result[24] alu_result[25] alu_result[26] alu_result[27] \
              alu_result[28] alu_result[29] alu_result[30] alu_result[31]} \
    -side LEFT -layer Metal3 -spreadType SIDE

editPin -pin {wd[0] wd[1] wd[2] wd[3] wd[4] wd[5] wd[6] wd[7] \
              wd[8] wd[9] wd[10] wd[11] wd[12] wd[13] wd[14] wd[15] \
              wd[16] wd[17] wd[18] wd[19] wd[20] wd[21] wd[22] wd[23] \
              wd[24] wd[25] wd[26] wd[27] wd[28] wd[29] wd[30] wd[31] \
              rd[0] rd[1] rd[2] rd[3] rd[4] rd[5] rd[6] rd[7] \
              rd[8] rd[9] rd[10] rd[11] rd[12] rd[13] rd[14] rd[15] \
              rd[16] rd[17] rd[18] rd[19] rd[20] rd[21] rd[22] rd[23] \
              rd[24] rd[25] rd[26] rd[27] rd[28] rd[29] rd[30] rd[31]} \
    -side RIGHT -layer Metal3 -spreadType SIDE

puts "INFO: Pin placement complete."

# ── Save Checkpoint ──────────────────────────────────────────
set SAVE_DIR ${PROJ_ROOT}/physical_design/checkpoints
save_design ${SAVE_DIR}/02_floorplan.enc

puts ""
puts "INFO: Floorplan complete. Saved to: ${SAVE_DIR}/02_floorplan.enc"
puts ""
