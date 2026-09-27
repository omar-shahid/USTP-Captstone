module mux(y,sel,a,b);
input sel;
input [31:0]a,b;
output reg [31:0]y;
always@(*)
if (sel)
y=b;
else
y=a;
endmodule