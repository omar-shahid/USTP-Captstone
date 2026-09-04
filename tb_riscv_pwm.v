// ============================================================
//  tb_riscv_pwm.v
//  Instruction-level path verification: drives the actual risc_v
//  core through a small RV32I program that talks to pwm_regs
//  purely via lw/sw MMIO -- no hierarchical pokes into pwm_regs
//  itself. Confirms:
//    1. sw to PWM_CTRL/PWM_DUTY actually reaches pwm_regs and
//       produces the correct pwm_out duty cycle.
//    2. lw from PWM_TACH_PERIOD / PWM_STATUS returns the correct
//       live value into a GPR (address decode + read mux path).
//    3. Stall detection (no tach edges) is visible to software
//       through a normal lw, and pwm_stall_irq follows it.
//    4. CTRL.CLR_ERR written from software actually clears the
//       error once tach activity resumes (again just via sw/lw).
//    5. Regular data_mem loads/stores adjacent in the address map
//       are undisturbed by the PWM decode (regression on sel_dmem).
//  Program: prog/pwm_test.hex (see prog/pwm_test.asm)
// ============================================================
`timescale 1ns/1ps
module tb_riscv_pwm;

  // Scaled-down but self-consistent timing so STALL_TIMEOUT (20 cyc)
  // is safely above the tach generator period (8 cyc), same relationship
  // as an already-verified tb_pwm_regs run.
  localparam CLK_FREQ         = 1000;
  localparam PWM_FREQ         = 100;   // PWM_PERIOD_CYCLES = 10
  localparam STALL_TIMEOUT_MS = 20;    // STALL_TIMEOUT_CYCLES = 20
  localparam PWM_PERIOD_CYCLES = (CLK_FREQ + PWM_FREQ/2) / PWM_FREQ;

  reg clk = 1'b0;
  reg reset;
  reg tach_in;
  wire tx, pwm_out, pwm_stall_irq, uart_rx_ready;
  wire [7:0] uart_rx_data;
  wire result_src, memwrite, alu_src, regwrite, pc_src;
  wire [1:0] imm_src;
  wire [31:0] pc, inst, alu_result, wd, rd;

  integer pass_cnt, fail_cnt;

  risc_v #(
      .CLK_FREQ(CLK_FREQ), .BAUD_RATE(9600),
      .PWM_FREQ(PWM_FREQ), .STALL_TIMEOUT_MS(STALL_TIMEOUT_MS),
      .HEX_FILE("prog/pwm_test.hex")
  ) dut (
      .clk(clk), .reset(reset),
      .tx(tx), .rx(1'b1), .uart_rx_ready(uart_rx_ready), .uart_rx_data(uart_rx_data),
      .pwm_out(pwm_out), .tach_in(tach_in), .pwm_stall_irq(pwm_stall_irq),
      .result_src(result_src), .memwrite(memwrite), .alu_src(alu_src),
      .regwrite(regwrite), .pc_src(pc_src), .imm_src(imm_src),
      .pc(pc), .inst(inst), .alu_result(alu_result), .wd(wd), .rd(rd)
  );

  always #1 clk = ~clk;

  // ── Background tach pulse generator, gated on/off by PC milestones,
  //    exactly like tb_pwm_regs' generator but synchronized to program
  //    execution via the core's own exposed `pc` output instead of
  //    wall-clock guessing. ─────────────────────────────────────────
  reg tach_gen_en;
  integer tach_gen_period, tach_gen_cnt;
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

  task check;
    input           cond;
    input [8*80-1:0] msg;
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

  // wait until PC == addr (checked right after a clk_d-edge instruction retires).
  // MUST be automatic: it's called concurrently from two different initial
  // blocks below (the main sequence and the duty-cycle checker) -- a static
  // task's arguments/locals are shared storage across concurrent calls, so
  // without "automatic" the two concurrent wait_pc calls clobber each
  // other's target address.
  task automatic wait_pc;
    input [31:0] addr;
    begin
      wait (pc == addr);
    end
  endtask

  initial begin
    pass_cnt = 0; fail_cnt = 0;
    tach_gen_en = 1'b0; tach_gen_period = 8; tach_gen_cnt = 0;
    reset = 1'b1; // tach_in is driven solely by the generator always-block below
                  // (which already forces it low under reset) -- do not also
                  // drive it here, that would be two procedural drivers on one reg
    repeat (5) @(posedge clk);
    reset = 1'b0;

    // tach active from the start so the first TACH_PERIOD/STATUS
    // read (0x20/0x24) already sees a healthy, measured fan
    tach_gen_en = 1'b1;

    // -------------------------------------------------------------
    // Let the program run up through the first status/tach read
    // (instructions at 0x20/0x24, results saved to data_mem at
    // 0x28/0x2C). Stop the tach generator exactly when DELAY2 starts
    // (PC = 0x30) so the stall window that follows is deterministic.
    // -------------------------------------------------------------
    wait_pc(32'h30);
    tach_gen_en = 1'b0;
    $display("(info) t=%0t: reached DELAY2 (stall wait) with x4=%0d x5=%0d",
              $time, dut.RF.regs[4], dut.RF.regs[5]);
    check((dut.RF.regs[4] == 32'd8),
          "lw PWM_TACH_PERIOD into x4 matches generator period (8) via CPU path");
    check((dut.RF.regs[5] == 32'd5),
          "lw PWM_STATUS into x5 == EN=1,STALL=0,TACH_VALID=1 via CPU path");
    check((dut.DM.mem[0] == 8'd8 && dut.DM.mem[1]==8'd0 && dut.DM.mem[2]==8'd0 && dut.DM.mem[3]==8'd0),
          "sw x4 -> data_mem[0..3] stored tach period correctly (regression: dmem decode unaffected by PWM)");
    check((dut.DM.mem[4] == 8'd5),
          "sw x5 -> data_mem[4] stored status correctly (regression: dmem decode unaffected by PWM)");

    // -------------------------------------------------------------
    // Resume tach right as the program reaches the CLR_ERR write
    // (PC = 0x44), i.e. well before DELAY3 gives it time to settle,
    // mirroring tb_pwm_regs' "CLR_ERR while tach actively toggling" case.
    // -------------------------------------------------------------
    // wait until PC has moved past BOTH the lw x8,8(x1) at 0x3C and the
    // sw x8,8(x0) at 0x40 -- their register/memory writes only commit on
    // the clk_d edge that advances PC to the *next* instruction, so we
    // must wait for PC==0x44, not PC==0x3C, before reading x8/dmem[8].
    wait_pc(32'h44);
    $display("(info) t=%0t: status-after-stall read x8=%0d, stall_irq=%b", $time, dut.RF.regs[8], pwm_stall_irq);
    check((dut.RF.regs[8][1] == 1'b1),
          "lw PWM_STATUS into x8 shows STALL_ERR=1 via CPU path after idle tach");
    check((pwm_stall_irq == 1'b1), "pwm_stall_irq output follows STALL_ERR");
    check((dut.DM.mem[8] == dut.RF.regs[8][7:0]),
          "sw x8 -> data_mem[8] stored stalled status correctly");

    tach_gen_en = 1'b1; // resume now -- we're at PC=0x44 (addi x9,...),
                         // still before the CLR_ERR sw at 0x48 executes

    wait_pc(32'h60); // HALT loop reached: program ran to completion
    #10;
    $display("(info) t=%0t: final status x11=%0d", $time, dut.RF.regs[11]);
    check((dut.RF.regs[11] == 32'd5),
          "lw PWM_STATUS into x11 == EN=1,STALL=0,TACH_VALID=1 after CLR_ERR + resumed tach, via CPU path");
    check((pwm_stall_irq == 1'b0), "pwm_stall_irq deasserted after software-issued CLR_ERR");
    check((dut.DM.mem[12] == dut.RF.regs[11][7:0]),
          "sw x11 -> data_mem[12] stored final status correctly");
    check((pc == 32'h60), "program reached HALT (self-loop) without diverging");

    $display("=====================================================");
    $display(" TOTAL: %0d passed, %0d failed", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display(" RESULT: ALL TESTS PASSED");
    else                $display(" RESULT: %0d TEST(S) FAILED", fail_cnt);
    $display("=====================================================");
    $finish;
  end

  // ── Independent duty-cycle check, running concurrently: samples
  //    pwm_out over one full PWM period once EN is expected to be set
  //    (after the program's very first sw at PC=0x08/0x10 has retired).
  // ─────────────────────────────────────────────────────────────────
  integer high_cnt, k;
  initial begin
    wait (reset == 1'b0);
    wait_pc(32'h18); // past the two setup sw's (DUTY=50, CTRL EN=1)
    wait (dut.PWM.pwm_cnt == 0);
    high_cnt = 0;
    for (k = 0; k < PWM_PERIOD_CYCLES; k = k + 1) begin
      @(posedge clk); #0.05;
      if (pwm_out) high_cnt = high_cnt + 1;
    end
    $display("(info) t=%0t: duty measured high_cnt=%0d / %0d (expect %0d for 50%%)",
              $time, high_cnt, PWM_PERIOD_CYCLES, (50*PWM_PERIOD_CYCLES)/100);
    check((high_cnt == (50*PWM_PERIOD_CYCLES)/100),
          "pwm_out duty cycle matches the 50% written via sw PWM_DUTY (full CPU->bus->pwm_regs->pin path)");
  end

  initial begin
    #200000;
    $display("[TIMEOUT] Testbench did not finish in time");
    $finish;
  end

endmodule