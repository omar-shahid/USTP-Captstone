# ============================================================
#  constraints.sdc — Timing Constraints for RISC-V SoC
#
#  Dual-Clock Design:
#    clk   — 50 MHz system clock (UART, PWM, SPI)
#    clk_d — Generated clock (clk / 200 = 250 KHz, CPU core)
#
#  Technology: TSMC 0.18um (CL018G / tsmc18)
# ============================================================

# ── Primary Clock: clk at 50 MHz ──────────────────────────────
set CLK_PERIOD 20.0
set CLK_NAME   clk

create_clock -name $CLK_NAME -period $CLK_PERIOD [get_ports clk]

# ── Generated Clock: clk_d (CPU divided clock) ────────────────
# clk_div counts 0→99, toggles clk_d → divide-by-200
# clk_d period = 200 × 20 ns = 4000 ns (250 KHz)
# Instance name in risc_v.v is CLK_DIVIDER
create_generated_clock -name clk_d \
    -source [get_ports clk] \
    -divide_by 200 \
    [get_pins CLK_DIVIDER/clk_d]

# ── Clock Uncertainty ──────────────────────────────────────────
# Setup uncertainty (jitter + skew margin)
set_clock_uncertainty -setup 0.5 [get_clocks clk]
set_clock_uncertainty -setup 1.0 [get_clocks clk_d]

# Hold uncertainty
set_clock_uncertainty -hold 0.2 [get_clocks clk]
set_clock_uncertainty -hold 0.3 [get_clocks clk_d]

# ── Clock Transition ──────────────────────────────────────────
set_clock_transition 0.2 [get_clocks clk]
set_clock_transition 0.5 [get_clocks clk_d]

# ── Clock Domain Crossing — False Paths ──────────────────────
# CPU (clk_d) <-> Peripherals (clk) crossing is handled by software polling.
set_false_path -from [get_clocks clk]   -to [get_clocks clk_d]
set_false_path -from [get_clocks clk_d] -to [get_clocks clk]

# ── Asynchronous Reset ────────────────────────────────────────
set_false_path -from [get_ports reset]

# ── Peripheral Input Delays (relative to clk: 50 MHz) ────────
set_input_delay  -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports rx]
set_input_delay  -clock clk -min 0.0                         [get_ports rx]

set_input_delay  -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports tach_in]
set_input_delay  -clock clk -min 0.0                         [get_ports tach_in]

set_input_delay  -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports spi_miso]
set_input_delay  -clock clk -min 0.0                         [get_ports spi_miso]

# ── Peripheral Output Delays (relative to clk: 50 MHz) ───────
set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports tx]
set_output_delay -clock clk -min 0.0                         [get_ports tx]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports uart_rx_ready]
set_output_delay -clock clk -min 0.0                         [get_ports uart_rx_ready]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports {uart_rx_data[*]}]
set_output_delay -clock clk -min 0.0                         [get_ports {uart_rx_data[*]}]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports pwm_out]
set_output_delay -clock clk -min 0.0                         [get_ports pwm_out]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports pwm_stall_irq]
set_output_delay -clock clk -min 0.0                         [get_ports pwm_stall_irq]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports spi_sclk]
set_output_delay -clock clk -min 0.0                         [get_ports spi_sclk]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports spi_mosi]
set_output_delay -clock clk -min 0.0                         [get_ports spi_mosi]

set_output_delay -clock clk -max [expr {$CLK_PERIOD * 0.3}] [get_ports spi_cs]
set_output_delay -clock clk -min 0.0                         [get_ports spi_cs]

# ── Debug / CPU Core Output Delays (relative to clk_d) ────────
set_output_delay -clock clk_d -max 5.0 [get_ports result_src]
set_output_delay -clock clk_d -min 0.0 [get_ports result_src]

set_output_delay -clock clk_d -max 5.0 [get_ports memwrite]
set_output_delay -clock clk_d -min 0.0 [get_ports memwrite]

set_output_delay -clock clk_d -max 5.0 [get_ports alu_src]
set_output_delay -clock clk_d -min 0.0 [get_ports alu_src]

set_output_delay -clock clk_d -max 5.0 [get_ports regwrite]
set_output_delay -clock clk_d -min 0.0 [get_ports regwrite]

set_output_delay -clock clk_d -max 5.0 [get_ports pc_src]
set_output_delay -clock clk_d -min 0.0 [get_ports pc_src]

set_output_delay -clock clk_d -max 5.0 [get_ports {imm_src[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {imm_src[*]}]

set_output_delay -clock clk_d -max 5.0 [get_ports {pc[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {pc[*]}]

set_output_delay -clock clk_d -max 5.0 [get_ports {inst[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {inst[*]}]

set_output_delay -clock clk_d -max 5.0 [get_ports {alu_result[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {alu_result[*]}]

set_output_delay -clock clk_d -max 5.0 [get_ports {wd[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {wd[*]}]

set_output_delay -clock clk_d -max 5.0 [get_ports {rd[*]}]
set_output_delay -clock clk_d -min 0.0 [get_ports {rd[*]}]

# ── Design Rule Constraints (TSMC 0.18um) ────────────────────
set_max_transition 1.5 [current_design]
set_max_fanout     20  [current_design]
set_max_capacitance 1.0 [current_design]

puts "INFO: SDC constraints loaded for TSMC 0.18um (Dual-clock SoC: clk & clk_d)."
