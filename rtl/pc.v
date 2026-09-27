module pc(clk,reset,x,out);
input clk,reset;
input [31:0]x;
output reg [31:0]out;

initial
out=0;

always @(posedge clk or posedge reset)
begin 
 if (reset)
 out <= 32'd0;
 else 
 out <= {x[31:1], 1'b0};
end
endmodule

