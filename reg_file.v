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
        $strobe("WRITE @%0t rd=%0d wd=%h", $time, rd, wd);
    end
end
endmodule

module reg_file_tb;
reg [4:0] rs1, rs2, rd;
reg clk, regwrite, reset;
reg [31:0] wd;
wire [31:0] rd1, rd2;

reg_file REG(
    .rd1(rd1),
    .rd2(rd2),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(wd),
    .regwrite(regwrite),
    .clk(clk),
    .reset(reset)
);

initial clk = 0;
always #5 clk = ~clk;

initial begin
reset = 1;
regwrite = 1'b0;
wd = 0; rd = 0; rs1 = 0; rs2 = 0;
#15 reset = 0;
regwrite = 1'b1;
wd = 32'hA4562D47; rd = 5'd6; #10;  // write to x6
rs1 = 5'd6;

wd = 32'hDEADBEEF; rd = 5'd4; rs2 = 5'd4; #10; // write to x4
regwrite = 1'b0;
wd = 32'h12345678; rd = 5'd5; rs1 = 5'd5; rs2 = 5'd4; #10; // no write

regwrite = 1'b1;
wd = 32'hCAFEBABE; rd = 5'd7; #10; // write to x7
rs1 = 5'd7; rs2 = 5'd6; #10;

$stop;
end
initial
$monitor("t=%0t | rs1=%0d rd1=%h | rs2=%0d rd2=%h",$time, rs1, rd1, rs2, rd2);
endmodule
