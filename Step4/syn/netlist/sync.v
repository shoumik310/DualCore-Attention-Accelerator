// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sync #(parameter width=8)(clk, reset, in, out);

input  clk;
input reset;
input [width-1:0] in; 
output [width-1:0] out;

reg [width-1:0] int1; 
reg [width-1:0] int2; 

assign out = int2;

always @ (posedge clk or posedge reset) begin
   if(reset) begin
      int1 <= {(width-1){1'b0}};
      int2 <= {(width-1){1'b0}};
   end else begin
      int1 <= in;
      int2 <= int1;
   end
end

endmodule
