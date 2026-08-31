// ============================================================
//  uart_edge_tb.v -- Comprehensive Self-Checking UART Edge Case Testbench
//
//  Tests:
//    1. UART TX & RX boundary patterns (0x00, 0xFF, 0x55, 0xAA, walking 1s)
//    2. Back-to-back continuous transmission
//    3. Start bit glitch rejection (sub-baud noise pulse)
//    4. Stop bit violation rejection (framing error)
//    5. Reset behavior (asynchronous reset mid-transmission recovery)
//    6. Memory-mapped register block (0x80 TX_DATA, 0x84 TX_STATUS,
//       0x88 RX_DATA, 0x8C RX_STATUS, unmapped register reads,
//       and RX ready clear on read).
// ============================================================
`timescale 1ns/1ps

module uart_edge_tb;

    integer pass_count  = 0;
    integer fail_count  = 0;
    integer total_tests = 0;

    localparam CLK_FREQ   = 10_000_000; // 10 MHz
    localparam BAUD_RATE  = 1_000_000;  // 1 MBaud -> 10 clocks per bit
    localparam CLKS_PER_BIT  = 10;
    localparam CLKS_PER_HALF = 5;
    localparam CLK_PERIOD_NS = 100;     // 100ns period (10 MHz)
    localparam BIT_PERIOD_NS = CLKS_PER_BIT * CLK_PERIOD_NS; // 1000ns

    reg clk;
    reg reset;

    // Helper checking tasks
    task check_byte(input string name, input [7:0] actual, input [7:0] expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: 0x%02X ('%c')", $time, name, actual, (actual >= 32 && actual < 127) ? actual : 8'h2E);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = 0x%02X, Actual = 0x%02X", $time, name, expected, actual);
        end
    endtask

    task check_val32(input string name, input [31:0] actual, input [31:0] expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: 0x%08X", $time, name, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = 0x%08X, Actual = 0x%08X", $time, name, expected, actual);
        end
    endtask

    task check_bit(input string name, input actual, input expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: %b", $time, name, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = %b, Actual = %b", $time, name, expected, actual);
        end
    endtask

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // Watchdog
    initial begin
        #5_000_000;
        $display("[ERROR] [%0t] Simulation watchdog timeout reached!", $time);
        $finish;
    end

    // ── Direct TX & RX Instances ──────────────────────────────
    reg        tx_start;
    reg  [7:0] tx_data_in;
    wire       tx_serial;
    wire       tx_busy;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) U_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data_in),
        .tx(tx_serial),
        .tx_busy(tx_busy)
    );

    reg        rx_serial_stim;
    wire [7:0] rx_data_out;
    wire       rx_ready_out;

    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) U_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx_serial_stim),
        .rx_data(rx_data_out),
        .rx_ready(rx_ready_out)
    );

    // ── UART MMIO Register Block Instance ─────────────────────
    reg  [31:0] mmio_addr, mmio_wd;
    reg         mmio_memwrite;
    wire [31:0] mmio_rd;
    wire        mmio_tx;
    reg         mmio_rx;
    wire        mmio_rx_ready;
    wire [7:0]  mmio_rx_data;

    uart_regs #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) U_REGS (
        .clk(clk),
        .reset(reset),
        .addr(mmio_addr),
        .wd(mmio_wd),
        .memwrite(mmio_memwrite),
        .rd(mmio_rd),
        .tx(mmio_tx),
        .rx(mmio_rx),
        .rx_ready(mmio_rx_ready),
        .rx_data(mmio_rx_data)
    );

    // ── Task: Send Serial Frame into RX ───────────────────────
    task send_rx_frame(input [7:0] byte_val, input send_valid_stop);
        integer b;
        begin
            // Start bit
            @(posedge clk);
            rx_serial_stim = 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);

            // 8 Data bits LSB first
            for (b = 0; b < 8; b = b + 1) begin
                rx_serial_stim = byte_val[b];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            // Stop bit (1 if valid, 0 if framing error)
            rx_serial_stim = send_valid_stop ? 1'b1 : 1'b0;
            repeat (CLKS_PER_BIT) @(posedge clk);
            rx_serial_stim = 1'b1;
        end
    endtask

    // ── Task: Capture TX Serial Output ────────────────────────
    task capture_tx_frame(output [7:0] captured);
        integer b;
        begin
            // Wait for start bit falling edge
            @(negedge tx_serial);
            // Mid-start bit
            repeat (CLKS_PER_HALF) @(posedge clk);
            if (tx_serial !== 1'b0)
                $display("[FAIL] TX Start bit is not 0");

            // Sample 8 data bits
            for (b = 0; b < 8; b = b + 1) begin
                repeat (CLKS_PER_BIT) @(posedge clk);
                captured[b] = tx_serial;
            end

            // Stop bit
            repeat (CLKS_PER_BIT) @(posedge clk);
            if (tx_serial !== 1'b1)
                $display("[FAIL] TX Stop bit is not 1");
        end
    endtask

    // ── Main Test Sequencer ───────────────────────────────────
    reg [7:0] cap_val;
    reg [7:0] test_patterns [0:7];
    integer i;

    initial begin
        test_patterns[0] = 8'h00;
        test_patterns[1] = 8'hFF;
        test_patterns[2] = 8'h55;
        test_patterns[3] = 8'hAA;
        test_patterns[4] = 8'h01;
        test_patterns[5] = 8'h80;
        test_patterns[6] = 8'hA5;
        test_patterns[7] = 8'h5A;

        $display("\n==================================================");
        $display("STARTING COMPREHENSIVE UART EDGE & MMIO TESTBENCH");
        $display("==================================================\n");

        // Initialization
        reset = 1;
        tx_start = 0;
        tx_data_in = 8'h00;
        rx_serial_stim = 1'b1;
        mmio_addr = 0;
        mmio_wd = 0;
        mmio_memwrite = 0;
        mmio_rx = 1'b1;

        repeat (5) @(posedge clk);
        reset = 0;
        repeat (2) @(posedge clk);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 1: Reset Behavior & Initial Conditions
        // ════════════════════════════════════════════════════════
        $display("[INFO] [%0t] --- Test Group 1: Reset Behavior ---", $time);
        check_bit("TX idle-high post-reset", tx_serial, 1'b1);
        check_bit("TX not busy post-reset", tx_busy, 1'b0);
        check_bit("RX ready low post-reset", rx_ready_out, 1'b0);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 2: TX Extrema & Walking Bit Patterns
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 2: TX Boundary & Bit Patterns ---", $time);
        for (i = 0; i < 8; i = i + 1) begin
            @(posedge clk);
            tx_data_in = test_patterns[i];
            tx_start   = 1'b1;
            @(posedge clk);
            tx_start   = 1'b0;

            capture_tx_frame(cap_val);
            check_byte($sformatf("TX Pattern [%0d] (0x%02X)", i, test_patterns[i]), cap_val, test_patterns[i]);
            @(negedge tx_busy);
        end

        // ════════════════════════════════════════════════════════
        // TEST GROUP 3: RX Extrema, Glitch Rejection & Stop Violation
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 3: RX Boundary & Fault Injections ---", $time);

        // Normal RX frame 0xA5
        fork
            send_rx_frame(8'hA5, 1);
            begin
                @(posedge rx_ready_out);
                check_byte("RX normal frame 0xA5", rx_data_out, 8'hA5);
            end
        join

        // Normal RX frame 0x5A
        fork
            send_rx_frame(8'h5A, 1);
            begin
                @(posedge rx_ready_out);
                check_byte("RX normal frame 0x5A", rx_data_out, 8'h5A);
            end
        join

        // Glitch injection on RX: falling edge lasting only 2 clock cycles (< CLKS_PER_HALF = 5)
        $display("[INFO] [%0t] Injecting RX Start Bit Glitch (2 cycles)...", $time);
        @(posedge clk);
        rx_serial_stim = 1'b0;
        repeat (2) @(posedge clk);
        rx_serial_stim = 1'b1; // Glitch ends
        repeat (CLKS_PER_BIT * 2) @(posedge clk);
        check_bit("RX ignored start bit glitch", rx_ready_out, 1'b0);

        // Framing error: send byte 0x33 with Stop bit = 0
        $display("[INFO] [%0t] Injecting Stop Bit Violation (Framing Error)...", $time);
        send_rx_frame(8'h33, 0); // Invalid stop bit
        repeat (CLKS_PER_BIT) @(posedge clk);
        check_bit("RX rejected frame with invalid stop bit", rx_ready_out, 1'b0);

        // Recovery: send valid frame 0xCC immediately after error
        fork
            send_rx_frame(8'hCC, 1);
            begin
                @(posedge rx_ready_out);
                check_byte("RX recovered after framing error (0xCC)", rx_data_out, 8'hCC);
            end
        join

        // ════════════════════════════════════════════════════════
        // TEST GROUP 4: Reset Mid-Transmission
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 4: Reset Mid-Transmission ---", $time);
        @(posedge clk);
        tx_data_in = 8'h55;
        tx_start   = 1'b1;
        @(posedge clk);
        tx_start   = 1'b0;
        repeat (CLKS_PER_BIT * 3) @(posedge clk); // Middle of transmitting data bit 2
        check_bit("TX actively busy before mid-abort reset", tx_busy, 1'b1);

        // Assert reset mid-transmission
        reset = 1;
        repeat (3) @(posedge clk);
        check_bit("TX immediately idle-high during reset", tx_serial, 1'b1);
        check_bit("TX not busy during reset", tx_busy, 1'b0);
        reset = 0;
        repeat (5) @(posedge clk);

        // Verify transmitter works cleanly post-abort
        fork
            begin
                @(posedge clk);
                tx_data_in = 8'h99;
                tx_start   = 1'b1;
                @(posedge clk);
                tx_start   = 1'b0;
            end
            begin
                capture_tx_frame(cap_val);
                check_byte("TX normal operation after abort (0x99)", cap_val, 8'h99);
            end
        join
        @(negedge tx_busy);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 5: MMIO Register Block Functionality
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 5: UART MMIO Registers ---", $time);

        // Check TX_STATUS initially ready (0x84 bit 0 == 1)
        mmio_addr = 32'h84; mmio_memwrite = 0; #1;
        check_val32("MMIO Read 0x84 (TX_STATUS ready)", mmio_rd, 32'h0000_0001);

        // Write byte 0x7E to 0x80 (TX_DATA)
        @(negedge clk);
        mmio_addr = 32'h80; mmio_wd = 32'h0000_007E; mmio_memwrite = 1;
        @(posedge clk); // Cycle 1: uart_regs detects write and asserts tx_start <= 1
        @(posedge clk); // Cycle 2: uart_tx latches tx_start, enters START state (busy = 1)
        @(negedge clk);
        mmio_memwrite = 0;
        #1;
        check_val32("MMIO Read 0x80 (TX_DATA readback)", mmio_rd, 32'h0000_007E);

        // Check TX_STATUS is now busy (0x84 bit 0 == 0)
        mmio_addr = 32'h84; #1;
        check_val32("MMIO Read 0x84 (TX_STATUS busy while transmitting)", mmio_rd, 32'h0000_0000);

        // Wait for MMIO TX completion
        repeat (CLKS_PER_BIT * 11) @(posedge clk);
        mmio_addr = 32'h84; #1;
        check_val32("MMIO Read 0x84 (TX_STATUS ready after completion)", mmio_rd, 32'h0000_0001);

        // Inject RX byte into MMIO block (0x4B = 'K')
        $display("[INFO] [%0t] Injecting serial byte 0x4B into MMIO RX...", $time);
        fork
            begin
                integer b;
                mmio_rx = 1'b0; // start bit
                repeat (CLKS_PER_BIT) @(posedge clk);
                for (b = 0; b < 8; b = b + 1) begin
                    mmio_rx = (8'h4B >> b) & 1'b1;
                    repeat (CLKS_PER_BIT) @(posedge clk);
                end
                mmio_rx = 1'b1; // stop bit
                repeat (CLKS_PER_BIT) @(posedge clk);
            end
            begin
                @(posedge mmio_rx_ready);
                check_byte("MMIO Direct rx_data output (0x4B)", mmio_rx_data, 8'h4B);
            end
        join

        // Check RX_STATUS is 1 (byte waiting at 0x8C)
        mmio_addr = 32'h8C; #1;
        check_val32("MMIO Read 0x8C (RX_STATUS byte ready)", mmio_rd, 32'h0000_0001);

        // Read RX_DATA (0x88)
        mmio_addr = 32'h88; mmio_memwrite = 0; #1;
        check_val32("MMIO Read 0x88 (RX_DATA)", mmio_rd, 32'h0000_004B);

        // Trigger read cycle on posedge clk to clear ready flag
        @(posedge clk); #1;
        mmio_addr = 32'h8C; #1;
        check_val32("MMIO Read 0x8C (RX_STATUS cleared after read of 0x88)", mmio_rd, 32'h0000_0000);

        // Unmapped address read (0x90)
        mmio_addr = 32'h90; #1;
        check_val32("MMIO Read unmapped addr 0x90", mmio_rd, 32'h0000_0000);

        // ════════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ════════════════════════════════════════════════════════
        #20;
        $display("\n=================================");
        $display("SIMULATION SUMMARY: UART Core & MMIO");
        $display("Total Tests: %0d", total_tests);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("=================================\n");

        if (fail_count == 0 && total_tests > 0)
            $display("[RESULT] ALL TESTS PASSED");
        else
            $display("[RESULT] SIMULATION FAILED");

        $finish;
    end

endmodule

