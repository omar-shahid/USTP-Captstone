# ============================================================
#  spi_temp_test.s  -  SPI Master, Temp Sensor & PWM MMIO Test
# ============================================================
.text
.globl main
main:
    addi  x10, x0, 128
    addi  x11, x0, 192
    addi  x12, x0, 256
    addi  x1, x0, 4
    sw    x1, 16(x12)
    addi  x2, x0, 1
    sw    x2, 0(x12)
    addi  x7, x0, 1
    sw    x7, 0(x11)
    addi  x8, x0, 80
    sw    x8, 4(x11)
    lw    x9, 4(x11)
    bne   x8, x9, fail
    addi  x3, x0, 3
    sw    x3, 0(x12)
poll_spi:
    lw    x4, 12(x12)
    andi  x4, x4, 1
    bne   x4, x0, poll_spi
    lw    x5, 8(x12)
    addi  x6, x0, 25
    bne   x5, x6, fail
    sw    x5, 0(x0)
    addi  x14, x0, 1
    sw    x14, 4(x0)
    addi  x15, x0, 83
poll_tx_0:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_0
    sw    x15, 0(x10)
    addi  x15, x0, 80
poll_tx_1:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_1
    sw    x15, 0(x10)
    addi  x15, x0, 73
poll_tx_2:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_2
    sw    x15, 0(x10)
    addi  x15, x0, 32
poll_tx_3:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_3
    sw    x15, 0(x10)
    addi  x15, x0, 84
poll_tx_4:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_4
    sw    x15, 0(x10)
    addi  x15, x0, 69
poll_tx_5:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_5
    sw    x15, 0(x10)
    addi  x15, x0, 77
poll_tx_6:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_6
    sw    x15, 0(x10)
    addi  x15, x0, 80
poll_tx_7:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_7
    sw    x15, 0(x10)
    addi  x15, x0, 32
poll_tx_8:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_8
    sw    x15, 0(x10)
    addi  x15, x0, 50
poll_tx_9:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_9
    sw    x15, 0(x10)
    addi  x15, x0, 53
poll_tx_10:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_10
    sw    x15, 0(x10)
    addi  x15, x0, 67
poll_tx_11:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_11
    sw    x15, 0(x10)
    addi  x15, x0, 32
poll_tx_12:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_12
    sw    x15, 0(x10)
    addi  x15, x0, 79
poll_tx_13:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_13
    sw    x15, 0(x10)
    addi  x15, x0, 75
poll_tx_14:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_14
    sw    x15, 0(x10)
    addi  x15, x0, 10
poll_tx_15:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_15
    sw    x15, 0(x10)
end_pass:
    beq   x0, x0, end_pass
fail:
    addi  x14, x0, 99
    sw    x14, 4(x0)
fail_loop:
    beq   x0, x0, fail_loop
