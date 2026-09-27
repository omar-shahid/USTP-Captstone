# ============================================================
#  uart_echo_loopback.s  -  MMIO UART RX Polling & Echo Loop
# ============================================================
.globl main
.text
main:
    # UART MMIO base address is 0x80 (128 in decimal)
    addi x1, x0, 128        # x1 = 0x80

poll_rx:
    # Read UART_RX_STATUS at 0x80 + 12 = 0x8C
    lw   x2, 12(x1)
    # Loop back if bit 0 is 0 (no byte waiting)
    beq  x2, x0, poll_rx

    # Read byte from UART_RX_DATA at 0x80 + 8 = 0x88
    lw   x3, 8(x1)

poll_tx:
    # Read UART_TX_STATUS at 0x80 + 4 = 0x84
    lw   x4, 4(x1)
    # Loop back if bit 0 is 0 (transmitter busy)
    beq  x4, x0, poll_tx

    # Send received byte out to UART_TX_DATA at 0x80 + 0 = 0x80
    sw   x3, 0(x1)

    # Jump back to poll_rx to wait for the next incoming byte
    beq  x0, x0, poll_rx