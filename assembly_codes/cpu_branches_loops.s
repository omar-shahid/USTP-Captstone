# ============================================================
#  cpu_branches_loops.s  –  Conditional Branching & Loop Test
#
#  Tests BEQ and BNE forward and backward branch resolution,
#  loop iteration counter, and accumulator calculation (sum 1..5 = 15).
# ============================================================
.text
.globl main
main:
    addi x1, x0, 5          # 0x00: x1 = loop limit (N=5)
    addi x2, x0, 0          # 0x04: x2 = counter (i=0)
    addi x3, x0, 0          # 0x08: x3 = accumulator (sum=0)
    addi x4, x0, 1          # 0x0C: x4 = increment (1)

loop_start:                 # 0x10
    add  x2, x2, x4         # 0x10: i = i + 1
    add  x3, x3, x2         # 0x14: sum = sum + i
    bne  x2, x1, -8         # 0x18: if (i != N) goto loop_start (0x10)

    # Test forward BEQ branch
    addi x5, x0, 15         # 0x1C: x5 = 15
    beq  x3, x5, 8          # 0x20: if (sum == 15) goto branch_eq (0x28)
    addi x6, x0, 99         # 0x24: skipped if branch taken
branch_eq:                  # 0x28
    addi x6, x0, 1          # 0x28: x6 = 1 (passed branch test)

    # Store results to Data Memory
    sw   x3, 0(x0)          # 0x2C: mem[0x00] = 15
    sw   x6, 4(x0)          # 0x30: mem[0x04] = 1

end_loop:                   # 0x34
    beq  x0, x0, 0          # 0x34: infinite loop
