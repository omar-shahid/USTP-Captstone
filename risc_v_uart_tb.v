// ============================================================
//  risc_v_uart_tb.v  --  Simulation Testbench for RISC-V + UART
//
//  Uses small CLK_FREQ / BAUD_RATE parameters so the baud period
//  is only 20 system clock cycles, making simulation fast.
//
//  The testbench:
//    1. Drives clk and reset
//    2. Holds rx = 1 (idle -- no incoming data)
//    3. Monitors the tx line and decodes UART frames automatically
//    4. Prints each received character to the simulator console
//
//  Expected output (repeating):
//    [UART RX] char = H (0x48)
//    [UART RX] char = i (0x69)
// ============================================================
`timescale 1ns/1ps

module risc_v_uart_tb;

// -- Simulation parameters ------------------------------------
// Use tiny CLK_FREQ/BAUD_RATE so simulation runs in microseconds.
// CLKS_PER_BIT = SIM_CLK_FREQ / SIM_BAUD = 20
localparam SIM_CLK_FREQ  = 200_000;
localparam SIM_BAUD_RATE = 10_000;

// Half-period for 200 kHz clock = 2500 ns
localparam CLK_HALF = 2500;

// -- DUT signals ----------------------------------------------
reg  clk, reset, rx;
wire tx;
wire result_src, memwrite, alu_src, regwrite, pc_src;
wire [1:0]  imm_src;
wire [31:0] pc, inst, alu_result, wd, rd;

// -- Instantiate DUT ------------------------------------------
risc_v #(
    .CLK_FREQ  (SIM_CLK_FREQ),
    .BAUD_RATE (SIM_BAUD_RATE)
) DUT (
    .clk        (clk),
    .reset      (reset),
    .tx         (tx),
    .rx         (rx),
    .result_src (result_src),
    .memwrite   (memwrite),
    .alu_src    (alu_src),
    .regwrite   (regwrite),
    .pc_src     (pc_src),
    .imm_src    (imm_src),
    .pc         (pc),
    .inst       (inst),
    .alu_result (alu_result),
    .wd         (wd),
    .rd         (rd)
);

// -- Clock generation -----------------------------------------
initial clk = 0;
always  #CLK_HALF clk = ~clk;

// -- Reset sequence -------------------------------------------
initial begin
    rx    = 1'b1;
    reset = 1'b1;
    repeat (10) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;
    $display("[TB] Reset released at t=%0t ns", $time);
end

// -- UART RX decoder ------------------------------------------
// Watches the tx line, decodes 8N1 frames, prints each byte.
localparam BIT_PERIOD = (1_000_000_000 / SIM_BAUD_RATE);

integer char_count;
reg [7:0] rx_byte;
integer   bit_i;

initial begin
    char_count = 0;
    @(negedge reset);

    forever begin
        // Wait for start bit (falling edge on tx)
        @(negedge tx);

        // Sample at centre of start bit
        #(BIT_PERIOD / 2);

        // Sample 8 data bits LSB first
        rx_byte = 8'h00;
        for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
            #BIT_PERIOD;
            rx_byte = {tx, rx_byte[7:1]};
        end

        // Wait for stop bit
        #BIT_PERIOD;
        if (tx !== 1'b1)
            $display("[TB] WARNING: missing stop bit at t=%0t", $time);

        char_count = char_count + 1;
        $display("[UART RX] char #%0d = %s (0x%02X)  t=%0t ns",
                 char_count, rx_byte, rx_byte, $time);

        // Stop after 6 characters (HiHiHi) to keep log manageable
        if (char_count >= 6) begin
            $display("[TB] Received %0d characters -- simulation done.", char_count);
            $finish;
        end
    end
end

// -- Timeout watchdog -----------------------------------------
initial begin
    #500_000_000;
    $display("[TB] TIMEOUT -- no activity on tx");
    $finish;
end

endmodule
