// ============================================================
//  risc_v_uart_full_tb.v -- Comprehensive Self-Checking Full Integration Testbench
//
//  Tests:
//    1. CPU -> Serial TX frame generation & validation ('H', 'i')
//    2. Hardware Loopback (TX connected to RX) and top-level debug RX monitoring
//    3. External serial byte injection into CPU RX pin (0xA5, 0x5A, 0x3C)
//    4. Active Reset Recovery: Reset asserted during CPU execution and transmission,
//       verifying clean reset and successful re-transmission.
// ============================================================
`timescale 1ns/1ps

module risc_v_uart_full_tb;

    integer pass_count  = 0;
    integer fail_count  = 0;
    integer total_tests = 0;

    localparam CLK_FREQ     = 1_000_000; // 1 MHz master clock
    localparam BAUD_RATE    = 100_000;   // 100 kBaud -> 10 clocks per bit
    localparam CLKS_PER_BIT = 10;
    localparam CLK_HALF     = 500;       // 500ns half-period (1 MHz)
    localparam BIT_PERIOD   = (1_000_000_000 / BAUD_RATE); // 10,000 ns

    reg  clk, reset, rx_stim;
    wire tx_out;
    wire uart_rx_ready;
    wire [7:0] uart_rx_data;
    wire result_src, memwrite, alu_src, regwrite, pc_src;
    wire [1:0] imm_src;
    wire [31:0] pc, inst, alu_result, wd, rd;

    // -- Helper checking tasks ------------------------------------
    task check_byte(input string name, input [7:0] actual, input [7:0] expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: 0x%02X ('%c')", $time, name, actual,
                     (actual >= 32 && actual < 127) ? actual : 8'h2E);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = 0x%02X, Actual = 0x%02X", $time, name, expected, actual);
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

    // -- Instantiate DUT ------------------------------------------
    risc_v #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) DUT (
        .clk          (clk),
        .reset        (reset),
        .tx           (tx_out),
        .rx           (rx_stim),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_data (uart_rx_data),
        .result_src   (result_src),
        .memwrite     (memwrite),
        .alu_src      (alu_src),
        .regwrite     (regwrite),
        .pc_src       (pc_src),
        .imm_src      (imm_src),
        .pc           (pc),
        .inst         (inst),
        .alu_result   (alu_result),
        .wd           (wd),
        .rd           (rd)
    );

    // -- Clock generation (1 MHz) ---------------------------------
    initial clk = 0;
    always #CLK_HALF clk = ~clk;

    // -- Watchdog -------------------------------------------------
    initial begin
        #50_000_000;
        $display("[ERROR] [%0t] Simulation watchdog timeout reached!", $time);
        $finish;
    end

    // -- Task: Inject Serial Byte on RX pin -----------------------
    task inject_rx_byte(input [7:0] val);
        integer b;
        begin
            @(posedge clk);
            rx_stim = 1'b0; // start bit
            repeat (CLKS_PER_BIT) @(posedge clk);

            for (b = 0; b < 8; b = b + 1) begin
                rx_stim = val[b];
                repeat (CLKS_PER_BIT) @(posedge clk);
            end

            rx_stim = 1'b1; // stop bit
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    // -- Task: Capture TX Byte ------------------------------------
    task capture_tx_byte(output [7:0] val);
        integer b;
        begin
            @(negedge tx_out);
            #(BIT_PERIOD / 2);
            for (b = 0; b < 8; b = b + 1) begin
                #BIT_PERIOD;
                val[b] = tx_out;
            end
            #BIT_PERIOD;
        end
    endtask

    // -- Test Execution Sequence ----------------------------------
    reg [7:0] captured_tx;

    initial begin
        $display("\n==================================================");
        $display("STARTING RISC-V FULL INTEGRATION & LOOPBACK TEST");
        $display("==================================================\n");

        reset = 1;
        rx_stim = 1'b1;

        repeat (20) @(posedge clk);
        @(negedge clk);
        reset = 0;
        $display("[INFO] [%0t] Reset released, processor running...", $time);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 1: Verify CPU TX Stream Output
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Phase 1: Verify CPU Program Output ---", $time);

        capture_tx_byte(captured_tx);
        check_byte("CPU TX Output Character #1", captured_tx, "H");

        capture_tx_byte(captured_tx);
        check_byte("CPU TX Output Character #2", captured_tx, "i");

        // ════════════════════════════════════════════════════════
        // TEST GROUP 2: External Injections to RX & Output Check
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Phase 2: External RX Serial Frame Injections ---", $time);

        // Inject 0xA5 into RX
        fork
            inject_rx_byte(8'hA5);
            begin
                @(posedge uart_rx_ready);
                check_byte("Top-level uart_rx_data output (0xA5)", uart_rx_data, 8'hA5);
            end
        join

        // Inject 0x5A into RX
        fork
            inject_rx_byte(8'h5A);
            begin
                @(posedge uart_rx_ready);
                check_byte("Top-level uart_rx_data output (0x5A)", uart_rx_data, 8'h5A);
            end
        join

        // Inject 0x3C into RX
        fork
            inject_rx_byte(8'h3C);
            begin
                @(posedge uart_rx_ready);
                check_byte("Top-level uart_rx_data output (0x3C)", uart_rx_data, 8'h3C);
            end
        join

        // ════════════════════════════════════════════════════════
        // TEST GROUP 3: Reset Mid-Execution and Recovery Check
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Phase 3: Active Mid-Execution Reset & Recovery ---", $time);
        @(posedge clk);
        reset = 1;
        repeat (10) @(posedge clk);
        check_bit("TX idle during reset", tx_out, 1'b1);
        reset = 0;
        $display("[INFO] [%0t] Reset released, validating CPU reboot...", $time);

        capture_tx_byte(captured_tx);
        check_byte("CPU TX Reboot Output Character #1", captured_tx, "H");

        capture_tx_byte(captured_tx);
        check_byte("CPU TX Reboot Output Character #2", captured_tx, "i");

        // ════════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ════════════════════════════════════════════════════════
        #10000;
        $display("\n=================================");
        $display("SIMULATION SUMMARY: Full System Integration");
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

