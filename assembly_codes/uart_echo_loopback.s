# ============================================================
#  uart_echo_loopback.s  –  MMIO UART RX Polling & Echo Loop
#
#  Continuously polls UART_RX_STATUS (0x8C). When a byte arrives,
#  reads from UART_RX_DATA (0x88), polls UART_TX_STATUS (0x84),
#  and writes the byte out to UART_TX_DATA (0x80).
# ============================================================
.text
.globl main
main:
    addi x1, x0, 128        # 0x00: x1 = 0x80 (UART base)

poll_rx:                    # 0x04
    lw   x2, 12(x1)         # 0x04: read UART_RX_STATUS (0x8C)
    beq  x2, x0, -4         # 0x08: if (rx_ready == 0) wait

    lw   x3, 8(x1)          # 0x0C: read UART_RX_DATA (0x88)

poll_tx:                    # 0x10
    lw   x4, 4(x1)          # 0x10: read UART_TX_STATUS (0x84)
    beq  x4, x0, -4         # 0x14: if (tx_ready == 0) wait

    sw   x3, 0(x1)          # 0x18: send byte to UART_TX_DATA (0x80)
    beq  x0, x0, -24        # 0x1C: jump back to poll_rx (0x04)
