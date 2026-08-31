// ============================================================
//  risc_v.v  –  Single-Cycle RISC-V Processor with UART MMIO
//
//  Memory Map
//    0x00–0x3F  data_mem  (64 bytes of RAM)
//    0x80       UART_TX_DATA    (W)  – write byte to transmit
//    0x84       UART_TX_STATUS  (R)  – bit[0]=1 → TX idle/ready
//    0x88       UART_RX_DATA    (R)  – last received byte
//    0x8C       UART_RX_STATUS  (R)  – bit[0]=1 → byte waiting
//
//  Parameters
//    CLK_FREQ  – master clock frequency in Hz passed to UART
//    BAUD_RATE – UART baud rate
// ============================================================
module risc_v #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    // Core
    input         clk,
    input         reset,
    // UART pins (connect to physical RX/TX or USB-UART)
    output        tx,
    input         rx,
    output        uart_rx_ready,
    output [7:0] uart_rx_data,
    // Debug / observation outputs
    output        result_src,
    memwrite,
    alu_src,
    regwrite,
    pc_src,
    output [ 1:0] imm_src,
    output [31:0] pc,
    output [31:0] inst,
    output [31:0] alu_result,
    output [31:0] wd,          // data being written to memory
    output [31:0] rd           // data read from memory
);

  // ── Internal wires ─────────────────────────────────────────
  wire [31:0] pc_next, pc_4, pc_target;
  wire [31:0] rd1, rd2, result;
  wire [31:0] imm_ext;
  wire [31:0] src_b;
  wire [ 2:0] alu_control;
  wire [31:0] read_data;
  wire        zero;
  wire        clk_d;
  wire [7:0] rx_data_wire;
  wire       rx_ready_wire;

  // ── Address decode ─────────────────────────────────────────
  // addr[7] = 1  →  UART registers (0x80–0xFF)
  // addr[7] = 0  →  data memory    (0x00–0x7F)
  wire        sel_uart = alu_result[7];

  // ── Clock divider (CPU clock) ──────────────────────────────
  clk_div clkd (
      clk,
      reset,
      clk_d
  );

  // ── PC next MUX ───────────────────────────────────────────
  mux PC_next (
      pc_next,
      pc_src,
      pc_4,
      pc_target
  );

  // ── Program Counter ────────────────────────────────────────
  pc ProgC (
      clk_d,
      reset,
      pc_next,
      pc
  );

  // ── PC + 4 ────────────────────────────────────────────────
  adder pc_plus4 (
      pc_4,
      pc,
      32'b100
  );

  // ── Instruction Memory ────────────────────────────────────
  instr_mem IM (
      pc,
      inst
  );

  // ── Register File ─────────────────────────────────────────
  reg_file RF (
      rd1,
      rd2,
      inst[19:15],
      inst[24:20],
      inst[11:7],
      result,
      regwrite,
      clk_d
  );

  // ── Immediate Extension ───────────────────────────────────
  imm_ext ImmExt (
      imm_ext,
      imm_src,
      inst
  );

  // ── ALU source B MUX ──────────────────────────────────────
  mux SRC_B (
      src_b,
      alu_src,
      rd2,
      imm_ext
  );

  // ── ALU ───────────────────────────────────────────────────
  alu ALU (
      alu_result,
      zero,
      rd1,
      src_b,
      alu_control
  );

  // ── PC Branch target adder ────────────────────────────────
  adder PC_target (
      pc_target,
      pc,
      imm_ext
  );

  // ── Control Unit ──────────────────────────────────────────
  cu CU (
      alu_src,
      result_src,
      regwrite,
      memwrite,
      pc_src,
      imm_src,
      alu_control,
      inst[6:0],
      inst[14:12],
      inst[30],
      zero
  );

  // ── Data Memory (CPU clock for write sync) ────────────────
  wire [31:0] dmem_rd;
  data_mem DM (
      .rd      (dmem_rd),
      .clk     (clk_d),
      .memwrite(memwrite & ~sel_uart),
      .addr    (alu_result),
      .wd      (rd2)
  );

  // ── UART Registers (system clock for baud generation) ─────
  wire [31:0] uart_rd;
  uart_regs #(
      .CLK_FREQ (CLK_FREQ),
      .BAUD_RATE(BAUD_RATE)
  ) UART (
      .clk       (clk),
      .reset     (reset),
      .addr      (alu_result),
      .wd        (rd2),
      .memwrite  (memwrite & sel_uart),
      .rd        (uart_rd),
      .tx        (tx),
      .rx        (rx),
      .rx_ready  (uart_rx_ready),
      .rx_data   (uart_rx_data)
  );

  // ── Memory read-data MUX ──────────────────────────────────
  assign read_data = sel_uart ? uart_rd : dmem_rd;

  // ── Result MUX (ALU result vs memory read) ────────────────
  mux result_mux (
      result,
      result_src,
      alu_result,
      read_data
  );

  // ── Debug output assignments ──────────────────────────────
  assign wd = rd2;  // data written to memory
  assign rd = read_data;  // data read from memory

endmodule

