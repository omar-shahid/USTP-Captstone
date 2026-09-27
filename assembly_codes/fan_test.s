# ============================================================
#  fan_test.s  -  Virtual Fan & PWM Tachometer MMIO Test
#
#  RV32I Assembly Program for Layered Verification
#
#  Specification:
#    1. Configure PWM Controller:
#       - PWM_CTRL (0xC0) = 5 (bit 0 = EN, bit 2 = TACH_EN)
#       - PWM_DUTY (0xC4) = 80 (80% duty cycle => 4800 RPM)
#
#    2. Tachometer Period Verification @ 80% Duty:
#       - Virtual fan ramps to 4800 RPM.
#       - At 200 kHz CLK and 4800 RPM with 2 pulses/rev:
#         tach_period = (60 * 200000) / (4800 * 2) = 1250 cycles.
#       - Software polls PWM_TACH_PERIOD (0xCC) until period == 1250.
#       - Stores 1250 to mem[0x00].
#
#    3. Speed Throttling to 40% Duty:
#       - PWM_DUTY (0xC4) = 40 (40% duty cycle => 2400 RPM)
#       - At 2400 RPM, tach_period = 2500 cycles.
#       - Software polls PWM_TACH_PERIOD until period == 2500.
#       - Stores 2500 to mem[0x04].
#
#    4. Pass Flag & Telemetry:
#       - Stores 1 to mem[0x08] (pass flag).
#       - Transmits "FAN TACH OK\n" over UART TX (0x80).
# ============================================================

.text
.globl main
main:
    addi  x10, x0, 128       # x10 = 0x80 (UART Base Address)
    addi  x11, x0, 192       # x11 = 0xC0 (PWM Base Address)

    # 1. Enable PWM and Tachometer
    addi  x1,  x0, 5         # x1  = 5 (EN=1, TACH_EN=1)
    sw    x1,  0(x11)        # PWM_CTRL (0xC0) = 5

    # 2. Set Duty to 80%
    addi  x2,  x0, 80        # x2  = 80
    sw    x2,  4(x11)        # PWM_DUTY (0xC4) = 80

    # 3. Wait for Fan to reach 4800 RPM (Period = 1250)
    addi  x6,  x0, 1250      # x6  = 1250
poll_tach_80:
    lw    x3,  12(x11)       # x3  = PWM_TACH_PERIOD (0xCC)
    bne   x3,  x6,  poll_tach_80

    # Store 1250 to mem[0x00]
    sw    x3,  0(x0)

    # 4. Set Duty to 40% (Throttling)
    addi  x4,  x0, 40        # x4  = 40
    sw    x4,  4(x11)        # PWM_DUTY (0xC4) = 40

    # 5. Wait for Fan to adjust to 2400 RPM (Period = 2500)
    add   x7,  x6,  x6       # x7  = 1250 + 1250 = 2500
poll_tach_40:
    lw    x5,  12(x11)       # x5  = PWM_TACH_PERIOD (0xCC)
    bne   x5,  x7,  poll_tach_40

    # Store 2500 to mem[0x04]
    sw    x5,  4(x0)

    # 6. Store Pass Flag = 1 to mem[0x08]
    addi  x14, x0, 1         # x14 = 1 (Pass flag)
    sw    x14, 8(x0)

    # 7. Transmit "FAN TACH OK\n" over UART TX
    # 'F' (70)
    addi  x15, x0, 70
poll_tx_0:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_0
    sw    x15, 0(x10)

    # 'A' (65)
    addi  x15, x0, 65
poll_tx_1:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_1
    sw    x15, 0(x10)

    # 'N' (78)
    addi  x15, x0, 78
poll_tx_2:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_2
    sw    x15, 0(x10)

    # ' ' (32)
    addi  x15, x0, 32
poll_tx_3:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_3
    sw    x15, 0(x10)

    # 'T' (84)
    addi  x15, x0, 84
poll_tx_4:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_4
    sw    x15, 0(x10)

    # 'A' (65)
    addi  x15, x0, 65
poll_tx_5:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_5
    sw    x15, 0(x10)

    # 'C' (67)
    addi  x15, x0, 67
poll_tx_6:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_6
    sw    x15, 0(x10)

    # 'H' (72)
    addi  x15, x0, 72
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

    # 'O' (79)
    addi  x15, x0, 79
poll_tx_9:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_9
    sw    x15, 0(x10)

    # 'K' (75)
    addi  x15, x0, 75
poll_tx_10:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_10
    sw    x15, 0(x10)

    # '\n' (10)
    addi  x15, x0, 10
poll_tx_11:
    lw    x16, 4(x10)
    andi  x16, x16, 1
    beq   x16, x0, poll_tx_11
    sw    x15, 0(x10)

end_pass:
    beq   x0,  x0,  end_pass

fail:
    addi  x14, x0, 99
    sw    x14, 8(x0)
fail_loop:
    beq   x0,  x0,  fail_loop
