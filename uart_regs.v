// ============================================================
//  uart_regs.v  –  UART Memory-Mapped Register Block
//
//  Memory Map (byte addresses, relative to system bus):
//
//    0x80  UART_TX_DATA   (W)  – write byte here to transmit
//    0x84  UART_TX_STATUS (R)  – bit[0] = tx_ready (1 = idle, OK to send)
//    0x88  UART_RX_DATA   (R)  – last received byte
//    0x8C  UART_RX_STATUS (R)  – bit[0] = rx_ready (1 = new byte waiting)
//                                 clears automatically on next RX byte latch
//
//  Parameters:
//    CLK_FREQ  – system clock fed to this module (Hz)
//    BAUD_RATE – baud rate for TX and RX
// ============================================================
module uart_regs #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input             clk,     // system (fast) clock for baud generation
    input             reset,
    // CPU bus
    input      [31:0] addr,
    input      [31:0] wd,
    input             memwrite,
    output reg [31:0] rd,
    // UART pins
    output            tx,
    input             rx
);

// ── Internal UART TX signals ──────────────────────────────────
wire      tx_busy;
reg       tx_start;
reg [7:0] tx_byte;

// ── Internal UART RX signals ──────────────────────────────────
wire [7:0] rx_data_wire;
wire       rx_ready_wire;
reg  [7:0] rx_buf;
reg        rx_ready_flag;

// ── Instantiate TX ────────────────────────────────────────────
uart_tx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) U_TX (
    .clk      (clk),
    .reset    (reset),
    .tx_start (tx_start),
    .tx_data  (tx_byte),
    .tx       (tx),
    .tx_busy  (tx_busy)
);

// ── Instantiate RX ────────────────────────────────────────────
uart_rx #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) U_RX (
    .clk      (clk),
    .reset    (reset),
    .rx       (rx),
    .rx_data  (rx_data_wire),
    .rx_ready (rx_ready_wire)
);

// ── Latch received byte + status ──────────────────────────────
always @(posedge clk or posedge reset) begin
    if (reset) begin
        rx_buf        <= 8'h00;
        rx_ready_flag <= 1'b0;
    end else if (rx_ready_wire) begin
        rx_buf        <= rx_data_wire;
        rx_ready_flag <= 1'b1;
    end
end

// ── TX write: generate one-cycle tx_start on write to 0x80 ───
reg prev_write_80;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        tx_start      <= 1'b0;
        tx_byte       <= 8'h00;
        prev_write_80 <= 1'b0;
    end else begin
        tx_start      <= 1'b0;     // default: de-asserted
        prev_write_80 <= (memwrite && (addr == 32'h80));

        // Rising-edge detection: first cycle memwrite hits 0x80
        if (memwrite && (addr == 32'h80) && !prev_write_80) begin
            tx_byte  <= wd[7:0];
            tx_start <= 1'b1;
        end
    end
end

// ── Read logic ────────────────────────────────────────────────
always @(*) begin
    case (addr)
        32'h80:  rd = {24'h0, tx_byte};          // TX_DATA  (last byte written)
        32'h84:  rd = {31'h0, ~tx_busy};          // TX_STATUS: 1 = ready
        32'h88:  rd = {24'h0, rx_buf};            // RX_DATA
        32'h8C:  rd = {31'h0, rx_ready_flag};     // RX_STATUS: 1 = byte waiting
        default: rd = 32'h00000000;
    endcase
end

endmodule
