// ============================================================
//  risc_v_isa_tb.v -- Comprehensive Self-Checking ISA & Unit Testbench
//
//  Tests:
//    1. ALU operations (ADD, SUB, AND, OR, SLT, SLL, SRL, SRA, Zero flag)
//    2. Arithmetic extrema, signed overflows, negative numbers, shift boundaries
//    3. Immediate extension (I, S, B, J types with positive & negative signs)
//    4. Control Unit & ALU Control decoding (R, I, S, B types, branch logic)
//    5. Register file (x0 zero hardwiring, write-enable, read/write isolation)
//    6. Data memory word writes and reads
// ============================================================
`timescale 1ns/1ps

module risc_v_isa_tb;

    integer pass_count  = 0;
    integer fail_count  = 0;
    integer total_tests = 0;

    // ── Helper check task ─────────────────────────────────────
    task check_32(input string name, input [31:0] actual, input [31:0] expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: Value = 0x%08X", $time, name, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = 0x%08X, Actual = 0x%08X", $time, name, expected, actual);
        end
    endtask

    task check_1(input string name, input actual, input expected);
        total_tests = total_tests + 1;
        if (actual === expected) begin
            pass_count = pass_count + 1;
            $display("[PASS] [%0t] %s: Value = %b", $time, name, actual);
        end else begin
            fail_count = fail_count + 1;
            $display("[FAIL] [%0t] %s: Expected = %b, Actual = %b", $time, name, expected, actual);
        end
    endtask

    // ── Watchdog Timer ────────────────────────────────────────
    initial begin
        #1_000_000;
        $display("[ERROR] [%0t] Simulation watchdog timeout reached!", $time);
        $finish;
    end

    // ── DUT Signals for Submodules ────────────────────────────
    // ALU
    reg  [31:0] alu_a, alu_b;
    reg  [ 2:0] alu_ctrl;
    wire [31:0] alu_out;
    wire        alu_zero;
    alu U_ALU (
        .result(alu_out),
        .zero(alu_zero),
        .a(alu_a),
        .b(alu_b),
        .alu_control(alu_ctrl)
    );

    // Immediate Extender
    reg  [ 1:0] imm_src;
    reg  [31:0] imm_inst;
    wire [31:0] imm_out;
    imm_ext U_IMM (
        .imm_out(imm_out),
        .imm_src(imm_src),
        .inst(imm_inst)
    );

    // Control Unit
    reg  [ 6:0] cu_opcode;
    reg  [ 2:0] cu_fun3;
    reg         cu_fun7, cu_zero;
    wire        cu_alu_src, cu_result_src, cu_regwrite, cu_memwrite, cu_pc_src;
    wire [ 1:0] cu_imm_src;
    wire [ 2:0] cu_alu_control;
    cu U_CU (
        .alu_src(cu_alu_src),
        .result_src(cu_result_src),
        .regwrite(cu_regwrite),
        .memwrite(cu_memwrite),
        .pc_src(cu_pc_src),
        .imm_src(cu_imm_src),
        .alu_control(cu_alu_control),
        .opcode(cu_opcode),
        .fun3(cu_fun3),
        .fun7(cu_fun7),
        .zero(cu_zero)
    );

    // Register File
    reg         rf_clk, rf_regwrite, rf_reset;
    reg  [ 4:0] rf_rs1, rf_rs2, rf_rd;
    reg  [31:0] rf_wd;
    wire [31:0] rf_rd1, rf_rd2;
    reg_file U_RF (
        .rd1(rf_rd1),
        .rd2(rf_rd2),
        .rs1(rf_rs1),
        .rs2(rf_rs2),
        .rd(rf_rd),
        .wd(rf_wd),
        .regwrite(rf_regwrite),
        .clk(rf_clk),
        .reset(rf_reset)
    );

    // Data Memory
    reg         dm_clk, dm_memwrite;
    reg  [31:0] dm_addr, dm_wd;
    wire [31:0] dm_rd;
    data_mem U_DM (
        .rd(dm_rd),
        .clk(dm_clk),
        .memwrite(dm_memwrite),
        .addr(dm_addr),
        .wd(dm_wd)
    );

    // Clocks
    initial begin
        rf_clk = 0;
        dm_clk = 0;
        forever #5 begin
            rf_clk = ~rf_clk;
            dm_clk = ~dm_clk;
        end
    end

    // ── Main Test Process ─────────────────────────────────────
    initial begin
        $display("\n==================================================");
        $display("STARTING COMPREHENSIVE RISC-V ISA & UNIT TESTBENCH");
        $display("==================================================\n");

        #10;

        // ════════════════════════════════════════════════════════
        // TEST GROUP 1: ALU Operations & Edge Cases
        // ════════════════════════════════════════════════════════
        $display("[INFO] [%0t] --- Test Group 1: ALU Operations ---", $time);

        // ADD
        alu_ctrl = 3'd0; alu_a = 32'd15; alu_b = 32'd27; #1;
        check_32("ALU ADD (15 + 27)", alu_out, 32'd42);
        check_1 ("ALU Zero flag (15 != 27)", alu_zero, 1'b0);

        alu_a = 32'hFFFF_FFFF; alu_b = 32'd1; #1; // -1 + 1 = 0
        check_32("ALU ADD (-1 + 1 overflow to 0)", alu_out, 32'h0000_0000);
        check_1 ("ALU Zero flag (a != b)", alu_zero, 1'b0);

        alu_a = 32'h7FFF_FFFF; alu_b = 32'd1; #1; // INT_MAX + 1 = INT_MIN
        check_32("ALU ADD (INT_MAX + 1)", alu_out, 32'h8000_0000);

        // SUB
        alu_ctrl = 3'd1; alu_a = 32'd100; alu_b = 32'd40; #1;
        check_32("ALU SUB (100 - 40)", alu_out, 32'd60);

        alu_a = 32'd55; alu_b = 32'd55; #1; // a == b -> result 0, zero=1
        check_32("ALU SUB (55 - 55)", alu_out, 32'd0);
        check_1 ("ALU Zero flag (55 == 55)", alu_zero, 1'b1);

        alu_a = 32'd10; alu_b = 32'd20; #1; // 10 - 20 = -10 (0xFFFF_FFF6)
        check_32("ALU SUB (10 - 20 = -10)", alu_out, 32'hFFFF_FFF6);

        // AND
        alu_ctrl = 3'd2; alu_a = 32'hAAAA_5555; alu_b = 32'hFFFF_0000; #1;
        check_32("ALU AND bitwise", alu_out, 32'hAAAA_0000);

        // OR
        alu_ctrl = 3'd3; alu_a = 32'hAAAA_0000; alu_b = 32'h0000_5555; #1;
        check_32("ALU OR bitwise", alu_out, 32'hAAAA_5555);

        // SLT (Signed comparison)
        alu_ctrl = 3'd4;
        alu_a = 32'hFFFF_FFFE; alu_b = 32'd5; #1; // -2 < 5 -> 1
        check_32("ALU SLT (-2 < 5)", alu_out, 32'd1);

        alu_a = 32'd5; alu_b = 32'hFFFF_FFFE; #1; // 5 < -2 -> 0
        check_32("ALU SLT (5 < -2)", alu_out, 32'd0);

        alu_a = 32'h8000_0000; alu_b = 32'h7FFF_FFFF; #1; // INT_MIN < INT_MAX -> 1
        check_32("ALU SLT (INT_MIN < INT_MAX)", alu_out, 32'd1);

        alu_a = 32'd10; alu_b = 32'd10; #1; // 10 < 10 -> 0
        check_32("ALU SLT (10 < 10)", alu_out, 32'd0);

        // SLL (Shift Left Logical)
        alu_ctrl = 3'd5; alu_a = 32'h0000_0001; alu_b = 32'd4; #1;
        check_32("ALU SLL (1 << 4)", alu_out, 32'h0000_0010);

        alu_a = 32'h0000_0001; alu_b = 32'd31; #1;
        check_32("ALU SLL (1 << 31)", alu_out, 32'h8000_0000);

        alu_a = 32'h0000_0001; alu_b = 32'd36; #1; // Shift amount wraps to 4 (36 & 0x1F = 4)
        check_32("ALU SLL (1 << (36&0x1F))", alu_out, 32'h0000_0010);

        // SRL (Shift Right Logical)
        alu_ctrl = 3'd6; alu_a = 32'h8000_0000; alu_b = 32'd4; #1;
        check_32("ALU SRL (0x8000_0000 >> 4)", alu_out, 32'h0800_0000);

        // SRA (Shift Right Arithmetic - Sign Preserved)
        alu_ctrl = 3'd7; alu_a = 32'h8000_0000; alu_b = 32'd4; #1;
        check_32("ALU SRA (0x8000_0000 >>> 4)", alu_out, 32'hF800_0000);

        alu_a = 32'h7000_0000; alu_b = 32'd4; #1;
        check_32("ALU SRA positive (0x7000_0000 >>> 4)", alu_out, 32'h0700_0000);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 2: Immediate Extension
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 2: Immediate Extension ---", $time);

        // I-type positive: imm = 42 (0x02A)
        imm_src = 2'b00; imm_inst = {12'h02A, 5'd1, 3'b000, 5'd2, 7'b0010011}; #1;
        check_32("IMM I-type (+42)", imm_out, 32'd42);

        // I-type negative: imm = -4 (0xFFC)
        imm_inst = {12'hFFC, 5'd1, 3'b000, 5'd2, 7'b0010011}; #1;
        check_32("IMM I-type (-4)", imm_out, 32'hFFFF_FFFC);

        // S-type: imm = 0x14 (20) -> imm[11:5]=0, imm[4:0]=20 (0x14)
        imm_src = 2'b01; imm_inst = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'b10100, 7'b0100011}; #1;
        check_32("IMM S-type (+20)", imm_out, 32'd20);

        // S-type negative: imm = -20 (0xFE0) -> imm[11:5]=7'b1111111, imm[4:0]=5'b01100
        imm_inst = {7'b1111111, 5'd2, 5'd1, 3'b010, 5'b01100, 7'b0100011}; #1;
        check_32("IMM S-type (-20)", imm_out, 32'hFFFF_FFEC);

        // B-type: branch offset = -4 -> imm[12]=1, imm[11]=1, imm[10:5]=6'b111111, imm[4:1]=4'b1110, imm[0]=0
        // inst[31]=1, inst[7]=1, inst[30:25]=6'b111111, inst[11:8]=4'b1110
        imm_src = 2'b10;
        imm_inst = {1'b1, 6'b111111, 5'd3, 5'd0, 3'b000, 4'b1110, 1'b1, 7'b1100011}; #1;
        check_32("IMM B-type (-4)", imm_out, 32'hFFFF_FFFC);

        // J-type: offset = 40 (0x28) -> imm[20]=0, imm[19:12]=0, imm[11]=0, imm[10:1]=20 (0x14)
        imm_src = 2'b11;
        imm_inst = {1'b0, 10'd20, 1'b0, 8'd0, 5'd1, 7'b1101111}; #1;
        check_32("IMM J-type (+40)", imm_out, 32'd40);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 3: Control Unit & Decoder
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 3: Control Unit ---", $time);

        // R-type: ADD
        cu_opcode = 7'b0110011; cu_fun3 = 3'b000; cu_fun7 = 1'b0; cu_zero = 1'b0; #1;
        check_1 ("CU R-type ADD regwrite", cu_regwrite, 1'b1);
        check_1 ("CU R-type ADD memwrite", cu_memwrite, 1'b0);
        check_1 ("CU R-type ADD alu_src", cu_alu_src, 1'b0);
        check_32("CU R-type ADD alu_control", {29'b0, cu_alu_control}, 32'd0);

        // R-type: SUB
        cu_fun7 = 1'b1; #1;
        check_32("CU R-type SUB alu_control", {29'b0, cu_alu_control}, 32'd1);

        // I-type: ADDI with positive immediate
        cu_opcode = 7'b0010011; cu_fun3 = 3'b000; cu_fun7 = 1'b0; #1;
        check_1 ("CU ADDI regwrite", cu_regwrite, 1'b1);
        check_1 ("CU ADDI alu_src (use imm)", cu_alu_src, 1'b1);
        check_32("CU ADDI alu_control (must be ADD)", {29'b0, cu_alu_control}, 32'd0);

        // I-type: ADDI with inst[30]=1 (e.g. negative immediate) must NOT become SUB
        cu_fun7 = 1'b1; #1;
        check_32("CU ADDI with bit30=1 alu_control (must remain ADD)", {29'b0, cu_alu_control}, 32'd0);

        // Load: LW
        cu_opcode = 7'b0000011; cu_fun3 = 3'b010; #1;
        check_1 ("CU LW regwrite", cu_regwrite, 1'b1);
        check_1 ("CU LW result_src (from mem)", cu_result_src, 1'b1);
        check_1 ("CU LW alu_src", cu_alu_src, 1'b1);

        // Store: SW
        cu_opcode = 7'b0100011; cu_fun3 = 3'b010; #1;
        check_1 ("CU SW regwrite", cu_regwrite, 1'b0);
        check_1 ("CU SW memwrite", cu_memwrite, 1'b1);
        check_1 ("CU SW alu_src", cu_alu_src, 1'b1);

        // Branch: BEQ taken vs not taken
        cu_opcode = 7'b1100011; cu_fun3 = 3'b000; cu_zero = 1'b1; #1;
        check_1 ("CU BEQ taken pc_src", cu_pc_src, 1'b1);

        cu_zero = 1'b0; #1;
        check_1 ("CU BEQ not taken pc_src", cu_pc_src, 1'b0);

        // Branch: BNE taken vs not taken
        cu_fun3 = 3'b001; cu_zero = 1'b0; #1;
        check_1 ("CU BNE taken pc_src", cu_pc_src, 1'b1);

        cu_zero = 1'b1; #1;
        check_1 ("CU BNE not taken pc_src", cu_pc_src, 1'b0);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 4: Register File
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 4: Register File ---", $time);

        // Reset RF
        rf_reset = 1'b1; rf_regwrite = 1'b0; #10;
        rf_reset = 1'b0; #5;

        // Write to x1
        @(negedge rf_clk);
        rf_regwrite = 1'b1; rf_rd = 5'd1; rf_wd = 32'hCAFE_BABE;
        @(posedge rf_clk);
        #1;
        rf_regwrite = 1'b0; rf_rs1 = 5'd1; #1;
        check_32("RF Read x1 after write", rf_rd1, 32'hCAFE_BABE);

        // Write to x0 (should NOT modify x0, x0 remains 0)
        @(negedge rf_clk);
        rf_regwrite = 1'b1; rf_rd = 5'd0; rf_wd = 32'hDEAD_BEEF;
        @(posedge rf_clk);
        #1;
        rf_regwrite = 1'b0; rf_rs1 = 5'd0; #1;
        check_32("RF Read x0 (must remain 0)", rf_rd1, 32'd0);

        // Write to x5 and x6, read both ports simultaneously
        @(negedge rf_clk);
        rf_regwrite = 1'b1; rf_rd = 5'd5; rf_wd = 32'h1234_5678;
        @(posedge rf_clk);
        @(negedge rf_clk);
        rf_rd = 5'd6; rf_wd = 32'h8765_4321;
        @(posedge rf_clk);
        #1;
        rf_regwrite = 1'b0; rf_rs1 = 5'd5; rf_rs2 = 5'd6; #1;
        check_32("RF Dual read rs1 (x5)", rf_rd1, 32'h1234_5678);
        check_32("RF Dual read rs2 (x6)", rf_rd2, 32'h8765_4321);

        // ════════════════════════════════════════════════════════
        // TEST GROUP 5: Data Memory
        // ════════════════════════════════════════════════════════
        $display("\n[INFO] [%0t] --- Test Group 5: Data Memory ---", $time);

        // Write word to addr 0x04
        @(negedge dm_clk);
        dm_memwrite = 1'b1; dm_addr = 32'h04; dm_wd = 32'hA5A5_5A5A;
        @(posedge dm_clk);
        @(negedge dm_clk);
        dm_memwrite = 1'b0; dm_addr = 32'h04;
        #1;
        check_32("DM Read written word at 0x04", dm_rd, 32'hA5A5_5A5A);

        // Write word to addr 0x10
        @(negedge dm_clk);
        dm_memwrite = 1'b1; dm_addr = 32'h10; dm_wd = 32'h1122_3344;
        @(posedge dm_clk);
        @(negedge dm_clk);
        dm_memwrite = 1'b0; dm_addr = 32'h10;
        #1;
        check_32("DM Read written word at 0x10", dm_rd, 32'h1122_3344);

        // Check addr 0x04 is still intact
        dm_addr = 32'h04; #1;
        check_32("DM Verify addr 0x04 intact", dm_rd, 32'hA5A5_5A5A);

        // ════════════════════════════════════════════════════════
        // FINAL SUMMARY
        // ════════════════════════════════════════════════════════
        #20;
        $display("\n=================================");
        $display("SIMULATION SUMMARY: RISC-V ISA & Units");
        $display("Total Tests: %0d", total_tests);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("=================================\n");

        if (fail_count == 0 && total_tests > 0)
            $display("[RESULT] ALL TESTS PASSED");
        else
            $display("[RESULT] SIMULATION FAILED");

        $finish;
    end

endmodule

