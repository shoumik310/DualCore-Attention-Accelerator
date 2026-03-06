// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 


module fifo_tb;

parameter bw = 4;
parameter width = 1;
parameter total_cycle = 64;

reg clk = 0;
reg rd = 0;
reg wr = 0;
reg  reset = 0;
reg [bw-1:0] w_vector_bin;
wire [bw-1:0] out;
wire full, ready;

integer w_file ; // file handler
integer w_scan_file ; // file handler
integer captured_data;
reg [bw-1:0] in;
integer i; 
integer j; 
integer u; 

integer  w[total_cycle-1:0];



function [3:0] w_bin ;
  input integer  weight ;
  begin

    if (weight>-1)
     w_bin[3] = 0;
    else begin
     w_bin[3] = 1;
     weight = weight + 8;
    end

    if (weight>3) begin
     w_bin[2] = 1;
     weight = weight - 4;
    end
    else 
     w_bin[2] = 0;

    if (weight>1) begin
     w_bin[1] = 1;
     weight = weight - 2;
    end
    else 
     w_bin[1] = 0;

    if (weight>0) 
     w_bin[0] = 1;
    else 
     w_bin[0] = 0;

  end
endfunction


fifo_top #(.bw(bw), .width(width)) fifo_top_instance (
        .clk(clk),
        .in(in), 
        .out(out), 
        .rd(rd),
        .wr(wr), 
        .o_full(full), 
        .reset(reset), 
        .o_ready(ready));

initial begin 

  w_file = $fopen("b_data.txt", "r");  //weight data

  $dumpfile("fifo_tb.vcd");
  $dumpvars(0,fifo_tb);
 
  #1 clk = 1'b0; reset = 1; 
  #1 clk = 1'b1; reset = 0; 
  #1 clk = 1'b0;

  $display("-------------------- 1st Computation start --------------------");
  
  wr = 1;
  for (i=0; i<total_cycle; i=i+1) begin

     w_scan_file = $fscanf(w_file, "%d\n", captured_data);
     w[i] = captured_data;
     in = w_bin(w[i]);  

     #1 clk = 1'b1;
     #1 clk = 1'b0;

  end

  wr = 0;
  #1 clk = 1'b1;
  #1 clk = 1'b0;


  rd = 1;

  for (i=0; i<total_cycle; i=i+1) begin
     #1 clk = 1'b1;
     #1 clk = 1'b0;
  end
  rd = 0;

  $display("-------------------- 1st Computation completed --------------------");


 
  $display("-------------------- 2nd Computation start --------------------");
  
  wr = 1;
  for (i=0; i<total_cycle; i=i+1) begin

     w_scan_file = $fscanf(w_file, "%d\n", captured_data);
     w[i] = captured_data;
     in = w_bin(w[i]);  

     #1 clk = 1'b1;
     #1 clk = 1'b0;

  end

  wr = 0;
  #1 clk = 1'b1;
  #1 clk = 1'b0;


  rd = 1;

  for (i=0; i<total_cycle; i=i+1) begin
     #1 clk = 1'b1;
     #1 clk = 1'b0;
  end
  rd = 0;

  $display("-------------------- 2nd Computation completed --------------------");

 


  #10 $finish;


end

endmodule





