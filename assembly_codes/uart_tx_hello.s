# ============================================================
#  uart_tx_hello.s  –  MMIO UART String Transmitter Test
#
#  Polls UART_TX_STATUS (0x84) bit 0 and transmits the string
#  "Hello, RISC-V!\n" over the UART TX serial pin.
# ============================================================
.text
.globl main
main:
    addi x1, x0, 128        # x1 = 0x80 (UART base)

    # Send 'H' (72 / 0x48)
    addi x2, x0, 72
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'e' (101 / 0x65)
    addi x2, x0, 101
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'l' (108 / 0x6C)
    addi x2, x0, 108
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'l' (108 / 0x6C)
    addi x2, x0, 108
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'o' (111 / 0x6F)
    addi x2, x0, 111
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send ',' (44 / 0x2C)
    addi x2, x0, 44
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send ' ' (32 / 0x20)
    addi x2, x0, 32
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'R' (82 / 0x52)
    addi x2, x0, 82
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'I' (73 / 0x49)
    addi x2, x0, 73
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'S' (83 / 0x53)
    addi x2, x0, 83
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'C' (67 / 0x43)
    addi x2, x0, 67
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send '-' (45 / 0x2D)
    addi x2, x0, 45
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send 'V' (86 / 0x56)
    addi x2, x0, 86
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send '!' (33 / 0x21)
    addi x2, x0, 33
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

    # Send '\n' (10 / 0x0A)
    addi x2, x0, 10
    lw   x3, 4(x1)
    beq  x3, x0, -4
    sw   x2, 0(x1)

end_loop:
    beq  x0, x0, 0          # infinite loop
