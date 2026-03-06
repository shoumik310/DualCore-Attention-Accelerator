module async_fifo #(
    parameter bw = 8,
    parameter depth = 64
)(data_in, wr_en, wr_clk, wr_rst, full, data_out, rd_en, rd_clk, rd_rst, empty);

    input wire [bw-1:0] data_in;
    input wire wr_en;
    input wire wr_clk;
    input wire wr_rst;
    output wire full;

    output wire [bw-1:0] data_out;
    input wire rd_en;
    input wire rd_clk;
    input wire rd_rst;
    output wire empty;

    localparam addr_width = $clog2(depth);
    reg[bw-1:0] data [0:depth-1];

    reg[addr_width:0] wr_ptr_bin, wr_ptr_gray;
    reg[addr_width:0] rd_ptr_bin, rd_ptr_gray;

    wire[addr_width:0] wr_ptr_gray_sync, rd_ptr_gray_sync;
    wire[addr_width:0] wr_ptr_bin_sync, rd_ptr_bin_sync;

    // wire[addr_width:0] wr_ptr_bin_next = wr_ptr_bin+1;
    // wire[addr_width:0] rd_ptr_bin_next = rd_ptr_bin+1;

    sync #(.width(addr_width+1)) rd_sync 
        (.clk(wr_clk), .reset(wr_rst), 
        .in(rd_ptr_gray), .out(rd_ptr_gray_sync));

    sync #(.width(addr_width+1)) wr_sync 
        (.clk(rd_clk), .reset(rd_rst), 
        .in(wr_ptr_gray), .out(wr_ptr_gray_sync));

    always @ (posedge wr_clk or posedge wr_rst) begin
        if(wr_rst) begin
            wr_ptr_bin <= {addr_width{1'b0}};
            wr_ptr_gray <= {addr_width{1'b0}};
        end 
        else begin
            if (wr_en && !full) begin
                data[wr_ptr_bin[addr_width-1:0]] <= data_in;
                wr_ptr_bin <= wr_ptr_bin+1;
                wr_ptr_gray <= (wr_ptr_bin+1)^((wr_ptr_bin+1)>>1);
            end
        end
    end

    always @ (posedge rd_clk or posedge rd_rst) begin
        if(rd_rst) begin
            rd_ptr_bin <= {addr_width{1'b0}};
            rd_ptr_gray <= {addr_width{1'b0}};
            // data_out <= {bw{1'b0}};
        end 
        else begin
            if (rd_en && !empty) begin
                // data_out <= data[rd_ptr_bin[addr_width-1:0]];
                rd_ptr_bin <= rd_ptr_bin+1;
                rd_ptr_gray <= (rd_ptr_bin+1)^((rd_ptr_bin+1)>>1);
            end
        end
    end

    function automatic [addr_width:0] gray_to_bin;
    input [addr_width:0] gray;
    integer i;
    begin
        gray_to_bin[addr_width] = gray[addr_width];
        for(i = addr_width-1; i >=0; i = i-1)
            gray_to_bin[i] = gray_to_bin[i+1] ^ gray[i]; 
    end    
    endfunction

    assign data_out = data[rd_ptr_bin[addr_width-1:0]];

    assign wr_ptr_bin_sync = gray_to_bin(wr_ptr_gray_sync);
    assign rd_ptr_bin_sync = gray_to_bin(rd_ptr_gray_sync);

    assign empty = rd_ptr_bin[addr_width-1:0] == wr_ptr_bin_sync[addr_width-1:0];
    assign full = (wr_ptr_bin[addr_width] != rd_ptr_bin_sync[addr_width]) && (wr_ptr_bin[addr_width-1:0] == rd_ptr_bin_sync[addr_width-1:0]);

endmodule