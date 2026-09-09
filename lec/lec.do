vpxmode

set log file risc_v_lec.log -replace

// 1. Flattening directives to align with synthesis optimizations
set flatten model -seq_constant
set flatten model -nodff_to_dlat_zero
set flatten model -nodff_to_dlat_feedback
set directive on synopsys translate_off translate_on

// 2. Read cell and macro Liberty libraries
read library -liberty -both \
    ../lib/slow.lib \
    ../lib/ram_128x16A_slow_syn.lib \
    ../lib/rom_512x16A_slow_syn.lib

// 3. Read Golden RTL design
read design \
    ../mux.v \
    ../adder.v \
    ../pc.v \
    ../alu.v \
    ../alu_control.v \
    ../control_unit.v \
    ../cu.v \
    ../reg_file.v \
    ../imm_ext.v \
    ../instr_mem.v \
    ../data_mem.v \
    ../clk_div.v \
    ../uart_tx.v \
    ../uart_rx.v \
    ../uart_regs.v \
    ../pwm_regs.v \
    ../spi_reg.v \
    ../risc_v.v \
    -verilog -golden

set root module risc_v -golden

// 4. Read Revised netlist
read design ../synthesis/output/risc_v_netlist.v -verilog -revised
set root module risc_v -revised

// 5. Pin constraints (Reset is active-high; hold inactive at 0 during comparison)
add pin constraints 0 reset -both

// 6. Switch to LEC mode & Run comparison
set system mode lec
map key points
add compared point -all
compare

// 7. Output reports
report compare data -summary
report compare data -noneq > nonequivalent_points.rpt