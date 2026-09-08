`timescale 1ns/1ps

// ============================================================
// RISC-V TOP
//
// Memory Map
//
// 0x000 - 0x07F : DATA MEMORY
// 0x080 - 0x0BF : UART
// 0x0C0 - 0x0FF : PWM
// 0x100 - 0x11F : SPI
//
// ============================================================

module risc_v #(
    parameter CLK_FREQ         = 50_000_000,
    parameter BAUD_RATE        = 9600,
    parameter PWM_FREQ         = 25_000,
    parameter STALL_TIMEOUT_MS = 500,
    parameter HEX_FILE         = ""
)(
    input clk,
    input reset,

    // UART
    output tx,
    input  rx,

    output       uart_rx_ready,
    output [7:0] uart_rx_data,

    // PWM
    output pwm_out,
    input  tach_in,
    output pwm_stall_irq,

    // SPI
    output spi_sclk,
    output spi_mosi,
    input  spi_miso,
    output spi_cs,

    // DEBUG
    output       result_src,
    output       memwrite,
    output       alu_src,
    output       regwrite,
    output       pc_src,

    output [1:0] imm_src,

    output [31:0] pc,
    output [31:0] inst,
    output [31:0] alu_result,
    output [31:0] wd,
    output [31:0] rd
);

    // ========================================================
    // CLOCK
    // ========================================================

    wire clk_d;


    // ========================================================
    // PC SIGNALS
    // ========================================================

    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    wire [31:0] pc_target;


    // ========================================================
    // INSTRUCTION
    // ========================================================

    wire [31:0] instruction;


    // ========================================================
    // REGISTER FILE
    // ========================================================

    wire [31:0] rd1;
    wire [31:0] rd2;


    // ========================================================
    // IMMEDIATE
    // ========================================================

    wire [31:0] imm_ext_data;


    // ========================================================
    // ALU
    // ========================================================

    wire [31:0] src_b;
    wire [2:0]  alu_control;
    wire        zero;


    // ========================================================
    // MEMORY READ DATA
    // ========================================================

    wire [31:0] dmem_rd;
    wire [31:0] uart_rd;
    wire [31:0] pwm_rd;
    wire [31:0] spi_rd;

    wire [31:0] read_data;


    // ========================================================
    // ADDRESS SELECTS
    // ========================================================

    wire sel_dmem;
    wire sel_uart;
    wire sel_pwm;
    wire sel_spi;


    // ========================================================
    // ADDRESS DECODER
    // ========================================================

    // DATA MEMORY : 0x00 - 0x7F
    assign sel_dmem =
        (alu_result[31:7] == 25'd0);


    // UART : 0x80 - 0xBF
    assign sel_uart =
        (alu_result[31:6] == 26'd2);


    // PWM : 0xC0 - 0xFF
    assign sel_pwm =
        (alu_result[31:6] == 26'd3);


    // SPI : 0x100 - 0x11F
    assign sel_spi =
        (alu_result >= 32'h00000100) &&
        (alu_result <= 32'h0000011F);


    // ========================================================
    // CLOCK DIVIDER
    // ========================================================

    clk_div CLK_DIVIDER (
        .clk   (clk),
        .reset (reset),
        .clk_d (clk_d)
    );


    // ========================================================
    // PC NEXT MUX
    // ========================================================

    mux PC_MUX (
        .a   (pc_plus4),
        .b   (pc_target),
        .sel (pc_src),
        .y   (pc_next)
    );


    // ========================================================
    // PROGRAM COUNTER
    //
    // Actual interface:
    //
    // pc(clk, reset, x, out)
    // ========================================================

    pc PC_REG (
        .clk   (clk_d),
        .reset (reset),
        .x     (pc_next),
        .out   (pc)
    );


    // ========================================================
    // PC + 4
    // ========================================================

    adder PC_PLUS4 (
        .c (pc_plus4),
        .a (pc),
        .b (32'd4)
    );


    // ========================================================
    // PC TARGET
    // ========================================================

    adder PC_TARGET (
        .c (pc_target),
        .a (pc),
        .b (imm_ext_data)
    );


    // ========================================================
    // INSTRUCTION MEMORY
    //
    // Interface:
    //
    // input  addr
    // output inst
    // ========================================================

    instr_mem #(
        .HEX_FILE (HEX_FILE)
    )
    INSTRUCTION_MEMORY (
        .addr (pc),
        .inst (instruction)
    );


    assign inst = instruction;


    // ========================================================
    // REGISTER FILE
    //
    // Actual interface:
    //
    // reg_file(
    //     rd1,
    //     rd2,
    //     rs1,
    //     rs2,
    //     rd,
    //     wd,
    //     regwrite,
    //     clk
    // )
    // ========================================================

    reg_file REG_FILE (
        .rd1      (rd1),
        .rd2      (rd2),

        .rs1      (instruction[19:15]),
        .rs2      (instruction[24:20]),

        .rd       (instruction[11:7]),

        .wd       (wd),

        .regwrite (regwrite),

        .clk      (clk_d)
    );


    // ========================================================
    // IMMEDIATE EXTENSION
    //
    // Actual interface:
    //
    // imm_ext(imm_out, imm_src, inst)
    // ========================================================

    imm_ext IMM_EXT (
        .imm_out (imm_ext_data),
        .imm_src (imm_src),
        .inst    (instruction)
    );


    // ========================================================
    // ALU SOURCE MUX
    // ========================================================

    mux ALU_SRC_MUX (
        .a   (rd2),
        .b   (imm_ext_data),
        .sel (alu_src),
        .y   (src_b)
    );


    // ========================================================
    // ALU
    //
    // Actual interface:
    //
    // alu(result, zero, a, b, alu_control)
    // ========================================================

    alu ALU (
        .result      (alu_result),
        .zero        (zero),
        .a           (rd1),
        .b           (src_b),
        .alu_control (alu_control)
    );


    // ========================================================
    // CONTROL UNIT
    //
    // Actual interface:
    //
    // cu(
    //     alu_src,
    //     result_src,
    //     regwrite,
    //     memwrite,
    //     pc_src,
    //     imm_src,
    //     alu_control,
    //     opcode,
    //     fun3,
    //     fun7,
    //     zero
    // )
    // ========================================================

    cu CONTROL_UNIT (
        .alu_src     (alu_src),
        .result_src  (result_src),
        .regwrite    (regwrite),
        .memwrite    (memwrite),
        .pc_src      (pc_src),

        .imm_src     (imm_src),
        .alu_control (alu_control),

        .opcode      (instruction[6:0]),
        .fun3        (instruction[14:12]),
        .fun7        (instruction[30]),
        .zero        (zero)
    );


    // ========================================================
    // DATA MEMORY
    //
    // Actual interface:
    //
    // data_mem(
    //     rd,
    //     clk,
    //     memwrite,
    //     addr,
    //     wd
    // )
    // ========================================================

    data_mem DATA_MEMORY (
        .rd       (dmem_rd),
        .clk      (clk_d),

        .memwrite (memwrite & sel_dmem),

        .addr     (alu_result),
        .wd       (rd2)
    );


    // ========================================================
    // UART
    // ========================================================

    uart_regs #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    )
    UART_REGS (
        .clk       (clk),
        .reset     (reset),

        .addr      (alu_result),
        .wd        (rd2),
        .memwrite  (memwrite & sel_uart),

        .rd        (uart_rd),

        .tx        (tx),
        .rx        (rx),

        .rx_ready  (uart_rx_ready),
        .rx_data   (uart_rx_data)
    );


    // ========================================================
    // PWM
    // ========================================================

    pwm_regs #(
        .CLK_FREQ         (CLK_FREQ),
        .PWM_FREQ         (PWM_FREQ),
        .STALL_TIMEOUT_MS (STALL_TIMEOUT_MS)
    )
    PWM_REGS (
        .clk       (clk),
        .reset     (reset),

        .addr      (alu_result),
        .wd        (rd2),
        .memwrite  (memwrite & sel_pwm),

        .rd        (pwm_rd),

        .pwm_out   (pwm_out),
        .tach_in   (tach_in),
        .stall_irq (pwm_stall_irq)
    );


    // ========================================================
    // SPI
    // ========================================================

    spi_regs SPI_REGS (
        .clk       (clk),
        .reset     (reset),

        .addr      (alu_result),
        .wd        (rd2),
        .memwrite  (memwrite & sel_spi),

        .rd        (spi_rd),

        .spi_sclk  (spi_sclk),
        .spi_mosi  (spi_mosi),
        .spi_miso  (spi_miso),
        .spi_cs    (spi_cs)
    );


    // ========================================================
    // READ DATA MUX
    // ========================================================

    assign read_data =
        sel_spi  ? spi_rd  :
        sel_pwm  ? pwm_rd  :
        sel_uart ? uart_rd :
                   dmem_rd;


    // ========================================================
    // WRITE BACK
    // ========================================================

    mux RESULT_MUX (
        .a   (alu_result),
        .b   (read_data),
        .sel (result_src),
        .y   (wd)
    );


    // ========================================================
    // DEBUG READ DATA
    // ========================================================

    assign rd = read_data;

endmodule