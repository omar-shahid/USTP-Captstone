module clk_div (clk,reset,clk_d);

input clk, reset;
output reg clk_d;
reg [31:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count   <= 0;
            clk_d <= 0;
        end else begin
            count <= count + 1;
            if (count == 99) begin  // small number for fast simulation
                clk_d <= ~clk_d;
                count   <= 0;
            end
        end
    end
endmodule

