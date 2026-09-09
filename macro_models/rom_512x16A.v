// ============================================================
//  rom_512x16A.v — Behavioral Simulation Model for Artisan TSMC 0.18um ROM
//
//  Macro:      rom_512x16A (512 words x 16 bits = 8 Kbit)
//  Technology: TSMC 0.18um CL018G
//  Foundry:    Artisan Components, Inc.
//
//  Pins:
//    CLK — Clock
//    CEN — Chip Enable (active low: 0 = enable, 1 = disable)
//    A   — Address [8:0] (512 words)
//    Q   — Data output [15:0]
// ============================================================
`timescale 1ns/1ps

module rom_512x16A (
    input             CLK,
    input             CEN,
    input      [8:0]  A,
    output     [15:0] Q
);

  // 512 x 16-bit storage array
  reg [15:0] mem [0:511];

  integer i;
  initial begin
    for (i = 0; i < 512; i = i + 1) begin
      mem[i] = 16'h0000;
    end
  end

  // Output: when enabled, drive data combinationally for single-cycle datapath
  assign Q = (!CEN) ? mem[A] : 16'h0000;

endmodule
