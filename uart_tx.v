// ============================================================
//  uart_tx.v  –  UART Transmitter (8N1)
//
//  Parameters:
//    CLK_FREQ  – system clock frequency in Hz (default 50 MHz)
//    BAUD_RATE – desired baud rate             (default 9600)
//
//  Interface:
//    tx_start  – assert for at least one clk cycle to begin TX
//    tx_data   – byte to send (latched on tx_start while IDLE)
//    tx        – serial output line (idle-high)
//    tx_busy   – high while a frame is being transmitted
// ============================================================
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
)(
    input            clk,
    input            reset,
    input            tx_start,
    input      [7:0] tx_data,
    output reg       tx,
    output           tx_busy
);

localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

// FSM states
localparam IDLE  = 2'd0;
localparam START = 2'd1;
localparam DATA  = 2'd2;
localparam STOP  = 2'd3;

reg [1:0]  state;
reg [31:0] clk_count;
reg [2:0]  bit_idx;
reg [7:0]  shift_reg;

assign tx_busy = (state != IDLE);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state     <= IDLE;
        tx        <= 1'b1;   // idle-high
        clk_count <= 0;
        bit_idx   <= 0;
        shift_reg <= 0;
    end else begin
        case (state)

            // ── IDLE ──────────────────────────────────────────────
            IDLE: begin
                tx <= 1'b1;
                if (tx_start) begin
                    shift_reg <= tx_data;
                    clk_count <= 0;
                    state     <= START;
                end
            end

            // ── START BIT (logic 0) ───────────────────────────────
            START: begin
                tx <= 1'b0;
                if (clk_count >= CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    bit_idx   <= 0;
                    state     <= DATA;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            // ── DATA BITS (LSB first) ─────────────────────────────
            DATA: begin
                tx <= shift_reg[0];
                if (clk_count >= CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    shift_reg <= shift_reg >> 1;
                    if (bit_idx == 3'd7)
                        state <= STOP;
                    else
                        bit_idx <= bit_idx + 1;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            // ── STOP BIT (logic 1) ────────────────────────────────
            STOP: begin
                tx <= 1'b1;
                if (clk_count >= CLKS_PER_BIT - 1) begin
                    clk_count <= 0;
                    state     <= IDLE;
                end else begin
                    clk_count <= clk_count + 1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule
