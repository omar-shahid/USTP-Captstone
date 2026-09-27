// ============================================================
//  data_mem.v — Data Memory using 2x Artisan ram_128x16A Macros
//
//  Structure:
//    - Two 128x16 RAM macros arranged in parallel:
//        ram_data_lo: provides rd[15:0], receives wd[15:0]
//        ram_data_hi: provides rd[31:16], receives wd[31:16]
//    - Capacity: 128 words x 32 bits = 512 Bytes
//    - Addressing: Word-aligned (addr[8:2] -> A[6:0])
//
//  Technology: TSMC 0.18um (CL018G) Hard Macro ram_128x16A
// ============================================================
`timescale 1ns/1ps

module data_mem (
    output [31:0] rd,
    input         clk,
    input         memwrite,
    input  [31:0] addr,
    input  [31:0] wd
);

  // Word-aligned 7-bit address (128 words)
  wire [6:0] word_addr = addr[8:2];

  // Chip enable: active low
  wire cen = (addr[31:9] == 23'b0) ? 1'b0 : 1'b1;

  // Output enable: active low (always driven)
  wire oen = 1'b0;

  // Write enable: active low (0 = write, 1 = read)
  wire wen = ~memwrite;

  wire [15:0] q_lo;
  wire [15:0] q_hi;

  // ── Lower halfword RAM macro (bits [15:0]) ─────────────────
  ram_128x16A ram_data_lo (
      .CLK(clk),
      .CEN(cen),
      .OEN(oen),
      .WEN(wen),
      .A  (word_addr),
      .D  (wd[15:0]),
      .Q  (q_lo)
  );

  // ── Upper halfword RAM macro (bits [31:16]) ────────────────
  ram_128x16A ram_data_hi (
      .CLK(clk),
      .CEN(cen),
      .OEN(oen),
      .WEN(wen),
      .A  (word_addr),
      .D  (wd[31:16]),
      .Q  (q_hi)
  );

  assign rd = {q_hi, q_lo};

  // ── Simulation Initialization ──────────────────────────────
  // synthesis translate_off
  integer i;
  reg [31:0] b0, b1, b2, b3;
  initial begin
    for (i = 0; i < 128; i = i + 1) begin
      b0 = 4*i;
      b1 = 4*i + 1;
      b2 = 4*i + 2;
      b3 = 4*i + 3;
      ram_data_lo.mem[i] = { b1[7:0], b0[7:0] };
      ram_data_hi.mem[i] = { b3[7:0], b2[7:0] };
    end
  end
  // synthesis translate_on

endmodule
