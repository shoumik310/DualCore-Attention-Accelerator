class transaction #(parameter bw = 8);
    rand bit [bw-1:0] data;

    rand bit wr_en;
    rand bit rd_en;

    bit [bw-1:0] exp_data;
    bit force_write;
    bit force_read;

    function new();
        data = 'b0;
        wr_en = 'b0;
        rd_en = 'b0;
        exp_data = 'b0;        
    endfunction

    function void display(string tag = "");
        $display("[%0s] TX: wr_en = %0b, rd_en = %0b, data = 0x%0b, expected = 0x%0b",
                tag, wr_en, rd_en, data, exp_data);
    endfunction

    function transaction #(bw) copy();
        transaction #(bw) t = new();
        t.data = this.data;
        t.wr_en = this.wr_en;
        t.rd_en = this.rd_en;
        t.exp_data =  this.exp_data;
        return t;
    endfunction

    function bit compare(transaction t);
        return this.data == t.data;    
    endfunction

endclass

class generator #(parameter bw = 8);
    bit random_mode;
    transaction #(bw) t_queue[$];
    event gen_done;
    mailbox #(transaction #(bw)) g2d_mbx;
    // event drv_done;
    int num_transaction = 10;

    function new(mailbox #(transaction #(bw)) mbx);
        this.g2d_mbx = mbx;
        this.random_mode = 1;
    endfunction

    task add_transaction(transaction #(bw) tr) ;
        t_queue.push_back(tr);
    endtask

    task run();
        transaction #(bw) tr;
        if(random_mode) begin
            $display("[Gen] Running random mode");
            repeat(num_transaction) begin
                tr = new();
                assert(tr.randomize() with {wr_en || rd_en;});
                tr.display("GEN");
                g2d_mbx.put(tr);
            end
        end else begin
            $display("[Gen] Running testcase mode");
            while (t_queue.size() > 0) begin
                transaction #(bw) tr;
                tr = t_queue.pop_front(); 
                tr.display("GEN");
                g2d_mbx.put(tr); 
            end
        end
        ->gen_done; 
        $display("[GEN] All transactions pushed to mailbox at %0t", $time);
    endtask

endclass


class driver #(parameter bw = 8);
    virtual afifo_if #(bw) w_vif;
    virtual afifo_if #(bw) r_vif;
    mailbox #(transaction #(bw)) g2d_mbx;

    function new(virtual afifo_if #(bw).wr_drv w_vif,
                virtual afifo_if #(bw).rd_drv r_vif, 
                mailbox #(transaction #(bw)) mbx);
        this.w_vif = w_vif;
        this.r_vif = r_vif;
        this.g2d_mbx = mbx;
    endfunction

    task run();
        transaction #(bw) tr;
        forever begin
            g2d_mbx.get(tr);

            fork
                begin : write_process
                    if (tr.wr_en) drive_write(tr);
                end
                begin : read_process
                    if (tr.rd_en) drive_read(tr);
                end
            join
        end
    endtask

   task drive_write(transaction #(bw) tr);
        if (tr.wr_en) begin
            
            // Wait for reset to be low before starting
            wait(w_vif.wr_rst == 0); 
            
            // Respect Full flag unless force_write is set
            if (!tr.force_write) begin
                while(w_vif.full) @(w_vif.wr_cb);
            end

            @(w_vif.wr_cb);
            w_vif.wr_cb.wr_en <= 1'b1;
            w_vif.wr_cb.data_in <= tr.data;
            @(w_vif.wr_cb);
            w_vif.wr_cb.wr_en <= 1'b0;
            
            $display("[DRV] Write: Data: 0x%0h @ %0t", tr.data, $time);
        end
    endtask
    

    task drive_read(transaction #(bw) tr);
        if (tr.rd_en) begin
            wait(r_vif.rd_rst == 0);
            
            if (!tr.force_read) begin
                while(r_vif.empty) @(r_vif.rd_cb);
            end

            @(r_vif.rd_cb);
            r_vif.rd_cb.rd_en <= 1'b1;
            @(r_vif.rd_cb);
            r_vif.rd_cb.rd_en <= 1'b0;
            $display("[DRV] Read Triggered @ %0t", $time); 
        end
    endtask

    task reset();
        $display("[DRV] Reset started at %0t", $time);
        
        w_vif.wr_cb.wr_rst <= 1'b1;
        r_vif.rd_cb.rd_rst <= 1'b1;
        w_vif.wr_cb.wr_en  <= 1'b0;
        r_vif.rd_cb.rd_en  <= 1'b0;
        w_vif.wr_cb.data_in <= 'b0;

        repeat(5) @(w_vif.wr_cb);
        
        w_vif.wr_cb.wr_rst <= 1'b0;
        r_vif.rd_cb.rd_rst <= 1'b0;
        
        $display("[DRV] Reset de-asserted at %0t", $time);
    endtask
endclass

class monitor #(parameter bw = 8);
    virtual afifo_if #(bw) vif;

    mailbox #(transaction #(bw)) mon2scb_wr_mbx;
    mailbox #(transaction #(bw)) mon2scb_rd_mbx;

    function new ( virtual afifo_if #(bw).monitor vif,
                    mailbox #(transaction #(bw)) wr_mbx,
                    mailbox #(transaction #(bw)) rd_mbx);
        this.vif = vif;
        this.mon2scb_rd_mbx = rd_mbx;
        this.mon2scb_wr_mbx = wr_mbx;
    endfunction

    task run();
        fork
            sample_write();
            sample_read();
        join
    endtask

    task sample_write();
        forever begin
            @(posedge vif.wr_clk);
            if (vif.wr_en && !vif.full) begin
                transaction #(bw) tr;
                tr = new();
                tr.data = vif.data_in;
                tr.wr_en = 1;
                tr.rd_en = 0;
                mon2scb_wr_mbx.put(tr);
                $display("[MON_WR] Captured Write: Data=0x%0h @ %0t", tr.data, $time);
                @(posedge vif.wr_clk);
            end
        end
    endtask

    task sample_read();
        bit reading = 0;
        forever begin
            @(posedge vif.rd_clk);
            if (vif.rd_en && !vif.empty) begin
                reading = 1;
            end
            
            if (reading) begin 
                transaction #(bw) tr;
                tr = new();
                
                tr.data = vif.data_out;
                tr.rd_en = 1;
                tr.wr_en = 0;
                mon2scb_rd_mbx.put(tr);
                $display("[MON_RD] Captured Read: Data=0x%0h @ %0t", tr.data, $time);
                reading = 0;
                @(posedge vif.rd_clk);
            end
        end
    endtask

endclass

class scoreboard #(parameter bw = 8);
    mailbox #(transaction #(bw)) mon2scb_rd_mbx;
    mailbox #(transaction #(bw)) mon2scb_wr_mbx;

    bit [bw-1:0] expected_data_q[$];

    int match_count = 0;
    int error_count = 0;
    int data_dropped = 0;

    function new(mailbox #(transaction #(bw)) wr_mbx,
                mailbox #(transaction #(bw)) rd_mbx);
        this.mon2scb_rd_mbx = rd_mbx;
        this.mon2scb_wr_mbx = wr_mbx;
    endfunction

    task run();
        fork
            forever begin
                transaction #(bw) tr_wr;
                mon2scb_wr_mbx.get(tr_wr);
                expected_data_q.push_back(tr_wr.data);
                $display("[SCB] Expected Data Logged: 0x%0h", tr_wr.data);
            end

            forever begin
                transaction #(bw) tr_rd;
                bit [bw-1:0] exp_data;
                mon2scb_rd_mbx.get(tr_rd);

                if(expected_data_q.size() > 0) begin
                    exp_data = expected_data_q.pop_front();
                    if(tr_rd.data === exp_data) begin
                        $display("[SCB] MATCH: Expected 0x%0h, Got 0x%0h", exp_data, tr_rd.data);
                        match_count++;
                    end else begin
                        $error("[SCB] MISMATCH: Expected 0x%0h, Got 0x%0h", exp_data, tr_rd.data);
                        error_count++;
                    end
                end else begin
                    $error("[SCB] UNDERFLOW ERROR: Read detected but Scoreboard queue is empty!");
                    error_count++;
                end
            end
        join
    endtask

    function void flush();
        expected_data_q.delete();
        $display("[SCB] Scoreboard queue flushed due to Reset.");
    endfunction

    function void report();
        $display("\n--- SCOREBOARD REPORT ---");
        $display("Matches: %0d", match_count);
        $display("Errors: %0d", error_count);
        $display("Items left in FIFO: %0d", expected_data_q.size());
        $display("--------------------------\n");
    endfunction

endclass

class environment #(parameter bw=8);
    generator #(bw) gen;
    driver #(bw) drv;
    monitor #(bw) mon;
    scoreboard #(bw) scb;

    mailbox #(transaction #(bw)) g2d_mbx;
    mailbox #(transaction #(bw)) mon2scb_rd_mbx;
    mailbox #(transaction #(bw)) mon2scb_wr_mbx;

    virtual afifo_if #(bw) vif;
    
    task wait_until_idle();
        // 1. Ensure the Generator has finished creating and pushing all transactions
        // wait(gen.gen_done.triggered);
        
        // 2. Ensure the Driver has pulled all transactions from the input mailbox
        wait(g2d_mbx.num() == 0);
        
        // 3. Ensure the Monitors have finished sending captured data to the Scoreboard
        wait(mon2scb_wr_mbx.num() == 0);
        wait(mon2scb_rd_mbx.num() == 0);
        
        // 4. Give the Scoreboard one last cycle to finish its final comparison
        repeat(5) @(vif.rd_clk);
        
        $display("[ENV] System is idle at %0t", $time);
    endtask

    function new(virtual afifo_if #(bw) vif);
        this.vif = vif;
        g2d_mbx = new();
        mon2scb_rd_mbx = new();
        mon2scb_wr_mbx = new();

        gen = new(g2d_mbx);

        drv = new(vif, vif, g2d_mbx);
        mon = new(vif, mon2scb_wr_mbx, mon2scb_rd_mbx);
        scb = new(mon2scb_wr_mbx, mon2scb_rd_mbx);
    endfunction

    task run();
        fork
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask

    task run_gen();
        gen.run();
    endtask

endclass

`timescale 1ns/1ns
interface afifo_if #(parameter bw = 8)
    (input bit wr_clk, rd_clk);
    logic [bw-1:0] data_in;
    bit wr_en;
    bit wr_rst;
    logic full;

    logic [bw-1:0] data_out;
    bit rd_en;
    bit rd_rst;
    logic empty;

    // property write_on_full;
    //     @(posedge wr_clk)
    //     (wr_en && full) |-> $stable(); 
    // endproperty

    // property write_on_empty;
    //     @(posedge rd_clk) 
    //     (rd_en && empty) |-> $stable(); 
    // endproperty

    // property reset_to_idle;
    //     @(posedge wr_clk)
    //     $rose(wr_clk) || $rose(rd) ##[0:$] !full && empty;
    // endproperty

    clocking wr_cb @(posedge wr_clk);
        default input #1ns output #1ns;
        output data_in, wr_en, wr_rst;
        input full;
    endclocking

    clocking rd_cb @(posedge rd_clk);
        default input #1ns output #1ns;
        output rd_en, rd_rst;
        input data_out, empty;
    endclocking

    modport wr_drv (clocking wr_cb, input wr_clk, output wr_rst);
    modport rd_drv (clocking rd_cb, input rd_clk, output rd_rst);
    modport monitor (input data_in, wr_en, full, data_out, rd_en, empty, wr_clk, rd_clk);

endinterface //afifo_if

class test #(parameter bw = 8);
    environment #(bw) env;
    virtual afifo_if #(bw) vif;

    function new (virtual afifo_if #(bw) vif);
        this.vif = vif;
        this.env = new(vif);
    endfunction

    task setup_test();
        env.drv.reset();    // Hardware reset
        env.scb.flush();    // Clear scoreboard golden model
        env.scb.match_count = 0;
        env.scb.error_count = 0;
    endtask

    // 1. One write and then Read Test
    task test_single_rw();
        transaction #(bw) tr;
        env.gen.random_mode = 0;
        setup_test();
        $display("\n--- TEST: Single Write-Read ---");
        
        tr = new();
        tr.wr_en = 1; tr.data = $urandom;
        env.gen.add_transaction(tr);
        tr = new();
        tr.rd_en = 1;
        env.gen.add_transaction(tr);

        env.run_gen();
        // wait(env.gen.gen_done);
        $display("\n--- Done Gen Single Write-Read ---");
        
        #200; // Wait for async domains to process
        env.scb.report();
        $stop;
    endtask

    // 2. Multiple Read and Write
    task test_multiple_rw(int count);
        transaction #(bw) tr;
        env.gen.random_mode = 0;
        setup_test();
        $display("\n--- TEST: Multiple Read and Write (%0d) ---", count);
        
        repeat(count) begin
            tr = new();
            tr.wr_en = 1; tr.rd_en = 0; tr.data = $urandom;
            env.gen.add_transaction(tr);
        end
        repeat(count) begin
            tr = new();
            tr.wr_en = 0; tr.rd_en = 1;
            env.gen.add_transaction(tr);
        end       
        
        env.run_gen();
        // @(env.gen.gen_done);

        #1000;
        env.scb.report();
        $stop;
    endtask

    // 3. Overflow Condition
    task test_overflow(int depth);
        transaction #(bw) tr;
        env.gen.random_mode = 0;
        setup_test();
        $display("\n--- TEST: Overflow Condition ---");
        
        repeat(depth + 2) begin // Write beyond capacity
            tr = new();
            tr.wr_en = 1; tr.data = $urandom;
            tr.force_write = 1; 
            env.gen.add_transaction(tr);
        end

        env.run_gen();
        // @(env.gen.gen_done);
        
        #1000;
        env.scb.report();
        $stop;
    endtask

    // 4. Underflow Condition
    task test_underflow();
        transaction #(bw) tr;
        env.gen.random_mode = 0;
        setup_test();
        $display("\n--- TEST: Underflow Condition ---");
        
        tr = new();
        tr.rd_en = 1;
        tr.force_read = 1;
        env.gen.add_transaction(tr);

        env.run_gen();
        // @(env.gen.gen_done);
        
        #1000;
        env.scb.report();
        $stop;
    endtask

    // 5. Wrap-around Test
    task test_wrap_around(int depth);
        transaction #(bw) tr;
        env.gen.random_mode = 0;
        setup_test();
        $display("\n--- TEST: Wrap-around Logic ---");
        
        repeat(depth * 2) begin
            tr = new();
            tr.wr_en = 1; tr.rd_en = 1; // Simultaneous to keep pointers moving
            tr.data = $urandom;
            env.gen.add_transaction(tr);
        end

        env.run_gen();
        // @(env.gen.gen_done);
        
        #2000;
        env.scb.report();
        $stop;
    endtask

    // 6. Random Testing
    task test_random();
        env.gen.random_mode = 1;
        env.gen.num_transaction = 16;
        setup_test();
        $display("\n--- TEST: Random Stimulus ---");

        env.run_gen();
        // @(env.gen.gen_done);
              
        #2000;
        env.scb.report();
        $stop;
    endtask

    // Master execution task
    task run_all(int depth);
        // Start background components
        // fork
            // env.drv.run();
            // env.mon.run();
            // env.scb.run();
        // join_none
        env.run();

        // Execute tests independently
        test_single_rw();
        test_multiple_rw(5);
        test_overflow(depth);
        test_underflow();
        test_wrap_around(depth);
        test_random();
        
        $display("\n*** ALL TESTS COMPLETED ***");
        // $finish;
        $stop;
    endtask
endclass

`timescale 1ns/1ns
module top;
    parameter bw = 8;
    parameter depth = 8;

    bit wr_clk =0;
    bit rd_clk =0;

    always #5 wr_clk = ~wr_clk; 
    always #13 rd_clk = ~rd_clk;

    afifo_if #(bw) aif(wr_clk, rd_clk);

    async_fifo #(.bw(bw), .depth(depth)) DUT(
        .wr_clk   (aif.wr_clk),
        .wr_rst   (aif.wr_rst),
        .wr_en    (aif.wr_en),
        .data_in  (aif.data_in),
        .full     (aif.full),
        
        .rd_clk   (aif.rd_clk),
        .rd_rst   (aif.rd_rst),
        .rd_en    (aif.rd_en),
        .data_out (aif.data_out),
        .empty    (aif.empty)
    );

    test #(bw) t_inst;

    initial begin
        t_inst = new(aif);

        t_inst.run_all(depth);
    end

    initial begin
        #5000000ns; // Absolute maximum simulation time
        $display("ERROR: Simulation Timeout! Check for Driver/RTL deadlock.");
        $finish;
    end


endmodule