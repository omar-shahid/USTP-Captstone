# ============================================================
#  cpu_memory_access.s  –  Data Memory SW & LW Test
#
#  Stores multiple 32-bit words into RAM, loads them back,
#  accumulates the values and stores the sum to verify memory integrity.
# ============================================================
.text
.globl main
main:
    addi x1, x0, 100        # x1 = 100 (0x64)
    addi x2, x0, 200        # x2 = 200 (0xC8)
    addi x3, x0, 300        # x3 = 300 (0x12C)
    addi x4, x0, 400        # x4 = 400 (0x190)

    # Store words to data memory (0x00, 0x04, 0x08, 0x0C)
    sw   x1, 0(x0)          # mem[0x00] = 100
    sw   x2, 4(x0)          # mem[0x04] = 200
    sw   x3, 8(x0)          # mem[0x08] = 300
    sw   x4, 12(x0)         # mem[0x0C] = 400

    # Load words back into new registers
    lw   x5, 0(x0)          # x5 = 100
    lw   x6, 4(x0)          # x6 = 200
    lw   x7, 8(x0)          # x7 = 300
    lw   x8, 12(x0)         # x8 = 400

    # Accumulate loaded values
    add  x9, x5, x6         # x9 = 100 + 200 = 300
    add  x9, x9, x7         # x9 = 300 + 300 = 600
    add  x9, x9, x8         # x9 = 600 + 400 = 1000

    # Store total to 0x10
    sw   x9, 16(x0)         # mem[0x10] = 1000 (0x3E8)

end_loop:
    beq  x0, x0, 0          # infinite loop
