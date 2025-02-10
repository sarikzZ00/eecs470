
module complete_tb;
    logic clock;
    logic reset;
    //Ex input
    EX_CP_PACKET [`N-1:0] ex_pack;

    //Squashing inputs
    logic need_to_squash;
	logic [`NUM_ROBS_BITS - 1:0] squash_younger_than;
	logic [`NUM_ROBS_BITS - 1:0] rob_head_pointer;

    //Load replacement input
    logic [`N-1:0] [`XLEN-1:0] ld_replacement_values;

    //Output
    CDB_ROW [`N-1:0] cdb_table;
    
    //Expected output
    CDB_ROW [`N-1:0] expected_cdb_table;

    int fd_complete;
    complete c1 (
        .clock(clock),
        .reset(reset),
        .ex_pack(ex_pack),
        .squash_younger_than(squash_younger_than),
        .rob_head_pointer(rob_head_pointer),
        .ld_replacement_values(ld_replacement_values),
        .cdb_table(cdb_table)
    );
    
    task open_all_files;
		$display("Opening All Files");
		fd_complete = $fopen("./debug_outputs/reservation_output.txt", "w");
	endtask

    task close_all_files;
		$display("Closing All Files");
		$fclose(fd_complete);
	endtask

    task print_CDB_output;
        $fdisplay(fd_complete, "CDB at time %d", $time);
        for(int j = 0; j < `N; j = j + 1) begin 
            print_CDB_table_entry(j, cdb_table[j]);
        end
	endtask

    task print_CDB_table_entry; 
        input index;
        input CDB_ROW input_packet;
    
        $display("index:%d, phys_regs:%h, valid:%h, branch_mispredict:%h, rob_id:%h, result:%h, PC_plus_4:%h, is_uncond_branch:%h, halt:%h, illegal:%h",
                 index, 
                 input_packet.phys_regs,
                 input_packet.valid,
                 input_packet.branch_mispredict,
                 input_packet.rob_id,
                 input_packet.result,
                 input_packet.PC_plus_4,
                 input_packet.is_uncond_branch,
                 input_packet.halt,
                 input_packet.illegal);

    endtask
    task exit_on_error;
        begin
            $display("@@@Failed",$time);
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Time:%4.0f clock:%b", $time, clock);
            $finish;
        end
    endtask;

    task hard_reset;
        for(int reset_index = 0; reset_index < `N; reset_index = reset_index + 1) begin 
            ex_pack[reset_index] = 'b0;
        end
    endtask;

    
    task compare_cdb_table;
        for(int cdb_index = 0; cdb_index < `N; cdb_index = cdb_index + 1) begin
            if(cdb_table[cdb_index] != expected_cdb_table[cdb_index]) begin
                $display("Expected CDB Table Entry at Index %d", cdb_index);
                print_CDB_table_entry(cdb_index, expected_cdb_table[cdb_index]);
                $display("Actual CDB Table Entry at Index %d", cdb_index);
                print_CDB_table_entry(cdb_index, cdb_table[cdb_index]);
            end
        end
    endtask;


    always @(negedge clock) begin
         $display("##########");
         $display("Time: %4.0f", $time);
         $display("##########");
         #5; 
         print_CDB_output();
         compare_cdb_table(); //#5 Allows time for all outputs to settle
    end

    always begin
        #5 clock <= ~clock;
    end

    initial begin
    
    clock = 1'b0; 
    reset = 1'b1;
    hard_reset(); 
    @(negedge clock);
    //TEST 1, no need to squash, no loads
    $display("----------- STARTING TEST 1 ---------");
    reset = 0;
    need_to_squash = 0;
    squash_younger_than = 2;
    rob_head_pointer = 3;
    
    for (int i = 0; i < `N; i = i + 1) begin
        ld_replacement_values[i] = 5 + i;
        ex_pack[i].result = 10 + i;
        ex_pack[i].PC = i + 4;
        ex_pack[i].branch_mispredict = 0;
        ex_pack[i].rob_id = i;
        ex_pack[i].dest_reg = i + 3;
        ex_pack[i].is_uncond_branch = 0;
        ex_pack[i].is_ld = 0;
        ex_pack[i].is_signed = 1;
        ex_pack[i].valid = 1;
        ex_pack[i].halt = 0;
        ex_pack[i].illegal = 0;    
    end
   
   //Set the expected CDB_table

   for (int i = 0; i < `N; i = i + 1) begin
        expected_cdb_table[i].phys_regs = i + 3;
        expected_cdb_table[i].valid = 1;
        expected_cdb_table[i].branch_mispredict = 0;  
        expected_cdb_table[i].rob_id = i;
        expected_cdb_table[i].result = 10 + i;
        expected_cdb_table[i].PC_plus_4 = i + 8;
        expected_cdb_table[i].is_uncond_branch = 0;
        expected_cdb_table[i].halt = 0;
        expected_cdb_table[i].illegal = 0;
   end

    compare_cdb_table();
    @(negedge clock);

    //TEST 2, need_to_squash = 1, no loads
    $display("----------- STARTING TEST 2 ---------");
    need_to_squash = 1;
    squash_younger_than = 2;
    rob_head_pointer = 1;
    //Set the ex_pack
    for (int i = 0; i < `N; i = i + 1) begin
        ex_pack[i].result = 10 + i;
        ex_pack[i].PC = i + 4;
        ex_pack[i].branch_mispredict = 0;
        ex_pack[i].rob_id = i;      // 0 1 2 3 4
        ex_pack[i].dest_reg = i + 3;
        ex_pack[i].is_uncond_branch = 0;
        ex_pack[i].is_ld = 0;
        ex_pack[i].is_signed = 1;
        ex_pack[i].valid = 1;
        ex_pack[i].halt = 0;
        ex_pack[i].illegal = 0;    
    end


    $display("@@@Passed");
    $finish;
    /*
    ex_pack[0].result = 12;
    ex_pack[0].NPC = 4;
    ex_pack[0].PC = 0;
    ex_pack[0].take_branch = 0;
    ex_pack[0].rob_id = `NUM_ROBS_BITS'd1;
    ex_pack[0].tag_dest = `NUM_PHYS_BITS'd4;
    ex_pack[0].tag_1 = `NUM_PHYS_BITS'd1;
    ex_pack[0].tag_2 = `NUM_PHYS_BITS'd2;
    ex_pack[0].done = `NUM_ROBS_BITS'd1;
    ex_pack[0].functional_unit = ST;
    ex_pack[0].inst = `XLEN'h0042_033b;
    ex_pack[0].opa_select = OPA_IS_RS1;
    ex_pack[0].opb_select = OPB_IS_RS2;

    ex_pack[2].result = 16;
    ex_pack[2].NPC = 4;
    ex_pack[2].PC = 0;
    ex_pack[2].take_branch = 1;
    ex_pack[2].rob_id = `NUM_ROBS_BITS'd2;
    ex_pack[2].tag_dest = `NUM_PHYS_BITS'd6;
    ex_pack[2].tag_1 = `NUM_PHYS_BITS'd1;
    ex_pack[2].tag_2 = `NUM_PHYS_BITS'd2;
    ex_pack[2].done = 1;
    ex_pack[2].functional_unit = ALU;
    ex_pack[2].inst = `XLEN'h0042_033b;
    ex_pack[2].opa_select = OPA_IS_RS1;
    ex_pack[2].opb_select = OPB_IS_RS2;

    ex_pack[3].result = 16;
    ex_pack[3].NPC = 4;
    ex_pack[3].PC = 0;
    ex_pack[3].take_branch = 1;
    ex_pack[3].rob_id = `NUM_ROBS_BITS'd3;
    ex_pack[3].tag_dest = `NUM_PHYS_BITS'd6;
    ex_pack[3].tag_1 = `NUM_PHYS_BITS'd1;
    ex_pack[3].tag_2 = `NUM_PHYS_BITS'd2;
    ex_pack[3].done = 1;
    ex_pack[3].functional_unit = ALU;
    ex_pack[3].inst = `XLEN'h0042_033b;
    ex_pack[3].opa_select = OPA_IS_RS1;
    ex_pack[3].opb_select = OPB_IS_RS2;

    cp.expected_num_complete = 1;

    cp.expected_rob_id_vec[0] = `NUM_ROBS_BITS'd0;
    cp.expected_map_valid_vec[0] = 1'b1;
    cp.expected_cdb_table.phys_regs[0] = `NUM_PHYS_BITS'd3;
    cp.expected_cdb_table.valid[0] = 1;
    cp.expected_cdb_table.branch_mispredict[0] = 1'b0;
    cp.expected_wr_en_vec[0] = 1'd1;
    cp.expected_wr_data_vec[0] = `XLEN'd5;
    cp.expected_wr_idx_vec[0] = `NUM_PHYS_BITS'd3;

    compare_all(cp);
    @(negedge clock);

    hard_reset(); 

    cp.expected_num_complete = 2;

    cp.expected_rob_id_vec[0] = `NUM_ROBS_BITS'd1;
    cp.expected_map_valid_vec[0] = 1'b0;
    cp.expected_wr_en_vec[0] = 1'd0;
    cp.expected_wr_data_vec[0] = `XLEN'd0;
    cp.expected_wr_idx_vec[0] = `NUM_PHYS_BITS'd0;
    cp.expected_cdb_table.phys_regs[0] = `NUM_PHYS_BITS'd0;
    cp.expected_cdb_table.valid[0] = 1'b0;
    cp.expected_cdb_table.branch_mispredict[0] = 1'b0;

    cp.expected_rob_id_vec[1] = `NUM_ROBS_BITS'd2;
    cp.expected_map_valid_vec[1] = 1'b0;
    cp.expected_wr_en_vec[1] = 1'd0;
    cp.expected_wr_data_vec[1] = `XLEN'd0;
    cp.expected_wr_idx_vec[1] = `NUM_PHYS_BITS'd0;
    cp.expected_cdb_table.phys_regs[1] = `NUM_PHYS_BITS'd0;
    cp.expected_cdb_table.valid[1] = 1'b0;
    cp.expected_cdb_table.branch_mispredict[1] = 1'b1;

    compare_all(cp);
    @(negedge clock);

    $display("@@@Passed");
    $finish; */
    end
endmodule
