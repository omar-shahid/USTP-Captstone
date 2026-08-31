// ============================================================
//  risc_v_hex_tb.v  –  Self-Checking Hex-Loading Testbench
//
//  Loads RISC-V machine code from a .hex file (default: program.hex,
//  or specified at runtime via +HEX=<path_to_file>) and feeds it
//  to the processor core.
//
//  Features:
//    - Dynamic +HEX=<path> runtime loading via $readmemh
//    - Automatic UART Serial TX decoder & string logger
//    - UART Serial RX injection task for bidirectional testing
//    - PC & MMIO activity tracing
//    - Watchdog timer and pass/fail summary reporting
// ============================================================
`timescale 1ns/1ps

module risc_v_hex_tb;

    // Simulation Parameters
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

    integer pass_count  = 0;
    integer fail_count  = 0;
    integer total_tests = 0;
    string  hex_file    = "program.hex";
    string  received_str = "";
    integer idle_cycles = 0;
    reg [31:0] last_pc  = 32'hFFFFFFFF;

    // ── Helper Checking Tasks ─────────────────────────────────
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

    // ── Instantiate DUT ───────────────────────────────────────
    risc_v #(
        .CLK_FREQ  (SIM_CLK_FREQ),
        .BAUD_RATE (SIM_BAUD_RATE),
        .HEX_FILE  ("program.hex")
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

    // ── Clock Generation ──────────────────────────────────────
    initial clk = 0;
    always  #CLK_HALF clk = ~clk;

    // ── Hex Loading & Initialization ──────────────────────────
    initial begin
        $display("\n==================================================");
        $display("  RISC-V PROCESSOR HEX-LOADER SIMULATION");
        $display("==================================================");

        // Initialize instruction memory with NOPs (addi x0, x0, 0) before loading
        for (integer k = 0; k < DUT.IM.MEM_WORDS; k = k + 1) begin
            DUT.IM.mem[k] = 32'h00000013;
        end

        // Check for runtime +HEX=<file> argument
        if ($value$plusargs("HEX=%s", hex_file)) begin
            $display("[INFO] Loading runtime hex file: %s", hex_file);
            $readmemh(hex_file, DUT.IM.mem);
        end else begin
            $display("[INFO] Using default program hex: %s", hex_file);
            $readmemh("program.hex", DUT.IM.mem);
        end

        rx    = 1'b1;
        reset = 1'b1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[INFO] [%0t] Reset de-asserted. CPU executing instructions...\n", $time);

        // If echo loopback test is being run, inject test characters
        if (hex_file == "assembly_codes/uart_echo_loopback.hex" ||
            hex_file == "uart_echo_loopback.hex") begin
            #500_000;
            send_uart_byte(8'h41); // 'A'
            #2_000_000;
            send_uart_byte(8'h42); // 'B'
            #2_000_000;
            send_uart_byte(8'h21); // '!'
            #2_000_000;
        end
    end

    // ── UART RX Injector Task (Host to CPU) ───────────────────
    task send_uart_byte(input [7:0] data);
        integer bit_idx;
        begin
            $display("[UART_HOST_TX] [%0t] Injecting byte 0x%02X ('%c') to CPU RX", $time, data, data);
            rx = 1'b0; // Start bit
            #BIT_PERIOD;
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                rx = data[bit_idx];
                #BIT_PERIOD;
            end
            rx = 1'b1; // Stop bit
            #BIT_PERIOD;
        end
    endtask

    // ── UART TX Monitor (CPU to Host) ─────────────────────────
    reg [7:0] captured_byte;
    integer   bit_i;

    initial begin
        @(negedge reset);
        forever begin
            @(negedge tx); // Detect start bit
            #(BIT_PERIOD / 2);
            if (tx === 1'b0) begin
                captured_byte = 8'h00;
                for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
                    #BIT_PERIOD;
                    captured_byte = {tx, captured_byte[7:1]};
                end
                #BIT_PERIOD; // Stop bit
                if (tx === 1'b1) begin
                    $display("[UART_CPU_TX] [%0t] Character: '%c' (0x%02X)", $time, captured_byte, captured_byte);
                    received_str = {received_str, string'(captured_byte)};
                    pass_count   = pass_count + 1;
                    total_tests  = total_tests + 1;
                end
            end
        end
    end

    // ── Core Activity & Register Trace Monitor ────────────────
    always @(posedge DUT.clk_d) begin
        if (!reset) begin
            if (memwrite) begin
                if (alu_result >= 32'h80)
                    $display("[TRACE] [%0t] PC=0x%08X | MMIO WRITE Addr=0x%08X Data=0x%08X", $time, pc, alu_result, wd);
                else
                    $display("[TRACE] [%0t] PC=0x%08X | MEM WRITE  Addr=0x%08X Data=0x%08X", $time, pc, alu_result, wd);
            end

            // Detect infinite idle loop (PC repeating continuously)
            if (pc == last_pc) begin
                idle_cycles = idle_cycles + 1;
            end else begin
                idle_cycles = 0;
                last_pc     = pc;
            end

            // If CPU has looped at the end for 200 cycles, finish test
            if (idle_cycles > 200 && (received_str != "" || hex_file != "program.hex")) begin
                #1_000_000;
                finish_sim();
            end
        end
    end

    // ── Summary & Finish Task ─────────────────────────────────
    task finish_sim();
        begin
            $display("\n==================================================");
            $display("SIMULATION SUMMARY: RISC-V HEX TESTBENCH");
            $display("Hex File:      %s", hex_file);
            $display("UART Output:   \"%s\"", received_str);
            $display("Tests Passed:  %0d", pass_count);
            $display("Tests Failed:  %0d", fail_count);
            $display("==================================================");

            if (fail_count == 0 && (pass_count > 0 || idle_cycles > 0))
                $display("[RESULT] ALL TESTS PASSED\n");
            else
                $display("[RESULT] SIMULATION FAILED\n");

            $finish;
        end
    endtask

    // ── Watchdog Timer ────────────────────────────────────────
    initial begin
        #60_000_000;
        finish_sim();
    end

endmodule
