`timescale 1ns/1ps
//=============================================================================
// File   : rv_layered_tb.sv
// Author : Auto-generated
// Date   : 2026-09-18
// Desc   : Top-level module for the layered RISC-V testbench.
//
//          Responsibilities:
//            - Clock generation and DUT instantiation via rv_if
//            - Backdoor helpers (read_reg, read_dmem, load_hex) that use
//              hierarchical paths into the DUT – kept here because virtual
//              interfaces cannot carry hierarchical references.
//            - Main test flow: build env → start env → load hex → wait for
//              program_done → drain check transactions → report results.
//            - Watchdog timer (80 ms sim time) to prevent hangs.
//=============================================================================

module rv_layered_tb;

    import rv_layered_pkg::*;

    //=========================================================================
    // Simulation Parameters (fast clock for simulation)
    //=========================================================================

    localparam SIM_CLK_FREQ  = 200_000;   // 200 kHz
    localparam SIM_BAUD_RATE = 10_000;    // 10 kBaud
    localparam CLK_HALF      = 2500;      // Half-period → 5000 ns period


    //=========================================================================
    // Clock Generation
    //=========================================================================

    reg clk = 0;
    always #CLK_HALF clk = ~clk;


    //=========================================================================
    // Interface
    //=========================================================================

    rv_if #(
        .CLK_FREQ  (SIM_CLK_FREQ),
        .BAUD_RATE (SIM_BAUD_RATE)
    ) rvif (.clk(clk));


    //=========================================================================
    // DUT Instantiation
    //=========================================================================

    risc_v #(
        .CLK_FREQ  (SIM_CLK_FREQ),
        .BAUD_RATE (SIM_BAUD_RATE),
        .HEX_FILE  ("")                  // Hex loaded dynamically by Driver via vif
    ) DUT (
        .clk           (clk),
        .reset         (rvif.reset),
        .tx            (rvif.tx),
        .rx            (rvif.rx),
        .uart_rx_ready (rvif.uart_rx_ready),
        .uart_rx_data  (rvif.uart_rx_data),
        .pwm_out       (rvif.pwm_out),
        .tach_in       (rvif.tach_in),
        .pwm_stall_irq (rvif.pwm_stall_irq),
        .spi_sclk      (rvif.spi_sclk),
        .spi_mosi      (rvif.spi_mosi),
        .spi_miso      (rvif.spi_miso),
        .spi_cs        (rvif.spi_cs),
        .result_src    (rvif.result_src),
        .memwrite      (rvif.memwrite),
        .alu_src       (rvif.alu_src),
        .regwrite      (rvif.regwrite),
        .pc_src        (rvif.pc_src),
        .imm_src       (rvif.imm_src),
        .pc            (rvif.pc),
        .inst          (rvif.inst),
        .alu_result    (rvif.alu_result),
        .wd            (rvif.wd),
        .rd            (rvif.rd)
    );


    //=========================================================================
    // Environment & Main Test Flow
    //=========================================================================

    rv_environment env;
    string         test_name;

    initial begin : main_test
        $display("");
        $display("==================================================");
        $display("  RISC-V LAYERED TESTBENCH");
        $display("==================================================");

        // Get test name from plusarg (default: all - runs all 5 tests continuously)
        if (!$value$plusargs("TEST=%s", test_name))
            test_name = "all";
        $display("[TB] Running test: %s", test_name);

        // Build environment
        env = new(rvif);
        env.build(test_name);

        // Run isolated verification environment
        env.run();

        // Print final verification summary
        env.report();
        $stop;
    end


    //=========================================================================
    // Watchdog Timer – prevent infinite simulation (350ms total for all 5 tests)
    //=========================================================================

    initial begin : watchdog
        #350_000_000;
        $display("");
        $display("[TB] *** WATCHDOG TIMEOUT at %0t ***", $time);
        env.report();
        $stop;
    end

endmodule
