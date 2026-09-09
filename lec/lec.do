vpxmode
set log file risc_v_lec.log -replace

// 1. Enable sequential optimizations and constant resolution
set naming rule -parameter
set flatten model -seq_constant
set flatten model -nodff_to_dlat_zero
set flatten model -nodff_to_dlat_feedback
set directive on synopsys translate_off translate_on

// 2. Read libraries
read library -liberty -both \
    ../lib/slow.lib \
    ../lib/ram_128x16A_slow_syn.lib \
    ../lib/rom_512x16A_slow_syn.lib

// 3. Read designs
read design ../mux.v ../adder.v ../pc.v ../alu.v ../alu_control.v ../control_unit.v ../cu.v ../reg_file.v ../imm_ext.v ../instr_mem.v ../data_mem.v ../clk_div.v ../uart_tx.v ../uart_rx.v ../uart_regs.v ../pwm_regs.v ../spi_reg.v ../risc_v.v -verilog -golden
set root module risc_v -golden

read design ../synthesis/output/risc_v_netlist.v -verilog -revised
set root module risc_v -revised

// 4. Map & Compare
set system mode lec
map key points
add compared point -all
compare

// 5. Detailed report
report compare data -summary
report compare data -noneq > nonequivalent_points.rpt