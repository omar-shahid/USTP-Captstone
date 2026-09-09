// 1. Log file setup
set log file risc_v_lec.log -replace

// 2. Read cell and macro libraries (-liberty for .lib, or -verilog if using verilog models)
read library -liberty -both \
    ../lib/slow.lib \
    ../lib/ram_128x16A_slow_syn.lib \
    ../lib/rom_512x16A_slow_syn.lib

// 3. Read Golden design (RTL source files)
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

// 4. Read Revised design (Synthesized Gate-Level Netlist)
read design ../synthesis/output/risc_v_netlist.v -verilog -revised

set root module risc_v -revised

// 5. DFT Scan constraints (Uncomment only if scan insertion / DFT was run)
// add pin constraints 0 SE      -revised
// add ignored inputs  scan_in   -revised
// add ignored outputs scan_out  -revised

// 6. Switch to LEC mode & Compare
set system mode lec
add compared point -all
compare

// 7. Summary
report compare data -summary