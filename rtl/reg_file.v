module reg_file(
    output [31:0] rd1,
    output [31:0] rd2,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] wd,
    input         regwrite,
    input         clk,
    input         reset
);

reg [31:0] regs [0:31];
integer i;

initial begin
   for (i = 0; i < 32; i = i + 1)
       regs[i] = 32'd0;
end

// x0 is hardwired to 0 per RISC-V specification
assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

always @(posedge clk or posedge reset) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] <= 32'd0;
        end
    end else if (regwrite && (rd != 5'd0)) begin
        regs[rd] <= wd;
`ifdef DEBUG_REG_WRITE
        $strobe("WRITE @%0t rd=%0d wd=%h", $time, rd, wd);
`endif
    end
end
endmodule
