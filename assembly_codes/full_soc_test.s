# ============================================================
#  full_soc_test.s  –  Comprehensive RV32I Processor + MMIO Test
#
#  Performs ALU computation (15+25=40), stores to RAM, reads back,
#  validates correctness, and transmits "OK\n" over UART TX.
# ============================================================
.text
.globl main
main:
    # 1. ALU Compute
    addi x1, x0, 15         # 0x00: x1 = 15
    addi x2, x0, 25         # 0x04: x2 = 25
    add  x3, x1, x2         # 0x08: x3 = 40

    # 2. Data memory RAM test
    sw   x3, 0(x0)          # 0x0C: mem[0x00] = 40
    lw   x4, 0(x0)          # 0x10: x4 = mem[0x00] = 40

    # 3. Validation
    addi x5, x0, 40         # 0x14: x5 = 40
    bne  x4, x5, 60         # 0x18: if (x4 != 40) goto fail_soc (0x54)

    # 4. Transmit 'O', 'K', '\n' via UART
    addi x10, x0, 128       # 0x1C: x10 = 0x80 (UART base)

    # 'O' (79 / 0x4F)
    addi x11, x0, 79        # 0x20: addi x11, x0, 79
    lw   x12, 4(x10)        # 0x24: lw x12, 4(x10)
    beq  x12, x0, -4        # 0x28: beq x12, x0, -4
    sw   x11, 0(x10)        # 0x2C: sw x11, 0(x10)

    # 'K' (75 / 0x4B)
    addi x11, x0, 75        # 0x30: addi x11, x0, 75
    lw   x12, 4(x10)        # 0x34: lw x12, 4(x10)
    beq  x12, x0, -4        # 0x38: beq x12, x0, -4
    sw   x11, 0(x10)        # 0x3C: sw x11, 0(x10)

    # '\n' (10 / 0x0A)
    addi x11, x0, 10        # 0x40: addi x11, x0, 10
    lw   x12, 4(x10)        # 0x44: lw x12, 4(x10)
    beq  x12, x0, -4        # 0x48: beq x12, x0, -4
    sw   x11, 0(x10)        # 0x4C: sw x11, 0(x10)

end_pass:
    beq  x0, x0, 0          # 0x50: PASS loop

fail_soc:
    addi x10, x0, 128       # 0x54: x10 = 0x80
    addi x11, x0, 70        # 0x58: 'F' (70 / 0x46)
    lw   x12, 4(x10)        # 0x5C: lw x12, 4(x10)
    beq  x12, x0, -4        # 0x60: beq x12, x0, -4
    sw   x11, 0(x10)        # 0x64: sw x11, 0(x10)
fail_loop:
    beq  x0, x0, 0          # 0x68: FAIL loop
