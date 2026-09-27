module control_unit(branch,regwrite,memwrite,alu_src,result_src,imm_src,aluop,opcode);
input [6:0]opcode;
output [1:0]aluop, imm_src;
output branch,regwrite,memwrite,alu_src,result_src;
wire [8:0]controls;

assign {alu_src,result_src,imm_src,regwrite,memwrite,branch,aluop} = controls;

assign controls = 
        (opcode == 7'b0110011) ? 9'b0_0_xx_1_0_0_10: // R-type
        (opcode == 7'b0000011) ? 9'b1_1_00_1_0_0_00: // Load (lw)
        (opcode == 7'b0100011) ? 9'b1_x_01_0_1_0_00: // Store (sw)
        (opcode == 7'b1100011) ? 9'b0_x_10_0_0_1_01: // Branch (beq/bne/blt/bge)
        (opcode == 7'b0010011) ? 9'b1_0_00_1_0_0_10: // I-type (addi)
                                 9'bx_x_xx_x_x_x_xx; // default
endmodule
