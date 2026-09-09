// ============================================================
//  instr_mem.v — Instruction Memory using 2x Artisan rom_512x16A Macros
//
//  Structure:
//    - Two 512x16 ROM macros arranged in parallel:
//        rom_inst_lo: provides inst[15:0]
//        rom_inst_hi: provides inst[31:16]
//    - Capacity: 512 words x 32 bits = 2 KB
//    - Addressing: Word-aligned (addr[10:2] -> A[8:0])
//
//  Technology: TSMC 0.18um (CL018G) Hard Macro rom_512x16A
// ============================================================
`timescale 1ns/1ps

module instr_mem #(
    parameter HEX_FILE  = "",
    parameter MEM_WORDS = 512
) (
    input             clk,
    input      [31:0] addr,
    output     [31:0] inst
);

  // Word-aligned 9-bit address (512 words)
  wire [8:0] word_addr = addr[10:2];

  // Chip enable: active low (always enabled when in range)
  wire cen = (addr[31:11] == 21'b0) ? 1'b0 : 1'b1;

  wire [15:0] q_lo;
  wire [15:0] q_hi;

  // ── Lower halfword ROM macro (bits [15:0]) ─────────────────
  rom_512x16A rom_inst_lo (
      .CLK(clk),
      .CEN(cen),
      .A  (word_addr),
      .Q  (q_lo)
  );

  // ── Upper halfword ROM macro (bits [31:16]) ────────────────
  rom_512x16A rom_inst_hi (
      .CLK(clk),
      .CEN(cen),
      .A  (word_addr),
      .Q  (q_hi)
  );

  assign inst = (cen == 1'b0) ? {q_hi, q_lo} : 32'h00000013; // default NOP

  // ── Simulation Initialization & Dynamic Hex-Loading ─────────
  // synthesis translate_off
  reg [31:0] mem [0:MEM_WORDS-1];
  integer idx;

  initial begin
    for (idx = 0; idx < MEM_WORDS; idx = idx + 1) begin
      mem[idx] = 32'h00000013;
    end

    // Default boot program ("Hi" MMIO UART loop)
    mem[0] = 32'h08000093; // 0x00: addi x1, x0, 128   (x1 = 0x80)
    mem[1] = 32'h04800113; // 0x04: addi x2, x0, 72    (x2 = 'H')
    mem[2] = 32'h0040A183; // 0x08: lw   x3, 4(x1)     (status)
    mem[3] = 32'hFE018EE3; // 0x0C: beq  x3, x0, -4    (wait)
    mem[4] = 32'h0020A023; // 0x10: sw   x2, 0(x1)     (tx 'H')
    mem[5] = 32'h06900113; // 0x14: addi x2, x0, 105   (x2 = 'i')
    mem[6] = 32'h0040A183; // 0x18: lw   x3, 4(x1)     (status)
    mem[7] = 32'hFE018EE3; // 0x1C: beq  x3, x0, -4    (wait)
    mem[8] = 32'h0020A023; // 0x20: sw   x2, 0(x1)     (tx 'i')
    mem[9] = 32'hFC000EE3; // 0x24: beq  x0, x0, -36   (loop)

    if (HEX_FILE != "") begin
      $readmemh(HEX_FILE, mem);
    end
  end

  // Synchronously and combinational reflect mem array into macro instances
  always @(*) begin
    rom_inst_lo.mem[word_addr] = mem[word_addr][15:0];
    rom_inst_hi.mem[word_addr] = mem[word_addr][31:16];
  end
  // synthesis translate_on

endmodule
