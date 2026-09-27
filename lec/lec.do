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
    ../rtl/mux.v \
    ../rtl/adder.v \
    ../rtl/pc.v \
    ../rtl/alu.v \
    ../rtl/alu_control.v \
    ../rtl/control_unit.v \
    ../rtl/cu.v \
    ../rtl/reg_file.v \
    ../rtl/imm_ext.v \
    ../rtl/instr_mem.v \
    ../rtl/data_mem.v \
    ../rtl/clk_div.v \
    ../rtl/uart_tx.v \
    ../rtl/uart_rx.v \
    ../rtl/uart_regs.v \
    ../rtl/pwm_regs.v \
    ../rtl/spi_reg.v \
    ../rtl/risc_v.v \
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