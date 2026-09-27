module alu_control(alu_control, aluop, fun3, fun7);
input [1:0] aluop;
input [2:0] fun3;
input fun7;
output reg [2:0] alu_control;

always @(*) begin
    case (aluop)
        2'b00: alu_control = 3'd0; // Load/Store => ADD
        2'b01: begin // Branch: use SUB for BEQ (compare)
            case(fun3)
                3'b000: alu_control = 3'd1; // BEQ => SUB
                3'b001: alu_control = 3'd1; // BNE => SUB 
                3'b100: alu_control = 3'd4; // BLT => SLT
                3'b101: alu_control = 3'd1; // BGE => SUB 
                default: alu_control = 3'd0;
            endcase
        end
        2'b10: begin  // R-type
            case(fun3)
                3'b000: alu_control = fun7 ? 3'd1 : 3'd0; // SUB/ADD
                3'b111: alu_control = 3'd2; // AND
                3'b110: alu_control = 3'd3; // OR
                3'b100: alu_control = 3'd4; // SLT
                3'b001: alu_control = 3'd5; // SLL
                3'b101: alu_control = fun7 ? 3'd7 : 3'd6; // SRA:SRL
                default: alu_control = 3'd0;
            endcase
        end
        default: alu_control = 3'd0;
    endcase
end

endmodule
