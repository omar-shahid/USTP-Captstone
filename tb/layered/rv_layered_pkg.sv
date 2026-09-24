`timescale 1ns/1ps
//=============================================================================
// File   : rv_layered_pkg.sv
// Author : Auto-generated
// Date   : 2026-09-18
// Desc   : Package for layered RISC-V testbench.
//          Contains reusable transaction and scoreboard classes.
//=============================================================================

package rv_layered_pkg;

    //=========================================================================
    // 1. Stimulus Transaction (Generator -> Driver)
    //=========================================================================
    class rv_stim_tx;
        string      test_name;
        string      hex_file;
        bit         inject_uart;
        logic [7:0] rx_bytes[$];
        int         rx_delays[$]; // Delay before injecting each byte (in BIT_PERIOD units)

        function new();
            test_name   = "";
            hex_file    = "";
            inject_uart = 1'b0;
        endfunction
    endclass


    //=========================================================================
    // 2. Observed Transaction (DUT -> Monitor -> Scoreboard)
    //=========================================================================
    typedef enum {
        OBS_REG_WRITE,
        OBS_MEM_WRITE,
        OBS_UART_CHAR,
        OBS_PROGRAM_DONE
    } obs_kind_e;

    class rv_observed_tx;
        obs_kind_e   kind;
        int          reg_addr;
        logic [31:0] mem_addr;
        logic [31:0] data;
        byte         uart_char;
        time         timestamp;

        function new();
            kind      = OBS_PROGRAM_DONE;
            reg_addr  = 0;
            mem_addr  = 32'h0;
            data      = 32'h0;
            uart_char = 8'h00;
            timestamp = 0;
        endfunction
    endclass


    //=========================================================================
    // 3. Autonomous Scoreboard Class (Scoreboard <- Monitor <- DUT)
    //=========================================================================
    class rv_scoreboard;

        // Mailbox receiving observed transactions from Monitor
        mailbox #(rv_observed_tx) mon2sb;

        // Completion flag & event
        bit   is_done;
        event done;

        // Pass / Fail statistics
        int pass_count;
        int fail_count;
        int total_tests;

        // Test configuration name
        string test_name;

        // Directed Golden Reference Tables
        logic [31:0] expected_regs[int];
        logic [31:0] expected_mem[logic [31:0]];
        string       expected_uart_str;

        // Observed State Tables
        logic [31:0] observed_regs[32];
        logic [31:0] observed_mem[logic [31:0]];
        string       observed_uart_str;

        // ----- Constructor -----
        function new(mailbox #(rv_observed_tx) mon2sb);
            this.mon2sb      = mon2sb;
            this.is_done     = 1'b0;
            this.pass_count  = 0;
            this.fail_count  = 0;
            this.total_tests = 0;
            this.test_name   = "";
            this.expected_uart_str = "";
            this.observed_uart_str = "";
            for (int i = 0; i < 32; i++)
                observed_regs[i] = 32'h0;
        endfunction

        // ----- Build: Initialize Directed Golden Reference -----
        function void build(string test_name);
            this.test_name = test_name;
            expected_regs.delete();
            expected_mem.delete();
            expected_uart_str = "";

            case (test_name)
                "alu_test": begin
                    // Register expectations (x1 - x17)
                    expected_regs[1]  = 32'd10;
                    expected_regs[2]  = 32'd20;
                    expected_regs[3]  = 32'hFFFFFFFB; // -5
                    expected_regs[4]  = 32'd30;
                    expected_regs[5]  = 32'd10;
                    expected_regs[6]  = 32'd25;
                    expected_regs[7]  = 32'd15;
                    expected_regs[8]  = 32'd7;
                    expected_regs[9]  = 32'd7;
                    expected_regs[10] = 32'd15;
                    expected_regs[11] = 32'd1;
                    expected_regs[12] = 32'd0;
                    expected_regs[13] = 32'd1;
                    expected_regs[14] = 32'd4;
                    expected_regs[15] = 32'd16;
                    expected_regs[16] = 32'd1;
                    expected_regs[17] = 32'hFFFFFFFD; // -3

                    // Memory expectations
                    expected_mem[32'h00] = 32'd30;
                    expected_mem[32'h04] = 32'd25;
                    expected_mem[32'h08] = 32'd7;
                    expected_mem[32'h0C] = 32'd15;
                    expected_mem[32'h10] = 32'd16;
                    expected_mem[32'h14] = 32'hFFFFFFFD; // -3
                end

                "mem_test": begin
                    // Register expectations (x1 - x9)
                    expected_regs[1] = 32'd100;
                    expected_regs[2] = 32'd200;
                    expected_regs[3] = 32'd300;
                    expected_regs[4] = 32'd400;
                    expected_regs[5] = 32'd100;
                    expected_regs[6] = 32'd200;
                    expected_regs[7] = 32'd300;
                    expected_regs[8] = 32'd400;
                    expected_regs[9] = 32'd1000;

                    // Memory expectations
                    expected_mem[32'h00] = 32'd100;
                    expected_mem[32'h04] = 32'd200;
                    expected_mem[32'h08] = 32'd300;
                    expected_mem[32'h0C] = 32'd400;
                    expected_mem[32'h10] = 32'd1000;
                end

                "branch_test": begin
                    // Register expectations (x1 - x6)
                    expected_regs[1] = 32'd5;
                    expected_regs[2] = 32'd5;
                    expected_regs[3] = 32'd15;
                    expected_regs[4] = 32'd1;
                    expected_regs[5] = 32'd15;
                    expected_regs[6] = 32'd1;

                    // Memory expectations
                    expected_mem[32'h00] = 32'd15;
                    expected_mem[32'h04] = 32'd1;
                end

                "uart_test": begin
                    expected_uart_str = "Hello";
                end

                "full_soc_test": begin
                    expected_regs[1] = 32'd15;
                    expected_regs[2] = 32'd25;
                    expected_regs[3] = 32'd40;
                    expected_regs[4] = 32'd40;
                    expected_regs[5] = 32'd40;

                    expected_mem[32'h00] = 32'd40;
                    expected_uart_str    = "OK";
                end

                default: begin
                    $display("[SB] WARNING: No golden reference defined for test '%s'", test_name);
                end
            endcase
            $display("[SB] Built golden reference model for test: %s", test_name);
        endfunction

        // ----- Run: Consume observed transactions from Monitor -----
        task run();
            rv_observed_tx item;
            forever begin
                mon2sb.get(item);
                case (item.kind)
                    OBS_REG_WRITE: begin
                        observed_regs[item.reg_addr] = item.data;
                    end
                    OBS_MEM_WRITE: begin
                        observed_mem[item.mem_addr] = item.data;
                    end
                    OBS_UART_CHAR: begin
                        observed_uart_str = {observed_uart_str, string'(item.uart_char)};
                    end
                    OBS_PROGRAM_DONE: begin
                        verify_all();
                        is_done = 1'b1;
                        -> done;
                        break;
                    end
                endcase
            end
        endtask

        // ----- Verify observed state against golden reference -----
        function void verify_all();
            $display("\n[SB] [%0t] Verifying observed DUT results against golden model...", $time);

            // 1. Check Registers
            foreach (expected_regs[idx])
                check_val($sformatf("REG: x%0d", idx), observed_regs[idx], expected_regs[idx]);

            // 2. Check Memory
            foreach (expected_mem[addr])
                check_val($sformatf("MEM: 0x%08X", addr), observed_mem[addr], expected_mem[addr]);

            // 3. Check UART Stream
            if (expected_uart_str != "")
                check_str("UART: Stream", observed_uart_str, expected_uart_str);
        endfunction

        // ----- Check a 32-bit value -----
        function void check_val(string name, logic [31:0] actual, logic [31:0] expected);
            total_tests++;
            if (actual === expected) begin
                pass_count++;
                $display("[PASS] [%0t] %s: 0x%08X", $time, name, actual);
            end else begin
                fail_count++;
                $display("[FAIL] [%0t] %s: Expected=0x%08X Actual=0x%08X",
                         $time, name, expected, actual);
            end
        endfunction

        // Helper: check if haystack contains needle
        function automatic bit str_contains(string haystack, string needle);
            int h_len, n_len;
            h_len = haystack.len();
            n_len = needle.len();
            if (n_len == 0) return 1'b1;
            if (h_len < n_len) return 1'b0;
            for (int i = 0; i <= h_len - n_len; i++) begin
                if (haystack.substr(i, i + n_len - 1) == needle)
                    return 1'b1;
            end
            return 1'b0;
        endfunction

        // ----- Check a string value (exact match or substring) -----
        function void check_str(string name, string actual, string expected);
            total_tests++;
            if (actual == expected || str_contains(actual, expected)) begin
                pass_count++;
                $display("[PASS] [%0t] %s: Found \"%s\"", $time, name, expected);
            end else begin
                fail_count++;
                $display("[FAIL] [%0t] %s: Expected=\"%s\" Actual=\"%s\"",
                         $time, name, expected, actual);
            end
        endfunction

        // ----- End-of-test summary -----
        function void report();
            $display("");
            $display("==================================================");
            $display("              SCOREBOARD SUMMARY                   ");
            $display("==================================================");
            $display("  Total : %0d | Passed : %0d | Failed : %0d",
                     total_tests, pass_count, fail_count);
            $display("==================================================");
            if (fail_count == 0 && total_tests > 0)
                $display("[RESULT] ALL TESTS PASSED");
            else
                $display("[RESULT] SIMULATION FAILED");
            $display("");
        endfunction

    endclass
    
    // ----- Include Component Classes -----
    `include "rv_generator.sv"
    `include "rv_driver.sv"
    `include "rv_monitor.sv"
    `include "rv_environment.sv"

endpackage
