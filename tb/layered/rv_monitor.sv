//=============================================================================
// File   : rv_monitor.sv
// Author : Auto-generated
// Date   : 2026-09-18
// Desc   : Passive monitor for layered RISC-V testbench.
//
//          Two parallel observation tasks run in the background:
//            1. monitor_pc_stall() – detects when the PC stops advancing
//               for >300 consecutive clocks, then triggers `program_done`.
//            2. monitor_uart_tx()  – captures bytes from the async serial TX
//               line using bit-bang sampling (10 kHz baud, BIT_PERIOD = 100 µs).
//
//          Because backdoor register / memory access requires hierarchical
//          paths that cannot pass through a virtual interface, the monitor
//          does NOT attempt those reads.  The top-level TB reads the DUT
//          internals directly and forwards results to the scoreboard.
//=============================================================================

class rv_monitor;

    //=========================================================================
    // Handles & Synchronization
    //=========================================================================
    virtual rv_if               vif;
    mailbox #(rv_observed_tx)   mon2sb;
    event                       program_completed;
    logic [31:0]                shadow_regs[32];

    //=========================================================================
    // Constructor
    //=========================================================================
    function new(virtual rv_if vif, mailbox #(rv_observed_tx) mon2sb);
        this.vif    = vif;
        this.mon2sb = mon2sb;
        for (int r = 0; r < 32; r++)
            shadow_regs[r] = 32'h0;
    endfunction

    //=========================================================================
    // run() – Launch observation threads in background
    //=========================================================================
    task run();
        fork
            monitor_datapath();
            monitor_uart_tx();
            detect_program_end();
        join_none
    endtask

    //=========================================================================
    // monitor_datapath() – Cycle-accurate instruction retirement observation
    // Samples register writes and data memory writes on instruction boundary
    //=========================================================================
    task monitor_datapath();
        logic [31:0] prev_pc         = 32'hFFFF_FFFF;
        logic [31:0] prev_inst       = 32'h0;
        logic [31:0] prev_wd         = 32'h0;
        logic [31:0] prev_alu_result = 32'h0;
        logic        prev_regwrite   = 1'b0;
        logic        prev_memwrite   = 1'b0;

        forever begin
            @(posedge vif.clk);
            if (!vif.reset) begin
                if (vif.pc !== prev_pc) begin
                    // An instruction has retired at prev_pc!
                    if (prev_regwrite && (prev_inst[11:7] != 5'd0)) begin
                        shadow_regs[prev_inst[11:7]] = prev_wd;
                        begin
                            rv_observed_tx obs = new();
                            obs.kind      = OBS_REG_WRITE;
                            obs.reg_addr  = prev_inst[11:7];
                            obs.data      = prev_wd;
                            obs.timestamp = $time;
                            mon2sb.put(obs);
                        end
                    end

                    if (prev_memwrite) begin
                        rv_observed_tx obs = new();
                        obs.kind      = OBS_MEM_WRITE;
                        obs.mem_addr  = prev_alu_result;
                        // For Store Word (SW), rs2 is inst[24:20]
                        obs.data      = (prev_inst[24:20] == 5'd0) ? 32'd0 : shadow_regs[prev_inst[24:20]];
                        obs.timestamp = $time;
                        mon2sb.put(obs);
                    end

                    // Latch new PC and instruction signals
                    prev_pc         = vif.pc;
                    prev_inst       = vif.inst;
                    prev_wd         = vif.wd;
                    prev_alu_result = vif.alu_result;
                    prev_regwrite   = vif.regwrite;
                    prev_memwrite   = vif.memwrite;
                end else begin
                    // Update latest stable bus values within current core cycle
                    prev_inst       = vif.inst;
                    prev_wd         = vif.wd;
                    prev_alu_result = vif.alu_result;
                    prev_regwrite   = vif.regwrite;
                    prev_memwrite   = vif.memwrite;
                end
            end else begin
                prev_pc       = 32'hFFFF_FFFF;
                prev_regwrite = 1'b0;
                prev_memwrite = 1'b0;
            end
        end
    endtask

    //=========================================================================
    // monitor_uart_tx() – Asynchronous serial receiver sampling at mid-bit
    // Timing strictly derived from vif.BIT_PERIOD (BAUD_RATE)
    //=========================================================================
    task monitor_uart_tx();
        logic [7:0] rx_byte;
        int i;

        forever begin
            @(negedge vif.tx); // Start bit edge

            #(vif.BIT_PERIOD / 2); // Sample at mid-point of start bit
            if (vif.tx === 1'b0) begin
                rx_byte = 8'h00;
                for (i = 0; i < 8; i++) begin
                    #(vif.BIT_PERIOD);
                    rx_byte = {vif.tx, rx_byte[7:1]};
                end

                #(vif.BIT_PERIOD); // Stop bit
                if (vif.tx === 1'b1) begin
                    rv_observed_tx obs = new();
                    obs.kind      = OBS_UART_CHAR;
                    obs.uart_char = rx_byte;
                    obs.timestamp = $time;
                    mon2sb.put(obs);
                    $display("[MONITOR] [%0t] UART TX Output: '%c' (0x%02X)", $time, rx_byte, rx_byte);
                end else begin
                    $display("[MONITOR] [%0t] WARNING: UART framing error on TX", $time);
                end
            end
        end
    endtask

    //=========================================================================
    // detect_program_end() – Detects when PC is stalled in infinite loop
    // Waits for UART serialization to finish using BAUD_RATE drain guard
    //=========================================================================
    task detect_program_end();
        int          idle_count   = 0;
        logic [31:0] last_seen_pc = 32'hFFFF_FFFF;

        forever begin
            @(posedge vif.clk);
            if (!vif.reset) begin
                if (vif.pc === last_seen_pc)
                    idle_count++;
                else begin
                    idle_count   = 0;
                    last_seen_pc = vif.pc;
                end

                if (idle_count > 300) begin
                    $display("[MONITOR] [%0t] PC stall detected at 0x%08X after %0d cycles.",
                             $time, last_seen_pc, idle_count);

                    // Wait for UART TX line to be idle-high
                    wait (vif.tx === 1'b1);

                    // Add 2 bit periods drain delay relative to BAUD_RATE
                    #(2 * vif.BIT_PERIOD);

                    // Emit OBS_PROGRAM_DONE to Scoreboard
                    begin
                        rv_observed_tx obs = new();
                        obs.kind      = OBS_PROGRAM_DONE;
                        obs.timestamp = $time;
                        mon2sb.put(obs);
                    end

                    // Trigger completion event
                    -> program_completed;
                    break;
                end
            end
        end
    endtask

endclass
