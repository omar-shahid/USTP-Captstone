# ==============================================================================
#  constraints.sdc — Timing Constraints for RISC-V SoC (risc_v)
#
#  Technology: TSMC 0.18um (CL018G / tsmc18)
#
#  Clock Domains:
#    clk   — 50 MHz system clock (period 20 ns)
#    clk_d — Generated clock (clk / 200 = 250 KHz, CPU core)
#
#  Syntax reference: Innovus_Block_Design/FPR/work/dtmf.sdc
# ==============================================================================

set sdc_version 1.2

current_design risc_v

# ------------------------------------------------------------------------------
#  Primary Clock: 50 MHz system clock
# ------------------------------------------------------------------------------
create_clock -name clk -period 20.0 -waveform {0 10.0} [get_ports {clk}]

# ------------------------------------------------------------------------------
#  Generated Clock: CPU divided clock (clk_d)
#    clk_div counts 0→99, toggles clk_d → divide-by-200
#    clk_d period = 200 × 20 ns = 4000 ns (250 KHz)
# ------------------------------------------------------------------------------
create_generated_clock -name clk_d \
    -source [get_ports {clk}] \
    -divide_by 200 \
    [get_pins {CLK_DIVIDER/clk_d}]

# ------------------------------------------------------------------------------
#  Clock Uncertainty
# ------------------------------------------------------------------------------
set_clock_uncertainty 0.5 -setup [get_clocks {clk}]
set_clock_uncertainty 1.0 -setup [get_clocks {clk_d}]
set_clock_uncertainty 0.2 -hold  [get_clocks {clk}]
set_clock_uncertainty 0.3 -hold  [get_clocks {clk_d}]

# ------------------------------------------------------------------------------
#  Clock Transition
# ------------------------------------------------------------------------------
set_clock_transition 0.2 [get_clocks {clk}]
set_clock_transition 0.5 [get_clocks {clk_d}]

# ------------------------------------------------------------------------------
#  Design Rule Constraints (TSMC 0.18um)
# ------------------------------------------------------------------------------
set_max_fanout     20  [current_design]
set_max_transition 1.5 [current_design]

# ------------------------------------------------------------------------------
#  Asynchronous Reset — False Path
# ------------------------------------------------------------------------------
set_false_path -from [get_ports {reset}]

# ------------------------------------------------------------------------------
#  Clock Domain Crossing — False Paths
#    CPU (clk_d) <-> Peripherals (clk) crossing handled by software polling
# ------------------------------------------------------------------------------
set_false_path -from [get_clocks {clk}]   -to [get_clocks {clk_d}]
set_false_path -from [get_clocks {clk_d}] -to [get_clocks {clk}]

# ------------------------------------------------------------------------------
#  Input Delays (relative to clk)
# ------------------------------------------------------------------------------
set_input_delay 6.0 -clock [get_clocks {clk}] [get_ports {rx}]
set_input_delay 6.0 -clock [get_clocks {clk}] [get_ports {tach_in}]
set_input_delay 6.0 -clock [get_clocks {clk}] [get_ports {spi_miso}]

# ------------------------------------------------------------------------------
#  Output Delays (relative to clk — Peripheral outputs)
# ------------------------------------------------------------------------------
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {tx}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_ready}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[0]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[1]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[2]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[3]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[4]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[5]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[6]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {uart_rx_data[7]}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {pwm_out}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {pwm_stall_irq}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {spi_sclk}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {spi_mosi}]
set_output_delay 4.0 -clock [get_clocks {clk}] [get_ports {spi_cs}]

# ------------------------------------------------------------------------------
#  Output Delays (relative to clk_d — CPU debug outputs)
# ------------------------------------------------------------------------------
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {result_src}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {memwrite}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {alu_src}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {regwrite}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {pc_src}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {imm_src[0]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {imm_src[1]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {pc[*]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {inst[*]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {alu_result[*]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {wd[*]}]
set_output_delay 5.0 -clock [get_clocks {clk_d}] [get_ports {rd[*]}]
