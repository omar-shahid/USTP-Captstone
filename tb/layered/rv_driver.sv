// ============================================================
//  rv_driver.sv — Layered Testbench Driver
//
//  Consumes rv_transaction items from the generator mailbox and
//  applies them to the DUT through the virtual interface.
//
//  Responsibilities:
//    - INSTR_LOAD : Assert reset, store hex path for top-level
//                   backdoor loading, de-assert reset
//    - REG_CHECK / MEM_CHECK / UART_CHECK : Forward to monitor
//      via drv2mon mailbox (scoreboard checking)
//
//  Note on backdoor access:
//    Hierarchical memory access (DUT.IM.mem[]) cannot traverse
//    virtual interfaces. The driver stores the hex file path in
//    `current_hex` and signals `reset_done` so that the top-level
//    testbench can perform the actual $readmemh via hierarchy.
// ============================================================
class rv_driver;

    // ── Input mailbox from Generator ─────────────────────────
    mailbox #(rv_stim_tx) gen2drv;

    // ── Virtual interface handle ─────────────────────────────
    virtual rv_if vif;

    // ── Constructor ──────────────────────────────────────────
    function new(virtual rv_if vif, mailbox #(rv_stim_tx) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    // ════════════════════════════════════════════════════════
    //  Main run loop — consume stimulus from Generator
    // ════════════════════════════════════════════════════════
    task run();
        rv_stim_tx tx;

        $display("[DRV] [%0t] Driver started.", $time);

        // Idle the RX line high (UART idle = logic 1)
        vif.drv_cb.rx <= 1'b1;

        forever begin
            gen2drv.get(tx);
            $display("[DRV] [%0t] Received stimulus for test '%s' (hex=%s)",
                     $time, tx.test_name, tx.hex_file);

            // 1. Assert reset while loading code
            vif.drv_cb.reset <= 1'b1;

            // 2. Load program into instruction memory via interface task
            vif.load_hex(tx.hex_file);

            // 3. Hold reset for 10 clock cycles
            repeat (10) @(vif.drv_cb);

            // 4. Release reset
            @(vif.drv_cb);
            vif.drv_cb.reset <= 1'b0;
            @(vif.drv_cb);
            $display("[DRV] [%0t] Reset released. CPU is now executing.", $time);

            // 5. If UART host injection is requested, bit-bang RX with BAUD-relative delays
            if (tx.inject_uart) begin
                foreach (tx.rx_bytes[i]) begin
                    int delay_multiplier = (i < tx.rx_delays.size()) ? tx.rx_delays[i] : 10;
                    #(delay_multiplier * vif.BIT_PERIOD);
                    send_uart_byte(tx.rx_bytes[i]);
                end
            end
        end
    endtask

    // ════════════════════════════════════════════════════════
    //  send_uart_byte — Bit-bang a byte on the RX line
    //  All timing strictly derived from vif.BIT_PERIOD (BAUD_RATE)
    // ════════════════════════════════════════════════════════
    task send_uart_byte(input [7:0] data);
        int bit_idx;

        $display("[DRV] [%0t] UART Host RX Inject: 0x%02X ('%c')", $time, data, data);

        // Start bit (low)
        vif.drv_cb.rx <= 1'b0;
        #(vif.BIT_PERIOD);

        // 8 data bits (LSB first)
        for (bit_idx = 0; bit_idx < 8; bit_idx++) begin
            vif.drv_cb.rx <= data[bit_idx];
            #(vif.BIT_PERIOD);
        end

        // Stop bit (high)
        vif.drv_cb.rx <= 1'b1;
        #(vif.BIT_PERIOD);
    endtask

endclass
