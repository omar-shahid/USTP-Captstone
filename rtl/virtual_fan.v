// ============================================================
//  virtual_fan.v
//  Behavioral model of a PC-style DC fan, for simulation only
//  (not meant to be synthesized -- it stands in for a physical
//  fan + tachometer so pwm_fan_controller / pwm_regs can be
//  verified without real hardware).
//
//  Connect:
//     pwm_in   <-- controller's pwm_out
//     tach_out --> controller's tach_in
//
//  Behavior modeled:
//   1. Duty measurement: measures the duty cycle of pwm_in over
//      one PWM period (must match the controller's PWM_FREQ).
//   2. Stiction: below STALL_DUTY_PCT the fan does not spin at
//      all (target RPM = 0) -- real fans need a minimum duty to
//      start turning.
//   3. Mechanical inertia: actual RPM ramps toward the
//      duty-commanded target RPM in fixed steps rather than
//      snapping instantly, modeling spin-up/spin-down lag.
//   4. Tachometer output: while spinning, tach_out is a square
//      wave with PULSES_PER_REV rising edges per revolution
//      (2 is the PC-fan convention). While stopped (RPM==0),
//      tach_out is held low -- no edges -- so a real stall
//      (fan actually not turning, e.g. duty commanded to 0, or
//      EN de-asserted) is indistinguishable from a physical
//      stall as far as the controller's stall-timeout logic is
//      concerned.
// ============================================================
module virtual_fan #(
    parameter CLK_FREQ         = 1_000,  // MUST match the controller's CLK_FREQ
    parameter PWM_FREQ         = 100,    // MUST match the controller's PWM_FREQ
    parameter PULSES_PER_REV   = 2,      // tach edges per revolution (2 = typical PC fan)
    parameter MAX_RPM          = 6000,   // modeled RPM at 100% duty
    parameter MIN_RPM          = 0,      // modeled RPM at/below STALL_DUTY_PCT (0 = fully stops)
    parameter STALL_DUTY_PCT   = 5,      // duty (%) below which the fan won't spin at all
    parameter RAMP_MS_PER_STEP = 2,      // simulated inertia: time between RPM ramp steps
    parameter RPM_STEP         = 50      // RPM change per ramp step
)(
    input  wire        clk,
    input  wire        reset,
    input  wire        pwm_in,      // from controller's pwm_out
    output reg         tach_out,    // to controller's tach_in
    output reg  [15:0] rpm_actual,  // debug: current modeled RPM
    output reg  [6:0]  duty_pct     // debug: last-measured duty %, 0-100
);

  localparam integer PWM_PERIOD_CYCLES = CLK_FREQ / PWM_FREQ;
  localparam integer RAMP_STEP_CYCLES  = (CLK_FREQ/1000) * RAMP_MS_PER_STEP;

  // ---------------------------------------------------------------
  // 1. Duty-cycle measurement: count pwm_in highs over one PWM period
  // ---------------------------------------------------------------
  integer high_cnt, win_cnt;
  reg [15:0] target_rpm;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      high_cnt <= 0; win_cnt <= 0; duty_pct <= 0;
    end else if (win_cnt >= PWM_PERIOD_CYCLES-1) begin
      duty_pct <= (high_cnt*100)/PWM_PERIOD_CYCLES;
      high_cnt <= pwm_in ? 1 : 0;
      win_cnt  <= 0;
    end else begin
      high_cnt <= high_cnt + (pwm_in ? 1 : 0);
      win_cnt  <= win_cnt + 1;
    end
  end

  always @(*) begin
    target_rpm = (duty_pct <= STALL_DUTY_PCT) ? MIN_RPM : (MAX_RPM * duty_pct) / 100;
  end

  // ---------------------------------------------------------------
  // 2. Mechanical inertia: ramp actual RPM toward target RPM
  // ---------------------------------------------------------------
  integer ramp_cnt;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      rpm_actual <= 0; ramp_cnt <= 0;
    end else if (ramp_cnt >= RAMP_STEP_CYCLES-1) begin
      ramp_cnt <= 0;
      if (rpm_actual < target_rpm)
        rpm_actual <= (target_rpm - rpm_actual > RPM_STEP) ? rpm_actual + RPM_STEP : target_rpm;
      else if (rpm_actual > target_rpm)
        rpm_actual <= (rpm_actual - target_rpm > RPM_STEP) ? rpm_actual - RPM_STEP : target_rpm;
    end else begin
      ramp_cnt <= ramp_cnt + 1;
    end
  end

  // ---------------------------------------------------------------
  // 3. Tach generation: square wave whose period matches rpm_actual.
  //    full_period_cycles = 60*CLK_FREQ / (rpm * PULSES_PER_REV)
  // ---------------------------------------------------------------
  integer tach_half_period, tach_cnt;
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      tach_out <= 1'b0; tach_cnt <= 0;
    end else if (rpm_actual == 0) begin
      tach_out <= 1'b0;  // stopped fan -> no tach edges -> controller will see a stall
      tach_cnt <= 0;
    end else begin
      tach_half_period = (64'd60*CLK_FREQ) / (rpm_actual * PULSES_PER_REV * 2);
      if (tach_half_period < 1) tach_half_period = 1;
      if (tach_cnt >= tach_half_period-1) begin
        tach_out <= ~tach_out;
        tach_cnt <= 0;
      end else begin
        tach_cnt <= tach_cnt + 1;
      end
    end
  end

endmodule