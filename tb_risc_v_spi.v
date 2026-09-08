`timescale 1ns/1ps

module tb_riscv_spi;

    //============================================================
    // CLOCK
    //============================================================
    reg clk;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;       // 100 MHz clock
    end


    //============================================================
    // RESET
    //============================================================
    reg reset;


    //============================================================
    // UART
    //============================================================
    wire tx;
    reg  rx;

    wire       uart_rx_ready;
    wire [7:0] uart_rx_data;


    //============================================================
    // PWM
    //============================================================
    wire pwm_out;
    reg  tach_in;
    wire pwm_stall_irq;


    //============================================================
    // SPI
    //============================================================
    wire spi_sclk;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs;


    //============================================================
    // RISC-V DEBUG SIGNALS
    //============================================================
    wire       result_src;
    wire       memwrite;
    wire       alu_src;
    wire       regwrite;
    wire       pc_src;

    wire [1:0] imm_src;

    wire [31:0] pc;
    wire [31:0] inst;
    wire [31:0] alu_result;
    wire [31:0] wd;
    wire [31:0] rd;


    //============================================================
    // DUT
    //============================================================
    risc_v #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(9600),
        .PWM_FREQ(25_000),
        .STALL_TIMEOUT_MS(500),
        .HEX_FILE("program.hex")
    )
    DUT (
        .clk(clk),
        .reset(reset),

        // UART
        .tx(tx),
        .rx(rx),
        .uart_rx_ready(uart_rx_ready),
        .uart_rx_data(uart_rx_data),

        // PWM
        .pwm_out(pwm_out),
        .tach_in(tach_in),
        .pwm_stall_irq(pwm_stall_irq),

        // SPI
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs(spi_cs),

        // CPU control/debug
        .result_src(result_src),
        .memwrite(memwrite),
        .alu_src(alu_src),
        .regwrite(regwrite),
        .pc_src(pc_src),
        .imm_src(imm_src),

        // CPU datapath/debug
        .pc(pc),
        .inst(inst),
        .alu_result(alu_result),
        .wd(wd),
        .rd(rd)
    );


    //============================================================
    // VIRTUAL SPI TEMPERATURE SENSOR
    // Temperature = 25 Celsius = 0x19
    //============================================================
    virtual_temp_sensor #(
        .TEMPERATURE(8'h19)
    )
    TEMP_SENSOR (
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs(spi_cs),
        .reset(reset),
        .spi_miso(spi_miso)
    );


    //============================================================
    // INITIAL VALUES
    //============================================================
    initial begin
        rx      = 1'b1;
        tach_in = 1'b0;
    end


    //============================================================
    // RESET SEQUENCE
    //============================================================
    initial begin

        reset = 1'b1;

        $display("==============================================");
        $display("       RISC-V SPI TESTBENCH STARTED");
        $display("==============================================");
        $display("Time = %0t : RESET ASSERTED", $time);

        #100;

        reset = 1'b0;

        $display("Time = %0t : RESET RELEASED", $time);
        $display("==============================================");

    end


    //============================================================
    // SPI MONITOR
    //============================================================
    integer spi_bit_count;
    reg [7:0] received_data;


    initial begin
        spi_bit_count = 0;
        received_data = 8'h00;
    end


    // SPI transaction starts when CS goes LOW
    always @(negedge spi_cs) begin

        spi_bit_count = 0;
        received_data = 8'h00;

        $display("");
        $display("==============================================");
        $display("SPI TRANSACTION START");
        $display("Time = %0t", $time);
        $display("==============================================");

    end


    // Receive sensor data on SPI clock
    always @(posedge spi_sclk) begin

        if (!spi_cs) begin

            spi_bit_count = spi_bit_count + 1;

            received_data = {
                received_data[6:0],
                spi_miso
            };

            $display(
                "Time=%0t  SPI BIT=%0d  MOSI=%b  MISO=%b",
                $time,
                spi_bit_count,
                spi_mosi,
                spi_miso
            );

        end

    end


    //============================================================
    // SPI TRANSACTION COMPLETE
    //============================================================
    always @(posedge spi_cs) begin

        if (!reset && spi_bit_count != 0) begin

            $display("");
            $display("==============================================");
            $display("SPI TRANSACTION COMPLETE");
            $display("Time          = %0t", $time);
            $display("Bits Received = %0d", spi_bit_count);
            $display("RX Data       = 0x%02h", received_data);
            $display("Expected      = 0x19");
            $display("==============================================");

            if ((spi_bit_count == 8) &&
                (received_data == 8'h19)) begin

                $display("************* TEST PASSED *************");
                $display("Temperature received = 25 C");

            end
            else begin

                $display("************* TEST FAILED *************");

            end

            $display("==============================================");
            $display("");

        end

    end


    //============================================================
    // CPU WRITE MONITOR
    //============================================================
    always @(posedge clk) begin

        if (!reset) begin

            if (memwrite) begin

                $display(
                    "Time=%0t CPU MEMORY WRITE: ADDR=%h DATA=%h",
                    $time,
                    alu_result,
                    rd
                );

            end

            if (regwrite) begin

                $display(
                    "Time=%0t CPU REGISTER WRITE: DATA=%h",
                    $time,
                    wd
                );

            end

        end

    end


    //============================================================
    // WAVEFORM
    //============================================================
    initial begin

        $dumpfile("riscv_spi.vcd");
        $dumpvars(0, tb_riscv_spi);

    end


    //============================================================
    // SIMULATION TIMEOUT
    //============================================================
    initial begin

        #2_000_000;

        $display("");
        $display("==============================================");
        $display("SIMULATION TIMEOUT");
        $display("==============================================");

        $finish;

    end

endmodule
