// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 

`timescale 1 ns/1 ps

module sram_tb;


`define NULL 0

reg CLK = 0;
reg [3:0]  A_EVEN = 0;
reg [3:0]  A_EVEN_Q = 0;
reg CEN_EVEN = 0;
reg CEN_EVEN_Q = 0;
reg WEN_EVEN = 1;
reg WEN_EVEN_Q = 1;

reg [3:0]  A_ODD = 0;
reg [3:0]  A_ODD_Q = 0;
reg CEN_ODD = 0;
reg CEN_ODD_Q = 0;
reg WEN_ODD = 1;
reg WEN_ODD_Q = 1;

reg [31:0] D = 0;
wire [31:0] Q_EVEN;
wire [31:0] Q_ODD;

integer x_file, x_scan_file ; // file_handler
integer captured_data; 
integer t, i, error;
reg [31:0] D_2D [63:0];

parameter run_cycle = 32;
parameter col = 0;

sram_w16 sram_instance_even (
	.CLK(CLK), 
	.CEN(CEN_EVEN_Q), 
	.WEN(WEN_EVEN_Q),
        .A(A_EVEN_Q), 
        .D(D), 
        .Q(Q_EVEN));

sram_w16 sram_instance_odd (
	.CLK(CLK), 
	.CEN(CEN_ODD_Q), 
	.WEN(WEN_ODD_Q),
        .A(A_ODD_Q), 
        .D(D), 
        .Q(Q_ODD));


initial begin 

  $dumpfile("sram_tb.vcd");
  $dumpvars(0,sram_tb);

  x_file = $fopen("data.txt", "r");

  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);


  #20 CLK = 1'b1;  
  #20 CLK = 1'b0;   WEN_EVEN = 0; 

  #20 CLK = 1'b1; 


  $display("########### Writing EVEN SRAM ############");

  for (t=0; t<run_cycle/2; t=t+1) begin  

    #20 CLK = 1'b0;  A_EVEN = A_EVEN + 1;

    x_scan_file = $fscanf(x_file,"%32b", D);
    D_2D[t][31:0] = D;
    $display("%2d-th written data is %h", t, D);
    
    #20 CLK = 1'b1;
     
    if (t == run_cycle/2-1)
      WEN_EVEN = 1;
  end


  error = 0; 

  #20 CLK = 1'b0;   WEN_EVEN = 1; A_EVEN = 0; 
  #20 CLK = 1'b1;  

  for (t=0; t<run_cycle/2+1 ; t=t+1) begin  

    #20 CLK = 1'b0;   A_EVEN = A_EVEN + 1;

    if (t>0) begin
      if (D_2D[t-1][31:0] == Q_EVEN)
        $display("%2d-th read data is %h --- Data matched", t-1, Q_EVEN);
      else begin
        $display("%2d-th read data is %h --- Data ERROR !!!", t-1, Q_EVEN);
        error = error+1;
      end
    end

    #20 CLK = 1'b1;   

  end

  $display("###### Total %2d errors are detected ######", error);
  #10 $finish;


end

 always @ (posedge CLK) begin
   WEN_EVEN_Q <= WEN_EVEN;
   CEN_EVEN_Q <= CEN_EVEN;
   A_EVEN_Q   <= A_EVEN;
   WEN_ODD_Q <= WEN_ODD;
   CEN_ODD_Q <= CEN_ODD;
   A_ODD_Q   <= A_ODD;
 end

endmodule




