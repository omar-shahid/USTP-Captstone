// ============================================================
//  pwm_regs.v  –  PWM Fan Controller Memory-Mapped Register Block
//
//  Adapts the PWM/tach/stall-detection engine to this project's exact
//  bus convention: combinational read (matches data_mem.v / uart_regs.v -
//  the top-level read_data mux is purely combinational with no wait
//  state, so a registered/latency read would return stale data here),
//  full 32-bit exact-address match, active-high reset (matches
//  clk_div.v / uart_regs.v).
//
//  Memory Map (byte addresses, relative to system bus):
//    0xC0  PWM_CTRL        (R/W) [0]EN [1]INVERT [2]TACH_EN
//                                 [3]CLR_ERR (write 1, self-clearing pulse)
//    0xC4  PWM_DUTY        (R/W) [7:0] duty_percent (0-100, clamped)
//    0xC8  PWM_STATUS      (R)   [0]EN_STAT [1]STALL_ERR [2]TACH_VALID
//    0xCC  PWM_TACH_PERIOD (R)   [31:0] clock cycles between the last two
//                                 tach_in rising edges (0 if none seen yet)
//
//  Software converts TACH_PERIOD to RPM as:
//    RPM = (60 * CLK_FREQ) / (TACH_PERIOD * TACH_PULSES_PER_REV)
//
//  Parameters:
//    CLK_FREQ         – system clock fed to this module (Hz) - this
//                        module runs on the fast `clk`, not the divided
//                        `clk_d`, same reasoning as uart_regs' baud gen:
//                        PWM frequency shouldn't depend on the CPU's
//                        instruction-rate divider.
//    PWM_FREQ         – target PWM switching frequency (Hz)
//    STALL_TIMEOUT_MS – ms with no tach edge before STALL_ERR sets
// ============================================================
module pwm_regs #(
    parameter CLK_FREQ         = 50_000_000,
    parameter PWM_FREQ         = 25_000,
    parameter STALL_TIMEOUT_MS = 500
)(
    input             clk,      // system (fast) clock
    input             reset,    // active-high, matches uart_regs/clk_div
    // CPU bus
    input      [31:0] addr,
    input      [31:0] wd,
    input             memwrite,
    output reg [31:0] rd,
    // fan-facing I/O
    output            pwm_out,
    input             tach_in,
    // optional status line (not wired into the core - no interrupt
    // controller in this single-cycle design - exposed for board LEDs /
    // testbench observation, same role as uart_rx_ready at the top level)
    output            stall_irq
);

  localparam PWM_PERIOD_CYCLES    = (CLK_FREQ + PWM_FREQ/2) / PWM_FREQ;
  localparam STALL_TIMEOUT_CYCLES = (CLK_FREQ / 1000) * STALL_TIMEOUT_MS;

  // ── CTRL register (persistent bits; CLR_ERR is a write-pulse, not stored) ──
  reg ctrl_en, ctrl_invert, ctrl_tach_en;
  wire clr_err_pulse = memwrite && (addr == 32'hC0) && wd[3];

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      ctrl_en      <= 1'b0;
      ctrl_invert  <= 1'b0;
      ctrl_tach_en <= 1'b0;
    end else if (memwrite && (addr == 32'hC0)) begin
      ctrl_en      <= wd[0];
      ctrl_invert  <= wd[1];
      ctrl_tach_en <= wd[2];
      // wd[3] (CLR_ERR) intentionally not stored - handled as a pulse
    end
  end

  // ── DUTY register (0-100, clamped on write) ────────────────────────
  reg [7:0] duty_reg;
  always @(posedge clk or posedge reset) begin
    if (reset)
      duty_reg <= 8'd0;
    else if (memwrite && (addr == 32'hC4))
      duty_reg <= (wd[7:0] > 8'd100) ? 8'd100 : wd[7:0];
  end

  // ── PWM period counter + duty compare ──────────────────────────────
  reg [31:0] pwm_cnt;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      pwm_cnt <= 32'd0;
    end else if (ctrl_en) begin
      if (pwm_cnt == PWM_PERIOD_CYCLES - 1)
        pwm_cnt <= 32'd0;
      else
        pwm_cnt <= pwm_cnt + 32'd1;
    end else begin
      pwm_cnt <= 32'd0;
    end
  end

  // duty*period/100 computed straight into a 32-bit reg - no separate
  // narrow intermediate, so the divide is never truncated first.
  reg [31:0] compare_val;
  always @(*) begin
    compare_val = (duty_reg * PWM_PERIOD_CYCLES) / 100;
  end

  wire pwm_raw = ctrl_en && (pwm_cnt < compare_val);
  assign pwm_out = ctrl_invert ? ~pwm_raw : pwm_raw;

  // ── Tach input synchronizer + rising-edge detect ───────────────────
  reg tach_ff0, tach_ff1, tach_ff2;
  wire tach_rising = tach_ff1 & ~tach_ff2;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      tach_ff0 <= 1'b0;
      tach_ff1 <= 1'b0;
      tach_ff2 <= 1'b0;
    end else begin
      tach_ff0 <= tach_in;
      tach_ff1 <= tach_ff0;
      tach_ff2 <= tach_ff1;
    end
  end

  // ── Tach period measurement ─────────────────────────────────────────
  reg [31:0] period_cnt, period_reg;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      period_cnt <= 32'd0;
      period_reg <= 32'd0;
    end else if (ctrl_tach_en) begin
      if (tach_rising) begin
        period_reg <= period_cnt + 32'd1;
        period_cnt <= 32'd0;
      end else begin
        period_cnt <= period_cnt + 32'd1;
      end
    end else begin
      period_cnt <= 32'd0;
    end
  end

  // ── Stall detection (sticky error, cleared via CTRL.CLR_ERR) ───────
  reg [31:0] stall_cnt;
  reg        stall_err;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      stall_cnt <= 32'd0;
      stall_err <= 1'b0;
    end else begin
      if (clr_err_pulse)
        stall_err <= 1'b0;

      if (!ctrl_en || !ctrl_tach_en) begin
        stall_cnt <= 32'd0;
      end else if (tach_rising) begin
        stall_cnt <= 32'd0;
      end else if (stall_cnt == STALL_TIMEOUT_CYCLES - 1) begin
        stall_err <= 1'b1;   // overrides same-cycle clear if condition persists
        stall_cnt <= stall_cnt;
      end else begin
        stall_cnt <= stall_cnt + 32'd1;
      end
    end
  end

  wire tach_valid = ctrl_tach_en && !stall_err;
  assign stall_irq = stall_err;

  // ── Combinational read (matches data_mem.v / uart_regs.v style) ────
  always @(*) begin
    case (addr)
      32'hC0:  rd = {28'h0, 1'b0, ctrl_tach_en, ctrl_invert, ctrl_en};
      32'hC4:  rd = {24'h0, duty_reg};
      32'hC8:  rd = {29'h0, tach_valid, stall_err, ctrl_en};
      32'hCC:  rd = period_reg;
      default: rd = 32'h00000000;
    endcase
  end

endmodule