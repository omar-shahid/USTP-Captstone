# ============================================================
#  cpu_arithmetic_logic.s  –  ALU & Immediate Verification
#
#  Tests R-type (ADD, SUB, AND, OR, SLT, SLL, SRL, SRA) and
#  I-type (ADDI) arithmetic, logic, and shift instructions.
# ============================================================
.text
.globl main
main:
    # 1. ADDI tests
    addi x1, x0, 10         # x1 = 10 (0x0A)
    addi x2, x0, 20         # x2 = 20 (0x14)
    addi x3, x0, -5         # x3 = -5 (0xFFFFFFFB)

    # 2. ADD & SUB
    add  x4, x1, x2         # x4 = 10 + 20 = 30 (0x1E)
    sub  x5, x2, x1         # x5 = 20 - 10 = 10 (0x0A)
    add  x6, x4, x3         # x6 = 30 + (-5) = 25 (0x19)

    # 3. Bitwise AND & OR
    addi x7, x0, 15         # x7 = 0x0F
    addi x8, x0, 7          # x8 = 0x07
    and  x9, x7, x8         # x9 = 0x0F & 0x07 = 0x07
    or   x10, x7, x8        # x10 = 0x0F | 0x07 = 0x0F

    # 4. Set Less Than (SLT)
    slt  x11, x3, x1        # x11 = (-5 < 10) = 1 (true)
    slt  x12, x1, x3        # x12 = (10 < -5) = 0 (false)

    # 5. Shift operations (SLL, SRL, SRA)
    addi x13, x0, 1         # x13 = 1
    addi x14, x0, 4         # x14 = 4 (shift amount)
    sll  x15, x13, x14      # x15 = 1 << 4 = 16 (0x10)
    srl  x16, x15, x14      # x16 = 16 >> 4 = 1 (0x01)
    sra  x17, x3, x13       # x17 = (-5) >> 1 = -3 (0xFFFFFFFD)

    # 6. Store computed results to Data Memory
    sw   x4,  0(x0)         # mem[0x00] = 30
    sw   x6,  4(x0)         # mem[0x04] = 25
    sw   x9,  8(x0)         # mem[0x08] = 7
    sw   x10, 12(x0)        # mem[0x0C] = 15
    sw   x15, 16(x0)        # mem[0x10] = 16
    sw   x17, 20(x0)        # mem[0x14] = -3

end_loop:
    beq  x0, x0, 0          # Infinite loop
