module instr_mem (
    input  [31:0] addr,
    output reg [31:0] inst
);

  reg [7:0] mem[63:0];

  initial begin
    // ──────────────────────────────────────────────────────────────
    //  UART "Hi" demo program
    //
    //  Repeatedly transmits the string "Hi" via the MMIO UART.
    //
    //  Register usage:
    //    x1  = UART base address (0x80)
    //    x2  = character to send
    //    x3  = TX status scratch
    //
    //  Memory Map used:
    //    0x80  UART_TX_DATA    (W) – write byte to start TX
    //    0x84  UART_TX_STATUS  (R) – bit0=1 means TX idle (ready)
    //
    //  Assembly:
    //    0x00: addi x1, x0, 128        # x1 = 0x80 (UART base)
    //    0x04: addi x2, x0, 72         # x2 = 'H'  (0x48)
    //  poll_H:
    //    0x08: lw   x3, 4(x1)          # x3 = TX_STATUS (addr 0x84)
    //    0x0C: beq  x3, x0, poll_H     # if not ready (0), wait  [offset=-4]
    //    0x10: sw   x2, 0(x1)          # send 'H' to TX_DATA (addr 0x80)
    //    0x14: addi x2, x0, 105        # x2 = 'i'  (0x69)
    //  poll_i:
    //    0x18: lw   x3, 4(x1)          # x3 = TX_STATUS
    //    0x1C: beq  x3, x0, poll_i     # wait  [offset=-4]
    //    0x20: sw   x2, 0(x1)          # send 'i'
    //    0x24: beq  x0, x0, -36        # loop back to 0x00  [offset=-36]
    // ──────────────────────────────────────────────────────────────

    // 0x00 : addi x1, x0, 128    → 0x08000093
    mem[0]  = 8'h93; mem[1]  = 8'h00; mem[2]  = 8'h00; mem[3]  = 8'h08;

    // 0x04 : addi x2, x0, 72     → 0x04800113
    mem[4]  = 8'h13; mem[5]  = 8'h01; mem[6]  = 8'h80; mem[7]  = 8'h04;

    // 0x08 : lw x3, 4(x1)        → 0x0040A183
    mem[8]  = 8'h83; mem[9]  = 8'hA1; mem[10] = 8'h40; mem[11] = 8'h00;

    // 0x0C : beq x3, x0, -4      → 0xFE018EE3   (target = 0x08)
    mem[12] = 8'hE3; mem[13] = 8'h8E; mem[14] = 8'h01; mem[15] = 8'hFE;

    // 0x10 : sw x2, 0(x1)        → 0x0020A023
    mem[16] = 8'h23; mem[17] = 8'hA0; mem[18] = 8'h20; mem[19] = 8'h00;

    // 0x14 : addi x2, x0, 105    → 0x06900113
    mem[20] = 8'h13; mem[21] = 8'h01; mem[22] = 8'h90; mem[23] = 8'h06;

    // 0x18 : lw x3, 4(x1)        → 0x0040A183
    mem[24] = 8'h83; mem[25] = 8'hA1; mem[26] = 8'h40; mem[27] = 8'h00;

    // 0x1C : beq x3, x0, -4      → 0xFE018EE3   (target = 0x18)
    mem[28] = 8'hE3; mem[29] = 8'h8E; mem[30] = 8'h01; mem[31] = 8'hFE;

    // 0x20 : sw x2, 0(x1)        → 0x0020A023
    mem[32] = 8'h23; mem[33] = 8'hA0; mem[34] = 8'h20; mem[35] = 8'h00;

    // 0x24 : beq x0, x0, -36     → 0xFC000EE3   (target = 0x00)
    mem[36] = 8'hE3; mem[37] = 8'h0E; mem[38] = 8'h00; mem[39] = 8'hFC;
  end

  always @(*) begin
    inst = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
  end

endmodule
