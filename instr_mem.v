// ============================================================
//  instr_mem.v  –  Instruction Memory with Hex Loading Support
//
//  Parameters:
//    HEX_FILE  – path to .hex file for $readmemh (empty string uses default program)
//    MEM_WORDS – size of instruction memory in 32-bit words (default: 256 = 1KB)
// ============================================================
`timescale 1ns/1ps

module instr_mem #(
    parameter HEX_FILE  = "",
    parameter MEM_WORDS = 256
) (
    input  [31:0] addr,
    output reg [31:0] inst
);

  reg [31:0] mem [0:MEM_WORDS-1];
  integer i;

  initial begin
    // Initialize memory with NOP instructions (addi x0, x0, 0)
    for (i = 0; i < MEM_WORDS; i = i + 1) begin
      mem[i] = 32'h00000013;
    end

    // Default boot program ("Hi" MMIO UART loop)
    // 0x00: addi x1, x0, 128    (x1 = 0x80 UART base)
    mem[0] = 32'h08000093;
    // 0x04: addi x2, x0, 72     (x2 = 'H')
    mem[1] = 32'h04800113;
    // 0x08: lw   x3, 4(x1)      (x3 = UART_TX_STATUS at 0x84)
    mem[2] = 32'h0040A183;
    // 0x0C: beq  x3, x0, -4     (wait until TX ready)
    mem[3] = 32'hFE018EE3;
    // 0x10: sw   x2, 0(x1)      (send 'H' to 0x80)
    mem[4] = 32'h0020A023;
    // 0x14: addi x2, x0, 105    (x2 = 'i')
    mem[5] = 32'h06900113;
    // 0x18: lw   x3, 4(x1)      (x3 = UART_TX_STATUS)
    mem[6] = 32'h0040A183;
    // 0x1C: beq  x3, x0, -4     (wait until TX ready)
    mem[7] = 32'hFE018EE3;
    // 0x20: sw   x2, 0(x1)      (send 'i' to 0x80)
    mem[8] = 32'h0020A023;
    // 0x24: beq  x0, x0, -36    (loop back to 0x00)
    mem[9] = 32'hFC000EE3;

    // If a hex file path was provided, load it
    if (HEX_FILE != "") begin
      $readmemh(HEX_FILE, mem);
    end
  end

  // Word-aligned addressing (PC >> 2)
  wire [29:0] word_addr = addr[31:2];

  always @(*) begin
    if (word_addr < MEM_WORDS) begin
      inst = mem[word_addr];
    end else begin
      inst = 32'h00000013; // Default NOP for out-of-range
    end
  end

endmodule
