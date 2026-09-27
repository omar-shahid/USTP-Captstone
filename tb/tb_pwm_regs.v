`timescale 1ns/1ps
module tb_pwm_regs;

  localparam CLK_FREQ  = 1000;  // scaled "cycles-per-ms" for fast, exact sim
  localparam PWM_FREQ  = 100;   // -> PWM_PERIOD_CYCLES = 10
  localparam STALL_MS  = 5;     // -> STALL_TIMEOUT_CYCLES = 5
  localparam PWM_PERIOD_CYCLES = (CLK_FREQ + PWM_FREQ/2) / PWM_FREQ;

  reg clk = 1'b0;
  reg reset;
  reg  [31:0] addr, wd;
  reg         memwrite;
  wire [31:0] rd;
  wire        pwm_out;
  reg         tach_in;
  wire        stall_irq;

  integer pass_cnt, fail_cnt;
  reg     tach_gen_en;
  integer tach_gen_period, tach_gen_cnt;
  integer exp, hc, j;

  pwm_regs #(.CLK_FREQ(CLK_FREQ), .PWM_FREQ(PWM_FREQ), .STALL_TIMEOUT_MS(STALL_MS))
  dut (.clk(clk), .reset(reset), .addr(addr), .wd(wd), .memwrite(memwrite),
       .rd(rd), .pwm_out(pwm_out), .tach_in(tach_in), .stall_irq(stall_irq));

  always #1 clk = ~clk;

  // background tach pulse generator (active-high reset version)
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      tach_gen_cnt <= 0;
      tach_in      <= 1'b0;
    end else if (tach_gen_en) begin
      if (tach_gen_cnt == 0) begin
        tach_in      <= 1'b1;
        tach_gen_cnt <= tach_gen_period - 1;
      end else begin
        tach_in      <= 1'b0;
        tach_gen_cnt <= tach_gen_cnt - 1;
      end
    end else begin
      tach_in <= 1'b0;
    end
  end

  task bus_write;
    input [31:0] a;
    input [31:0] d;
    begin
      @(posedge clk); #0.2;
      addr = a; wd = d; memwrite = 1'b1;
      @(posedge clk); #0.2;
      memwrite = 1'b0;
    end
  endtask

  task reset_dut;
    begin
      reset = 1'b1; memwrite = 1'b0; addr = 0; wd = 0;
      tach_gen_en = 1'b0; tach_gen_period = 0; tach_gen_cnt = 0;
      repeat (3) @(posedge clk);
      #0.2 reset = 1'b0;
      repeat (2) @(posedge clk);
    end
  endtask

  task check;
    input           cond;
    input [8*72-1:0] msg;
    begin
      if (cond) begin
        pass_cnt = pass_cnt + 1;
        $display("[PASS] %s", msg);
      end else begin
        fail_cnt = fail_cnt + 1;
        $display("[FAIL] %s", msg);
      end
    end
  endtask

  function [31:0] ctrl_word;
    input en, inv, tach_en, clr;
    begin
      ctrl_word = {28'b0, clr, tach_en, inv, en};
    end
  endfunction

  function integer exp_compare;
    input integer duty_pct;
    begin
      exp_compare = (duty_pct * PWM_PERIOD_CYCLES) / 100;
    end
  endfunction

  task measure_duty;
    output integer high_cnt;
    integer k;
    begin
      wait (dut.pwm_cnt == 0);
      high_cnt = 0;
      for (k = 0; k < PWM_PERIOD_CYCLES; k = k + 1) begin
        @(posedge clk); #0.05;
        if (pwm_out) high_cnt = high_cnt + 1;
      end
    end
  endtask

  initial begin
    pass_cnt = 0; fail_cnt = 0;
    $display("=== pwm_regs Self-Checking Testbench (RISC-V bus convention) ===");
    reset_dut;

    // -------------------------------------------------------------
    // 1. Reset state (active-high reset)
    // -------------------------------------------------------------
    addr = 32'hC0; #0.1; check((rd == 32'h0), "RESET: CTRL reads 0");
    addr = 32'hC4; #0.1; check((rd == 32'h0), "RESET: DUTY reads 0");
    addr = 32'hC8; #0.1; check((rd == 32'h0), "RESET: STATUS reads 0");
    addr = 32'hCC; #0.1; check((rd == 32'h0), "RESET: TACH_PERIOD reads 0");
    check((pwm_out == 1'b0), "RESET: pwm_out is 0 while disabled");

    // -------------------------------------------------------------
    // 2. Combinational read contract: rd must reflect addr with NO
    //    clock edge needed - this is the key behavioral difference
    //    from the original registered-read core, and the whole reason
    //    for this adapter existing.
    // -------------------------------------------------------------
    bus_write(32'hC4, 32'd42);
    addr = 32'hC4; #0.1; // no @(posedge clk) here on purpose
    check((rd == 32'd42), "COMB READ: rd reflects addr combinationally, no clock wait needed");
    addr = 32'hC0; #0.1;
    check((rd != 32'd42), "COMB READ: rd changes immediately when addr changes mid-cycle");

    // -------------------------------------------------------------
    // 3. Basic register write / read-back
    // -------------------------------------------------------------
    bus_write(32'hC0, ctrl_word(1,0,0,0));
    addr = 32'hC0; #0.1;
    check((rd[0]==1 && rd[1]==0 && rd[2]==0), "CTRL write/read-back EN=1,INV=0,TACH_EN=0");

    bus_write(32'hC4, 32'd50);
    addr = 32'hC4; #0.1;
    check((rd == 32'd50), "DUTY write/read-back 50%");

    // -------------------------------------------------------------
    // 4. Duty-cycle sweep incl. edge cases
    // -------------------------------------------------------------
    measure_duty(hc);
    exp = exp_compare(50);
    $display("  (info) DUTY 50%%: high=%0d expected=%0d (period=%0d)", hc, exp, PWM_PERIOD_CYCLES);
    check((hc == exp), "DUTY 50%: high-cycle count matches expected");

    bus_write(32'hC4, 32'd0);
    measure_duty(hc);
    check((hc == 0), "DUTY 0% (edge case): high-cycle count is zero");
    check((pwm_out == 1'b0), "DUTY 0%: pwm_out held low throughout period");

    bus_write(32'hC4, 32'd100);
    measure_duty(hc);
    check((hc == PWM_PERIOD_CYCLES), "DUTY 100% (edge case): full period high");

    // -------------------------------------------------------------
    // 5. Duty clamp: values above 100 saturate to 100
    // -------------------------------------------------------------
    bus_write(32'hC4, 32'd150);
    addr = 32'hC4; #0.1;
    check((rd == 32'd100), "DUTY clamp: writing 150 clamps to 100");

    bus_write(32'hC4, 32'hFF); // all-ones in the 8-bit duty field
    addr = 32'hC4; #0.1;
    check((rd == 32'd100), "DUTY clamp: all-ones duty field clamps to 100");

    // -------------------------------------------------------------
    // 6. EN=0 gating
    // -------------------------------------------------------------
    bus_write(32'hC4, 32'd80);
    bus_write(32'hC0, ctrl_word(0,0,0,0)); // EN=0
    repeat (PWM_PERIOD_CYCLES*2) @(posedge clk);
    check((pwm_out == 1'b0), "EN=0: pwm_out forced low even with duty=80%");
    check((dut.pwm_cnt == 0), "EN=0: pwm period counter held at 0");

    // -------------------------------------------------------------
    // 7. INVERT polarity
    // -------------------------------------------------------------
    bus_write(32'hC0, ctrl_word(1,1,0,0));
    bus_write(32'hC4, 32'd30);
    measure_duty(hc);
    exp = PWM_PERIOD_CYCLES - exp_compare(30);
    check((hc == exp), "INVERT: inverted high-cycle count matches expected");
    bus_write(32'hC0, ctrl_word(1,0,0,0));

    // -------------------------------------------------------------
    // 8. Exact-address matching: an address one byte off from any
    //    register must not decode to anything (this convention has no
    //    word-alignment masking, unlike the original core - it must
    //    match uart_regs.v's exact-compare style exactly)
    // -------------------------------------------------------------
    addr = 32'hC1; #0.1;
    check((rd == 32'h0), "Exact-match decode: addr 0xC1 (off-by-one) reads 0, not aliased to CTRL");
    bus_write(32'hC1, 32'hFFFFFFFF); // must be a no-op
    addr = 32'hC0; #0.1;
    check((rd[0] == 1'b1), "Exact-match decode: write to 0xC1 did not disturb CTRL (EN still 1)");

    // -------------------------------------------------------------
    // 9. Tach period measurement
    // -------------------------------------------------------------
    bus_write(32'hC0, ctrl_word(1,0,1,0)); // EN=1, TACH_EN=1
    tach_gen_period = 8; tach_gen_cnt = 0; tach_gen_en = 1'b1;
    repeat (30) @(posedge clk);
    addr = 32'hCC; #0.1;
    $display("  (info) TACH_PERIOD: measured=%0d expected=8", rd);
    check((rd == 32'd8), "TACH_PERIOD: measured period matches known generator spacing");
    tach_gen_en = 1'b0;

    // -------------------------------------------------------------
    // 10. Stall detection
    // -------------------------------------------------------------
    repeat (STALL_MS + 3) @(posedge clk);
    addr = 32'hC8; #0.1;
    check((rd[1] == 1'b1), "STALL_ERR sets after timeout with no tach edges");
    check((stall_irq == 1'b1), "stall_irq mirrors STALL_ERR");

    bus_write(32'hC0, ctrl_word(1,0,1,1)); // CLR_ERR while still stalled
    addr = 32'hC8; #0.1;
    check((rd[1] == 1'b1), "CLR_ERR while still stalled: STALL_ERR remains set");

    tach_gen_period = 2; tach_gen_cnt = 0; tach_gen_en = 1'b1;
    repeat (10) @(posedge clk);
    bus_write(32'hC0, ctrl_word(1,0,1,1)); // CLR_ERR while tach actively toggling
    addr = 32'hC8; #0.1;
    check((rd[1] == 1'b0), "CLR_ERR after tach resumes: STALL_ERR clears");
    check((rd[2] == 1'b1), "TACH_VALID set once healthy again");
    tach_gen_en = 1'b0;

    bus_write(32'hC0, ctrl_word(1,0,0,0)); // TACH_EN=0
    repeat (STALL_MS + 5) @(posedge clk);
    addr = 32'hC8; #0.1;
    check((rd[1] == 1'b0), "TACH_EN=0: no false stall error");

    // -------------------------------------------------------------
    // 11. Mid-operation reset (active-high)
    // -------------------------------------------------------------
    bus_write(32'hC4, 32'd70);
    bus_write(32'hC0, ctrl_word(1,0,1,0));
    repeat (5) @(posedge clk);
    reset_dut;
    addr = 32'hC0; #0.1; check((rd == 32'h0), "Mid-op reset: CTRL clears");
    addr = 32'hC4; #0.1; check((rd == 32'h0), "Mid-op reset: DUTY clears");
    addr = 32'hC8; #0.1; check((rd == 32'h0), "Mid-op reset: STATUS clears");
    addr = 32'hCC; #0.1; check((rd == 32'h0), "Mid-op reset: TACH_PERIOD clears");
    check((pwm_out == 1'b0), "Mid-op reset: pwm_out low");

    $display("=====================================================");
    $display(" TOTAL: %0d passed, %0d failed", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display(" RESULT: ALL TESTS PASSED");
    else                $display(" RESULT: %0d TEST(S) FAILED", fail_cnt);
    $display("=====================================================");
    $finish;
  end

  initial begin
    #100000;
    $display("[TIMEOUT] Testbench did not finish in time");
    $finish;
  end

endmodule