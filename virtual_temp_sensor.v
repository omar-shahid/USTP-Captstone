`timescale 1ns/1ps

// ============================================================
// VIRTUAL TEMPERATURE SENSOR
//
// SPI SLAVE
//
// SPI MODE 0
//
// CPOL = 0
// CPHA = 0
//
// Temperature:
//
//     25 decimal
//     = 0x19
//     = 00011001
//
// The sensor returns 0x19 whenever the master performs
// an SPI transaction.
//
// ============================================================

module virtual_temp_sensor #(
    parameter [7:0] TEMPERATURE = 8'h19
)(
    input  spi_sclk,
    input  spi_mosi,
    input  spi_cs,
    input  reset,

    output reg spi_miso
);

    // ========================================================
    // INTERNAL REGISTERS
    // ========================================================

    reg [7:0] tx_shift;

    reg [7:0] rx_shift;

    reg [2:0] bit_count;

    // ========================================================
    // SENSOR INITIALIZATION
    //
    // CS is active LOW.
    //
    // When CS goes LOW, load the temperature value.
    //
    // MSB is placed on MISO before the first rising edge.
    // ========================================================

    always @(negedge spi_cs or posedge reset) begin

        if (reset) begin

            tx_shift  <= TEMPERATURE;
            rx_shift  <= 8'h00;
            bit_count <= 3'd0;

            // MSB of 0x19 = 0
            spi_miso <= TEMPERATURE[7];

        end
        else begin

            tx_shift  <= TEMPERATURE;

            rx_shift  <= 8'h00;

            bit_count <= 3'd0;

            // First bit
            spi_miso <= TEMPERATURE[7];

        end

    end

    // ========================================================
    // SPI MODE 0
    //
    // Master samples MISO on rising edge.
    //
    // Slave changes MISO on falling edge.
    // ========================================================

    always @(negedge spi_sclk) begin

        if (!spi_cs) begin

            if (bit_count < 3'd7) begin

                bit_count <=
                    bit_count + 3'd1;

                // Shift received MOSI
                rx_shift <=
                    {rx_shift[6:0], spi_mosi};

                // Shift sensor TX register
                tx_shift <=
                    {tx_shift[6:0], 1'b0};

                // Next output bit
                spi_miso <=
                    tx_shift[6];

            end

            else begin

                // Last bit completed
                spi_miso <= 1'b0;

            end

        end

    end

endmodule
