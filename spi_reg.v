`timescale 1ns/1ps

// ============================================================
// SPI REGISTER / SPI MASTER
//
// SPI MODE 0
//
// CPOL = 0
// CPHA = 0
//
// Register Map:
//
// 0x100 : SPI_CTRL
//         bit 0 = enable
//         bit 1 = start
//
// 0x104 : SPI_TXDATA
//
// 0x108 : SPI_RXDATA
//
// 0x10C : SPI_STATUS
//         bit 0 = busy
//         bit 1 = done
//
// 0x110 : SPI_CLKDIV
//
// ============================================================

module spi_regs (
    input             clk,
    input             reset,

    // --------------------------------------------------------
    // CPU MMIO interface
    // --------------------------------------------------------
    input      [31:0] addr,
    input      [31:0] wd,
    input             memwrite,

    output reg [31:0] rd,

    // --------------------------------------------------------
    // SPI interface
    // --------------------------------------------------------
    output reg        spi_sclk,
    output reg        spi_mosi,
    input             spi_miso,
    output reg        spi_cs
);

    // ========================================================
    // SPI REGISTERS
    // ========================================================

    reg        spi_enable;

    reg [7:0]  tx_data;
    reg [7:0]  rx_data;

    reg        busy;
    reg        done;

    reg [15:0] clk_div;
    reg [15:0] clk_count;

    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;

    reg [2:0]  bit_count;

    // Used to detect a new START command
    reg        prev_start_write;

    wire start_write;

    // ========================================================
    // START DETECTION
    //
    // Start when CPU writes:
    //
    // address = 0x100
    // wd[1]   = 1
    //
    // A rising event is generated only once.
    // ========================================================

    assign start_write =
        memwrite &&
        (addr == 32'h00000100) &&
        wd[1] &&
        !prev_start_write;

    // ========================================================
    // CONTROL REGISTER
    // ========================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            spi_enable      <= 1'b0;
            prev_start_write <= 1'b0;

        end
        else begin

            prev_start_write <=
                memwrite &&
                (addr == 32'h00000100) &&
                wd[1];

            if (memwrite &&
                (addr == 32'h00000100)) begin

                spi_enable <= wd[0];

            end

        end

    end

    // ========================================================
    // TX DATA REGISTER
    // ========================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            tx_data <= 8'h00;

        end
        else if (memwrite &&
                 (addr == 32'h00000104)) begin

            tx_data <= wd[7:0];

        end

    end

    // ========================================================
    // CLOCK DIVIDER REGISTER
    // ========================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            clk_div <= 16'd4;

        end
        else if (memwrite &&
                 (addr == 32'h00000110)) begin

            if (wd[15:0] == 16'd0)
                clk_div <= 16'd1;
            else
                clk_div <= wd[15:0];

        end

    end

    // ========================================================
    // SPI MASTER
    //
    // MODE 0:
    //
    // SCLK idle = 0
    //
    // Data is changed on falling edge.
    //
    // Data is sampled on rising edge.
    //
    // MSB first.
    // ========================================================

    always @(posedge clk or posedge reset) begin

        if (reset) begin

            spi_sclk <= 1'b0;
            spi_mosi <= 1'b0;
            spi_cs   <= 1'b1;

            busy <= 1'b0;
            done <= 1'b0;

            clk_count <= 16'd0;

            tx_shift <= 8'h00;
            rx_shift <= 8'h00;

            rx_data <= 8'h00;

            bit_count <= 3'd0;

        end
        else begin

            // ------------------------------------------------
            // DONE is a one-clock pulse
            // ------------------------------------------------

            if (done)
                done <= 1'b0;

            // ------------------------------------------------
            // START SPI TRANSACTION
            // ------------------------------------------------

            if (!busy &&
                spi_enable &&
                start_write) begin

                busy <= 1'b1;
                done <= 1'b0;

                // CS active low
                spi_cs <= 1'b0;

                // Mode 0 idle clock
                spi_sclk <= 1'b0;

                clk_count <= 16'd0;

                // Load transmit byte
                tx_shift <= tx_data;

                // Clear receive shift register
                rx_shift <= 8'h00;

                // First bit = MSB
                spi_mosi <= tx_data[7];

                // Eight bits
                bit_count <= 3'd0;

            end

            // ------------------------------------------------
            // SPI ACTIVE
            // ------------------------------------------------

            else if (busy) begin

                // ------------------------------------------------
                // Clock divider
                // ------------------------------------------------

                if (clk_count >= (clk_div - 16'd1)) begin

                    clk_count <= 16'd0;

                    // ====================================================
                    // LOW -> HIGH
                    //
                    // SPI Mode 0 samples MISO here.
                    // ====================================================

                    if (spi_sclk == 1'b0) begin

                        spi_sclk <= 1'b1;

                        // Sample MISO
                        rx_shift <=
                            {rx_shift[6:0], spi_miso};

                    end

                    // ====================================================
                    // HIGH -> LOW
                    //
                    // Prepare next transmitted bit.
                    // ====================================================

                    else begin

                        spi_sclk <= 1'b0;

                        // ------------------------------------------------
                        // Last bit completed
                        // ------------------------------------------------

                        if (bit_count == 3'd7) begin

                            busy <= 1'b0;
                            done <= 1'b1;

                            // CS inactive
                            spi_cs <= 1'b1;

                            spi_mosi <= 1'b0;

                            // IMPORTANT:
                            //
                            // Include the current spi_miso bit because
                            // rx_shift has not yet been updated when using
                            // a non-blocking assignment.
                            //
                            rx_data <=
                                {rx_shift[6:0], spi_miso};

                        end

                        // ------------------------------------------------
                        // More bits remaining
                        // ------------------------------------------------

                        else begin

                            bit_count <=
                                bit_count + 3'd1;

                            // Shift TX data left
                            tx_shift <=
                                {tx_shift[6:0], 1'b0};

                            // Next MSB
                            spi_mosi <=
                                tx_shift[6];

                        end

                    end

                end

                else begin

                    clk_count <=
                        clk_count + 16'd1;

                end

            end

        end

    end

    // ========================================================
    // MMIO READ
    // ========================================================

    always @(*) begin

        case (addr)

            // ------------------------------------------------
            // SPI_CTRL
            // ------------------------------------------------

            32'h00000100:
                rd = {
                    30'd0,
                    1'b0,
                    spi_enable
                };

            // ------------------------------------------------
            // SPI_TXDATA
            // ------------------------------------------------

            32'h00000104:
                rd = {
                    24'd0,
                    tx_data
                };

            // ------------------------------------------------
            // SPI_RXDATA
            // ------------------------------------------------

            32'h00000108:
                rd = {
                    24'd0,
                    rx_data
                };

            // ------------------------------------------------
            // SPI_STATUS
            //
            // bit 0 = busy
            // bit 1 = done
            // ------------------------------------------------

            32'h0000010C:
                rd = {
                    30'd0,
                    done,
                    busy
                };

            // ------------------------------------------------
            // SPI_CLKDIV
            // ------------------------------------------------

            32'h00000110:
                rd = {
                    16'd0,
                    clk_div
                };

            // ------------------------------------------------
            // Invalid address
            // ------------------------------------------------

            default:
                rd = 32'h00000000;

        endcase

    end

endmodule
