// ============================================================
//  risc_v_temp_pwm_tb.v  -  Closed-Loop Thermal PWM & Serial Telemetry
//
//  Verifies closed-loop temperature-driven PWM fan control:
//    - Protocols slowed down to run with CPU core clock (250 kHz):
//        * CPU core clock: 250 kHz (50 MHz / 200)
//        * SPI clock:      250 kHz (SPI_CLKDIV = 100 in software)
//        * UART baud rate: 115.2 kBaud (standard 115200 baud)
//    - Calculates simulated temperature dynamically based on PWM duty cycle:
//        1. Normal duty cycle = 80% (causes temperature to rise)
//        2. At temp >= 75 C, CPU throttles PWM duty cycle to 40%
//        3. At 40% duty, temperature cools down towards 50 C
//        4. At temp <= 50 C, CPU restores PWM duty cycle to 80%
//    - Transmits real-time temperature over UART TX as ASCII text ("50\n")
//    - Testbench deserializes and prints UART ASCII telemetry
//    - Self-checking pass/fail assertion monitors
// ============================================================

`timescale 1ns/1ps

module risc_v_temp_pwm_tb;

    // ── Simulation Parameters ─────────────────────────────────
    localparam SIM_CLK_FREQ  = 50_000_000;
    localparam CLK_HALF      = 10; // 50 MHz clock => 20 ns period

    // Protocol Clocks: UART configured to standard 115200 baud
    localparam SIM_BAUD_RATE = 115_200; // Standard 115200 baud rate (115.2 kBaud)
    localparam BIT_PERIOD    = (1_000_000_000 / SIM_BAUD_RATE); // 8680 ns per bit

    // ── Signals ───────────────────────────────────────────────
    reg         clk;
    reg         reset;

    // UART
    wire        tx;
    reg  [7:0]  uart_rx_byte;
    string      uart_line_buf = "";
    integer     telemetry_count = 0;

    // PWM
    wire        pwm_out;
    wire        tach_in;
    wire [15:0] fan_rpm;
    wire [6:0]  fan_duty_pct;
    wire        pwm_stall_irq;

    // SPI
    wire        spi_sclk;
    wire        spi_mosi;
    wire        spi_miso;
    wire        spi_cs;

    // CPU debug signals
    wire        result_src;
    wire        memwrite;
    wire        alu_src;
    wire        regwrite;
    wire        pc_src;
    wire [1:0]  imm_src;
    wire [31:0] pc;
    wire [31:0] inst;
    wire [31:0] alu_result;
    wire [31:0] wd;
    wire [31:0] rd;

    // Closed-loop simulated temperature
    reg  [7:0]  sim_temp;
    string      hex_file = "functional_test/pwm_temp_control.hex";

    // Test tracking flags
    integer     pass_count = 0;
    integer     fail_count = 0;
    reg         seen_init_80     = 1'b0;
    reg         seen_throttle_40 = 1'b0;
    reg         seen_recover_80  = 1'b0;

    // ── Clock Generation ──────────────────────────────────────
    initial clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    // ── DUT Instantiation ─────────────────────────────────────
    risc_v #(
        .CLK_FREQ         (SIM_CLK_FREQ),
        .BAUD_RATE        (SIM_BAUD_RATE),
        .PWM_FREQ         (25_000),
        .STALL_TIMEOUT_MS (500),
        .HEX_FILE         ("program.hex")
    ) DUT (
        .clk              (clk),
        .reset            (reset),

        // UART
        .tx               (tx),
        .rx               (1'b1),
        .uart_rx_ready    (),
        .uart_rx_data     (),

        // PWM
        .pwm_out          (pwm_out),
        .tach_in          (tach_in),
        .pwm_stall_irq    (pwm_stall_irq),

        // SPI
        .spi_sclk         (spi_sclk),
        .spi_mosi         (spi_mosi),
        .spi_miso         (spi_miso),
        .spi_cs           (spi_cs),

        // CPU debug
        .result_src       (result_src),
        .memwrite         (memwrite),
        .alu_src          (alu_src),
        .regwrite         (regwrite),
        .pc_src           (pc_src),
        .imm_src          (imm_src),
        .pc               (pc),
        .inst             (inst),
        .alu_result       (alu_result),
        .wd               (wd),
        .rd               (rd)
    );

    // ── Virtual Temperature Sensor ────────────────────────────
    virtual_temp_sensor #(
        .TEMPERATURE (8'd55)
    ) TEMP_SENSOR (
        .spi_sclk (spi_sclk),
        .spi_mosi (spi_mosi),
        .spi_cs   (spi_cs),
        .reset    (reset),
        .temp_in  (sim_temp),
        .spi_miso (spi_miso)
    );

    // ── Virtual DC Cooling Fan Model ─────────────────────────
    virtual_fan #(
        .CLK_FREQ         (SIM_CLK_FREQ),
        .PWM_FREQ         (25_000),
        .PULSES_PER_REV   (2),
        .MAX_RPM          (6000),
        .MIN_RPM          (0),
        .STALL_DUTY_PCT   (5),
        .RAMP_MS_PER_STEP (1),
        .RPM_STEP         (1200)
    ) FAN_MODEL (
        .clk              (clk),
        .reset            (reset),
        .pwm_in           (pwm_out),
        .tach_out         (tach_in),
        .rpm_actual       (fan_rpm),
        .duty_pct         (fan_duty_pct)
    );

    // ── Hex Loading & Reset Sequence ──────────────────────────
    initial begin
        $display("\n==================================================");
        $display("   RISC-V CLOSED-LOOP THERMAL PWM & TELEMETRY TB");
        $display("==================================================");
        $display("[CONFIG] System Clock:      %0d MHz", SIM_CLK_FREQ / 1_000_000);
        $display("[CONFIG] CPU Core Clock:    250 kHz (clk / 200)");
        $display("[CONFIG] Protocol Clocking:");
        $display("         - UART Baud Rate:  %0d baud (standard 115.2 kBaud)", SIM_BAUD_RATE);
        $display("         - SPI Clock:       Configured to 250 kHz via software SPI_CLKDIV=100");
        $display("==================================================\n");

        // Initialize instruction memory with NOPs (addi x0, x0, 0)
        for (integer k = 0; k < DUT.IM.MEM_WORDS; k = k + 1) begin
            DUT.IM.mem[k] = 32'h00000013;
        end

        // Check for runtime +HEX=<path>
        if ($value$plusargs("HEX=%s", hex_file)) begin
            $display("[INFO] Loading runtime hex file: %s", hex_file);
            $readmemh(hex_file, DUT.IM.mem);
        end else begin
            $display("[INFO] Loading default hex file: %s", hex_file);
            $readmemh("functional_test/pwm_temp_control.hex", DUT.IM.mem);
        end

        // Directly populate the ROM macro storage arrays (matches rv_if.sv convention)
        for (integer k = 0; k < DUT.IM.MEM_WORDS; k = k + 1) begin
            DUT.IM.rom_inst_lo.mem[k] = DUT.IM.mem[k][15:0];
            DUT.IM.rom_inst_hi.mem[k] = DUT.IM.mem[k][31:16];
        end

        // Clear data RAM for clean test isolation
        for (integer k = 0; k < 128; k = k + 1) begin
            DUT.DATA_MEMORY.ram_data_lo.mem[k] = 16'h0000;
            DUT.DATA_MEMORY.ram_data_hi.mem[k] = 16'h0000;
        end

        sim_temp = 8'd55; // Initial temperature: 55 C

        reset = 1'b1;
        repeat (10) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        $display("[INFO] [%0t] Reset released. CPU executing instructions...\n", $time);
    end

    // ── SPI Clock Frequency Measurement & Activity Monitor ────
    time last_sclk_rise = 0;
    time sclk_period_ns = 0;

    always @(posedge spi_sclk) begin
        if (!reset && !spi_cs) begin
            if (last_sclk_rise > 0) begin
                sclk_period_ns = $time - last_sclk_rise;
            end
            last_sclk_rise = $time;
        end
    end

    always @(negedge spi_cs) begin
        if (!reset) begin
            last_sclk_rise = 0;
            $display("[SPI_MONITOR] [%0t] SPI Transaction Start -> Sensor feeding: %0d C (0x%02X)", 
                     $time, TEMP_SENSOR.active_temp, TEMP_SENSOR.active_temp);
        end
    end

    always @(posedge spi_cs) begin
        if (!reset) begin
            $display("[SPI_MONITOR] [%0t] SPI Transaction Done  -> Master received: %0d C (0x%02X) | sclk period = %0d ns (%0d kHz)", 
                     $time, DUT.SPI_REGS.rx_data, DUT.SPI_REGS.rx_data, sclk_period_ns, (sclk_period_ns > 0 ? 1_000_000 / sclk_period_ns : 0));
        end
    end

    // ── UART Telemetry Monitor (Deserializer & ASCII Display) ─
    always begin
        // Wait for start bit (falling edge of tx)
        @(negedge tx);
        if (!reset) begin
            // Sample in the middle of the start bit
            #(BIT_PERIOD / 2);
            if (tx == 1'b0) begin
                // Sample 8 data bits (LSB first)
                for (integer b = 0; b < 8; b = b + 1) begin
                    #(BIT_PERIOD);
                    uart_rx_byte[b] = tx;
                end
                // Wait for stop bit
                #(BIT_PERIOD);
                if (tx == 1'b1) begin
                    if (uart_rx_byte == 8'h0A) begin // '\n' newline
                        $display("[SERIAL_MONITOR] [%0t] CPU Log: \"%s\"", 
                                 $time, uart_line_buf);
                        uart_line_buf = "";
                        telemetry_count = telemetry_count + 1;
                    end else begin
                        uart_line_buf = $sformatf("%s%c", uart_line_buf, uart_rx_byte);
                    end
                end
            end
        end
    end

    // ── Closed-Loop Thermal Physics Simulation Model ──────────
    // Calculates temperature dynamically based on the current PWM duty cycle:
    //   - If Duty == 80%: High heat generation => temp gradually increases to ~85 C
    //   - If Duty == 40%: Cooldown mode        => temp gradually decreases to ~45 C
    // Update interval is 600 us (~150 CPU cycles), providing ample time
    // for SPI reading (32 us), ASCII conversion, and 14-character UART logging (560 us).
    always begin
        #600_000;

        if (!reset) begin
            if (DUT.PWM_REGS.duty_reg >= 7'd70) begin
                // Heating up under high duty cycle
                if (sim_temp < 8'd85) begin
                    sim_temp = sim_temp + 8'd2;
                    $display("[THERMAL_MODEL] [%0t] PWM=%0d%% => HEATING: Temp = %0d C", 
                             $time, DUT.PWM_REGS.duty_reg, sim_temp);
                end
            end else if (DUT.PWM_REGS.duty_reg <= 7'd50 && DUT.PWM_REGS.ctrl_en) begin
                // Cooling down under low duty cycle
                if (sim_temp > 8'd45) begin
                    sim_temp = sim_temp - 8'd2;
                    $display("[THERMAL_MODEL] [%0t] PWM=%0d%% => COOLING: Temp = %0d C", 
                             $time, DUT.PWM_REGS.duty_reg, sim_temp);
                end
            end
        end
    end

    // ── Self-Checking CPU Activity & PWM Monitor ──────────────
    always @(posedge DUT.clk_d) begin
        if (!reset && memwrite) begin
            // Detect writes to PWM_DUTY register (0xC4)
            if (alu_result == 32'h000000C4) begin
                $display("\n>>> [CPU_PWM_EVENT] [%0t] CPU set PWM Duty to %0d%% (Current Temp = %0d C)", 
                         $time, DUT.rd2[6:0], sim_temp);

                // Check 1: Initial PWM set to 80%
                if (!seen_init_80 && DUT.rd2[6:0] == 7'd80) begin
                    seen_init_80 = 1'b1;
                    pass_count   = pass_count + 1;
                    $display("[PASS] [CHECK 1] CPU successfully initialized PWM to 80%% duty cycle.");
                end

                // Check 2: Throttling to 40% when temp >= 75 C
                else if (seen_init_80 && !seen_throttle_40 && DUT.rd2[6:0] == 7'd40) begin
                    if (sim_temp >= 8'd75) begin
                        seen_throttle_40 = 1'b1;
                        pass_count       = pass_count + 1;
                        $display("[PASS] [CHECK 2] Over-temp detected (%0d C >= 75 C)! CPU throttled PWM to 40%% duty cycle.", sim_temp);
                    end else begin
                        fail_count = fail_count + 1;
                        $display("[FAIL] [CHECK 2] CPU lowered PWM to 40%% prematurely at %0d C (< 75 C).", sim_temp);
                    end
                end

                // Check 3: Recovery back to 80% when temp <= 50 C
                else if (seen_throttle_40 && !seen_recover_80 && DUT.rd2[6:0] == 7'd80) begin
                    if (sim_temp <= 8'd50) begin
                        seen_recover_80 = 1'b1;
                        pass_count      = pass_count + 1;
                        $display("[PASS] [CHECK 3] Cooldown complete (%0d C <= 50 C)! CPU restored PWM to 80%% duty cycle.", sim_temp);

                        // All required transitions verified!
                        #250_000;
                        finish_test();
                    end else begin
                        fail_count = fail_count + 1;
                        $display("[FAIL] [CHECK 3] CPU restored PWM to 80%% prematurely at %0d C (> 50 C).", sim_temp);
                    end
                end
            end
        end
    end

    // ── Test Summary & Completion ─────────────────────────────
    task finish_test();
        begin
            $display("\n==================================================");
            $display("         CLOSED-LOOP THERMAL PWM TEST SUMMARY");
            $display("==================================================");
            $display("Initial 80%% Duty Set:      %s", seen_init_80     ? "PASSED" : "FAILED");
            $display("Throttle to 40%% (>=75 C):   %s", seen_throttle_40 ? "PASSED" : "FAILED");
            $display("Recovery to 80%% (<=50 C):   %s", seen_recover_80  ? "PASSED" : "FAILED");
            $display("Serial Monitor Logs:       %0d received", telemetry_count);
            $display("Fan RPM at Completion:     %0d RPM", fan_rpm);
            $display("Tachometer Period (50MHz): %0d cycles", DUT.PWM_REGS.period_reg);
            $display("--------------------------------------------------");
            $display("Checks Passed: %0d", pass_count);
            $display("Checks Failed: %0d", fail_count);
            $display("==================================================");

            if (fail_count == 0 && seen_init_80 && seen_throttle_40 && seen_recover_80 && telemetry_count > 0) begin
                $display("[RESULT] ALL TESTS PASSED: Closed-loop thermal PWM control & Serial Monitor fully verified!\n");
            end else if (telemetry_count == 0) begin
                $display("[RESULT] SIMULATION FAILED: No serial monitor strings were received.\n");
            end else begin
                $display("[RESULT] SIMULATION FAILED: One or more transitions did not pass.\n");
            end

            $finish;
        end
    endtask

    // ── Watchdog Timer ────────────────────────────────────────
    initial begin
        #30_000_000; // 30 ms simulation timeout
        $display("\n[TIMEOUT] [%0t] Simulation watchdog timer expired!", $time);
        finish_test();
    end

endmodule
