module sfp_row_singleCore (clk, acc, div, sfp_in, sfp_out);

  parameter col = 8;
  parameter bw = 8;
  parameter bw_psum = 2*bw+4;

 
  input  clk, div, acc;
  input  [col*bw_psum-1:0] sfp_in;
  wire  [col*bw_psum-1:0] abs;
  output [col*bw_psum-1:0] sfp_out;

  reg signed [bw_psum-1:0] sfp_out_reg0;
  reg signed [bw_psum-1:0] sfp_out_reg1;
  reg signed [bw_psum-1:0] sfp_out_reg2;
  reg signed [bw_psum-1:0] sfp_out_reg3;
  reg signed [bw_psum-1:0] sfp_out_reg4;
  reg signed [bw_psum-1:0] sfp_out_reg5;
  reg signed [bw_psum-1:0] sfp_out_reg6;
  reg signed [bw_psum-1:0] sfp_out_reg7;

  reg [col*bw_psum-1:0] abs_q;
  reg [bw_psum+3:0] sum_q;

  assign abs[bw_psum*1-1 : bw_psum*0] = (sfp_in[bw_psum*1-1]) ?  (~sfp_in[bw_psum*1-1 : bw_psum*0] + 1)  :  sfp_in[bw_psum*1-1 : bw_psum*0];
  assign abs[bw_psum*2-1 : bw_psum*1] = (sfp_in[bw_psum*2-1]) ?  (~sfp_in[bw_psum*2-1 : bw_psum*1] + 1)  :  sfp_in[bw_psum*2-1 : bw_psum*1];
  assign abs[bw_psum*3-1 : bw_psum*2] = (sfp_in[bw_psum*3-1]) ?  (~sfp_in[bw_psum*3-1 : bw_psum*2] + 1)  :  sfp_in[bw_psum*3-1 : bw_psum*2];
  assign abs[bw_psum*4-1 : bw_psum*3] = (sfp_in[bw_psum*4-1]) ?  (~sfp_in[bw_psum*4-1 : bw_psum*3] + 1)  :  sfp_in[bw_psum*4-1 : bw_psum*3];
  assign abs[bw_psum*5-1 : bw_psum*4] = (sfp_in[bw_psum*5-1]) ?  (~sfp_in[bw_psum*5-1 : bw_psum*4] + 1)  :  sfp_in[bw_psum*5-1 : bw_psum*4];
  assign abs[bw_psum*6-1 : bw_psum*5] = (sfp_in[bw_psum*6-1]) ?  (~sfp_in[bw_psum*6-1 : bw_psum*5] + 1)  :  sfp_in[bw_psum*6-1 : bw_psum*5];
  assign abs[bw_psum*7-1 : bw_psum*6] = (sfp_in[bw_psum*7-1]) ?  (~sfp_in[bw_psum*7-1 : bw_psum*6] + 1)  :  sfp_in[bw_psum*7-1 : bw_psum*6];
  assign abs[bw_psum*8-1 : bw_psum*7] = (sfp_in[bw_psum*8-1]) ?  (~sfp_in[bw_psum*8-1 : bw_psum*7] + 1)  :  sfp_in[bw_psum*8-1 : bw_psum*7];

  assign sfp_out[bw_psum*1-1 : bw_psum*0] = sfp_out_reg0;
  assign sfp_out[bw_psum*2-1 : bw_psum*1] = sfp_out_reg1;
  assign sfp_out[bw_psum*3-1 : bw_psum*2] = sfp_out_reg2;
  assign sfp_out[bw_psum*4-1 : bw_psum*3] = sfp_out_reg3;
  assign sfp_out[bw_psum*5-1 : bw_psum*4] = sfp_out_reg4;
  assign sfp_out[bw_psum*6-1 : bw_psum*5] = sfp_out_reg5;
  assign sfp_out[bw_psum*7-1 : bw_psum*6] = sfp_out_reg6;
  assign sfp_out[bw_psum*8-1 : bw_psum*7] = sfp_out_reg7;

  always @ (posedge clk) begin
    if (acc) begin
        sum_q <= 
            {4'b0, abs[bw_psum*1-1 : bw_psum*0]} +
            {4'b0, abs[bw_psum*2-1 : bw_psum*1]} +
            {4'b0, abs[bw_psum*3-1 : bw_psum*2]} +
            {4'b0, abs[bw_psum*4-1 : bw_psum*3]} +
            {4'b0, abs[bw_psum*5-1 : bw_psum*4]} +
            {4'b0, abs[bw_psum*6-1 : bw_psum*5]} +
            {4'b0, abs[bw_psum*7-1 : bw_psum*6]} +
            {4'b0, abs[bw_psum*8-1 : bw_psum*7]} ;
        abs_q <= abs;
    end
    else begin
        if (div) begin
            sfp_out_reg0 <= (abs_q[bw_psum*1-1 : bw_psum*0] << 8) / sum_q;
            sfp_out_reg1 <= (abs_q[bw_psum*2-1 : bw_psum*1] << 8) / sum_q;
            sfp_out_reg2 <= (abs_q[bw_psum*3-1 : bw_psum*2] << 8) / sum_q;
            sfp_out_reg3 <= (abs_q[bw_psum*4-1 : bw_psum*3] << 8) / sum_q;
            sfp_out_reg4 <= (abs_q[bw_psum*5-1 : bw_psum*4] << 8) / sum_q;
            sfp_out_reg5 <= (abs_q[bw_psum*6-1 : bw_psum*5] << 8) / sum_q;
            sfp_out_reg6 <= (abs_q[bw_psum*7-1 : bw_psum*6] << 8) / sum_q;
            sfp_out_reg7 <= (abs_q[bw_psum*8-1 : bw_psum*7] << 8) / sum_q;
        end
    end
 end

endmodule