`include "sys_defs.svh"
`include "ISA.svh"

module dispatch_test;

    //NOTE: This test does not work unless "DEBUG_OUT_FREE_LIST" is defined.

    //This will test free_list for any superscalar number.

    //Helper value
    INST inst;

    //Inputs
    logic clock;
    logic reset;
    IF_ID_PACKET [`N-1:0] if_id_packet_in;
    CDB_ROW [`N-1:0] CDB_output;
    logic [`NUM_FUNC_UNIT_TYPES-1:0] [31:0] num_fu_free;
    logic store_memory_complete;
    logic load_flush_next_cycle;
	logic load_flush_this_cycle;
    FLUSHED_INFO load_flush_info;

    
    //Outputs
    logic [$clog2(`NUM_ROWS):0] num_free_rs_rows;
    logic [(`NUM_ROBS_BITS+1)-1:0] num_free_rob_rows;
    RS_EX_PACKET [`N-1:0]  issued_rows;
    logic retiring_branch_mispredict_next_cycle_output;
    logic [`XLEN-1:0] retiring_branch_target_next_cycle;
    WB_OUTPUTS [`N-1:0] wb_testbench_outputs;
    logic [$clog2(`N+1):0] num_rows_retire;
	logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs;
	logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs;
	logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] register_file_out;
	DISPATCHED_LSQ_PACKET [`N-1:0] dispatched_loads_stores;
	MEMORY_STORE_REQUEST store_retire_memory_request;
    logic [$clog2(`N+1):0] num_loads_retire;
    logic [$clog2(`N+1):0] num_stores_retire;
    logic [`NUM_ROBS_BITS - 1:0] next_head_pointer;

    //Debug Outputs
    ID_EX_PACKET [`N-1:0] id_packet_out;
    MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table;
    MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices;
    logic [`N-1:0][`NUM_REG_BITS] dispatched_arch_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rda_idx;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rdb_idx;
    logic [`NUM_PHYS_BITS-1:0] rd_st_idx;
	logic [`N-1:0][`XLEN-1:0] rda_out;
	logic [`N-1:0][`XLEN-1:0] rdb_out;
	logic [`XLEN-1:0] rd_st_out;


    


    

    
    //Expected Outputs
    ID_EX_PACKET [`N-1:0]expected_id_packet_out;
    
    MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] expected_map_table ;
    MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] expected_arch_map_table;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_dispatched_preg_dest_indices;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_dispatched_preg_old_dest_indices;
    logic [`N-1:0][`NUM_REG_BITS] expected_dispatched_arch_regs;
    logic [`N-1:0][`NUM_REG_BITS-1:0] expected_retired_arch_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_retired_phys_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_retired_old_phys_regs;
    logic [`N-1:0][`NUM_ROBS_BITS-1:0] expected_issued_row_rob_ids;
    logic [$clog2(`NUM_ROWS):0] expected_num_free_rs_rows;
    logic [(`NUM_ROBS_BITS+1)-1:0] expected_num_free_rob_rows;
    logic expected_retiring_branch_mispredict_next_cycle;
    logic [`XLEN-1:0] expected_retiring_branch_target_next_cycle;
	DISPATCHED_LSQ_PACKET [`N-1:0] expected_dispatched_loads_stores;
    logic [`NUM_PHYS_BITS-1:0] expected_rd_st_idx;    

    dispatch tb(
        //Inputs
        .clock(clock),
        .reset(reset),
        .if_id_packet_in(if_id_packet_in),
        .CDB_table(CDB_output),
        .num_fu_free(num_fu_free),
        .store_memory_complete(store_memory_complete),
        .load_flush_next_cycle(load_flush_next_cycle),
	    .load_flush_this_cycle(load_flush_this_cycle),
        .load_flush_info(load_flush_info),
        
        //Outputs
        .num_free_rs_rows(num_free_rs_rows),
        .num_free_rob_rows(num_free_rob_rows),
        .issued_rows(issued_rows),
        .retiring_branch_mispredict_next_cycle_output(retiring_branch_mispredict_next_cycle_output),
        .retiring_branch_target_next_cycle(retiring_branch_target_next_cycle),
        .wb_testbench_outputs(wb_testbench_outputs),
        .num_rows_retire(num_rows_retire),
        .retired_phys_regs(retired_phys_regs),
        .retired_arch_regs(retired_arch_regs),
        .register_file_out(register_file_out),
        .dispatched_loads_stores(dispatched_loads_stores),
        .store_retire_memory_request(store_retire_memory_request),
        .num_loads_retire(num_loads_retire),
        .num_stores_retire(num_stores_retire),
        .next_head_pointer(next_head_pointer),

        //Debug Outputs
        .id_packet_out(id_packet_out),
        .map_table_debug(map_table),
        .arch_map_table_debug(arch_map_table),
        .dispatched_preg_dest_indices_debug(dispatched_preg_dest_indices),
        .dispatched_preg_old_dest_indices_debug(dispatched_preg_old_dest_indices),
        .dispatched_arch_regs_debug(dispatched_arch_regs),
        .retired_old_phys_regs_debug(retired_old_phys_regs),
        .rda_idx_debug(rda_idx),
        .rdb_idx_debug(rdb_idx),
        .rd_st_idx_debug(rd_st_idx),
        .rda_out_debug(rda_out),
        .rdb_out_debug(rdb_out),
        .rd_st_out_debug(rd_st_out)
    );

    task finish_successfully;
        $display("@@@Passed");
        $finish;
    endtask

    task set_num_dispatch;
        input integer n;
        for(int k = 0;k<`N;k=k+1)begin 
            if(k < n)begin
                if_id_packet_in[k].valid = 1;
                expected_id_packet_out[k].valid = 1;
            end
            else begin 
                if_id_packet_in[k].valid = 0;
                expected_id_packet_out[k].valid = 0;
            end
        end

    endtask

    task exit_on_error;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $finish;
      end
    endtask


    task check_valid;
        input ID_EX_PACKET [`N-1:0]id_packet;
        input ID_EX_PACKET  [`N-1:0]exp_id_packet;
        for(int i=0; i<`N; i = i + 1) begin
            if(id_packet[i].valid!=exp_id_packet[i].valid) begin
                $display("%d\n", i);
                $display("%d\n", id_packet[i].valid);
                $display("%d\n", exp_id_packet[i].valid);
                exit_on_error();
            end
        end
    endtask

    //checks map table and architectural map table values based on map_vs_expected_map input
    task check_map_valid;
        input MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table;
        input MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] expected_map_table;
        //denotes whether we are comparing map table or expected map table
        //1 means map table, 0 means expected map table
        input logic map_vs_expected_map;

        #1;
        for(int i=0; i<`N; i+=1)begin 
            if( map_table[i].phys_reg != expected_map_table[i].phys_reg ||
                map_table[i].ready != expected_map_table[i].ready)begin 
                if(map_vs_expected_map)
                    $display("Map table  Wrong at Time: %4.0f", $time);
                else begin 
                    $display("Architectural Map table  Wrong at Time: %4.0f", $time);
                end

                $display("Index %d Incorrect", i);
                
                $display("Expected reg:%d\trdy:%d", expected_map_table[i].phys_reg, expected_map_table[i].ready);
                $display("Actual   reg:%d\trdy:%d", map_table[i].phys_reg, map_table[i].ready);
                exit_on_error();
            end
        end
    endtask

    task compare_dispatched_loads_stores;
        for(int i=0;i<`N;i=i+1)begin
            if(dispatched_loads_stores[i].PC != expected_dispatched_loads_stores[i].PC)begin 
                $display("Dispatched Loads Stores PC incorrect at time: %4.0f \n Index %d Incorrect \n Expected: %d, Actual %d",$time,i,expected_dispatched_loads_stores[i].PC,dispatched_loads_stores[i].PC);
                exit_on_error();
            end
            if(dispatched_loads_stores[i].rob_id != expected_dispatched_loads_stores[i].rob_id)begin 
                $display("Dispatched Loads Stores ROB ID incorrect at time: %4.0f \n Index %d Incorrect \n Expected: %d, Actual %d",$time,i,expected_dispatched_loads_stores[i].rob_id,dispatched_loads_stores[i].rob_id);
                exit_on_error();
            end
            if(dispatched_loads_stores[i].mem_size != expected_dispatched_loads_stores[i].mem_size)begin 
                $display("Dispatched Loads Stores mem size incorrect at time: %4.0f \n Index %d Incorrect \n Expected: %d, Actual %d",$time,i,expected_dispatched_loads_stores[i].mem_size,dispatched_loads_stores[i].mem_size);
                exit_on_error();
            end
            if(dispatched_loads_stores[i].valid != expected_dispatched_loads_stores[i].valid)begin 
                $display("Dispatched Loads Stores valid incorrect at time: %4.0f \n Index %d Incorrect \n Expected: %d, Actual %d",$time,i,expected_dispatched_loads_stores[i].valid,dispatched_loads_stores[i].valid);
                exit_on_error();
            end
            if(dispatched_loads_stores[i].is_store != expected_dispatched_loads_stores[i].is_store)begin 
                $display("Dispatched Loads Stores is_store incorrect at time: %4.0f \n Index %d Incorrect \n Expected: %d, Actual %d",$time,i,expected_dispatched_loads_stores[i].is_store,dispatched_loads_stores[i].is_store);
                exit_on_error();
            end
        end
    endtask



    task compare_branch_mispredict;
        if(retiring_branch_mispredict_next_cycle_output != expected_retiring_branch_mispredict_next_cycle)begin 

            $display("Retiring branch mispredict next cycle signal incorrect at time: %4.0f, Expected: %d, Actual %d",$time,expected_retiring_branch_mispredict_next_cycle,retiring_branch_mispredict_next_cycle_output);
            exit_on_error();
        end
        if(retiring_branch_target_next_cycle != expected_retiring_branch_target_next_cycle) begin 
            $display("Retiring branch mispredict target incorrect at time: %4.0f, Expected: %d, Actual: %d",$time,expected_retiring_branch_target_next_cycle,retiring_branch_target_next_cycle);
            exit_on_error();
        end
    endtask

    task compare_num_free_rows;
        if(expected_num_free_rob_rows != num_free_rob_rows)begin
            $display("Num Free Rob Rows Wrong at Time: %4.0f",$time);
            $display("Expected: %d",expected_num_free_rob_rows);
            $display("Actual: %d",num_free_rob_rows);
            exit_on_error();
        end
        if(expected_num_free_rs_rows!= num_free_rs_rows)begin
            $display("Num Free Reservation Rows Wrong at Time: %4.0f",$time);
            $display("Expected: %d",expected_num_free_rs_rows);
            $display("Actual: %d",num_free_rs_rows);
            exit_on_error();
        end
    endtask

    task compare_retired_preg;
        foreach(retired_phys_regs[i])begin 
            if(retired_phys_regs[i] != expected_retired_phys_regs[i])begin 
                $display("Retired preg Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", i);
            
                $display("Expected: %d", expected_retired_phys_regs[i]);
                $display("Actual: %d", retired_phys_regs[i]);
                exit_on_error();
            end
        end
    endtask


    task compare_retired_old_preg;
        foreach(retired_old_phys_regs[i])begin 
            if(retired_old_phys_regs[i] != expected_retired_old_phys_regs[i])begin 
                $display("Retired preg old Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", i);
            
                $display("Expected: %d", expected_retired_old_phys_regs[i]);
                $display("Actual: %d", retired_old_phys_regs[i]);
                exit_on_error();
            end
        end
    endtask


    task compare_retired_arch_reg;
        foreach(retired_arch_regs[i])begin 
            if(retired_arch_regs[i] != expected_retired_arch_regs[i])begin 
                $display("Retired Architectural Register Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", i);
            
                $display("Expected: %d", expected_retired_arch_regs[i]);
                $display("Actual: %d", retired_arch_regs[i]);
                exit_on_error();
            end
        end
    endtask

    task compare_retired_vars;
        compare_retired_arch_reg();
        compare_retired_old_preg();
        compare_retired_preg();
    endtask;

    task set_expected_retire_none;
        foreach(expected_retired_arch_regs[r_idx])begin
            expected_retired_arch_regs[r_idx] = 0;
            expected_retired_old_phys_regs[r_idx] = 0;
            expected_retired_phys_regs[r_idx] = 0;
        end
    endtask

    task compare_dispatched_preg_dest_indices;
        foreach(dispatched_preg_dest_indices[dispatched_preg_dest_index])begin 
            if(dispatched_preg_dest_indices[dispatched_preg_dest_index] != expected_dispatched_preg_dest_indices[dispatched_preg_dest_index]) begin
                $display("Dispatched preg dest indices Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", dispatched_preg_dest_index);
            
                $display("Expected: %d", expected_dispatched_preg_dest_indices[dispatched_preg_dest_index]);
                $display("Actual: %d", dispatched_preg_dest_indices[dispatched_preg_dest_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_dispatched_preg_old_dest_indices;
        foreach(dispatched_preg_old_dest_indices[dispatched_preg_old_dest_index])begin 
            if(dispatched_preg_old_dest_indices[dispatched_preg_old_dest_index] != expected_dispatched_preg_old_dest_indices[dispatched_preg_old_dest_index]) begin
                $display("Dispatched old preg dest indices Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", dispatched_preg_old_dest_index);

                $display("Expected: %d", expected_dispatched_preg_old_dest_indices[dispatched_preg_old_dest_index]);
                $display("Actual: %d", dispatched_preg_old_dest_indices[dispatched_preg_old_dest_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_dispatched_arch_regs;
        foreach(dispatched_arch_regs[dispatched_arch_index])begin 
            if(dispatched_arch_regs[dispatched_arch_index] != expected_dispatched_arch_regs[dispatched_arch_index]) begin
                
                $display("Dispatched arch reg Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", dispatched_arch_index);
            
                $display("Expected: %d", expected_dispatched_arch_regs[dispatched_arch_index]);
                $display("Actual: %d", dispatched_arch_regs[dispatched_arch_index]);                
                
                exit_on_error();
            end
        end
    endtask

    task compare_dispatched_vars;
        compare_dispatched_arch_regs();
        compare_dispatched_preg_dest_indices();
        compare_dispatched_preg_old_dest_indices();
    endtask
    
    task compare_issued_rob_ids;
        foreach(expected_issued_row_rob_ids[id])begin 
            if(issued_rows[id].rob_id != expected_issued_row_rob_ids[id]) begin
                
                $display("Issued row rob_id incorrect at time: %4.0f", $time);
                $display("Index %d Incorrect", id);
            
                $display("Expected: %d", expected_issued_row_rob_ids[id]);        inst.s.rs1  = 5'h3;
        inst.s.rs2  = 5'h4;
        inst.s.off  = 0;
        inst.s.set  = 0;  
                $display("Actual: %d", issued_rows[id].rob_id);                
                
                exit_on_error();
            end
        end
    endtask


    task compare_expected;
        check_map_valid(map_table,expected_map_table,1);
        check_map_valid(arch_map_table,expected_arch_map_table,0);
        check_valid(id_packet_out, expected_id_packet_out);
        compare_dispatched_vars();
        compare_retired_vars();
        compare_issued_rob_ids();
        compare_num_free_rows();
        compare_branch_mispredict();
        compare_dispatched_loads_stores();
    endtask

    task set_expected_dispatch_none;
        foreach(expected_dispatched_arch_regs[r_idx])begin 
            expected_dispatched_arch_regs[r_idx] = 0;
            expected_dispatched_preg_dest_indices[r_idx] = 0;
            expected_dispatched_preg_old_dest_indices[r_idx] = 0;
        end
    endtask

    task set_expected_rob_ids_0;
        foreach(expected_issued_row_rob_ids[id])begin 

                expected_issued_row_rob_ids[id] = 0;
        end
    endtask


    task copy_arch_map;
        foreach(expected_map_table[m_idx])begin 
            expected_map_table[m_idx].phys_reg = expected_arch_map_table[m_idx].phys_reg;
            expected_map_table[m_idx].ready = expected_arch_map_table[m_idx].ready;
        end
    endtask

    task reset_map_tables;
        foreach(expected_map_table[m_idx])begin 
            expected_map_table[m_idx].phys_reg = 0;
            expected_map_table[m_idx].ready = 1;
            expected_arch_map_table[m_idx].phys_reg = 0;
            expected_arch_map_table[m_idx].ready=1;
        end
    endtask

    task zero_CDB;
        CDB_output = 0;
    endtask
    //used because reservation station prints dispatched rows in ff
    // always begin
    //     @(posedge clock)
    //     $display("##########");
    //     $display("POSEDGE");
    // end


    always begin
        #10 clock = ~clock;
    end

    // always @(negedge clock) begin

    //     $display("NEGEDGE at Time: %4.0f", $time);
    //     $display("##########");
    // end

    /*
    integer test_1_index;
    integer i2, i3, i4, i5, i6, i7, i8;
    */

    initial begin
        
        clock = 0;
        reset = 1;
        inst = 32'h13; // nop?
        for(int i=0; i<`N; i = i + 1) begin
            if_id_packet_in[i].valid = 0;
            if_id_packet_in[i].inst = inst;
            if_id_packet_in[i].NPC = 0;
            if_id_packet_in[i].PC = 0;
        end
        for (int fu_free_index = 0; fu_free_index < `NUM_FUNC_UNIT_TYPES; fu_free_index = fu_free_index+1) begin
          num_fu_free[fu_free_index] = 10;
        end
        set_expected_retire_none();
        set_expected_rob_ids_0();
        reset_map_tables();
        load_flush_this_cycle = 0;
        load_flush_next_cycle = 0;
        expected_retiring_branch_mispredict_next_cycle = 0;
        expected_retiring_branch_target_next_cycle = 0;
        expected_dispatched_loads_stores = 0;

    @(negedge clock); //Time 20

    if(`N==5 && `NUM_ROWS ==8 && `NUM_ROBS==8 && `NUM_ROBS_BITS==3) begin
        $display("Running tests for N=5 NUM_ROWS=8 and NUM_ROBS=8");
        $display("RUNNING TEST 1");
        reset = 0;

        inst = `RV32_ADD;
        inst.r.rs1  = 5'h1;
        inst.r.rs2  = 5'h2;
        inst.r.rd   = 5'h2;
        if_id_packet_in[0].valid = 1;
        if_id_packet_in[0].inst = inst;
        if_id_packet_in[0].NPC = `XLEN'h08;
        if_id_packet_in[0].PC = `XLEN'h04;

        inst = `RV32_SUB;
        inst.r.rs1  = 5'h1;
        inst.r.rs2  = 5'h2;
        inst.r.rd   = 5'h2;
        if_id_packet_in[1].valid = 1;
        if_id_packet_in[1].inst = inst;
        if_id_packet_in[1].NPC = `XLEN'h0C;
        if_id_packet_in[1].PC = `XLEN'h08;

        inst = `RV32_XOR;
        inst.r.rs1  = 5'h3;
        inst.r.rs2  = 5'h4;
        inst.r.rd   = 5'h3;
        if_id_packet_in[2].valid = 1;
        if_id_packet_in[2].inst = inst;
        if_id_packet_in[2].NPC = `XLEN'h10;
        if_id_packet_in[2].PC = `XLEN'h0C;

        inst = `RV32_ADDI;
        inst.i.imm  = 12'h88;
        inst.i.rs1  = 5'h4;
        inst.r.rd   = 5'h4;
        if_id_packet_in[3].valid = 1;
        if_id_packet_in[3].inst = inst;
        if_id_packet_in[3].NPC = `XLEN'h14;
        if_id_packet_in[3].PC = `XLEN'h10;

        inst = `RV32_BEQ;
        inst.b.rs1  = 5'h5;
        inst.b.rs2  = 5'h5;
        if_id_packet_in[4].valid = 1;
        if_id_packet_in[4].inst = inst;
        if_id_packet_in[4].NPC = `XLEN'h18;
        if_id_packet_in[4].PC = `XLEN'h14;

        expected_num_free_rob_rows = `NUM_ROBS-5;
        expected_num_free_rs_rows = `NUM_ROWS-5;

        expected_id_packet_out[0].valid = 1;
        expected_id_packet_out[1].valid = 1;
        expected_id_packet_out[2].valid = 1;
        expected_id_packet_out[3].valid = 1;
        expected_id_packet_out[4].valid = 1;

        expected_dispatched_preg_dest_indices[0] = 1;
        expected_dispatched_preg_dest_indices[1] = 2;
        expected_dispatched_preg_dest_indices[2] = 3;
        expected_dispatched_preg_dest_indices[3] = 4;    
        expected_dispatched_preg_dest_indices[4] = 0;


        expected_dispatched_preg_old_dest_indices[0] = 0;
        expected_dispatched_preg_old_dest_indices[1] = 1;
        expected_dispatched_preg_old_dest_indices[2] = 0;
        expected_dispatched_preg_old_dest_indices[3] = 0;    
        expected_dispatched_preg_old_dest_indices[4] = 0;

        expected_dispatched_arch_regs[0] = 2;
        expected_dispatched_arch_regs[1] = 2;
        expected_dispatched_arch_regs[2] = 3;
        expected_dispatched_arch_regs[3] = 4;
        expected_dispatched_arch_regs[4] = 0;
        #5;
        compare_expected();


        @(negedge clock); //time 40
        set_num_dispatch(3);

        inst = `RV32_SUB;
        inst.r.rs1  = 5'h1;
        inst.r.rs2  = 5'h4;
        inst.r.rd   = 5'h2;
        if_id_packet_in[0].valid = 1;
        if_id_packet_in[0].inst = inst;
        if_id_packet_in[0].NPC = `XLEN'h1C;
        if_id_packet_in[0].PC = `XLEN'h18;

        inst = `RV32_XOR;
        inst.r.rs1  = 5'h2;
        inst.r.rs2  = 5'h5;
        inst.r.rd   = 5'h5;
        if_id_packet_in[1].valid = 1;
        if_id_packet_in[1].inst = inst;
        if_id_packet_in[1].NPC = `XLEN'h20;
        if_id_packet_in[1].PC = `XLEN'h1C;

        inst = `RV32_ADDI;
        inst.i.imm  = 12'h88;
        inst.i.rs1  = 5'h4;
        inst.r.rd   = 5'h4;
        if_id_packet_in[2].valid = 1;
        if_id_packet_in[2].inst = inst;
        if_id_packet_in[2].NPC = `XLEN'h24;
        if_id_packet_in[2].PC = `XLEN'h20;
        
        expected_num_free_rob_rows = `NUM_ROBS-8;
        expected_num_free_rs_rows = `NUM_ROWS-4;

        expected_map_table[0].ready = 1'b1;
        expected_map_table[1].ready = 1'b1;
        expected_map_table[2].ready = 1'b0;
        expected_map_table[3].ready = 1'b0;
        expected_map_table[4].ready = 1'b0;
        expected_map_table[2].phys_reg = `NUM_PHYS_BITS'd2;
        expected_map_table[3].phys_reg = `NUM_PHYS_BITS'd3;
        expected_map_table[4].phys_reg = `NUM_PHYS_BITS'd4;

        expected_dispatched_preg_dest_indices[0] = 5;
        expected_dispatched_preg_dest_indices[1] = 6;
        expected_dispatched_preg_dest_indices[2] = 7;
        expected_dispatched_preg_dest_indices[3] = 0;    
        expected_dispatched_preg_dest_indices[4] = 0;

        expected_dispatched_preg_old_dest_indices[0] = 2;
        expected_dispatched_preg_old_dest_indices[1] = 0;
        expected_dispatched_preg_old_dest_indices[2] = 4;
        expected_dispatched_preg_old_dest_indices[3] = 0;    
        expected_dispatched_preg_old_dest_indices[4] = 0;

        expected_dispatched_arch_regs[0] = 2;
        expected_dispatched_arch_regs[1] = 5;
        expected_dispatched_arch_regs[2] = 4;
        expected_dispatched_arch_regs[3] = 0;
        expected_dispatched_arch_regs[4] = 0;

        expected_issued_row_rob_ids[0] = 0;
        expected_issued_row_rob_ids[1] = 2;
        expected_issued_row_rob_ids[2] = 3;
        expected_issued_row_rob_ids[3] = 4;
        expected_issued_row_rob_ids[4] = 0;

        #5;
        compare_expected();
        @(negedge clock); //time 60

        set_num_dispatch(0);
        set_expected_dispatch_none();

        expected_map_table[0].ready = 1'b1;
        expected_map_table[1].ready = 1'b1;
        expected_map_table[2].ready = 1'b0;
        expected_map_table[3].ready = 1'b0;
        expected_map_table[4].ready = 1'b0;
        expected_map_table[5].ready = 1'b0;
        expected_map_table[2].phys_reg = `NUM_PHYS_BITS'd5;
        expected_map_table[3].phys_reg = `NUM_PHYS_BITS'd3;
        expected_map_table[4].phys_reg = `NUM_PHYS_BITS'd7;
        expected_map_table[5].phys_reg = `NUM_PHYS_BITS'd6;

        expected_issued_row_rob_ids[0] = 0;
        expected_issued_row_rob_ids[1] = 0;
        expected_issued_row_rob_ids[2] = 0;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;

        #5;
        compare_expected();

        @(negedge clock); //time 80

        CDB_output[0].phys_regs = 1;
        CDB_output[0].valid = 1;
        CDB_output[0].branch_mispredict = 0;
        CDB_output[0].rob_id = 0;
        CDB_output[0].result = 0;

        CDB_output[1].phys_regs = 4;
        CDB_output[1].valid = 1;
        CDB_output[1].branch_mispredict = 0;
        CDB_output[1].rob_id = 3;
        CDB_output[1].result = 0;

        set_expected_rob_ids_0();

        #5;
        compare_expected();

        @(negedge clock);//time 100

        zero_CDB();

        expected_retired_arch_regs[0] = 2;
        expected_retired_phys_regs[0] = 1;
        expected_retired_old_phys_regs[0] = 0;

        expected_num_free_rob_rows = `NUM_ROBS-7;
        expected_num_free_rs_rows = `NUM_ROWS-1;

        expected_issued_row_rob_ids[0] = 1;
        expected_issued_row_rob_ids[1] = 5;
        expected_issued_row_rob_ids[2] = 7;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;

        #5;
        compare_expected();

        @(negedge clock);//time 120

        expected_retired_arch_regs[0] = 0;
        expected_retired_phys_regs[0] = 0;
        expected_retired_old_phys_regs[0] = 0;

        expected_issued_row_rob_ids[0] = 0;
        expected_issued_row_rob_ids[1] = 0;
        expected_issued_row_rob_ids[2] = 0;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;

        expected_arch_map_table[2].phys_reg = 1;



        #5;
        compare_expected();

        @(negedge clock);//140

        CDB_output[0].phys_regs = 2;
        CDB_output[0].valid = 1;
        CDB_output[0].branch_mispredict = 0;
        CDB_output[0].rob_id = 1;
        CDB_output[0].result = 0;

        CDB_output[1].phys_regs = 3;
        CDB_output[1].valid = 1;
        CDB_output[1].branch_mispredict = 0;
        CDB_output[1].rob_id = 2;
        CDB_output[1].result = 0;

        CDB_output[2].phys_regs = 0;
        CDB_output[2].valid = 1;
        CDB_output[2].branch_mispredict = 1;
        CDB_output[2].rob_id = 4;
        CDB_output[2].result = 4;

        CDB_output[3].phys_regs = 7;
        CDB_output[3].valid = 1;
        CDB_output[3].branch_mispredict = 0;
        CDB_output[3].rob_id = 7;
        CDB_output[3].result = 0;

        expected_issued_row_rob_ids[0] = 0;
        expected_issued_row_rob_ids[1] = 0;
        expected_issued_row_rob_ids[2] = 0;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;

        expected_retiring_branch_mispredict_next_cycle = 1;
        expected_retiring_branch_target_next_cycle = 4;

        expected_num_free_rs_rows = `NUM_ROWS;

        #5;
        compare_expected();

        @(negedge clock);//160;

        CDB_output = 0;
        expected_retiring_branch_mispredict_next_cycle = 0;
        expected_retiring_branch_target_next_cycle = 0;

        expected_retired_arch_regs[0] = 2;
        expected_retired_phys_regs[0] = 2;
        expected_retired_old_phys_regs[0] = 1;

        expected_retired_arch_regs[1] = 3;
        expected_retired_phys_regs[1] = 3;
        expected_retired_old_phys_regs[1] = 0;

        expected_retired_arch_regs[2] = 4;
        expected_retired_phys_regs[2] = 4;
        expected_retired_old_phys_regs[2] = 0;

        expected_retired_arch_regs[3] = 0;
        expected_retired_phys_regs[3] = 0;
        expected_retired_old_phys_regs[3] = 0;

        expected_num_free_rob_rows = `NUM_ROBS;
        expected_num_free_rs_rows = `NUM_ROWS;

        expected_map_table[3].ready = 1;
        expected_map_table[4].ready = 1;


        #5;
        compare_expected();

        @(negedge clock);//time 180

        set_expected_retire_none();

        expected_arch_map_table[2].phys_reg = 2;
        expected_arch_map_table[3].phys_reg = 3;
        expected_arch_map_table[4].phys_reg = 4;
        
        copy_arch_map();
        

        #5;
        compare_expected();
        @(negedge clock);//time 200
        reset = 1;
        inst = 32'h13; // nop?
        for(int i=0; i<`N; i = i + 1) begin
            if_id_packet_in[i].valid = 0;
            if_id_packet_in[i].inst = inst;
            if_id_packet_in[i].NPC = 0;
            if_id_packet_in[i].PC = 0;
        end
        for (int fu_free_index = 0; fu_free_index < `NUM_FUNC_UNIT_TYPES; fu_free_index = fu_free_index+1) begin
          num_fu_free[fu_free_index] = 10;
        end
        set_expected_retire_none();
        set_expected_rob_ids_0();
        reset_map_tables();
        load_flush_this_cycle = 0;
        load_flush_next_cycle = 0;
        expected_retiring_branch_mispredict_next_cycle = 0;
        expected_retiring_branch_target_next_cycle = 0;
        CDB_output = 0;
        @(negedge clock);//time 220
        $display("RUNNING TEST 2: TESTING LOAD FLUSH");
        reset=0;

        set_num_dispatch(5);

        inst = `RV32_LW;
        inst.i.rs1  = 5'h1;
        inst.i.imm  = 0;
        inst.i.rd   = 5'h2;
        if_id_packet_in[0].valid = 1;
        if_id_packet_in[0].inst = inst;
        if_id_packet_in[0].NPC = `XLEN'h08;
        if_id_packet_in[0].PC = `XLEN'h04;

        inst = `RV32_SW;
        inst.s.rs1  = 5'h2;
        inst.s.rs2  = 5'h4;
        inst.s.off  = 0;
        inst.s.set  = 0;  
        if_id_packet_in[1].valid = 1;
        if_id_packet_in[1].inst = inst;
        if_id_packet_in[1].NPC = `XLEN'h0C;
        if_id_packet_in[1].PC = `XLEN'h08;

        inst = `RV32_LHU;
        inst.i.rs1  = 5'h4;
        inst.i.imm  = 0;
        inst.i.rd   = 5'h5;
        if_id_packet_in[2].valid = 1;
        if_id_packet_in[2].inst = inst;
        if_id_packet_in[2].NPC = `XLEN'h10;
        if_id_packet_in[2].PC = `XLEN'h0C;

        inst = `RV32_SB;
        inst.s.rs1  = 5'h5;
        inst.s.rs2  = 5'h7;
        inst.s.off  = 0;
        inst.s.set  = 0;  
        if_id_packet_in[3].valid = 1;
        if_id_packet_in[3].inst = inst;
        if_id_packet_in[3].NPC = `XLEN'h14;
        if_id_packet_in[3].PC = `XLEN'h10;

        inst = `RV32_LB;
        inst.i.rs1  = 5'h5;
        inst.i.imm  = 0;
        inst.i.rd  = 5'h5;
        if_id_packet_in[4].valid = 1;
        if_id_packet_in[4].inst = inst;
        if_id_packet_in[4].NPC = `XLEN'h18;
        if_id_packet_in[4].PC = `XLEN'h14;

        expected_num_free_rob_rows = `NUM_ROBS-5;
        expected_num_free_rs_rows = `NUM_ROWS-5;

        expected_dispatched_preg_dest_indices[0] = 1;
        expected_dispatched_preg_dest_indices[1] = 0;
        expected_dispatched_preg_dest_indices[2] = 2;
        expected_dispatched_preg_dest_indices[3] = 0;    
        expected_dispatched_preg_dest_indices[4] = 3;


        expected_dispatched_preg_old_dest_indices[0] = 0;
        expected_dispatched_preg_old_dest_indices[1] = 0;
        expected_dispatched_preg_old_dest_indices[2] = 0;
        expected_dispatched_preg_old_dest_indices[3] = 0;    
        expected_dispatched_preg_old_dest_indices[4] = 2;

        expected_dispatched_arch_regs[0] = 2;
        expected_dispatched_arch_regs[1] = 0;
        expected_dispatched_arch_regs[2] = 5;
        expected_dispatched_arch_regs[3] = 0;
        expected_dispatched_arch_regs[4] = 5;

        expected_dispatched_loads_stores[0].PC = `XLEN'h04;
        expected_dispatched_loads_stores[0].mem_size = WORD;
        expected_dispatched_loads_stores[0].valid = 1;
        expected_dispatched_loads_stores[0].rob_id = 0;
        expected_dispatched_loads_stores[0].is_store = 0;

        expected_dispatched_loads_stores[1].PC = `XLEN'h08;
        expected_dispatched_loads_stores[1].mem_size = WORD;
        expected_dispatched_loads_stores[1].valid = 1;
        expected_dispatched_loads_stores[1].rob_id = 1;
        expected_dispatched_loads_stores[1].is_store = 1;

        expected_dispatched_loads_stores[2].PC = `XLEN'h0C;
        expected_dispatched_loads_stores[2].mem_size = HALF;
        expected_dispatched_loads_stores[2].valid = 1;
        expected_dispatched_loads_stores[2].rob_id = 2;
        expected_dispatched_loads_stores[2].is_store = 0;

        expected_dispatched_loads_stores[3].PC = `XLEN'h10;
        expected_dispatched_loads_stores[3].mem_size = BYTE;
        expected_dispatched_loads_stores[3].valid = 1;
        expected_dispatched_loads_stores[3].rob_id = 3;
        expected_dispatched_loads_stores[3].is_store = 1;

        expected_dispatched_loads_stores[4].PC = `XLEN'h14;
        expected_dispatched_loads_stores[4].mem_size = BYTE;
        expected_dispatched_loads_stores[4].valid = 1;
        expected_dispatched_loads_stores[4].rob_id = 4;
        expected_dispatched_loads_stores[4].is_store = 0;


        #5;
        compare_expected();

        @(negedge clock) //time 240
        set_num_dispatch(0);

        expected_dispatched_arch_regs = 0;
        expected_dispatched_preg_dest_indices = 0;
        expected_dispatched_preg_old_dest_indices = 0;
        expected_dispatched_loads_stores = 0;

        expected_map_table[2].ready = 1'b0;
        expected_map_table[5].ready = 1'b0;
        expected_map_table[2].phys_reg = `NUM_PHYS_BITS'd1;
        expected_map_table[5].phys_reg = `NUM_PHYS_BITS'd3;

        expected_num_free_rs_rows = `NUM_ROWS-3;

        expected_issued_row_rob_ids[0] = 0;
        expected_issued_row_rob_ids[1] = 2;
        expected_issued_row_rob_ids[2] = 0;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;        

        #5;
        compare_expected();

        @(negedge clock) //time 260
        CDB_output[0].phys_regs = 1;
        CDB_output[0].valid = 1;
        CDB_output[0].branch_mispredict = 0;
        CDB_output[0].rob_id = 0;
        CDB_output[0].result = 0;  

        @(negedge clock) //time 280

        CDB_output[0].phys_regs = 2;
        CDB_output[0].valid = 1;
        CDB_output[0].branch_mispredict = 0;
        CDB_output[0].rob_id = 0;
        CDB_output[0].result = 0;

        expected_issued_row_rob_ids[0] = 1;
        expected_issued_row_rob_ids[1] = 0;
        expected_issued_row_rob_ids[2] = 0;
        expected_issued_row_rob_ids[3] = 0;
        expected_issued_row_rob_ids[4] = 0;    
        
        expected_map_table[2].ready = 1'b1;

        expected_retired_arch_regs[0] = 2;
        expected_retired_phys_regs[0] = 1;
        expected_retired_old_phys_regs[0] = 0;

        $display("NEXT HEAD POINTER: expected: 1, actual: %d",next_head_pointer);

        load_flush_next_cycle = 1;
        load_flush_info.head_rob_id = 1;
        load_flush_info.mispeculated_rob_id=2;
        load_flush_info.mispeculated_PC=`XLEN'h0C;

        expected_num_free_rs_rows = `NUM_ROWS;
        expected_num_free_rob_rows = `NUM_ROBS-4;

        #5;
        compare_expected();
        
        @(negedge clock) //time 300
        
        CDB_output = 0;

        load_flush_next_cycle = 0;
        load_flush_this_cycle = 1;

        expected_arch_map_table[2].phys_reg = 1;
        expected_arch_map_table[2].ready = 1;
    
        expected_num_free_rob_rows = `NUM_ROBS-1;

        expected_issued_row_rob_ids = 0;

        expected_retired_arch_regs[0] = 0;
        expected_retired_phys_regs[0] = 0;
        expected_retired_old_phys_regs[0] = 0;

        #5;
        compare_expected();
        @(negedge clock) // time 320
        load_flush_this_cycle = 2;
        expected_map_table[5].phys_reg = 0;
        expected_map_table[5].ready = 1;

        #5;
        compare_expected();

        finish_successfully();

    end 
    else begin
        $display("PLEASE SET MACROS TO FIT SPECIFICATIONS OF A TEST (`N, `NUM_ROWS, `NUM_ROBS,`NUM_ROBS_BITS");
        exit_on_error();
    end




    end
endmodule

/*

            `ifdef DEBUG_OUT_DISPATCH
            foreach(rob_queue_next[rob_queue_index]) begin
            $display("Combination ROB Row Next Index at time %4.0f : %d Arch Reg Dest: %d Phys Reg Dest: %d Old Phys Reg Dest: %d Busy %d",
            $time,
            rob_queue_index,
            rob_queue_next[rob_queue_index].arch_reg_dest,
            rob_queue_next[rob_queue_index].phys_reg_dest,
            rob_queue_next[rob_queue_index].old_phys_reg_dest,
            rob_queue_next[rob_queue_index].busy);   
            end
            `endif
*/
