// ============================================================
//  uart_rx.v  –  UART Receiver (8N1, mid-bit sampling)
//
//  Parameters:
//    CLK_FREQ  – system clock frequency in Hz (default 50 MHz)
//    BAUD_RATE – baud rate to match the transmitter (default 9600)
//
//  Interface:
//    rx        – serial input line (idle-high)
//    rx_data   – received byte (valid when rx_ready pulses high)
//    rx_ready  – 1-cycle pulse when a valid byte has been captured
// ============================================================
module uart_rx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9600
) (
    input            clk,
    input            reset,
    input            rx,
    output reg [7:0] rx_data,
    output reg       rx_ready
);

  localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
  localparam CLKS_PER_HALF = CLKS_PER_BIT / 2;

  // FSM states
  localparam IDLE = 2'd0;
  localparam START = 2'd1;
  localparam DATA = 2'd2;
  localparam STOP = 2'd3;

  reg [ 1:0] state;
  reg [31:0] clk_count;
  reg [ 2:0] bit_idx;
  reg [ 7:0] shift_reg;

  // Simple 2-FF synchroniser for the rx input
  reg rx_s1, rx_sync;
  always @(posedge clk) begin
    rx_s1   <= rx;
    rx_sync <= rx_s1;
  end

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state     <= IDLE;
      clk_count <= 0;
      bit_idx   <= 0;
      shift_reg <= 0;
      rx_data   <= 0;
      rx_ready  <= 0;
    end else begin
      rx_ready <= 1'b0;  // default: cleared every cycle

      case (state)

        // ── IDLE: wait for falling edge (start bit) ───────────
        IDLE: begin
          clk_count <= 0;
          bit_idx   <= 0;
          if (rx_sync == 1'b0)  // start bit detected
            state <= START;
        end

        // ── START: wait to middle of start bit, verify ────────
        START: begin
          if (clk_count >= CLKS_PER_HALF - 1) begin
            if (rx_sync == 1'b0) begin  // still low – genuine start
              clk_count <= 0;
              state     <= DATA;
            end else begin  // glitch – abort
              state <= IDLE;
            end
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        // ── DATA: sample each bit at its centre ───────────────
        DATA: begin
          if (clk_count >= CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            // shift in LSB first
            shift_reg <= {rx_sync, shift_reg[7:1]};
            if (bit_idx == 3'd7) state <= STOP;
            else bit_idx <= bit_idx + 1;
          end else begin
            clk_count <= clk_count + 1;
          end
        end

        // ── STOP: verify stop bit, latch data ─────────────────
        STOP: begin
          if (clk_count >= CLKS_PER_BIT - 1) begin
            if (rx_sync == 1'b1) begin  // valid stop bit
              rx_data  <= shift_reg;
              rx_ready <= 1'b1;
            end
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
