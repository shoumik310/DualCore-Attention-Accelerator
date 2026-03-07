`timescale 1ns/1ps

module sfp_row_singleCore_tb;

parameter total_cycle = 8;   // how many streamed Q vectors will be processed
parameter bw = 8;            // Q & K vector bit precision
parameter bw_psum = 2*bw+4;  // partial sum bit precision
parameter pr = 16;           // how many products added in each dot product 
parameter col = 8;           // how many dot product units are equipped

integer qk_file ; // file handler
integer qk_scan_file ; // file handler


integer  captured_data;

integer  K[col-1:0][pr-1:0];
integer  Q[total_cycle-1:0][pr-1:0];
integer  result[total_cycle-1:0][col-1:0];
integer  row_sum[total_cycle-1:0];
integer  norm[total_cycle-1:0][col-1:0];

integer i,j,k,t,p,q,x,s,u,m;

reg [col*bw_psum-1:0] sfp_in;
wire [col*bw_psum-1:0] sfp_out;

reg reset = 1;
reg clk = 0;
reg acc = 0;
reg div = 0;

reg [bw_psum-1:0] temp5b;
reg [bw_psum*col-1:0] temp16b;


// TODO: sfp_row_singleCore instance creation here
sfp_row_singleCore #(.bw(bw), .bw_psum(bw_psum), .col(col)) sfp_row_singleCore_instance (
    .clk(clk),
    .acc(acc),
    .div(div),
    .sfp_in(sfp_in),
    .sfp_out(sfp_out)
);


initial begin 

  $dumpfile("sfp_row_singleCore_tb.vcd");
  $dumpvars(0,sfp_row_singleCore_tb);


///// Q data txt reading /////
$display("##### Q data txt reading #####");
  qk_file = $fopen("qdata.txt", "r");

  //// To get rid of first 3 lines in data file ////
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);


  for (q=0; q<total_cycle; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          Q[q][j] = captured_data;
          //$display("%d\n", K[q][j]);
    end
  end
/////////////////////////////////

  for (q=0; q<2; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
  end


///// K data txt reading /////
$display("##### K data txt reading #####");

  for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
  end
  reset = 0;

  qk_file = $fopen("kdata.txt", "r");

  //// To get rid of first 4 lines in data file ////
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);
  qk_scan_file = $fscanf(qk_file, "%s\n", captured_data);


  for (q=0; q<col; q=q+1) begin
    for (j=0; j<pr; j=j+1) begin
          qk_scan_file = $fscanf(qk_file, "%d\n", captured_data);
          K[q][j] = captured_data;
          //$display("##### %d\n", K[q][j]);
    end
  end
/////////////////////////////////


/////////////// Estimated result printing /////////////////


$display("##### Estimated multiplication result #####");

  for (t=0; t<total_cycle; t=t+1) begin
     for (q=0; q<col; q=q+1) begin
       result[t][q] = 0;
     end
  end

  for (t=0; t<total_cycle; t=t+1) begin
     row_sum[t] = 0;
     for (q=0; q<col; q=q+1) begin
         for (k=0; k<pr; k=k+1) begin
            result[t][q] = result[t][q] + Q[t][k] * K[q][k];
         end
         row_sum[t] = row_sum[t] + ((result[t][q] < 0) ? -result[t][q] : result[t][q]); // accumulate sum after each col MAC
     end

     // second loop over q-values to calculate normalized values
     for (x=0; x<col; x=x+1) begin 
        norm[t][x] = ((result[t][x] < 0) ? -result[t][x] : result[t][x]) / row_sum[t];

        temp5b = norm[t][x];
        temp16b = {temp16b[139:0], temp5b};
     end

     //$display("%d %d %d %d %d %d %d %d", result[t][0], result[t][1], result[t][2], result[t][3], result[t][4], result[t][5], result[t][6], result[t][7]);
     $display("norm @cycle%2d: %40h", t, temp16b);
  end

//////////////////////////////////////////////

  $display("##### load rows to sfp_in outputs #####");
  for (s=0; s<total_cycle; s=s+1) begin
    sfp_in[bw_psum*(s+1)-1 : bw_psum*s] = result[t][s];
  end


///// execution of normalization  /////
$display("##### normalize outputs #####");

  for (q=0; q<total_cycle; q=q+1) begin
    #0.5 clk = 1'b0;  
    acc = 1;
    #0.5 clk = 1'b1;  

    #0.5 clk = 1'b0;  
    acc = 0;
    div = 1;
    #0.5 clk = 1'b1; 

    #0.5 clk = 1'b0;  
    div = 0;
    #0.5 clk = 1'b1; 
  end

  #0.5 clk = 1'b0;  
  acc = 0; div = 0;
  #0.5 clk = 1'b1; 

///////////////////////////////////////////

///// display sfp_out /////
$display("##### sfp outputs #####");
  for (u=0; u<total_cycle; u=u+1) begin 
    for (m=0; m<col; m=m+1) begin 
        temp5b = sfp_out[u][m];
        temp16b = {temp16b[139:0], temp5b};
    end

    //$display("%d %d %d %d %d %d %d %d", result[t][0], result[t][1], result[t][2], result[t][3], result[t][4], result[t][5], result[t][6], result[t][7]);
    $display("out @cycle%2d: %40h", u, temp16b);
  end


///////////////////////////////////////////

 for (q=0; q<10; q=q+1) begin
    #0.5 clk = 1'b0;   
    #0.5 clk = 1'b1;   
 end

  #10 $finish;


end

endmodule