
`include "ISA.svh"
`include "sys_defs.svh"




module dcache_test;
	//INPUTS
	logic 	clock;
	logic	reset;
	MEMORY_RESPONSE		mem2proc_packet;
    EX_LD_REQ [`NUM_LD-1:0] load_req;
	MEMORY_STORE_REQUEST	store_req;
//	TAG_LOCATION			mem_service_broadcast;

	// OUTPUTS
	MEMORY_REQUEST 		dcache_req;
	CACHE_ROW [`N-1:0] 	dcache_rows_out;
	logic				write_success;
	DCACHE_PACKET [`CACHE_LINES-1:0] dcache;




	//File Pointers
	integer fd_dcache;
    integer fd_dcache_std_out;


dcache dcache_0(
    // INPUTS
    .clock(clock),
	.reset(reset),
	.mem2proc_packet(mem2proc_packet),
	.load_req(load_req),
	.store_req(store_req),
//	.mem_service_broadcast(mem_service_broadcast),

    // OUTPUTS
	.dcache_req(dcache_req),
	.dcache_rows_out(dcache_rows_out),
	.write_success(write_success)
	`ifdef DEBUG_OUT_DCACHE
		,
		.dcache_debug(dcache)
	`endif
);




	task open_all_files;
    
		//fd_dcache_std_out = $fopen("./debug_outputs/execute/Standard_Execute_Outputs.txt");
		fd_dcache = $fopen("./debug_outputs/execute/Dcache_Outputs.txt");
		$display("All Files Opened");
    endtask

    task close_all_files;

        $fclose(fd_dcache);
		//$fclose(fd_execute_std_out);
		$display("All Files Closed");
    endtask

    task exit_on_error;
    
        $display("@@@Failed",$time);
        $display("@@@ Incorrect at time %4.0f", $time);
        $display("@@@ Time:%4.0f clock:%b", $time, clock);
        $display("");
		close_all_files();
        $finish;
    endtask

	task finish_successfully;
        $display("@@@Passed");
		close_all_files();
        $finish;
    endtask

    integer dcache_out_int;
	task print_mem_dcache_inputs();
	`ifdef DEBUG_OUT_DCACHE
		$display("write_success: %b", write_success);
        
        $display("\t\t|LINE\t|\tSIZE\t|\tADDR");
        $display("\t\t--------------------------------------");
		for (dcache_out_int = 0; dcache_out_int < `NUM_LD; dcache_out_int = dcache_out_int + 1) begin
            if (dcache_rows_out[dcache_out_int].valid == `TRUE) begin
                $display("\t%h|\t%0s\t|\t%h\t|",
                    dcache_rows_out[dcache_out_int].line,
                    dcache_rows_out[dcache_out_int].size.name(),
                    dcache_rows_out[dcache_out_int].addr
                );
            end
        end

        $display("DCACHE_REQ:");
        $display("Command: %0s  Data: %h    Addr:  %h", dcache_req.command.name(), dcache_req.data, dcache_req.addr);
        $display(""); // new line

    `endif
    endtask



    integer dcache_index;
	task print_dcache_outputs();
	`ifdef DEBUG_OUT_DCACHE
		$display("write_success: %b", write_success);
        
        $display("WRITE_OUT");
        $display("\t\t|LINE\t|\tSIZE\t|\tADDR");
        $display("\t\t--------------------------------------");
		for (dcache_index = 0; dcache_index < `NUM_LD; dcache_index = dcache_index + 1) begin
            if (dcache_rows_out[dcache_index].valid == `TRUE) begin
                $display("\t%h|\t%0s\t|\t%h\t|",
                    dcache_rows_out[dcache_index].line,
                    dcache_rows_out[dcache_index].size.name(),
                    dcache_rows_out[dcache_index].addr
                );
            end
        end
    `endif
    endtask


	integer dcache_index;
	task print_dcache;
	`ifndef DEBUG_OUT_DCACHE
		$display("Silly! You forgot to define DEBUG_OUT_DCACHE");
	`endif
	`ifdef DEBUG_OUT_DCACHE

		$display("\t\t|STATUS\t|\tTAG\t|\tDATA");
		$display("\t\t--------------------------------------");
		for (dcache_index = 0; dcache_index < 32; dcache_index = dcache_index + 1) begin
			$display("\t%d\t|\t%0s\t|\t%h\t|\t%h\t",
				dcache_index,
				dcache[dcache_index].status.name(),
				dcache[dcache_index].tag,
				dcache[dcache_index].block
			);
		end

        print_dcache_outputs();
        
        print_mem_dcache_inputs();

   `endif
    endtask


    task print_ex_cp_packet;
    /*
        input EX_CP_PACKET in_packet;
        input integer index;

        $display("Index: %d, result: %h, branch_mispredict: %b, rob_id: %d, dest_reg: %d, valid %b, halt: %b, illegal: %b",
            index,
            in_packet.result,
            in_packet.branch_mispredict,
            in_packet.rob_id,
            in_packet.dest_reg,
            in_packet.valid,
            in_packet.halt,
            in_packet.illegal
        );
    */
    endtask

    task fprint_ex_cp_packet;
    /*
        input integer fd;
        input EX_CP_PACKET in_packet;
        input integer index;

        $fdisplay(fd, "Index: %d, result: %h, branch_mispredict: %h, rob_id: %d, dest_reg: %d, valid %b, halt: %b, illegal: %b",
            index,
            in_packet.result,
            in_packet.branch_mispredict,
            in_packet.rob_id,
            in_packet.dest_reg,
            in_packet.valid,
            in_packet.halt,
            in_packet.illegal
        );
    */
    endtask

    task print_ex_lsq_packet;
    /*
        input EX_LSQ_PACKET in_packet;
        input integer index;

        $display("Index: %d, address: %h, value: %h, rob_id: %d, valid: %b",
            index,
            in_packet.address,
            in_packet.value,
            in_packet.rob_id,
            in_packet.valid
        );
    */
    endtask

    task fprint_ex_lsq_packet;
    /*
        input integer fd;
        input EX_LSQ_PACKET in_packet;
        input integer index;

        $fdisplay(fd, "Index: %d, address: %h, value: %h, rob_id: %d, valid: %b",
            index,
            in_packet.address,
            in_packet.value,
            in_packet.rob_id,
            in_packet.valid
        );
    */
    endtask

	task compare_ld_address;
    /*
		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_ld_address[i] != ld_address[i]) begin
                $display("ld_address Incorrect");
                $display("Expected: %h", expected_ld_address[i]);
                $display("Actual: %h", ld_address[i]);
                exit_on_error();
            end
		end
    */
	endtask

	task compare_ld_ask_for_forward;
    /*
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_ld_ask_for_forward[i] != ld_ask_for_forward[i]) begin
                $display("ld_ask_for_forward Incorrect");
                $display("Expected: %b", expected_ld_ask_for_forward[i]);
                $display("Actual: %b", ld_ask_for_forward[i]);
                exit_on_error();
            end
		end
 */
	endtask

	task compare_ld_ask_for_memory;
    /*
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
			if (expected_ld_ask_for_memory[i] != ld_ask_for_memory[i]) begin
                $display("ld_ask_for_memory Incorrect");
                $display("Expected: %b", expected_ld_ask_for_memory[i]);
                $display("Actual: %b", ld_ask_for_memory[i]);
                exit_on_error();
            end
		end
 */
	endtask

	task compare_ex_packet_out;
    /*
        for (int i = 0; i < `N; i = i + 1) begin
            //If both packets are not valid, then the rest of the fields don't matter.
            if (expected_ex_packet_out[i].valid || ex_packet_out[i].valid) begin
                if (expected_ex_packet_out[i] != ex_packet_out[i]) begin
                    $display("ex_packet_out Incorrect");
                    $display("Expected:");
                    print_ex_cp_packet(expected_ex_packet_out, i);
                    $display("Actual:");
                    print_ex_cp_packet(ex_packet_out, i);
                    exit_on_error();
                end
            end
		end
 */
	endtask

	task compare_ex_lsq_st_out;
    /*
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            //If both packets are not valid, then the rest of the fields don't matter.
            if (expected_ex_lsq_st_out[i].valid || ex_lsq_st_out[i].valid) begin
                if (expected_ex_lsq_st_out[i] != ex_lsq_st_out[i]) begin
                    $display("ex_lsq_st_out Incorrect");
                    $display("Expected:");
                    print_ex_lsq_packet(expected_ex_lsq_st_out, i);
                    $display("Actual:");
                    print_ex_lsq_packet(ex_lsq_st_out, i);
                    exit_on_error();
                end
            end 
		end
 */
	endtask

	task compare_ex_lsq_ld_out;
    /*
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
            //If both packets are not valid, then the rest of the fields don't matter.
            if (expected_ex_lsq_ld_out[i].valid || ex_lsq_ld_out[i].valid) begin
                if (expected_ex_lsq_ld_out[i] != ex_lsq_ld_out[i]) begin
                    $display("ex_lsq_ld_out Incorrect");
                    $display("Expected:");
                    print_ex_lsq_packet(expected_ex_lsq_ld_out, i);
                    $display("Actual:");
                    print_ex_lsq_packet(ex_lsq_ld_out, i);
                    exit_on_error();
                end
            end 
		end
 */
	endtask

    task compare_num_fu_free;
    /*
        for (int i = 0; i < `NUM_FUNC_UNIT_TYPES; i = i + 1)begin
            if (expected_num_fu_free[i] != num_fu_free[i]) begin
                $display("Functional Unit %d Incorrect:", i);
                $display("Expected: %d", expected_num_fu_free[i]);
                $display("Actual: %d", num_fu_free[i]);
                exit_on_error();
            end
        end
    */
    endtask

    task compare_all;
    /*
		compare_ld_address();
        compare_ld_ask_for_forward();
		compare_ld_ask_for_memory();
		compare_ex_packet_out();
		compare_ex_lsq_st_out();
		compare_ex_lsq_ld_out();
		compare_num_fu_free();
    */
    endtask

    task fprint_ex_stage;
    /*
        $fdisplay(fd_execute_std_out, "##########");
        $fdisplay(fd_execute_std_out, "Time: %4.0f", $time);
        $fdisplay(fd_execute_std_out, "##########");
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "ex_packet_out:");
        for (int i = 0; i < `N; i = i + 1) begin
            fprint_ex_cp_packet(fd_execute_std_out, ex_packet_out[i], i);
        end
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "LD requests:");
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
            $fdisplay(fd_execute_std_out, "Index: %d, Address: %h, forward_req: %h, mem_req: %h",
                i,
                ld_address[i],
                ld_ask_for_forward[i],
                ld_ask_for_memory[i]
            );
        end
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "Completed Stores:");
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            fprint_ex_lsq_packet(fd_execute_std_out, ex_lsq_st_out, i);
        end
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "Completed Loads");
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            fprint_ex_lsq_packet(fd_execute_std_out, ex_lsq_ld_out, i);
        end
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "Functional Units Free:");
        for (logic [$clog2(`NUM_FUNC_UNIT_TYPES):0] i = 0; i < `NUM_FUNC_UNIT_TYPES; i = i + 1) begin
            //print out all FUs to the same line since it's pretty small.
            $fwrite(fd_execute_std_out, "FU %d Free:%d | ", i, num_fu_free[i]);
        end
        $fwrite(fd_execute_std_out, "\n"); //End the FU line

        $fdisplay(fd_execute_std_out, "");
        $fdisplay(fd_execute_std_out, "====================================================================================================================");
        $fdisplay(fd_execute_std_out, "");

    */
    endtask

	
	task fprint_debug_only_outputs;
    /*
		$fdisplay(fd_execute_debug_out, "##########");
        $fdisplay(fd_execute_debug_out, "Time: %4.0f", $time);
        $fdisplay(fd_execute_debug_out, "##########");
        $fdisplay(fd_execute_debug_out, "");

		`ifdef DEBUG_OUT_EX
			$fdisplay(fd_execute_debug_out, "alu_packets:");
			for (int i = 0; i < `NUM_ALU; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, alu_packets[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");

			$fdisplay(fd_execute_debug_out, "fp_packets:");
			for (int i = 0; i < `NUM_FP; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, fp_packets[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");

			$fdisplay(fd_execute_debug_out, "ld_packets:");
			for (int i = 0; i < `NUM_LD; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, ld_packets[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");
			$fdisplay(fd_execute_debug_out, "====================================================================================================================");
			$fdisplay(fd_execute_debug_out, "");


		`else 
			$fdisplay(fd_execute_debug_out, "DEBUG_OUT_EX is false.");
		`endif

 */
	endtask
	

	//Don't call helper methods here (i.e. ones with inputs)
	task fprint_all;
    /*
		fprint_ex_stage();
		fprint_debug_only_outputs();
 */
	endtask

	//Reset all inputs and expected values to their default values.
    task hard_reset;
    /*
		//Reset inputs
		ld_memory_result_here = 0;
		ld_memory_result_here = 0;
		ld_memory_results = 0;
		ld_memory_addresses = 0;

		ld_found_forward = 0;
		ld_forwarding_results = 0;
		ld_forwarding_addresses = 0;

		need_to_squash = 0;
		squash_younger_than = 0;
		rob_head_pointer = 0;

		//Reset expected values
		expected_ld_address = 0;
		expected_ld_ask_for_forward = 0;
		expected_ld_ask_for_memory = 0;

		expected_ex_packet_out = 0;
		expected_ex_lsq_st_out = 0;
		expected_ex_lsq_ld_out = 0;

        expected_num_fu_free[ALU] = `NUM_ALU;
        expected_num_fu_free[FP] = `NUM_FP;
		expected_num_fu_free[LD] = `NUM_LD;
    */
    endtask


	always begin
        #10 clock = ~clock;
    end

	always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
        #5; //#5 Allows time for all outputs to settle
		fprint_all();
		compare_all(); 
		
    end

	integer PC;
    initial begin
		open_all_files();

        $display("STARTING TESTBENCH!");
		PC = 0;

		if (`N != 5) begin
			$display("This testbench only works for N = 5");
            finish_successfully();
        end
        
        clock = 0;
		reset = 1;
        hard_reset();

        @(negedge clock); //20

        reset = 0;

		@(posedge clock); //30

        @(negedge clock); //40

		//Set Expected Results For Previous Cycle

		// TEST CASE 1: JUST STORE A BUNCH OF THINGS
        $display("TEST CASE 1");
		store_req.addr = 'hfff0;
		store_req.data = 'hbeef;
		store_req.size = WORD;
		store_req.valid = `TRUE;

        @(negedge clock); 

		print_dcache();


		store_req.addr = 'hffa4;
		store_req.data = 'hfeed;
		store_req.size = WORD;
		store_req.valid = `TRUE;

        @(negedge clock);

		print_dcache();

        load_req[0].address = 'hffb8;
        load_req[0].rob_id = 5; 
        load_req[0].size = WORD;
        load_req[0].valid = `TRUE;

        @(negedge clock);
        load_req = 0;

		print_dcache();


        // TEST CASE 2: READ AN INVALID BLOCK. 
        $display("TEST CASE 2");
		reset = 1;
        hard_reset();

        @(negedge clock);

        reset = 0;
        load_req[0].address = 'h00fc;
        load_req[0].rob_id = 'h02;
        load_req[0].size = WORD;
        load_req[0].valid = `TRUE;

        @(negedge clock);
        load_req = 0;

		print_dcache();


        // TEST CASE 3: WRITE A VALUE TO THE CACHE, BUT THE CACHE IS 
        // FULL, SO EVICT THE CORRECT ENTRY
        $display("TEST CASE 3");
		reset = 1;
        hard_reset();     

        @(negedge clock);

        reset = 0;        
		store_req.addr = 32'hc010_ffa0;
		store_req.data = 'hfeed;
		store_req.size = WORD;
		store_req.valid = `TRUE;

        @(negedge clock);

		store_req.addr = 32'hd010_3230;
		store_req.data = 'hfeed;
		store_req.size = WORD;
		store_req.valid = `TRUE;

        @(negedge clock);

		print_dcache();


        // TEST CASE 4: WRTIE TO AN INVALID BLOCK, SO WE DON'T EVICT 
        // NOT APPLICABLE
        $display("TEST CASE 4");


        //TEST CASE 5: WRITE A BYTE OR HALF_WORD OF DATA RATHER THAN A FULL BLOCK
        $display("TEST CASE 5");
		reset = 1;
        hard_reset();     

        @(negedge clock);

        reset = 0;        
	    store_req.addr = 32'h0000_0010;
        store_req.data = 64'hAAAA_BBBB_CCCC_DDDD;
		store_req.size = HALF;
		store_req.valid = `TRUE;

        @(negedge clock);

		print_dcache();


        // TEST CASE 6: WRITE A VALID VALUE, 
        // AND THEN HAVE ANOTHER WRITE TO THE SAME INDEX

        // addr A and B index into the same cache line
        // store x into A
        // store y into B
        // load from A (which should output x)
        // store x into A

        $display("TEST CASE 6");
		reset = 1;
        hard_reset();     

        @(negedge clock);

        begin

        localparam addrA = 32'h6000_0010;
        localparam addrB = 32'h4000_0010;

        reset = 0;        
	    store_req.addr = addrA;
        store_req.data = 64'h42;
		store_req.size = BYTE;
		store_req.valid = `TRUE;
        $display("store %h to %h in type %h", 
            store_req.data, 
            store_req.addr,
            store_req.size
        );

        @(negedge clock);

        // now get a response from memory

	    store_req.addr = addrB;
        store_req.data = 64'h92;
		store_req.size = BYTE;
		store_req.valid = `TRUE;
        $display("store %h to %h in type %h", 
            store_req.data, 
            store_req.addr,
            store_req.size
        );

        @(negedge clock);
        store_req = 0;

        print_dcache();

        mem2proc_packet             = 'b0; // reset needed
        mem2proc_packet.response    = 3'b101;
        mem2proc_packet.tag         = 3'b001;
        $display("memory resp:%b tag:%b", 
            mem2proc_packet.response,
            mem2proc_packet.tag,
        );

        @(negedge clock);

        mem2proc_packet             = 'b0; // TODO keep tag or not?
        mem2proc_packet.response    = 3'b000; // not valid yet
        mem2proc_packet.data        = 64'hbbbd;
        $display("memory resp:%b data:%h", 
            mem2proc_packet.response,
            mem2proc_packet.data,
        );

        repeat(5) @(negedge clock);

        mem2proc_packet             = 'b0; // TODO keep response or not?
        mem2proc_packet.tag         = 3'b001; // valid here?
        mem2proc_packet.data        = 64'hdead;
        $display("memory tag:%b data:%h", 
            mem2proc_packet.tag,
            mem2proc_packet.data,
        );

        print_dcache();
        @(negedge clock);

        mem2proc_packet             = 'b0; // TODO keep tag or not?
        mem2proc_packet.response    = 3'b101;
        mem2proc_packet.data        = 64'hbeef;
        $display("memory resp:%b data:%h", 
            mem2proc_packet.response,
            mem2proc_packet.data,
        );

        print_dcache();

        load_req[1].address = addrA;
        load_req[1].rob_id = 'h07;
        load_req[1].size = BYTE;
        load_req[1].valid = `TRUE;
        $display("load  %h to %d in type %h", 
            load_req[1].address, 
            load_req[1].rob_id,
            load_req[1].size
        );

        @(negedge clock);
        load_req = 0;

        print_dcache();

	    store_req.addr = addrA;
        store_req.data = 64'h24;
		store_req.size = BYTE;
		store_req.valid = `TRUE;
        $display("store %h to %h in type %h", 
            store_req.data, 
            store_req.addr,
            store_req.size
        );

        @(negedge clock);

        print_dcache();

        end

        @(negedge clock);

		print_dcache();


        // TEST CASE 7: 
        $display("TEST CASE 7");
		reset = 1;
        hard_reset();     

        @(negedge clock);

        // addr A and B index into the same cache line
        // store into A
        // (resp from memory)
        // store into B
        // load  from A 
        // load  from A 
        // store into B
        // load  from A 
        // load  from B
        begin

        localparam addrA = 32'h6000_0010;
        localparam addrB = 32'h4000_0010;

        reset = 0;        
	    store_req.addr = addrA;
        store_req.data = 64'h42;
		store_req.size = BYTE;
		store_req.valid = `TRUE;

        @(negedge clock);

	    store_req.addr = addrA;
        store_req.data = 64'h42;
		store_req.size = BYTE;
		store_req.valid = `TRUE;

		print_dcache();

        @(negedge clock);
        store_req = 0;

        repeat(3) @(negedge clock);

        // mem2proc_packet             = 'b0; // reset needed
        // mem2proc_packet.response    = 3'b010;
        // mem2proc_packet.tag         = 3'b010;
        // $display("memory resp:%b tag:%b", 
        //     mem2proc_packet.response,
        //     mem2proc_packet.tag,
        // );

        @(negedge clock);
		print_dcache();

        repeat(3) @(negedge clock);

	    // store_req.addr = addrB;
        // store_req.data = 64'h92;
		// store_req.size = BYTE;
		// store_req.valid = `TRUE;
        // @(negedge clock);

        // load_req[1].address = addrA;
        // load_req[1].rob_id = 'h07;
        // load_req[1].size = BYTE;
        // load_req[1].valid = `TRUE;
        // @(negedge clock);

	    // store_req.addr = addrA;
        // store_req.data = 64'h24;
		// store_req.size = BYTE;
		// store_req.valid = `TRUE;
        // @(negedge clock);

        end

        @(negedge clock);

		print_dcache();

        finish_successfully();


    end

endmodule

