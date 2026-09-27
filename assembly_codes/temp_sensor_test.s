# ============================================================
#  temp_sensor_test.s  -  Virtual Temperature Sensor SPI MMIO Test
#
#  RV32I Assembly Program for Layered Verification
#
#  Specification:
#    1. Configure SPI Master:
#       - SPI_CLKDIV (0x110) = 4
#       - SPI_CTRL   (0x100) = 1 (Enable SPI Master)
#
#    2. First Transfer (Initial Temp = 25 C / 0x19):
#       - Start transfer: SPI_CTRL = 3 (EN=1, START=1)
#       - Poll SPI_STATUS (0x10C) until bit 0 (busy) == 0.
#       - Read SPI_RXDATA (0x108): verifies temperature is 25 C.
#       - Stores 25 to mem[0x00].
#
#    3. Dynamic Sensor Update (Dynamic Temp = 75 C / 0x4B):
#       - Delay loop allows driver to dynamically update sim_temp to 75 C.
#       - Start second transfer: SPI_CTRL = 3
#       - Poll SPI_STATUS until bit 0 == 0.
#       - Read SPI_RXDATA: verifies updated temperature is 75 C.
#       - Stores 75 to mem[0x04].
#
#    4. Pass Flag & Telemetry:
#       - Stores 1 to mem[0x08] (pass flag).
#       - Transmits "TEMP 25C 75C OK\n" over UART TX (0x80).
# ============================================================

.text
.globl main
main:
    addi  x10, x0, 128       # x10 = 0x80  (UART Base Address)
    addi  x12, x0, 256       # x12 = 0x100 (SPI Base Address)

    # 1. Setup SPI Master
    addi  x1,  x0, 4         # SPI_CLKDIV = 4
    sw    x1,  16(x12)
    addi  x2,  x0, 1         # SPI_CTRL = 1 (Enable)
    sw    x2,  0(x12)

    # 2. First SPI Transfer: Read Initial Temperature (25 C)
    addi  x3,  x0, 3         # SPI_CTRL = 3 (EN + START)
    sw    x3,  0(x12)

poll_spi_1:
    lw    x4,  12(x12)       # Read SPI_STATUS (0x10C)
    andi  x4,  x4, 1         # Check busy bit (bit 0)
    bne   x4,  x0,  poll_spi_1

    lw    x5,  8(x12)        # x5 = SPI_RXDATA (0x108)
    addi  x6,  x0, 25        # Expected 25 C
    bne   x5,  x6,  fail

    # Store 25 to mem[0x00]
    sw    x5,  0(x0)

    # 3. Delay loop to allow testbench driver to inject 75 C
    addi  x8,  x0, 5
delay_loop:
    addi  x8,  x8, -1
    bne   x8,  x0,  delay_loop

    # 4. Second SPI Transfer: Read Dynamic Temperature (75 C)
    sw    x3,  0(x12)        # SPI_CTRL = 3 (START)

poll_spi_2:
    lw    x4,  12(x12)       # Read SPI_STATUS
    andi  x4,  x4, 1
    bne   x4,  x0,  poll_spi_2

    lw    x7,  8(x12)        # x7 = SPI_RXDATA
    addi  x9,  x0, 75        # Expected 75 C
    bne   x7,  x9,  fail

    # Store 75 to mem[0x04]
    sw    x7,  4(x0)

    # 5. Store Pass Flag = 1 to mem[0x08]
    addi  x14, x0, 1         # x14 = 1 (Pass flag)
    sw    x14, 8(x0)

    # 6. Transmit "TEMP 25C 75C OK\n" over UART TX
    # 'T' (84)
    addi  x15, x0, 84
poll_tx_0:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_0
    sw    x15, 0(x10)

    # 'E' (69)
    addi  x15, x0, 69
poll_tx_1:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_1
    sw    x15, 0(x10)

    # 'M' (77)
    addi  x15, x0, 77
poll_tx_2:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_2
    sw    x15, 0(x10)

    # 'P' (80)
    addi  x15, x0, 80
poll_tx_3:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_3
    sw    x15, 0(x10)

    # ' ' (32)
    addi  x15, x0, 32
poll_tx_4:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_4
    sw    x15, 0(x10)

    # '2' (50)
    addi  x15, x0, 50
poll_tx_5:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_5
    sw    x15, 0(x10)

    # '5' (53)
    addi  x15, x0, 53
poll_tx_6:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_6
    sw    x15, 0(x10)

    # 'C' (67)
    addi  x15, x0, 67
poll_tx_7:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_7
    sw    x15, 0(x10)

    # ' ' (32)
    addi  x15, x0, 32
poll_tx_8:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_8
    sw    x15, 0(x10)

    # '7' (55)
    addi  x15, x0, 55
poll_tx_9:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_9
    sw    x15, 0(x10)

    # '5' (53)
    addi  x15, x0, 53
poll_tx_10:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_10
    sw    x15, 0(x10)

    # 'C' (67)
    addi  x15, x0, 67
poll_tx_11:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_11
    sw    x15, 0(x10)

    # ' ' (32)
    addi  x15, x0, 32
poll_tx_12:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_12
    sw    x15, 0(x10)

    # 'O' (79)
    addi  x15, x0, 79
poll_tx_13:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_13
    sw    x15, 0(x10)

    # 'K' (75)
    addi  x15, x0, 75
poll_tx_14:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_14
    sw    x15, 0(x10)

    # '\n' (10)
    addi  x15, x0, 10
poll_tx_15:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_15
    sw    x15, 0(x10)

end_pass:
    beq   x0,  x0,  end_pass

fail:
    addi  x14, x0, 99
    sw    x14, 8(x0)
fail_loop:
    beq   x0,  x0,  fail_loop
