//=============================================================================
// File   : rv_environment.sv
// Author : Auto-generated
// Date   : 2026-09-18
// Desc   : Environment container for the layered RISC-V testbench.
//
//          Instantiates and wires all verification components:
//            rv_generator  → gen2drv mailbox → rv_driver → drv2mon mailbox
//            rv_monitor    (passive, parallel observation)
//            rv_scoreboard (result tracking)
//
//          The build() phase creates mailboxes and component instances.
//          The run()   phase forks gen, drv, and mon tasks, then waits
//          for the monitor's `program_done` event.
//=============================================================================

class rv_environment;

    //=========================================================================
    // Component Handles
    //=========================================================================
    rv_generator  gen;
    rv_driver     drv;
    rv_monitor    mon;
    rv_scoreboard sb;

    //=========================================================================
    // Inter-component Mailboxes
    //   gen2drv : Generator  -> Driver     (Stimulus packets)
    //   mon2sb  : Monitor    -> Scoreboard (Observed events)
    //=========================================================================
    mailbox #(rv_stim_tx)     gen2drv;
    mailbox #(rv_observed_tx) mon2sb;

    //=========================================================================
    // Virtual Interface
    //=========================================================================
    virtual rv_if vif;

    //=========================================================================
    // Constructor
    //=========================================================================
    function new(virtual rv_if vif);
        this.vif = vif;
    endfunction

    //=========================================================================
    // build() – Construct components and wire strictly decoupled mailboxes
    //=========================================================================
    function void build(string test_name);
        // Create mailboxes
        gen2drv = new();
        mon2sb  = new();

        // Instantiate isolated components
        gen = new(gen2drv, test_name);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2sb);
        sb  = new(mon2sb);

        // Scoreboard independently initializes golden expectations for test_name
        sb.build(test_name);

        $display("[ENV] [%0t] Build complete (test = %s)", $time, test_name);
    endfunction

    //=========================================================================
    // run() – Start all components concurrently and wait for test completion
    //=========================================================================
    task run();
        $display("[ENV] [%0t] Starting environment...", $time);

        fork
            gen.run();
            drv.run();
            mon.run();
            sb.run();
        join_none

        // Wait for Scoreboard to finish verifying observed results
        wait (sb.is_done);

        $display("[ENV] [%0t] Test completed.", $time);
    endtask

    //=========================================================================
    // report() – Print scoreboard summary
    //=========================================================================
    function void report();
        sb.report();
    endfunction

endclass
