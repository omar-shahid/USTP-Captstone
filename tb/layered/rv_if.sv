`timescale 1ns/1ps
//=============================================================================
// File   : rv_if.sv
// Author : Auto-generated
// Date   : 2026-09-18
// Desc   : Interface that bundles all signals for the risc_v DUT.
//          Provides clocking blocks and modports for driver / monitor access.
//=============================================================================

interface rv_if #(
    parameter int CLK_FREQ  = 200_000,
    parameter int BAUD_RATE = 10_000
)(
    input logic clk
);

    // Timing constants derived from BAUD_RATE
    localparam int BIT_PERIOD = (1_000_000_000 / BAUD_RATE); // 100,000 ns for 10 kHz

    //=========================================================================
    // Test Tracking & Synchronization (for waveform sectionalization)
    //=========================================================================
    string       current_test = "INIT";
    event        test_completed;

    //=========================================================================
    // Backdoor Loading Helper (invoked directly by Driver via vif)
    //=========================================================================
    task automatic load_hex(string hex_file);
        int k;
        for (k = 0; k < 512; k++)
            rv_layered_tb.DUT.IM.mem[k] = 32'h0000_0013; // NOP

        $readmemh(hex_file, rv_layered_tb.DUT.IM.mem);

        // Directly populate the ROM macro storage arrays
        for (k = 0; k < 512; k++) begin
            rv_layered_tb.DUT.IM.rom_inst_lo.mem[k] = rv_layered_tb.DUT.IM.mem[k][15:0];
            rv_layered_tb.DUT.IM.rom_inst_hi.mem[k] = rv_layered_tb.DUT.IM.mem[k][31:16];
        end

        // Clear data RAM for clean inter-test isolation
        for (k = 0; k < 128; k++) begin
            rv_layered_tb.DUT.DATA_MEMORY.ram_data_lo.mem[k] = 16'h0000;
            rv_layered_tb.DUT.DATA_MEMORY.ram_data_hi.mem[k] = 16'h0000;
        end

        $display("[IF] [%0t] Backdoor loaded program: %s (ROM macros & RAM initialized)", $time, hex_file);
    endtask

    //=========================================================================
    // DUT-facing signals
    //=========================================================================

    // ----- Core control -----
    logic        reset;

    // ----- UART -----
    logic        tx;                // DUT output – serial transmit
    logic        rx;                // DUT input  – serial receive
    logic        uart_rx_ready;     // DUT output – byte received flag
    logic [7:0]  uart_rx_data;      // DUT output – received byte

    // ----- PWM / Fan -----
    logic        pwm_out;           // DUT output – PWM drive
    logic        tach_in;           // DUT input  – tachometer feedback (stub)
    logic        pwm_stall_irq;     // DUT output – stall interrupt

    // ----- SPI -----
    logic        spi_sclk;          // DUT output – SPI clock
    logic        spi_mosi;          // DUT output – master-out-slave-in
    logic        spi_miso;          // DUT input  – master-in-slave-out (stub)
    logic        spi_cs;            // DUT output – chip select

    // ----- Datapath observation -----
    logic        result_src;
    logic        memwrite;
    logic        alu_src;
    logic        regwrite;
    logic        pc_src;
    logic [1:0]  imm_src;
    logic [31:0] pc;
    logic [31:0] inst;
    logic [31:0] alu_result;
    logic [31:0] wd;                // Write data
    logic [31:0] rd;                // Read data


    //=========================================================================
    // Clocking Blocks
    //=========================================================================

    // Driver clocking block – drives stimulus into the DUT
    clocking drv_cb @(posedge clk);
        output reset;
        output rx;
    endclocking

    // Monitor clocking block – samples DUT outputs
    clocking mon_cb @(posedge clk);
        input pc;
        input inst;
        input alu_result;
        input wd;
        input rd;
        input memwrite;
        input regwrite;
        input tx;
        input uart_rx_ready;
        input uart_rx_data;
        input pwm_out;
        input pwm_stall_irq;
        input spi_sclk;
        input spi_mosi;
        input spi_cs;
        input result_src;
        input alu_src;
        input pc_src;
        input imm_src;
    endclocking


    //=========================================================================
    // Modports
    //=========================================================================

    // For the driver component
    modport drv_mp (clocking drv_cb);

    // For the monitor / checker component
    modport mon_mp (clocking mon_cb);

endinterface
