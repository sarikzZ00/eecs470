module lsq_testbench;
    
    //Inputs
    logic                                   clock; 
    logic                                   reset; 
    logic [`NUM_LD-1:0]	                    load_forward_request;
    logic [`NUM_LD-1:0] [`XLEN-1:0]	        load_forward_address;
    logic                                   branch_mispredict;
    EX_LSQ_PACKET [`N-1:0]                  ex_lsq_load_packet;
    EX_LSQ_PACKET [`NUM_ST-1:0]	ex_lsq_store_packet;
    logic [`NUM_ROBS_BITS-1:0]              head_rob_id;
    
    DISPATCHED_LSQ_PACKET [`N-1:0]    	    dispatched_memory_instructions;
    logic [`NUM_ROBS_BITS-1:0]				num_retire_loads;
	logic [`NUM_ROBS_BITS-1:0]				num_retire_stores;
    

    //Outputs
    logic [`NUM_LD-1:0]                     forward_found;
	logic [`NUM_LD-1:0] [`XLEN-1:0]         forward_value;
	logic [`NUM_LD-1:0] [`XLEN-1:0]         load_forward_address_output;
    logic [`LQ_BITS:0]                    num_rows_load_queue_free;
    logic [`SQ_BITS:0]                    num_rows_store_queue_free;
    logic                                   error_detect;
    FLUSHED_INFO					            flushed_info;

    //Expected Outputs
    logic [`NUM_LD-1:0]                     expected_forward_found;
	logic [`NUM_LD-1:0] [`XLEN-1:0]         expected_forward_value;
	logic [`NUM_LD-1:0] [`XLEN-1:0]         expected_load_forward_address_output;
    logic [`LQ_BITS:0]                    expected_num_rows_load_queue_free;
    logic [`SQ_BITS:0]                    expected_num_rows_store_queue_free;
    logic                                   expected_error_detect;
    FLUSHED_INFO				                expected_flushed_info;
    logic [`NUM_ROBS_BITS-1:0]              expected_mispeculated_rob_id;
	logic [`XLEN-1:0] 			            expected_mispeculated_PC;
    logic [`LQ_BITS-1:0]                    expected_head_pointer_lq;
	logic [`SQ_BITS-1:0]                    expected_head_pointer_sq;
	logic [`LQ_BITS-1:0]                    expected_tail_pointer_lq;
	logic [`SQ_BITS-1:0]                    expected_tail_pointer_sq;
	logic signed [`SQ_BITS-1:0]             expected_sq_count;
	logic signed [`LQ_BITS-1:0]             expected_lq_count;
    SQ_ROW [`SQ_SIZE-1:0]                   expected_store_queue;
    LQ_ROW [`LQ_SIZE-1:0]                   expected_load_queue;

    //Debug outputs
    logic [`LQ_BITS-1:0] head_pointer_lq_debug;
	logic [`SQ_BITS-1:0] head_pointer_sq_debug;
	logic [`LQ_BITS-1:0] tail_pointer_lq_debug;
	logic [`SQ_BITS-1:0] tail_pointer_sq_debug;
	logic signed [`SQ_BITS:0] sq_count_debug;
	logic signed [`LQ_BITS:0] lq_count_debug;
	SQ_ROW [`SQ_SIZE-1:0] store_queue_debug;
    LQ_ROW [`LQ_SIZE-1:0] load_queue_debug;
	logic signed [`LQ_BITS-1:0] load_queue_alias_index_debug;

    
    int fd_lsq_out;
    LSQ lsq1 (
        .clock(clock),
        .reset(reset),

        // special input through pipeline
        // for age, process control, etc
        //.load_forward_request(load_forward_request),
        //.load_forward_address(load_forward_address),						
        .branch_mispredict(branch_mispredict),
        .ex_lsq_load_packet(ex_lsq_load_packet), 
        .ex_lsq_store_packet(ex_lsq_store_packet), 
        .head_rob_id(head_rob_id),

        // input of issued requests
        .dispatched_memory_instructions(dispatched_memory_instructions),
        .num_retire_loads(num_retire_loads),
        .num_retire_stores(num_retire_stores),

        // output for dispatch to issue new l/s instr
        //.forward_found(forward_found),
        //.forward_value(forward_value),
        //.load_forward_address_output(load_forward_address_output),
        .num_rows_load_queue_free(num_rows_load_queue_free),
        .num_rows_store_queue_free(num_rows_store_queue_free),

        // output for dispatch to squash itself and recover
        // rob, rs, etc
        .error_detect(error_detect),
        .flushed_info(flushed_info)

        `ifdef DEBUG_OUT_LSQ
            ,.head_pointer_lq_debug(head_pointer_lq_debug),
            .head_pointer_sq_debug(head_pointer_sq_debug),
            .tail_pointer_lq_debug(tail_pointer_lq_debug),
            .tail_pointer_sq_debug(tail_pointer_sq_debug),
            .sq_count_debug(sq_count_debug),
            .lq_count_debug(lq_count_debug),
            .store_queue_debug(store_queue_debug),
            .load_queue_debug(load_queue_debug),
            .load_queue_alias_index_debug(load_queue_alias_index_debug)
        `endif
    );

    always begin
        #10 clock = ~clock;
    end

    always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
        $fdisplay(fd_lsq_out, "##########");
        $fdisplay(fd_lsq_out,"Time: %4.0f", $time);
        $fdisplay(fd_lsq_out, "##########");
        #5; //#5 Allows time for all outputs to settle
		print_all(fd_lsq_out);
        $fdisplay(fd_lsq_out, "Head Pointer LQ: %h", head_pointer_lq_debug);
        $fdisplay(fd_lsq_out, "Head Pointer SQ: %h", head_pointer_sq_debug);
        $fdisplay(fd_lsq_out, "Tail Pointer LQ: %h", tail_pointer_lq_debug);
        $fdisplay(fd_lsq_out, "Tail Pointer SQ: %h", tail_pointer_sq_debug);
        $fdisplay(fd_lsq_out, "SQ Count: %h", sq_count_debug);
        $fdisplay(fd_lsq_out, "LQ Count: %h", lq_count_debug);
        $fdisplay(fd_lsq_out, "SQ Count: %h", sq_count_debug);
        $fdisplay(fd_lsq_out, "LQ Alias Index Count: %h",load_queue_alias_index_debug);
        #2;
		compare_all(); 

    end

    task open_all_files;
		fd_lsq_out = $fopen("./debug_outputs/execute/Standard_LSQ_Outputs.txt");
		$display("All Files Opened");
    endtask

    task close_all_files;
		$fclose(fd_lsq_out);
		$display("All Files Closed");
    endtask

    task finish_successfully;
        $display("@@@Passed");
		close_all_files();
        $finish;
    endtask

    task print_store_queue;
        $fdisplay(fd_lsq_out,"Store Queue State");
       for(int store_index = 0; store_index < `SQ_SIZE; store_index = store_index + 1) begin 
            $fdisplay(fd_lsq_out, "Index:%d, mem_addr:%h, complete:%h, value:%h, valid:%h, retire_bit:%h, rob_id:%h, age:%h, load_tail:%h",
                        store_index,
                        store_queue_debug[store_index].mem_addr,
                        store_queue_debug[store_index].mem_data,
                        store_queue_debug[store_index].complete,
                        store_queue_debug[store_index].value,
                        store_queue_debug[store_index].valid,
                        store_queue_debug[store_index].retire_bit,
                        store_queue_debug[store_index].rob_id,
                        store_queue_debug[store_index].age,
                        store_queue_debug[store_index].load_tail
                        );
       end
    endtask

    task print_sq_count;
        $display("sq_count:%h", sq_count_debug);
    endtask

    task print_lq_count;
        $display("lq_count:%h", lq_count_debug);
    endtask


    task print_load_queue;
        $fdisplay(fd_lsq_out,"Load Queue State");
       for(int load_index = 0; load_index < `SQ_SIZE; load_index = load_index + 1) begin 
            $fdisplay(fd_lsq_out, "Index:%d, PC:%h, mem_addr:%h, complete:%h, valid:%h, retire_bit:%h, rob_id:%h, age:%h, load_tail:%h",
                        load_index,
                        load_queue_debug[load_index].PC,
                        load_queue_debug[load_index].mem_addr,
                        load_queue_debug[load_index].mem_data,
                        load_queue_debug[load_index].complete,
                        load_queue_debug[load_index].valid,
                        load_queue_debug[load_index].retire_bit,
                        load_queue_debug[load_index].rob_id,
                        load_queue_debug[load_index].age,
                        load_queue_debug[load_index].store_tail
                        );
       end
    endtask

    task print_flush_packet_to_file;
        $fdisplay(fd_lsq_out, "Flush Packet: Head Rob ID: %h, Mispeculated Rob ID: %h, Mispeculated PC: %h", 
                    flushed_info.head_rob_id,
                    flushed_info.mispeculated_rob_id, 
                    flushed_info.mispeculated_PC);
        $fdisplay(fd_lsq_out, "Expected Flush Packet: Head Rob ID: %h, Mispeculated Rob ID: %h, Mispeculated PC: %h", 
                    expected_flushed_info.head_rob_id,
                    expected_flushed_info.mispeculated_rob_id, 
                    expected_flushed_info.mispeculated_PC);
    endtask


    task exit_on_error;
        $display("@@@Failed",$time);
        $display("@@@ Incorrect at time %4.0f", $time);
        $display("@@@ Time:%4.0f clock:%b", $time, clock);
        $display("");
        $finish;
    endtask

    task compare_forward_found;
		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_forward_found[i] != forward_found[i]) begin
                $display(fd_lsq_out,"forward_found Incorrect");
                $display(fd_lsq_out,"Expected: %h", expected_forward_found[i]);
                $display(fd_lsq_out,"Actual: %h", forward_found[i]);
                exit_on_error();
            end
		end
	endtask

    task compare_forward_value;
		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_forward_value[i] != forward_value[i]) begin
                $display(fd_lsq_out,"forward_value Incorrect");
                $display(fd_lsq_out,"Expected: %h", expected_forward_value[i]);
                $display(fd_lsq_out,"Actual: %h", forward_value[i]);
                exit_on_error();
            end
		end
	endtask

    task compare_load_forward_address_output;
		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_load_forward_address_output[i] != load_forward_address_output[i]) begin
                $display("load_forward_address Incorrect");
                $display("Expected: %h", expected_load_forward_address_output);
                $display("Actual: %h", load_forward_address_output);
                exit_on_error();
            end
		end
	endtask

    task compare_num_rows_load_queue_free;
        if (expected_num_rows_load_queue_free != num_rows_load_queue_free) begin
            $display("num_rows_load_queue_free Incorrect");
            $display("Expected: %h", expected_num_rows_load_queue_free);
            $display("Actual: %h", num_rows_load_queue_free);
            exit_on_error();
        end
	endtask

    task compare_num_rows_store_queue_free;
        if (expected_num_rows_store_queue_free != num_rows_store_queue_free) begin
            $display(fd_lsq_out,"num_rows_store_queue_free Incorrect");
            $display(fd_lsq_out,"Expected: %h", expected_num_rows_store_queue_free);
            $display(fd_lsq_out,"Actual: %h", num_rows_store_queue_free);
            exit_on_error();
        end
	endtask

    task compare_error_detect;
        if (expected_error_detect != error_detect) begin
            $display("error_detect Incorrect");
            $display("Expected: %h", expected_error_detect);
            $display("Actual: %h", error_detect);
            exit_on_error();
        end
    endtask

    task compare_head_pointer_lq;
        if (expected_head_pointer_lq != head_pointer_lq_debug) begin
            $display("load queue expected_head_pointer");
            $display("Expected: %h", expected_head_pointer_lq);
            $display("Actual: %h", head_pointer_lq_debug);
            exit_on_error();
        end
	endtask

    task compare_head_pointer_sq;
        if (expected_head_pointer_sq != head_pointer_sq_debug) begin
            $display("store queue expected_head_pointer");
            $display("Expected: %h", expected_head_pointer_sq);
            $display("Actual: %h", head_pointer_sq_debug);
            exit_on_error();
        end
	endtask


    task compare_tail_pointer_sq;
        if (expected_tail_pointer_sq != tail_pointer_sq_debug) begin
            $display("store queue expected_tail_pointer");
            $display("Expected: %h", expected_tail_pointer_sq);
            $display("Actual: %h", tail_pointer_sq_debug);
            exit_on_error();
        end
	endtask

    task compare_tail_pointer_lq;
        if (expected_tail_pointer_lq != tail_pointer_lq_debug) begin
            $display("load queue expected_tail_pointer");
            $display("Expected: %h", expected_tail_pointer_lq);
            $display("Actual: %h", tail_pointer_lq_debug);
            exit_on_error();
        end
	endtask

    task compare_sq_count;
        if (expected_sq_count != sq_count_debug) begin
            $display("expected store queue count");
            $display("Expected: %h", expected_sq_count);
            $display("Actual: %h", sq_count_debug);
            exit_on_error();
        end
	endtask

    task compare_lq_count;
        if (expected_lq_count != lq_count_debug) begin
            $display("expected load queue count");
            $display("Expected: %h", expected_lq_count);
            $display("Actual: %h", lq_count_debug);
            exit_on_error();
        end
	endtask

    task compare_flush_info;
            if (expected_flushed_info != flushed_info) begin 
                print_flush_packet_to_file();
                exit_on_error();
            end
    endtask

    task print_store_queue_debug;
        input store_index;
        input SQ_ROW input_packet;

            $display("Index:%d, mem_addr:%h, complete:%h, mem_data:%h, valid:%h, retire_bit:%h, rob_id:%h, age:%h, load_tail:%h",
                        store_index,
                        input_packet.mem_addr,
                        input_packet.complete,
                        input_packet.mem_data,
                        input_packet.valid,
                        input_packet.retire_bit,
                        input_packet.rob_id,
                        input_packet.age,
                        input_packet.load_tail
                        );
    endtask

    task print_load_queue_debug;
        input index;
        input LQ_ROW input_packet;
        $display("Index:%d, PC:%h, mem_addr:%h, mem_data: %h, complete:%h, valid:%h, retire_bit:%h, rob_id:%h, age:%h, store_tail:%h",
                    index,
                    input_packet.PC,
                    input_packet.mem_addr,
                    input_packet.mem_data,
                    input_packet.complete,
                    input_packet.valid,
                    input_packet.retire_bit,
                    input_packet.rob_id,
                    input_packet.age,
                    input_packet.store_tail
                    );
    endtask

    task compare_store_queue;
        for (int store_index = 0; store_index < `SQ_SIZE; store_index = store_index + 1) begin 
            if(expected_store_queue[store_index] != store_queue_debug[store_index]) begin 
                $display("Expected Value Store Queue:");
                print_store_queue_debug(store_index, expected_store_queue[store_index]);
                $display("Actual Value Store Queue:");
                print_store_queue_debug(store_index, store_queue_debug[store_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_load_queue;
        for (int load_index = 0; load_index < `LQ_SIZE; load_index = load_index + 1) begin 
            if(expected_load_queue[load_index] != load_queue_debug[load_index]) begin 
                $display("Expected Value Load Queue for %d",load_index);
                print_load_queue_debug(load_index, expected_load_queue[load_index]);
                $display("Actual Value Load Queue:");
                print_load_queue_debug(load_index, load_queue_debug[load_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_all;
        compare_forward_found();
        compare_forward_value();
        compare_load_forward_address_output();
        compare_num_rows_load_queue_free();
        compare_num_rows_store_queue_free();
        compare_error_detect();
        compare_head_pointer_lq();
        compare_head_pointer_sq();
        compare_tail_pointer_sq();
        compare_tail_pointer_lq();
        compare_sq_count();
        compare_lq_count();
        compare_flush_info();
        compare_store_queue();
        compare_load_queue();
    endtask

    task print_all;
        input fd;
        print_store_queue();
        print_load_queue();
        print_sq_count();
        print_lq_count();
    endtask

    task hard_reset;
        //Reset inputs
        branch_mispredict = 0;
        load_forward_request = 0;
        head_rob_id = 0;
        num_retire_loads = 0;
        num_retire_stores = 0;
        for (int i = 0; i < `N; i = i + 1) begin
            load_forward_address[i] = 0;
            ex_lsq_load_packet[i] = 0;
            dispatched_memory_instructions[i] = 0;
        end
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            ex_lsq_store_packet[i] = 0;
        end
    endtask

    task set_expected_zero;
        expected_forward_found = 0;
        for (int i = 0; i < `N; i = i + 1) begin
            expected_forward_value[i] = 0;
            expected_load_forward_address_output[i] = 0;
        end
        expected_num_rows_load_queue_free = `LQ_SIZE;
        expected_num_rows_store_queue_free = `SQ_SIZE;
        expected_error_detect = 0;
        expected_flushed_info = 0;
        expected_mispeculated_rob_id = 0;
	    expected_mispeculated_PC = 0;
        expected_head_pointer_lq = 0;
	    expected_head_pointer_sq = 0;
	    expected_tail_pointer_lq = 0;
	    expected_tail_pointer_sq = 0;
	    expected_sq_count = 0;
	    expected_lq_count = 0;
        expected_store_queue = 0;
        expected_load_queue = 0;
    endtask
    
    initial begin
		open_all_files();

        $display("STARTING TESTBENCH!");

        
        clock = 0;
        hard_reset();
        

        if (`N == 1) begin
            
            finish_successfully();
        end

        reset = 1;
        @(negedge clock); //20
        //TEST 1: Dispatching 5 store instructions
        $display("----------- STARTING TEST 1 ---------");
        reset = 0;
        for(int i = 0; i < `N; i = i + 1) begin
            dispatched_memory_instructions[i].is_store = 1;
            dispatched_memory_instructions[i].rob_id = i;
            dispatched_memory_instructions[i].valid = 1;
        end

        @(negedge clock); //40
        dispatched_memory_instructions = 0;
        expected_store_queue[0].rob_id = 0;
        expected_store_queue[0].load_tail = 0;
        expected_store_queue[0].age = 0;
        expected_store_queue[1].rob_id = 1;
        expected_store_queue[1].load_tail = 0;
        expected_store_queue[1].age = 1;
        expected_store_queue[2].rob_id = 2;
        expected_store_queue[2].load_tail = 0;
        expected_store_queue[2].age = 2;
        expected_store_queue[3].rob_id = 3;
        expected_store_queue[3].load_tail = 0;
        expected_store_queue[3].age = 3;
        expected_store_queue[4].rob_id = 4;
        expected_store_queue[4].load_tail = 0;
        expected_store_queue[4].age = 4;

        expected_head_pointer_sq = 0;
        expected_tail_pointer_sq = 5;
        @(negedge clock); //60

        num_retire_stores = 5;
        @(negedge clock); //80

        num_retire_stores = 0;
        // expected_store_queue = 0;

        for (int i = 0; i < `N; i = i + 1) begin 
            expected_store_queue[i].valid = 1'b1;
        end
        expected_head_pointer_sq = 0;

        @(negedge clock); //100
        @(negedge clock); //120
        @(negedge clock); //140

        @(posedge clock); //160
        reset = 1;
        hard_reset();
        set_expected_zero();
        @(negedge clock); //160
    
        
        
        //TEST 2: Dispatching 5 loads/stores instructions
        $display("----------- STARTING TEST 2 ---------");
        reset = 0;
        for(int i = 0; i < `N; i = i + 1) begin
            if((i % 2) == 0) begin 
                dispatched_memory_instructions[i].is_store = 1;
            end
            dispatched_memory_instructions[i].valid = 1;
            dispatched_memory_instructions[i].rob_id = i;
        end
        expected_num_rows_load_queue_free = 30;
        expected_num_rows_store_queue_free = 29;
        expected_sq_count = 3;
        expected_lq_count = 2;

        @(negedge clock); //180
        dispatched_memory_instructions = 0;
        expected_tail_pointer_sq = 3;
        expected_tail_pointer_lq = 2;
        expected_sq_count = 0;
        expected_lq_count = 0;

        expected_load_queue[0].rob_id = 1;
        expected_load_queue[0].store_tail = 1;
        expected_load_queue[0].age = 0;
        expected_load_queue[0].valid = 1;

        expected_load_queue[1].rob_id = 3;
        expected_load_queue[1].store_tail = 2;
        expected_load_queue[1].age = 1;
        expected_load_queue[1].valid = 1;

        expected_store_queue[0].rob_id = 0;
        expected_store_queue[0].load_tail = 0;
        expected_store_queue[0].age = 0;
        expected_store_queue[0].valid = 1;

        expected_store_queue[1].rob_id = 2;
        expected_store_queue[1].load_tail = 1;
        expected_store_queue[1].age = 1;
        expected_store_queue[1].valid = 1;

        expected_store_queue[2].rob_id = 4;
        expected_store_queue[2].load_tail = 2;
        expected_store_queue[2].age = 2;
        expected_store_queue[2].valid = 1;

        

        $display("Here 3");
        $display("head_pointer_lq: %h", head_pointer_lq_debug);
        $display("tail_pointer_lq: %h", tail_pointer_lq_debug);
        $display("lq_count: %h", lq_count_debug);

        $display("head_pointer_sq: %h", head_pointer_sq_debug);
        $display("tail_pointer_sq: %h", tail_pointer_sq_debug);
        $display("sq_count: %h", sq_count_debug);


        @(negedge clock); //200
        @(negedge clock); //220
        @(negedge clock); //240
        @(negedge clock); //260


        //TEST 3 : Forwarding example
        $display("----------- STARTING TEST 3 ---------");
        for (int request_index = 0; request_index < `N; request_index = request_index + 1) begin
            if ((request_index % 2) == 0) begin
                load_forward_request[request_index] = 1;
                load_forward_address[request_index] = request_index + 1000;
                dispatched_memory_instructions[request_index].is_store = 0; 
            end
            else begin
                load_forward_request[request_index] = 0;
                load_forward_address[request_index] = 0;
                dispatched_memory_instructions[request_index].is_store = 1;
            end
        end
        expected_load_forward_address_output[0] = 1000;
        expected_load_forward_address_output[2] = 1002;
        expected_load_forward_address_output[4] = 1004;
        //Need to set mem_addr for store and load queues
        
        for (int i = 0; i < `N; i = i + 1) begin
            ex_lsq_load_packet[i].address = i + 250;
            if ((i % 2) == 0) begin
            ex_lsq_store_packet[i].address = i + 1000;
            ex_lsq_store_packet[i].value = i;
            end
        end

        //Set the expected_forward_value and expected_forward_found 

        for (int i = 0; i < `N; i = i + 1) begin
            if ((i % 2) == 0) begin
                expected_forward_value[i] = i;
                expected_forward_found[i] = 1;
            end
        end

        @(negedge clock); //280
        dispatched_memory_instructions = 0;
        @(negedge clock); //300
        @(negedge clock); //320
        @(negedge clock); //340

      /*  //TEST 4 : Branch mispredict example 
        $display("----------- STARTING TEST 4 ---------");
        branch_mispredict = 1;
        @(negedge clock); 
        expected_head_pointer_lq = 0;
        expected_tail_pointer_lq = 0;
        expected_load_queue = 0;

        expected_head_pointer_sq = 0;
        expected_tail_pointer_sq = 0;
        expected_store_queue = 0;
        expected_num_rows_load_queue_free = `LQ_SIZE;
        expected_num_rows_store_queue_free = `SQ_SIZE;
        @(negedge clock); 
        dispatched_memory_instructions = 0;
     */
        //TEST 5: Check num of load rows 
        $display("----------- STARTING TEST 4 ---------");

        //Need to dispatch 5 loads and then retire 5 loads
        for (int i = 0; i < `N; i = i + 1) begin
            dispatched_memory_instructions[i].is_store = 0;
            dispatched_memory_instructions[i].rob_id = i+5;
            dispatched_memory_instructions[i].valid = 1;
        end
        $display("Here 3");
        $display("lq_count: %h", lq_count_debug);
        $display("tail_pointer_lq: %h", tail_pointer_lq_debug);
        $display("head_pointer_lq: %h", head_pointer_lq_debug);
        expected_num_rows_load_queue_free = `LQ_SIZE - 7;
        expected_lq_count = 5;
        @(negedge clock); //360
        dispatched_memory_instructions = 0;
        expected_num_rows_load_queue_free = `LQ_SIZE - 7;
        expected_tail_pointer_lq = 7;
        expected_lq_count = 0;

        expected_load_queue[0].rob_id = 1;
        expected_load_queue[0].store_tail = 1;
        expected_load_queue[0].age = 0;
        expected_load_queue[0].valid = 1;

        expected_load_queue[1].rob_id = 3;
        expected_load_queue[1].store_tail = 2;
        expected_load_queue[1].age = 1;
        expected_load_queue[1].valid = 1;

        expected_load_queue[2].rob_id = 5;
        expected_load_queue[2].store_tail = 3;
        expected_load_queue[2].age = 2;
        expected_load_queue[2].valid = 1;


        expected_load_queue[3].rob_id = 6;
        expected_load_queue[3].store_tail = 3;
        expected_load_queue[3].age = 3;
        expected_load_queue[3].valid = 1;

        expected_load_queue[4].rob_id = 7;
        expected_load_queue[4].store_tail = 3;
        expected_load_queue[4].age = 4;
        expected_load_queue[4].valid = 1;

        expected_load_queue[5].rob_id = 8;
        expected_load_queue[5].store_tail = 3;
        expected_load_queue[5].age = 5;
        expected_load_queue[5].valid = 1;

        expected_load_queue[6].rob_id = 9;
        expected_load_queue[6].store_tail = 3;
        expected_load_queue[6].age = 6;
        expected_load_queue[6].valid = 1;


        $display("Here 4");
        $display("head_pointer_lq: %h", head_pointer_lq_debug);
        $display("load_queue[head_pointer_lq].retire_bit :%h", load_queue_debug[head_pointer_lq_debug].retire_bit);
        $display("load_queue[head_pointer_lq].complete :%h", load_queue_debug[head_pointer_lq_debug].complete);
        $display("expected load queue index 0 rob id: %d",expected_load_queue[0].rob_id);
        $display("load queue index 0 rob id: %d",load_queue_debug[0].rob_id);        
        
        @(posedge clock); //380
        num_retire_loads = 7;
        expected_num_rows_load_queue_free = 32;
        $display("Head Pointer Load Queue:%h", head_pointer_lq_debug);
        $display("Tail Pointer Load Queue:%h", tail_pointer_lq_debug);
        @(negedge clock); //400
        @(negedge clock); //420
        
        @(posedge clock); //430
        reset = 1;
        hard_reset();
        set_expected_zero();
        @(negedge clock); //440
       $display("----------- STARTING TEST 5 ---------");
        //Load Flushing Logic
        for(int i = 0; i < `N; i = i + 1) begin
            if((i % 2) == 0) begin 
                dispatched_memory_instructions[i].is_store = 1;
            end
            dispatched_memory_instructions[i].valid = 1;
            dispatched_memory_instructions[i].rob_id = i;
            dispatched_memory_instructions[i].mem_size = WORD;
        end
        expected_num_rows_load_queue_free = `LQ_SIZE - 2;
        expected_lq_count = 2;
        expected_num_rows_store_queue_free = `SQ_SIZE - 3;
        expected_lq_count = 3;
        @(negedge clock); //460
        dispatched_memory_instructions = 0;
        expected_num_rows_load_queue_free = `LQ_SIZE - 3;
        expected_num_rows_store_queue_free = `SQ_SIZE - 2;
        expected_tail_pointer_lq = 2;
        expected_lq_count = 0;
        expected_tail_pointer_sq = 3;
        expected_sq_count = 0;

        expected_load_queue[0].rob_id = 1;
        expected_load_queue[0].store_tail = 1;
        expected_load_queue[0].age = 0;
        expected_load_queue[0].valid = 1;

        expected_load_queue[1].rob_id = 3;
        expected_load_queue[1].store_tail = 2;
        expected_load_queue[1].age = 1;
        expected_load_queue[1].valid = 1;

        expected_store_queue[0].rob_id = 0;
        expected_store_queue[0].load_tail = 3;
        expected_store_queue[0].age = 0;
        expected_store_queue[0].valid = 1;

        expected_store_queue[1].rob_id = 2;
        expected_store_queue[1].load_tail = 1;
        expected_store_queue[1].age = 1;
        expected_store_queue[1].valid = 1;

        expected_store_queue[2].rob_id = 4;
        expected_store_queue[2].load_tail = 2;
        expected_store_queue[2].age = 2;
        expected_store_queue[2].valid = 1;

        @(negedge clock); //480

        for(int i = 0; i < `NUM_LD; i = i + 1) begin
            ex_lsq_load_packet[i].address = i + 1000;
            ex_lsq_load_packet[i].value = i + 250;
            if(i == 0) begin 
                ex_lsq_load_packet[i].rob_id = 1;
            end else if (i == 1) begin
                ex_lsq_load_packet[i].rob_id = 3;
            end
            ex_lsq_load_packet[i].size = WORD;
        end

        for(int i = 0; i < `NUM_ST; i = i + 1) begin
            ex_lsq_store_packet[i].value = i + 250;
            if(i == 0) begin 
                ex_lsq_store_packet[i].rob_id = 0;
            end else if (i == 1) begin
                ex_lsq_store_packet[i].rob_id = 2;
            end else if (i == 2) begin 
                ex_lsq_store_packet[i].rob_id = 4;
            end
            ex_lsq_store_packet[i].size = WORD; 
        end

        ex_lsq_store_packet[0].address = 1001;
        ex_lsq_store_packet[0].address = 1002;
        ex_lsq_store_packet[0].address = 1000;
        @(negedge clock); //480

        expected_num_rows_load_queue_free = `LQ_SIZE;
        expected_num_rows_store_queue_free = `SQ_SIZE;

        expected_load_queue[0].rob_id = 0;
        expected_load_queue[0].store_tail = 0;
        expected_load_queue[0].age = 0;
        expected_load_queue[0].valid = 0;

        expected_load_queue[1].rob_id = 0;
        expected_load_queue[1].store_tail = 0;
        expected_load_queue[1].age = 0;
        expected_load_queue[1].valid = 0;

        
        
        finish_successfully();
    end


endmodule;
