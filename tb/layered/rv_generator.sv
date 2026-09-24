// ============================================================
//  rv_generator.sv — Layered Testbench Generator
//
//  Produces rv_transaction sequences for each test scenario
//  and pushes them into a mailbox consumed by rv_driver.
//
//  Supported tests:
//    alu_test      — ALU arithmetic/logic instructions
//    mem_test      — Load/store memory-access instructions
//    branch_test   — Branch and loop instructions
//    uart_test     — UART TX "Hello, RISC-V!\n" output
//    full_soc_test — Combined ALU + memory + UART test
// ============================================================
class rv_generator;

    // ── Mailbox to driver ────────────────────────────────────
    mailbox #(rv_stim_tx) gen2drv;

    // ── Test selector ────────────────────────────────────────
    string test_name;

    // ── Constructor ──────────────────────────────────────────
    function new(mailbox #(rv_stim_tx) gen2drv, string test_name = "alu_test");
        this.gen2drv   = gen2drv;
        this.test_name = test_name;
    endfunction

    // ── Build / Reconfigure ──────────────────────────────────
    function void build(string test_name);
        this.test_name = test_name;
    endfunction

    // ════════════════════════════════════════════════════════
    //  Main run task — produces stimulus packet for Driver
    // ════════════════════════════════════════════════════════
    task run();
        string test_list[$];

        if (test_name == "all" || test_name == "all_tests") begin
            test_list = '{"alu_test", "mem_test", "branch_test", "uart_test", "full_soc_test"};
        end else begin
            test_list = '{test_name};
        end

        foreach (test_list[i]) begin
            rv_stim_tx tx = new();
            tx.test_name = test_list[i];

            case (test_list[i])
                "alu_test":      tx.hex_file = "assembly_codes/cpu_arithmetic_logic.hex";
                "mem_test":      tx.hex_file = "assembly_codes/cpu_memory_access.hex";
                "branch_test":   tx.hex_file = "assembly_codes/cpu_branches_loops.hex";
                "uart_test":     tx.hex_file = "assembly_codes/uart_tx_hello.hex";
                "full_soc_test": tx.hex_file = "assembly_codes/full_soc_test.hex";
                default: begin
                    $display("[GEN] ERROR: Unknown test_name '%s'", test_list[i]);
                    tx.hex_file = "assembly_codes/cpu_arithmetic_logic.hex";
                end
            endcase

            gen2drv.put(tx);
            $display("[GEN] [%0t] Queued stimulus packet for: %s", $time, test_list[i]);
        end
    endtask

endclass
