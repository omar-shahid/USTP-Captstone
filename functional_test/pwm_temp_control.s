# ============================================================
#  pwm_temp_control.s  -  Thermal PWM Fan Controller & Serial Monitor
#
#  RV32I Assembly Program
#
#  Specification:
#    1. SPI Clock Rate Configuration:
#       - Configure SPI_CLKDIV (0x110) = 100 to slow down spi_sclk
#         to 250 kHz, matching the CPU core clock frequency (clk_d).
#
#    2. Closed-Loop Thermal Regulation (Hysteresis Loop):
#       - Normal Mode: PWM duty cycle = 80%
#       - Over-temperature: If temp >= 75 C, lower PWM duty to 40%
#       - Cooldown Mode:    Hold 40% until temp cools down to <= 50 C
#       - Recovery:         When temp <= 50 C, restore PWM duty to 80%
#
#    3. Serial Monitor Telemetry Logger:
#       - Logs changes in temperature and PWM duty cycle over UART TX.
#       - Output Format: "T=XXC, PWM=YY%\n" (e.g. "T=50C, PWM=80%\n")
#
#  MMIO Register Map:
#    UART Base: 0x080
#      0x80 : UART_TX_DATA   (write byte to transmit)
#      0x84 : UART_TX_STATUS (bit 0 = 1 when TX is idle/ready)
#
#    PWM Base:  0x0C0
#      0xC0 : PWM_CTRL       (bit 0 = EN)
#      0xC4 : PWM_DUTY       (bits [7:0] = duty percent 0..100)
#
#    SPI Base:  0x100
#      0x100: SPI_CTRL       (bit 0 = enable, bit 1 = start transfer)
#      0x108: SPI_RXDATA     (bits [7:0] = temperature from sensor)
#      0x10C: SPI_STATUS     (bit 0 = busy)
#      0x110: SPI_CLKDIV     (clock divider, set to 100 for 250 kHz)
#
#    Data RAM:
#      0x00 : Current temperature reading
#      0x04 : Current PWM duty cycle (80 or 40)
# ============================================================

.text
.globl main
main:
    # --------------------------------------------------------
    # 1. Base Addresses & Constants Setup
    # --------------------------------------------------------
    addi x10, x0, 128       # x10 = 0x80  (UART Base Address)
    addi x11, x0, 192       # x11 = 0xC0  (PWM Base Address)
    addi x12, x0, 256       # x12 = 0x100 (SPI Base Address)
    addi x13, x0, 75        # x13 = 75    (Over-temp Threshold: 75 C)
    addi x14, x0, 51        # x14 = 51    (Recovery Threshold: temp < 51 <=> temp <= 50)
    addi x15, x0, 80        # x15 = 80    (Normal PWM Duty: 80%)
    addi x16, x0, 40        # x16 = 40    (Throttled PWM Duty: 40%)
    addi x1,  x0, 1         # x1  = 1     (Constant 1 / Enable bit)
    addi x2,  x0, 3         # x2  = 3     (SPI Start: bit0=EN, bit1=START)
    addi x3,  x0, 100       # x3  = 100   (SPI_CLKDIV: 50MHz / 200 = 250kHz)
    addi x22, x0, 10        # x22 = 10    (Constant 10 for div & '\n')
    addi x19, x0, 255       # x19 = 255   (last logged temperature tracker)
    addi x23, x0, 255       # x23 = 255   (last logged PWM duty tracker)

    # --------------------------------------------------------
    # 2. Hardware Initialization
    # --------------------------------------------------------
    sw   x3,  16(x12)       # SPI_CLKDIV (0x110) = 100
    addi x4,  x0, 5
    sw   x4,  0(x11)        # PWM_CTRL   (0xC0)  = 5 (Enable PWM & Tachometer)
    sw   x1,  0(x12)        # SPI_CTRL   (0x100) = 1 (Enable SPI Master)

    # Initialize PWM to 80% duty cycle
    add  x17, x0,  x15      # x17 = 80 (Current PWM duty)
    sw   x17, 4(x11)        # PWM_DUTY (0xC4) = 80%
    sw   x17, 4(x0)         # mem[0x04] = 80

main_loop:
    # --------------------------------------------------------
    # 3. SPI Temperature Measurement
    # --------------------------------------------------------
    sw   x2,  0(x12)        # SPI_CTRL = 3 (Start SPI transaction)

poll_spi:
    lw   x7,  12(x12)       # Read SPI_STATUS (0x10C)
    andi x7,  x7, 1         # Isolate bit 0 (busy)
    bne  x7,  x0, poll_spi  # Wait while busy == 1

    lw   x5,  8(x12)        # Read SPI_RXDATA (0x108) = current temperature
    sw   x5,  0(x0)         # mem[0x00] = current temp

    # --------------------------------------------------------
    # 4. Change Detection (Serial Monitor Logging Trigger)
    # --------------------------------------------------------
    bne  x5,  x19, log_monitor      # Temperature changed -> log
    bne  x17, x23, log_monitor      # PWM duty changed    -> log
    beq  x0,  x0,  check_hysteresis # No change -> skip logging

log_monitor:
    add  x19, x0,  x5       # Update last logged temperature
    add  x23, x0,  x17      # Update last logged PWM duty

    # --------------------------------------------------------
    # 5. Convert Temperature (x5) to 2 ASCII Digits (x20, x21)
    # --------------------------------------------------------
    add  x18, x0,  x5
    addi x20, x0,  0
div_temp_loop:
    slt  x6,  x18, x22
    bne  x6,  x0,  div_temp_done
    sub  x18, x18, x22
    addi x20, x20, 1
    beq  x0,  x0,  div_temp_loop
div_temp_done:
    addi x20, x20, 48       # Temp Tens ASCII ('0'..'9')
    addi x21, x18, 48       # Temp Ones ASCII ('0'..'9')

    # --------------------------------------------------------
    # 6. Convert PWM Duty (x17) to 2 ASCII Digits (x24, x25)
    # --------------------------------------------------------
    add  x18, x0,  x17
    addi x24, x0,  0
div_pwm_loop:
    slt  x6,  x18, x22
    bne  x6,  x0,  div_pwm_done
    sub  x18, x18, x22
    addi x24, x24, 1
    beq  x0,  x0,  div_pwm_loop
div_pwm_done:
    addi x24, x24, 48       # PWM Tens ASCII ('8' or '4')
    addi x25, x18, 48       # PWM Ones ASCII ('0')

    # --------------------------------------------------------
    # 7. Read Tachometer & Compute RPM (x30)
    # --------------------------------------------------------
    lw   x29, 12(x11)       # Read PWM_TACH_PERIOD (0xCC) into x29

    # Construct N = 1,500,000,000 (0x59682F00)
    addi x28, x0, 89
    addi x26, x0, 8
    sll  x28, x28, x26      # x28 = 0x5900
    addi x28, x28, 104
    sll  x28, x28, x26      # x28 = 0x596800
    addi x28, x28, 47
    sll  x28, x28, x26      # x28 = 0x59682F00 = 1,500,000,000

    addi x30, x0, 0         # Default RPM = 0
    beq  x29, x0, rpm_calc_done

    # 14-iteration binary division: Q = 1,500,000,000 / period
    addi x26, x0, 14
    srl  x31, x28, x26      # x31 = R = N >> 14
    addi x26, x0, 18
    sll  x28, x28, x26      # x28 = N_shifted = N << 18
    addi x27, x0, 14        # loop counter = 14
    addi x4,  x0, 1         # constant 1

rpm_div_loop:
    sll  x31, x31, x4
    addi x26, x0, 31
    srl  x26, x28, x26
    or   x31, x31, x26
    sll  x28, x28, x4
    sll  x30, x30, x4

    slt  x6,  x31, x29      # R < D ?
    bne  x6,  x0,  rpm_div_next
    sub  x31, x31, x29      # R = R - D
    or   x30, x30, x4       # Q = Q | 1

rpm_div_next:
    addi x27, x27, -1
    bne  x27, x0,  rpm_div_loop

rpm_calc_done:
    # --------------------------------------------------------
    # 8. Convert RPM (x30) to 4 ASCII Digits (x26, x28, x29, x31)
    # --------------------------------------------------------
    add  x18, x0,  x30

    # Thousands Digit (x26)
    addi x26, x0,  0
    addi x27, x0,  1000
rpm_thous_loop:
    slt  x6,  x18, x27
    bne  x6,  x0,  rpm_thous_done
    sub  x18, x18, x27
    addi x26, x26, 1
    beq  x0,  x0,  rpm_thous_loop
rpm_thous_done:
    addi x26, x26, 48       # Thousands ASCII ('0'..'6')

    # Hundreds Digit (x28)
    addi x28, x0,  0
    addi x27, x0,  100
rpm_hund_loop:
    slt  x6,  x18, x27
    bne  x6,  x0,  rpm_hund_done
    sub  x18, x18, x27
    addi x28, x28, 1
    beq  x0,  x0,  rpm_hund_loop
rpm_hund_done:
    addi x28, x28, 48       # Hundreds ASCII ('0'..'9')

    # Tens Digit (x29)
    addi x29, x0,  0
rpm_tens_loop:
    slt  x6,  x18, x22
    bne  x6,  x0,  rpm_tens_done
    sub  x18, x18, x22
    addi x29, x29, 1
    beq  x0,  x0,  rpm_tens_loop
rpm_tens_done:
    addi x29, x29, 48       # Tens ASCII ('0'..'9')

    # Ones Digit (x31)
    addi x31, x18, 48       # Ones ASCII ('0'..'9')

    # --------------------------------------------------------
    # 9. Transmit Serial Monitor Message: "T=XXC, PWM=YY%, RPM=ZZZZ\n"
    # --------------------------------------------------------
    # 1. 'T' (84)
poll_tx_1:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_1
    addi x9,  x0, 84
    sw   x9,  0(x10)

    # 2. '=' (61)
poll_tx_2:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_2
    addi x9,  x0, 61
    sw   x9,  0(x10)

    # 3. Temp Tens Digit (x20)
poll_tx_3:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_3
    sw   x20, 0(x10)

    # 4. Temp Ones Digit (x21)
poll_tx_4:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_4
    sw   x21, 0(x10)

    # 5. 'C' (67)
poll_tx_5:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_5
    addi x9,  x0, 67
    sw   x9,  0(x10)

    # 6. ',' (44)
poll_tx_6:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_6
    addi x9,  x0, 44
    sw   x9,  0(x10)

    # 7. ' ' (32)
poll_tx_7:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_7
    addi x9,  x0, 32
    sw   x9,  0(x10)

    # 8. 'P' (80)
poll_tx_8:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_8
    addi x9,  x0, 80
    sw   x9,  0(x10)

    # 9. 'W' (87)
poll_tx_9:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_9
    addi x9,  x0, 87
    sw   x9,  0(x10)

    # 10. 'M' (77)
poll_tx_10:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_10
    addi x9,  x0, 77
    sw   x9,  0(x10)

    # 11. '=' (61)
poll_tx_11:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_11
    addi x9,  x0, 61
    sw   x9,  0(x10)

    # 12. PWM Tens Digit (x24)
poll_tx_12:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_12
    sw   x24, 0(x10)

    # 13. PWM Ones Digit (x25)
poll_tx_13:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_13
    sw   x25, 0(x10)

    # 14. '%' (37)
poll_tx_14:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_14
    addi x9,  x0, 37
    sw   x9,  0(x10)

    # 15. ',' (44)
poll_tx_15:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_15
    addi x9,  x0, 44
    sw   x9,  0(x10)

    # 16. ' ' (32)
poll_tx_16:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_16
    addi x9,  x0, 32
    sw   x9,  0(x10)

    # 17. 'R' (82)
poll_tx_17:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_17
    addi x9,  x0, 82
    sw   x9,  0(x10)

    # 18. 'P' (80)
poll_tx_18:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_18
    addi x9,  x0, 80
    sw   x9,  0(x10)

    # 19. 'M' (77)
poll_tx_19:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_19
    addi x9,  x0, 77
    sw   x9,  0(x10)

    # 20. '=' (61)
poll_tx_20:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_20
    addi x9,  x0, 61
    sw   x9,  0(x10)

    # 21. RPM Thousands (x26)
poll_tx_21:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_21
    sw   x26, 0(x10)

    # 22. RPM Hundreds (x28)
poll_tx_22:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_22
    sw   x28, 0(x10)

    # 23. RPM Tens (x29)
poll_tx_23:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_23
    sw   x29, 0(x10)

    # 24. RPM Ones (x31)
poll_tx_24:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_24
    sw   x31, 0(x10)

    # 25. '\n' (10)
poll_tx_25:
    lw   x8,  4(x10)
    andi x8,  x8, 1
    beq  x8,  x0, poll_tx_25
    sw   x22, 0(x10)

check_hysteresis:
    # --------------------------------------------------------
    # 8. Thermal Regulation (Hysteresis Loop)
    # --------------------------------------------------------
    beq  x17, x16, check_cooldown   # If current duty == 40%, check cooldown recovery

check_normal:
    # Mode = 80%: Throttling Check
    # slt x6, x5, x13 (temp < 75?)
    #   if temp < 75  => x6 = 1 (safe, remain at 80%)
    #   if temp >= 75 => x6 = 0 (over-temp! throttle to 40%)
    slt  x6,  x5,  x13
    bne  x6,  x0,  main_loop
    # Trigger 40% Throttle
    add  x17, x0,  x16              # x17 = 40
    sw   x17, 4(x11)                # PWM_DUTY (0xC4) = 40%
    sw   x17, 4(x0)                 # mem[0x04] = 40
    beq  x0,  x0,  main_loop        # Return to main_loop (logs new PWM on next cycle)

check_cooldown:
    # Mode = 40%: Recovery Check
    # slt x6, x5, x14 (temp < 51 <=> temp <= 50?)
    #   if temp <= 50 => x6 = 1 (recovery complete! restore to 80%)
    #   if temp > 50  => x6 = 0 (still cooling down, remain at 40%)
    slt  x6,  x5,  x14
    beq  x6,  x0,  main_loop
    # Trigger 80% Recovery
    add  x17, x0,  x15              # x17 = 80
    sw   x17, 4(x11)                # PWM_DUTY (0xC4) = 80%
    sw   x17, 4(x0)                 # mem[0x04] = 80
    beq  x0,  x0,  main_loop        # Return to main_loop (logs new PWM on next cycle)
