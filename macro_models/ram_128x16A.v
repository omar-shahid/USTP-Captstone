// ============================================================
//  ram_128x16A.v — Simulation Model for Artisan TSMC 0.18um RAM
//
//  Macro:      ram_128x16A (128 words x 16 bits = 2 Kbit)
//  Technology: TSMC 0.18um CL018G
//  Foundry:    Artisan Components, Inc.
//
//  Pins:
//    CLK — Clock (write operations)
//    CEN — Chip Enable (active low: 0 = enable, 1 = disable)
//    OEN — Output Enable (active low: 0 = drive Q, 1 = high-Z)
//    WEN — Write Enable (active low: 0 = write, 1 = read)
//    A   — Address [6:0] (128 words)
//    D   — Data input [15:0]
//    Q   — Data output [15:0]
// ============================================================
`timescale 1ns/1ps

module ram_128x16A (
    input             CLK,
    input             CEN,
    input             OEN,
    input             WEN,
    input      [6:0]  A,
    input      [15:0] D,
    output     [15:0] Q
);

  // 128 x 16-bit storage array
  reg [15:0] mem [0:127];

  integer i;
  initial begin
    for (i = 0; i < 128; i = i + 1) begin
      mem[i] = 16'h0000;
    end
  end

  // Synchronous write on rising clock edge
  always @(posedge CLK) begin
    if (!CEN && !WEN) begin
      mem[A] <= D;
    end
  end

  // Output: when CEN and OEN are low, drive data
  assign Q = (!CEN && !OEN) ? mem[A] : 16'hzzzz;

endmodule
