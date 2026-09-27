module imm_ext(imm_out,imm_src,inst);
input [1:0]imm_src;
input [31:0]inst;
output reg [31:0]imm_out;

always @(*) begin
    case (imm_src)
        2'b00: begin
            imm_out = {{20{inst[31]}}, inst[31:20]}; // I-Type
        end
        
        2'b01: begin
            imm_out = {{20{inst[31]}}, inst[31:25], inst[11:7]}; //S-Type
        end
        
        2'b10: begin
          imm_out = {{20{inst[31]}},inst[7],inst[30:25], inst[11:8], 1'b0}; //B-Type
        end

        2'b11: begin
          imm_out = {{12{inst[31]}},inst[19:12], inst[20], inst[30:21], 1'b0}; //J-Type
        end
        
        default: imm_out = 32'b0;
    endcase
end

endmodule

