module cu(alu_src,result_src,regwrite,memwrite,pc_src,imm_src,alu_control,opcode,fun3,fun7,zero);

input [6:0] opcode;
input zero,fun7;
input [2:0] fun3;
output [2:0] alu_control;
output [1:0] imm_src;
output result_src,memwrite,alu_src,regwrite,pc_src;
wire branch;
wire [1:0] aluop;

control_unit C1(branch, regwrite, memwrite, alu_src, result_src, imm_src, aluop, opcode);

wire fun7_eff = (fun3 == 3'b101) ? fun7 : (fun7 & opcode[5]);
alu_control C2(alu_control, aluop, fun3, fun7_eff);

// Branch condition decode (using funct3)
// fun3 000 = BEQ  : take when  zero (a == b)
// fun3 001 = BNE  : take when !zero (a != b)
wire beq_taken = (fun3 == 3'b000) &&  zero;
wire bne_taken = (fun3 == 3'b001) && !zero;
assign pc_src = branch && (beq_taken || bne_taken);

endmodule
