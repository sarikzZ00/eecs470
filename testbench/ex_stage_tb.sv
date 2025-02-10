
`include "ISA.svh"
`include "sys_defs.svh"


module ex_stage_test;

    //INPUTS
    logic clock;
    logic reset;
	logic branch_mispredict_next_cycle;

    RS_EX_PACKET [`N-1:0] input_rows;

        //LD Signals
	CACHE_ROW [`NUM_LD-1:0] forwarding_ld_return;
	CACHE_ROW [`NUM_LD-1:0] memory_ld_return;

        //Squash Signals
	logic need_to_squash;
	logic [`NUM_ROBS_BITS - 1:0] squash_younger_than; //rob_id which we need to squash instructions younger than
	logic [`NUM_ROBS_BITS - 1:0] rob_head_pointer;


    //OUTPUTS
    EX_LD_REQ [`NUM_LD-1:0] lsq_forward_request;
	EX_LD_REQ [`NUM_LD-1:0] dcache_memory_request;
	
	EX_CP_PACKET [`N-1:0] ex_packet_out;
	EX_LSQ_PACKET [`NUM_ST-1:0] ex_lsq_st_out; //Stores that have finished executing
	EX_LSQ_PACKET [`NUM_LD-1:0] ex_lsq_ld_out; //Loads that have finished executing (and are not stalled)
	logic [`NUM_FUNC_UNIT_TYPES-1:0] [31:0] num_fu_free;

        //Debug Outputs [Note: DEBUG_OUT_EX must be 1 for these to work]
    //TODO if needed
	EX_CP_PACKET [`NUM_ALU-1:0] alu_packets_debug;
	EX_CP_PACKET [`NUM_FP-1:0] fp_packets_debug;
	EX_CP_PACKET [`NUM_LD-1:0] ld_packets_debug;

    //Expected values for outputs
    EX_CP_PACKET  				        [`N-1:0] 		expected_ex_packet_out;

	EX_LD_REQ [`NUM_LD-1:0] expected_lsq_forward_request;
	EX_LD_REQ [`NUM_LD-1:0] expected_dcache_memory_request;
	
	EX_LSQ_PACKET [`NUM_ST-1:0] expected_ex_lsq_st_out; //Stores that have finished executing
	EX_LSQ_PACKET [`NUM_LD-1:0] expected_ex_lsq_ld_out; //Loads that have finished executing (and are not stalled)
	logic [`NUM_FUNC_UNIT_TYPES-1:0] [31:0] expected_num_fu_free;
    
	`ifdef DEBUG_OUT_EX
	EX_CP_PACKET [`NUM_ALU-1:0] expected_alu_packets;
	EX_CP_PACKET [`NUM_FP-1:0] expected_fp_packets;
	EX_CP_PACKET [`NUM_LD-1:0] expected_ld_packets;
	`endif

	//File Pointers
	integer fd_execute_std_out;
	integer fd_execute_debug_out;



    ex_stage ex1 (
		//inputs
		.clock(clock), 
		.system_reset(reset), 
		.branch_mispredict_next_cycle(branch_mispredict_next_cycle),

		.input_rows(input_rows),

		.forwarding_ld_return(forwarding_ld_return),
		.memory_ld_return(memory_ld_return),

		.need_to_squash(need_to_squash),
		.squash_younger_than(squash_younger_than), //rob_id which we need to squash instructions younger than
		.rob_head_pointer(rob_head_pointer),


		//outputs
		.lsq_forward_request(lsq_forward_request),
		.dcache_memory_request(dcache_memory_request),
		
		.ex_packet_out(ex_packet_out),
		.ex_lsq_st_out(ex_lsq_st_out), //Stores that have finished executing
		.ex_lsq_ld_out(ex_lsq_ld_out), //Loads that have finished executing (and are not stalled)
		.num_fu_free(num_fu_free)

		//debug outputs
		`ifdef DEBUG_OUT_EX
		,.alu_packets_debug(alu_packets_debug),
		.fp_packets_debug(fp_packets_debug),
		.ld_packets_debug(ld_packets_debug)
		`endif
                    );




	task open_all_files;
		fd_execute_std_out = $fopen("./debug_outputs/execute/Standard_Execute_Outputs.txt");
		fd_execute_debug_out = $fopen("./debug_outputs/execute/Debug_Execute_Outputs.txt");
		$display("All Files Opened");
    endtask

    task close_all_files;
		$fclose(fd_execute_debug_out);
		$fclose(fd_execute_std_out);
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

    task print_ex_cp_packet;
        input EX_CP_PACKET in_packet;
        input integer index;

        $display("Index: %d, result: %h, PC: %h, branch_mispredict: %b, rob_id: %d, dest_reg: %d, is_uncond_branch: %b, is_ld: %b, is_signed: %b, valid %b, halt: %b, illegal: %b",
            index,
            in_packet.result,
			in_packet.PC,
            in_packet.branch_mispredict,
            in_packet.rob_id,
            in_packet.dest_reg,
			in_packet.is_uncond_branch,
			in_packet.is_ld,
			in_packet.is_signed,
            in_packet.valid,
            in_packet.halt,
            in_packet.illegal
        );
    endtask

    task fprint_ex_cp_packet;
        input integer fd;
        input EX_CP_PACKET in_packet;
        input integer index;

        $fdisplay(fd, "Index: %d, result: %h, PC: %h, branch_mispredict: %b, rob_id: %d, dest_reg: %d, is_uncond_branch: %b, is_ld: %b, is_signed: %b, valid %b, halt: %b, illegal: %b",
            index,
            in_packet.result,
			in_packet.PC,
            in_packet.branch_mispredict,
            in_packet.rob_id,
            in_packet.dest_reg,
			in_packet.is_uncond_branch,
			in_packet.is_ld,
			in_packet.is_signed,
            in_packet.valid,
            in_packet.halt,
            in_packet.illegal
        );
    endtask

    task print_ex_lsq_packet;
        input EX_LSQ_PACKET in_packet;
        input integer index;

        $display("Index: %d, address: %h, value: %h, rob_id: %d, valid: %b",
            index,
            in_packet.address,
            in_packet.value,
            in_packet.rob_id,
            in_packet.valid
        );
    endtask

    task fprint_ex_lsq_packet;
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
    endtask

	task compare_ex_packet_out;
        for (int i = 0; i < `N; i = i + 1) begin
            //If both packets are not valid, then the rest of the fields don't matter.
            if (expected_ex_packet_out[i].valid || ex_packet_out[i].valid) begin
                if (expected_ex_packet_out[i] != ex_packet_out[i]) begin
                    $display("ex_packet_out Incorrect");
                    $display("Expected:");
                    print_ex_cp_packet(expected_ex_packet_out[i], i);
                    $display("Actual:");
                    print_ex_cp_packet(ex_packet_out[i], i);
                    exit_on_error();
                end
            end
		end
	endtask

	task compare_ex_lsq_st_out;
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            //If both packets are not valid, then the rest of the fields don't matter.
            if (expected_ex_lsq_st_out[i].valid || ex_lsq_st_out[i].valid) begin
                if (expected_ex_lsq_st_out[i] != ex_lsq_st_out[i]) begin
                    $display("ex_lsq_st_out Incorrect");
                    $display("Expected:");
                    print_ex_lsq_packet(expected_ex_lsq_st_out[i], i);
                    $display("Actual:");
                    print_ex_lsq_packet(ex_lsq_st_out[i], i);
                    exit_on_error();
                end
            end 
		end
	endtask

	task compare_ex_lsq_ld_out;
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
	endtask

    task compare_num_fu_free;
        for (int i = 0; i < `NUM_FUNC_UNIT_TYPES; i = i + 1)begin
            if (expected_num_fu_free[i] != num_fu_free[i]) begin
                $display("Functional Unit %d Incorrect:", i);
                $display("Expected: %d", expected_num_fu_free[i]);
                $display("Actual: %d", num_fu_free[i]);
                exit_on_error();
            end
        end
    endtask

    task compare_all;
		// compare_ld_address();
        // compare_ld_ask_for_forward();
		// compare_ld_ask_for_memory();
		compare_ex_packet_out();
		compare_ex_lsq_st_out();
		compare_ex_lsq_ld_out();
		compare_num_fu_free();
    endtask

    task fprint_ex_stage;
        $fdisplay(fd_execute_std_out, "##########");
        $fdisplay(fd_execute_std_out, "Time: %4.0f", $time);
        $fdisplay(fd_execute_std_out, "##########");
        $fdisplay(fd_execute_std_out, "");

        $fdisplay(fd_execute_std_out, "ex_packet_out:");
        for (int i = 0; i < `N; i = i + 1) begin
            fprint_ex_cp_packet(fd_execute_std_out, ex_packet_out[i], i);
        end
        $fdisplay(fd_execute_std_out, "");

		//TODO: If needed, make new print for the EX_LD_REQ packets

        // $fdisplay(fd_execute_std_out, "LD requests:");
        // for (int i = 0; i < `NUM_LD; i = i + 1) begin
        //     $fdisplay(fd_execute_std_out, "Index: %d, Address: %h, forward_req: %h, mem_req: %h",
        //         i,
        //         ld_address[i],
        //         ld_ask_for_forward[i],
        //         ld_ask_for_memory[i]
        //     );
        // end
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

    endtask

	
	task fprint_debug_only_outputs;
		$fdisplay(fd_execute_debug_out, "##########");
        $fdisplay(fd_execute_debug_out, "Time: %4.0f", $time);
        $fdisplay(fd_execute_debug_out, "##########");
        $fdisplay(fd_execute_debug_out, "");

		`ifdef DEBUG_OUT_EX
			$fdisplay(fd_execute_debug_out, "alu_packets:");
			for (int i = 0; i < `NUM_ALU; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, alu_packets_debug[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");

			$fdisplay(fd_execute_debug_out, "fp_packets:");
			for (int i = 0; i < `NUM_FP; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, fp_packets_debug[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");

			$fdisplay(fd_execute_debug_out, "ld_packets:");
			for (int i = 0; i < `NUM_LD; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute_debug_out, ld_packets_debug[i], i);
			end
			$fdisplay(fd_execute_debug_out, "");
			$fdisplay(fd_execute_debug_out, "====================================================================================================================");
			$fdisplay(fd_execute_debug_out, "");


		`else 
			$fdisplay(fd_execute_debug_out, "DEBUG_OUT_EX is false.");
		`endif

	endtask
	

	//Don't call helper methods here (i.e. ones with inputs)
	task fprint_all;
		fprint_ex_stage();
		fprint_debug_only_outputs();
	endtask

	//Reset all inputs and expected values to their default values.
    task hard_reset;
		//Reset inputs
		branch_mispredict_next_cycle = 0;

    	input_rows = 0;

        //LD Signals
		forwarding_ld_return = 0;
		memory_ld_return = 0;

        //Squash Signals
		need_to_squash = 0;
		squash_younger_than = 0; //rob_id which we need to squash instructions younger than
		rob_head_pointer = 0;

		//Reset expected values
		expected_ex_packet_out = 0;

		expected_lsq_forward_request = 0;
		expected_dcache_memory_request = 0;

		expected_ex_lsq_st_out = 0; //Stores that have finished executing
		expected_ex_lsq_ld_out = 0; //Loads that have finished executing (and are not stalled)


        expected_num_fu_free[ALU] = `NUM_ALU;
        expected_num_fu_free[FP] = `NUM_FP;
		expected_num_fu_free[LD] = `NUM_LD;
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

        
        clock = 0;
		reset = 1;
        hard_reset();
        

        

        

        @(negedge clock); //20
        reset = 0;

		@(posedge clock); //30

        @(negedge clock); //40
		//Set Expected Results For Previous Cycle


		@(posedge clock); //50
		//Set Inputs For This Cycle
		input_rows[0].valid = `TRUE;
		input_rows[0].PC = PC;
		input_rows[0].NPC = PC + 4;
		input_rows[0].rs1_value = 0;
		input_rows[0].rs2_value = 0;
		input_rows[0].inst = `RV32_ADD;
		input_rows[0].alu_func = ALU_ADD;
		input_rows[0].functional_unit = ALU;
		input_rows[0].opa_select = OPA_IS_RS1;
		input_rows[0].opb_select = OPB_IS_RS2;
		input_rows[0].cond_branch = `FALSE;
		input_rows[0].uncond_branch = `FALSE;
		input_rows[0].rob_id = 0;
		input_rows[0].dest_reg = 0;
		input_rows[0].halt = `FALSE;
		input_rows[0].illegal = `FALSE;
		PC = PC + 4;

		input_rows[1].valid = `TRUE;
		input_rows[1].PC = PC;
		input_rows[1].NPC = PC + 4;
		input_rows[1].rs1_value = 1;
		input_rows[1].rs2_value = 1;
		input_rows[1].inst = `RV32_ADD;
		input_rows[1].alu_func = ALU_ADD;
		input_rows[1].functional_unit = ALU;
		input_rows[1].opa_select = OPA_IS_RS1;
		input_rows[1].opb_select = OPB_IS_RS2;
		input_rows[1].cond_branch = `FALSE;
		input_rows[1].uncond_branch = `FALSE;
		input_rows[1].rob_id = 1;
		input_rows[1].dest_reg = 1;
		input_rows[1].halt = `FALSE;
		input_rows[1].illegal = `FALSE;
		PC = PC + 4;

		input_rows[2].valid = `TRUE;
		input_rows[2].PC = PC;
		input_rows[2].NPC = PC + 4;
		input_rows[2].rs1_value = 100;
		input_rows[2].rs2_value = 93;
		input_rows[2].inst = `RV32_ADD;
		input_rows[2].alu_func = ALU_ADD;
		input_rows[2].functional_unit = ALU;
		input_rows[2].opa_select = OPA_IS_RS1;
		input_rows[2].opb_select = OPB_IS_RS2;
		input_rows[2].cond_branch = `FALSE;
		input_rows[2].uncond_branch = `FALSE;
		input_rows[2].rob_id = 2;
		input_rows[2].dest_reg = 2;
		input_rows[2].halt = `FALSE;
		input_rows[2].illegal = `FALSE;
		PC = PC + 4;

		input_rows[3].valid = `TRUE;
		input_rows[3].PC = PC;
		input_rows[3].NPC = PC + 4;
		input_rows[3].rs1_value = -5;
		input_rows[3].rs2_value = -99;
		input_rows[3].inst = `RV32_ADD;
		input_rows[3].alu_func = ALU_ADD;
		input_rows[3].functional_unit = ALU;
		input_rows[3].opa_select = OPA_IS_RS1;
		input_rows[3].opb_select = OPB_IS_RS2;
		input_rows[3].cond_branch = `FALSE;
		input_rows[3].uncond_branch = `FALSE;
		input_rows[3].rob_id = 3;
		input_rows[3].dest_reg = 3;
		input_rows[3].halt = `FALSE;
		input_rows[3].illegal = `FALSE;
		PC = PC + 4;

		input_rows[4].valid = `TRUE;
		input_rows[4].PC = PC;
		input_rows[4].NPC = PC + 4;
		input_rows[4].rs1_value = 999;
		input_rows[4].rs2_value = 1001;
		input_rows[4].inst = `RV32_ADD;
		input_rows[4].alu_func = ALU_ADD;
		input_rows[4].functional_unit = ALU;
		input_rows[4].opa_select = OPA_IS_RS1;
		input_rows[4].opb_select = OPB_IS_RS2;
		input_rows[4].cond_branch = `FALSE;
		input_rows[4].uncond_branch = `FALSE;
		input_rows[4].rob_id = 4;
		input_rows[4].dest_reg = 4;
		input_rows[4].halt = `FALSE;
		input_rows[4].illegal = `FALSE;
		PC = PC + 4;

		


		



        @(negedge clock); //60
		//Set Expected Results For Previous Cycle
		expected_ex_packet_out[0].result = 0;
		expected_ex_packet_out[0].PC = 0;
		expected_ex_packet_out[0].branch_mispredict = `FALSE;
		expected_ex_packet_out[0].rob_id = 0;
		expected_ex_packet_out[0].dest_reg = 0;
		expected_ex_packet_out[0].valid = `TRUE;
		expected_ex_packet_out[0].halt = `FALSE;
		expected_ex_packet_out[0].illegal = `FALSE;

		if (`N > 1) begin
		expected_ex_packet_out[1].result = 2;
		expected_ex_packet_out[1].branch_mispredict = `FALSE;
		expected_ex_packet_out[1].PC = 4;
		expected_ex_packet_out[1].rob_id = 1;
		expected_ex_packet_out[1].dest_reg = 1;
		expected_ex_packet_out[1].valid = `TRUE;
		expected_ex_packet_out[1].halt = `FALSE;
		expected_ex_packet_out[1].illegal = `FALSE;
		end

		if (`N > 2) begin
		expected_ex_packet_out[2].result = 193;
		expected_ex_packet_out[2].PC = 8;
		expected_ex_packet_out[2].branch_mispredict = `FALSE;
		expected_ex_packet_out[2].rob_id = 2;
		expected_ex_packet_out[2].dest_reg = 2;
		expected_ex_packet_out[2].valid = `TRUE;
		expected_ex_packet_out[2].halt = `FALSE;
		expected_ex_packet_out[2].illegal = `FALSE;
		end

		if (`N > 3) begin
		expected_ex_packet_out[3].result = -104;
		expected_ex_packet_out[3].PC = 12;
		expected_ex_packet_out[3].branch_mispredict = `FALSE;
		expected_ex_packet_out[3].rob_id = 3;
		expected_ex_packet_out[3].dest_reg = 3;
		expected_ex_packet_out[3].valid = `TRUE;
		expected_ex_packet_out[3].halt = `FALSE;
		expected_ex_packet_out[3].illegal = `FALSE;
		end

		if (`N > 4) begin
		expected_ex_packet_out[4].result = 2000;
		expected_ex_packet_out[4].PC = 16;
		expected_ex_packet_out[4].branch_mispredict = `FALSE;
		expected_ex_packet_out[4].rob_id = 4;
		expected_ex_packet_out[4].dest_reg = 4;
		expected_ex_packet_out[4].valid = `TRUE;
		expected_ex_packet_out[4].halt = `FALSE;
		expected_ex_packet_out[4].illegal = `FALSE;
		end

		@(posedge clock) // 70
		//Set Inputs For This Cycle
		input_rows[0].valid = `FALSE;
		input_rows[1].valid = `FALSE;
		input_rows[2].valid = `FALSE;
		input_rows[3].valid = `FALSE;
		input_rows[4].valid = `FALSE;

        @(negedge clock); //80
		//Set Expected Results For Previous Cycle
		expected_ex_packet_out[0].valid = `FALSE;
		expected_ex_packet_out[1].valid = `FALSE;
		expected_ex_packet_out[2].valid = `FALSE;
		expected_ex_packet_out[3].valid = `FALSE;
		expected_ex_packet_out[4].valid = `FALSE;

		@(posedge clock) //90
		//Set Inputs For This Cycle


        @(negedge clock); //100
		//Set Expected Results For Previous Cycle

		

        @(posedge clock); //110
		//Set Inputs For This Cycle


        finish_successfully();
    end
endmodule
