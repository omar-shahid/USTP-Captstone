// ============================================================
//  risc_v_uart_tb.v  --  Self-Checking Testbench for RISC-V + UART
//
//  Verifies that the RISC-V CPU executes the demo boot program,
//  accesses UART MMIO registers (0x80, 0x84), polls TX readiness,
//  and produces the expected "Hi" character stream on the serial TX pin.
// ============================================================
`timescale 1ns/1ps

module risc_v_uart_tb;

    integer pass_count  = 0;
    integer fail_count  = 0;
    integer total_tests = 0;

    localparam SIM_CLK_FREQ  = 200_000;
    localparam SIM_BAUD_RATE = 10_000;
    localparam CLK_HALF      = 2500; // 200 kHz -> 5000ns period
    localparam BIT_PERIOD    = (1_000_000_000 / SIM_BAUD_RATE); // 100_000 ns

    reg  clk, reset, rx;
    wire tx;
    wire uart_rx_ready;
    wire [7:0] uart_rx_data;
    wire result_src, memwrite, alu_src, regwrite, pc_src;
    wire [1:0]  imm_src;
    wire [31:0] pc, inst, alu_result, wd, rd;

    // -- Helper checking task -------------------------------------
    task check_char(input string name, input [7:0] actual, input [7:0] expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: '%c' (0x%02X)", $time, name, actual, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = 0x%02X ('%c'), Actual = 0x%02X ('%c')",
                     $time, name, expected, expected, actual, actual);
        end
    endtask

    task check_cond(input string name, input condition);
        total_tests = total_tests + 1;
        if (condition) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s", $time, name);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s", $time, name);
        end
    endtask

    // -- Instantiate DUT ------------------------------------------
    risc_v #(
        .CLK_FREQ  (SIM_CLK_FREQ),
        .BAUD_RATE (SIM_BAUD_RATE)
    ) DUT (
        .clk          (clk),
        .reset        (reset),
        .tx           (tx),
        .rx           (rx),
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

    // -- Clock generation -----------------------------------------
    initial clk = 0;
    always  #CLK_HALF clk = ~clk;

    // -- Reset sequence -------------------------------------------
    initial begin
        $display("\n==================================================");
        $display("STARTING RISC-V + UART SERIAL TRANSMISSION TEST");
        $display("==================================================\n");

        rx    = 1'b1;
        reset = 1'b1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[INFO] [%0t] Reset released, CPU booting...", $time);
    end

    // -- Expected character buffer --------------------------------
    reg [7:0] expected_chars [0:5];
    initial begin
        expected_chars[0] = "H"; // 0x48
        expected_chars[1] = "i"; // 0x69
        expected_chars[2] = "H"; // 0x48
        expected_chars[3] = "i"; // 0x69
        expected_chars[4] = "H"; // 0x48
        expected_chars[5] = "i"; // 0x69
    end

    // -- UART RX Decoder & Self-Checking --------------------------
    integer char_count;
    reg [7:0] rx_byte;
    integer   bit_i;

    initial begin
        char_count = 0;
        @(negedge reset);

        forever begin
            // Wait for start bit (falling edge on tx)
            @(negedge tx);

            // Sample at center of start bit
            #(BIT_PERIOD / 2);
            check_cond("TX Start bit is 0", (tx === 1'b0));

            // Sample 8 data bits LSB first
            rx_byte = 8'h00;
            for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                #BIT_PERIOD;
                rx_byte = {tx, rx_byte[7:1]};
            end

            // Wait for stop bit
            #BIT_PERIOD;
            check_cond("TX Stop bit is 1", (tx === 1'b1));

            if (char_count < 6) begin
                check_char($sformatf("UART Transmitted Character #%0d", char_count + 1),
                           rx_byte, expected_chars[char_count]);
            end

            char_count = char_count + 1;

            if (char_count >= 6) begin
                #20000;
                $display("\n=================================");
                $display("SIMULATION SUMMARY: RISC-V UART TB");
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
        end
    end

    // -- Watchdog -------------------------------------------------
    initial begin
        #100_000_000;
        $display("[ERROR] [%0t] Simulation watchdog timeout reached!", $time);
        $finish;
    end

endmodule

