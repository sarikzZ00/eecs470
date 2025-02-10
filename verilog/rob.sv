/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rob.sv                                              //
//                                                                     //
//  Description : Reorder Buffer Module that takes in one instruction  //
//                at the tail of the module and pops the head at       //
//                retirement.                                          //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

// actual one in sys_defs.svh
// typedef struct packed {
//     logic [31:0] opcode;
//     logic [`NUM_PHYS_BITS - 1:0] phys_reg_1;
//     logic [`NUM_PHYS_BITS - 1:0] phys_reg_2;
//     logic [`NUM_PHYS_BITS - 1:0] phys_reg_dest;
//     logic [`NUM_ROBS_BITS - 1:0] rob_ids;
//     logic complete;
// } ROB_ROW;

`ifndef ROB_SV_
`define ROB_SV_

`include "sys_defs.svh"

module rob (
    input clock,
    input reset,
    input [$clog2(`N + 1): 0] num_inst_dispatched, 
    input [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices,
    input [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices,
    input [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_store_retire_source_registers,
    input [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs,
    input CDB_ROW [`N-1:0] CDB_output,
    input ID_EX_PACKET [`N-1:0] id_packet_out,
    input [`XLEN-1:0] rd_st_out,
    input store_memory_complete,
    input FLUSHED_INFO load_flush_info,
    input load_flush_next_cycle,
    input load_flush_this_cycle,
    input MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table_next,

    // for free list reg

    //Needs to be + 1 because values of [32, 0] are allowed, rather than [31, 0]
    output logic [(`NUM_ROBS_BITS):0] num_free_rob_rows, 
    output logic [`NUM_ROBS_BITS-1:0] tail_pointer,

    output logic [`NUM_PHYS_BITS-1:0] rd_st_idx,
    

    //In order to update arch map table, we need to know which registers have been retired
    output logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs,
    output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs,
    output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs,
    output logic [$clog2(`N + 1):0] num_rows_retire,
    output logic retiring_branch_mispredict_next_cycle,
    output logic [`XLEN-1:0] branch_target,
    output WB_OUTPUTS [`N-1:0] wb_testbench_outputs,
    output logic [$clog2(`N+1):0] num_loads_retire,
    output logic [$clog2(`N+1):0] num_stores_retire,
    output MEMORY_STORE_REQUEST store_retire_memory_request,
    output logic [`NUM_ROBS_BITS - 1:0] next_head_pointer,
    output logic [`NUM_REGISTERS-1:0][`NUM_PHYS_BITS-1:0] unrolled_map_table_entries,
    output logic [`NUM_REGISTERS-1:0] unrolled_map_table_valid,
    output logic [`NUM_PHYS_REGS-1:0] unrolled_free_regs

    `ifdef DEBUG_OUT_ROB
        ,output logic [`NUM_ROBS_BITS - 1:0] head_pointer_debug,
        output logic [`NUM_ROBS_BITS - 1:0] next_head_pointer_debug,
        output ROB_ROW [`NUM_ROBS - 1:0] rob_queue_debug,
        output logic [`NUM_ROBS_BITS-1:0] next_tail_pointer_debug
    `endif
);


    MEMORY_STORE_REQUEST store_retire_memory_request_next;
    logic store_retire_stall;
    logic store_retire_stall_next;
    
    WB_OUTPUTS [`N-1:0] wb_testbench_outputs_next;

    ROB_ROW [`NUM_ROBS - 1 : 0] rob_queue;
    ROB_ROW [`NUM_ROBS - 1 : 0] rob_queue_next;

    logic [`NUM_ROBS_BITS - 1:0] head_pointer;

    logic [`NUM_ROBS_BITS - 1:0] next_tail_pointer;

    logic [$clog2(`N + 1) : 0] num_rows_retire_next;
    
    logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs_next;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs_next;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs_next;

    logic [`NUM_ROBS_BITS - 1:0] head_plus_num_retiring;
    assign head_plus_num_retiring = head_pointer + num_rows_retire;

    logic retiring_branch_mispredict_this_cycle;

    logic [$clog2(`N+1):0] num_loads_retire_next;


    //logic [`NUM_PHYS_BITS - 1:0] old_phys_reg;
    /*
    Need to add an instruction to the ROB every cycle
    */
    integer rob_queue_reset_index;
    integer rob_queue_index;
    integer completed_rob_inst;
    integer rob_retire_index;
    logic [`NUM_ROBS_BITS-1:0] unroll_idx;
       /*
   TO DO: If the CDB informs us there is a mispredict for a completed instruction, then we have to update the branch mispredict bit in the ROB Row on the positive edge of the clock cycle
   */
    always_ff @(posedge clock) begin

        if (reset) begin
            
            foreach(rob_queue[rob_queue_reset_index]) begin 
                rob_queue[rob_queue_reset_index].arch_reg_dest <= 0;
                rob_queue[rob_queue_reset_index].phys_reg_dest <= 0;
                rob_queue[rob_queue_reset_index].old_phys_reg_dest <= 0;
                rob_queue[rob_queue_reset_index].rob_id <= rob_queue_reset_index;
                rob_queue[rob_queue_reset_index].complete <= `FALSE;
                rob_queue[rob_queue_reset_index].busy <= `FALSE; 
                rob_queue[rob_queue_reset_index].branch_mispredict <= `FALSE;
                rob_queue[rob_queue_reset_index].branch_target <= 0;
                rob_queue[rob_queue_reset_index].wb_output <= 0; 
            end
            retired_arch_regs <= 0;
            retired_phys_regs <= 0;
            retired_old_phys_regs <= 0;

            tail_pointer <= 0;
            head_pointer <= 0;
            num_rows_retire <= 0;
            retiring_branch_mispredict_this_cycle <= `FALSE;
            wb_testbench_outputs <= 0;
            store_retire_memory_request <= 0;
            num_loads_retire <= 0;
            store_retire_stall <= 0;

        end else begin
            rob_queue <= rob_queue_next;
            tail_pointer <= next_tail_pointer;
            head_pointer <= next_head_pointer;
            num_rows_retire <= num_rows_retire_next;

            retired_arch_regs <= retired_arch_regs_next;
            retired_phys_regs <= retired_phys_regs_next;
            retired_old_phys_regs <= retired_old_phys_regs_next;

            retiring_branch_mispredict_this_cycle <= retiring_branch_mispredict_next_cycle;
            wb_testbench_outputs <= wb_testbench_outputs_next;
            store_retire_memory_request <= store_retire_memory_request_next;
            store_retire_stall <= store_retire_stall_next;
            num_loads_retire <= num_loads_retire_next;
        end
    end


    logic [`NUM_ROBS_BITS-1:0] overflow_tmp;
    logic macro_debug;
    always_comb begin
        rob_queue_next = rob_queue;
        unrolled_free_regs = 0;
        unrolled_map_table_entries = 0;
        unrolled_map_table_valid = 0;
        macro_debug = 0;

        if (retiring_branch_mispredict_this_cycle) begin
            foreach(rob_queue_next[rob_queue_reset_index]) begin 
                rob_queue_next[rob_queue_reset_index] = 0;
                rob_queue_next[rob_queue_reset_index].rob_id = rob_queue_reset_index;
            end
        end


        //If we are branch mispredicting, then our next pointer should be 0.
        next_head_pointer = retiring_branch_mispredict_this_cycle ? 0 : head_pointer + num_rows_retire;


        unroll_idx = tail_pointer;
        if(load_flush_this_cycle)begin
            for(int t_idx = 0; t_idx < `NUM_ROBS;t_idx = t_idx+1)begin
                unroll_idx = unroll_idx - 1;
                macro_debug = (~load_flush_info.is_branch_mispredict && `LEFT_YOUNGER_OR_EQUAL(head_pointer,7,load_flush_info.mispeculated_rob_id))
                    || (load_flush_info.is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(head_pointer,7,load_flush_info.mispeculated_rob_id));
                if((~load_flush_info.is_branch_mispredict && `LEFT_YOUNGER_OR_EQUAL(head_pointer,unroll_idx,load_flush_info.mispeculated_rob_id))
                    || (load_flush_info.is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(head_pointer,unroll_idx,load_flush_info.mispeculated_rob_id)))begin
                    if(~rob_queue_next[unroll_idx].wb_output.wr_mem)begin
                        //$display("unroll idx: %h, rob_queue_next.wb_output.wr_mem: %h", unroll_idx, rob_queue_next[unroll_idx].wb_output.wr_mem);
                        unrolled_map_table_entries[rob_queue_next[unroll_idx].arch_reg_dest] = rob_queue_next[unroll_idx].old_phys_reg_dest;
                        unrolled_map_table_valid[rob_queue_next[unroll_idx].arch_reg_dest] = 1;
                        unrolled_free_regs[rob_queue_next[unroll_idx].phys_reg_dest] = 1;
                    end
                    rob_queue_next[unroll_idx] = 0;
                    rob_queue_next[unroll_idx].rob_id = unroll_idx; 
                end
            end
        end

        for (rob_retire_index = 0; rob_retire_index < num_rows_retire; rob_retire_index = rob_retire_index+1) begin 
            //Actually retire instructions
            overflow_tmp = head_pointer + rob_retire_index;
            rob_queue_next[overflow_tmp] = 0;
            rob_queue_next[overflow_tmp].rob_id = overflow_tmp;
        end

        //currently don't dispatch anything if you are flushing a load, as of right now
        //in pipeline we should ensure no instructions were fetched to be dispatched
        //when doing a load flush
            for (rob_queue_index = 0; rob_queue_index < num_inst_dispatched; rob_queue_index =  rob_queue_index + 1) begin 
                //For each dispatched row, set the new and old physical destination registers. Also set busy bit to true 
                if (retiring_branch_mispredict_this_cycle) begin
                    //If we are branch mispredicting this cycle, then we should put newly dispatched instructions at the beginning of the ROB.
                    rob_queue_next[rob_queue_index].arch_reg_dest = dispatched_arch_regs[rob_queue_index];
                    rob_queue_next[rob_queue_index].old_phys_reg_dest = dispatched_preg_old_dest_indices[rob_queue_index];
                    rob_queue_next[rob_queue_index].busy = `TRUE; 
                    rob_queue_next[rob_queue_index].wb_output.halt_detected = id_packet_out[rob_queue_index].halt;
                    rob_queue_next[rob_queue_index].wb_output.illegal_inst_detected = id_packet_out[rob_queue_index].illegal;
                    rob_queue_next[rob_queue_index].wb_output.wr_reg = (dispatched_preg_dest_indices[rob_queue_index] != 0);
                    rob_queue_next[rob_queue_index].wb_output.wr_mem = id_packet_out[rob_queue_index].wr_mem;
                    rob_queue_next[rob_queue_index].wb_output.rd_mem = id_packet_out[rob_queue_index].rd_mem;
                    rob_queue_next[rob_queue_index].wb_output.PC = id_packet_out[rob_queue_index].PC;
                    rob_queue_next[rob_queue_index].wb_output.mem_size = id_packet_out[rob_queue_index].mem_size;

                    //If this is a store, put the source register in the phys_reg_dest instead (since dest will always be 0)
                    //  We need map table because the instruction has the arch reg, but we need the phys reg.
                    if (id_packet_out[rob_queue_index].wr_mem) begin
                        rob_queue_next[rob_queue_index].phys_reg_dest = dispatched_store_retire_source_registers[rob_queue_index];
                    end else begin
                        rob_queue_next[rob_queue_index].phys_reg_dest = dispatched_preg_dest_indices[rob_queue_index];
                    end
                end
                //TODO: If we wish to allow dispatching instructions on the cycle of a flush we will have to 
                else if(load_flush_this_cycle) begin
                    overflow_tmp = load_flush_info.mispeculated_rob_id + rob_queue_index;
                    rob_queue_next[overflow_tmp].arch_reg_dest = dispatched_arch_regs[rob_queue_index];
                    rob_queue_next[overflow_tmp].old_phys_reg_dest = dispatched_preg_old_dest_indices[rob_queue_index];
                    rob_queue_next[overflow_tmp].busy = `TRUE;    
                    rob_queue_next[overflow_tmp].wb_output.halt_detected = id_packet_out[rob_queue_index].halt;
                    rob_queue_next[overflow_tmp].wb_output.illegal_inst_detected = id_packet_out[rob_queue_index].illegal;
                    rob_queue_next[overflow_tmp].wb_output.wr_reg = (dispatched_preg_dest_indices[rob_queue_index] != 0);
                    rob_queue_next[overflow_tmp].wb_output.wr_mem = id_packet_out[rob_queue_index].wr_mem;
                    rob_queue_next[overflow_tmp].wb_output.rd_mem = id_packet_out[rob_queue_index].rd_mem;
                    rob_queue_next[overflow_tmp].wb_output.PC = id_packet_out[rob_queue_index].PC;
                    rob_queue_next[overflow_tmp].wb_output.mem_size = id_packet_out[rob_queue_index].mem_size;

                    //If this is a store, put the source register in the phys_reg_dest instead (since dest will always be 0)
                    if (id_packet_out[rob_queue_index].wr_mem) begin
                        rob_queue_next[overflow_tmp].phys_reg_dest = dispatched_store_retire_source_registers[rob_queue_index];
                    end else begin
                        rob_queue_next[overflow_tmp].phys_reg_dest = dispatched_preg_dest_indices[rob_queue_index];
                    end
                end
                else begin
                    overflow_tmp = tail_pointer + rob_queue_index;
                    rob_queue_next[overflow_tmp].arch_reg_dest = dispatched_arch_regs[rob_queue_index];                    
                    rob_queue_next[overflow_tmp].old_phys_reg_dest = dispatched_preg_old_dest_indices[rob_queue_index];
                    rob_queue_next[overflow_tmp].busy = `TRUE;    
                    rob_queue_next[overflow_tmp].wb_output.halt_detected = id_packet_out[rob_queue_index].halt;
                    rob_queue_next[overflow_tmp].wb_output.illegal_inst_detected = id_packet_out[rob_queue_index].illegal;
                    rob_queue_next[overflow_tmp].wb_output.wr_reg = (dispatched_preg_dest_indices[rob_queue_index] != 0);
                    rob_queue_next[overflow_tmp].wb_output.wr_mem = id_packet_out[rob_queue_index].wr_mem;
                    rob_queue_next[overflow_tmp].wb_output.rd_mem = id_packet_out[rob_queue_index].rd_mem;
                    rob_queue_next[overflow_tmp].wb_output.PC = id_packet_out[rob_queue_index].PC;
                    rob_queue_next[overflow_tmp].wb_output.mem_size = id_packet_out[rob_queue_index].mem_size;

                    
                    //If this is a store, put the source register in the phys_reg_dest instead (since dest will always be 0)
                    if (id_packet_out[rob_queue_index].wr_mem) begin
                        rob_queue_next[overflow_tmp].phys_reg_dest = dispatched_store_retire_source_registers[rob_queue_index];
                    end else begin
                        rob_queue_next[overflow_tmp].phys_reg_dest = dispatched_preg_dest_indices[rob_queue_index];
                    end
                end
            end


        //If we are branch mispredicting, then our tail pointer gets reset to 0 (plus the number being dispatched)
        next_tail_pointer = retiring_branch_mispredict_this_cycle ? num_inst_dispatched : (
                            load_flush_this_cycle ? load_flush_info.mispeculated_rob_id + load_flush_info.is_branch_mispredict + num_inst_dispatched : tail_pointer + num_inst_dispatched);

        foreach(rob_queue_next[rob_index]) begin
            //For each row in the ROB

            for (completed_rob_inst = 0; completed_rob_inst < `N; completed_rob_inst = completed_rob_inst + 1) begin
                //For each CDB entry

                if(CDB_output[completed_rob_inst].valid) begin
                    //If the CDB entry is valid

                    if (CDB_output[completed_rob_inst].rob_id == rob_queue_next[rob_index].rob_id) begin
                        //If the CDB entry is the same as the current ROB row, set the ROB row's "complete" to true

                        rob_queue_next[rob_index].complete = `TRUE;
                        //set the branch_target (which is really the result field in rob row) equal to the cdb result
                        rob_queue_next[rob_index].branch_target = CDB_output[completed_rob_inst].result;
                        if(CDB_output[completed_rob_inst].branch_mispredict) begin 
                            //If the CDB entry is a branch mispredict, also set the ROB row's "branch mispredict" to true

                            rob_queue_next[rob_index].branch_mispredict = `TRUE;
                            
                        end //endif branch mispredict

                    end //endif CDB == ROB row
                end //endif CDB valid

                
            end
        end



    end
    
    always_comb begin
        if (retiring_branch_mispredict_this_cycle) begin
            //If we're retiring a branch mispredict, then we are about to reset the ROB, so all rows will be free,
            //  expect for ones that we are immediately dispatching into.

            num_free_rob_rows = `NUM_ROBS - num_inst_dispatched;

        end else if (next_head_pointer == next_tail_pointer) begin
            //If the head is the same as the tail, either the ROB is entirely full or entirely empty.
            //Also if we are currently branch mispredicting, then all of the rows should be free
            if (rob_queue_next[next_head_pointer].busy) begin
                num_free_rob_rows = 0;

            end else begin
                num_free_rob_rows = `NUM_ROBS;
            end

        end else if (next_tail_pointer > next_head_pointer) begin
            //If the tail is greater, then the difference between the tail and head is the number of used rows.
        
            num_free_rob_rows = `NUM_ROBS - (next_tail_pointer - next_head_pointer);
        end else begin
            //If the head is greater, then the difference is the number of free rows.

            num_free_rob_rows = next_head_pointer - next_tail_pointer;
        end
    end

    
    /*
        TO DO: Branch handling 
        Check if branch mispredict is already set or check if CDB is informing us that a mispredict happened
        If true, notify dispatch module that branch mispredict is happening
    */
    integer CDB_index;
    logic need_to_break;
    logic [`NUM_ROBS_BITS-1:0] wraparound_tmp;

    assign store_retire_memory_request_next.data = rd_st_out;
    always_comb begin

        //Need to detect a halt or illegal instruction to terminate the program in the testbench
        retiring_branch_mispredict_next_cycle = `FALSE;
        branch_target = 0;
        need_to_break = `FALSE;
        retired_arch_regs_next = 0;
        retired_phys_regs_next = 0;
        retired_old_phys_regs_next = 0;
        num_rows_retire_next = 0;
        num_loads_retire_next = 0;
        num_stores_retire = 0;
        store_retire_stall_next = 0;

        rd_st_idx = 0;
        store_retire_memory_request_next.size = 0;
        store_retire_memory_request_next.addr = 0;
        store_retire_memory_request_next.valid = `FALSE;

        wb_testbench_outputs_next = 0;
        if (~retiring_branch_mispredict_this_cycle && ~load_flush_next_cycle && ~load_flush_this_cycle) begin
            //If we are retiring a branch mispredict this cycle, then we are never retiring next cycle
            for(int num_retire_index = 0; num_retire_index < `N; num_retire_index = num_retire_index + 1) begin  

                //If we are currently stalling and we haven't just recieved a complete signal from dcache, break.
                if(store_retire_stall && ~store_memory_complete)begin
                    rd_st_idx = rob_queue[head_plus_num_retiring].phys_reg_dest;
                    //rd_st_idx = map_table_next[rob_queue[head_plus_num_retiring].arch_reg_dest].phys_reg;
                    store_retire_memory_request_next.size = rob_queue[head_plus_num_retiring].wb_output.mem_size;
                    store_retire_memory_request_next.addr = rob_queue[head_plus_num_retiring].branch_target;
                    store_retire_memory_request_next.valid = `TRUE;

                    store_retire_stall_next = 1;
                    break;
                end
                
                wraparound_tmp = head_plus_num_retiring + num_retire_index;

                if(wraparound_tmp == head_pointer && head_plus_num_retiring != head_pointer)begin
                    break;
                end
                
                //For each row that we are potentially retiring 
                if(rob_queue[wraparound_tmp].complete ) begin 
                    //If the current row is completed, increase the number of rows to retire by 1

                    if(rob_queue[wraparound_tmp].wb_output.rd_mem)begin
                        num_loads_retire_next = num_loads_retire_next+1;
                    end
                    //If this is a store that isn't [at the head and just got an acknoledgment from dcache]
                    //  Then we need to stall
                    if (rob_queue[wraparound_tmp].wb_output.wr_mem && (num_retire_index == 0 && store_memory_complete)) begin
                        num_stores_retire = 1;
                    end
                    if(rob_queue[wraparound_tmp].wb_output.wr_mem && ~(num_retire_index == 0 && store_memory_complete))begin
                        store_retire_stall_next = 1;
                        rd_st_idx = rob_queue[wraparound_tmp].phys_reg_dest;
                        //rd_st_idx = map_table_next[rob_queue[wraparound_tmp].arch_reg_dest].phys_reg;

                        store_retire_memory_request_next.size = rob_queue[wraparound_tmp].wb_output.mem_size;
                        store_retire_memory_request_next.addr = rob_queue[wraparound_tmp].branch_target;
                        
                        store_retire_memory_request_next.valid = `TRUE;

                        //If we are trying to retire a store, then we need to stall until it is actually written to mem.
                        break;
                    end else begin
                        //If this isn't a stalling store, then we can retire an additional instruction.
                        num_rows_retire_next = num_rows_retire_next+1;
                    end

                    
                    if (rob_queue[wraparound_tmp].branch_mispredict) begin 
                        //If it is a branch mispredict, then don't retire any more rows
                        retired_arch_regs_next[num_retire_index] = rob_queue[wraparound_tmp].arch_reg_dest;
                        retired_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].phys_reg_dest;
                        retired_old_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].old_phys_reg_dest;
                        retiring_branch_mispredict_next_cycle = `TRUE;
                        branch_target = rob_queue[wraparound_tmp].branch_target;
                        wb_testbench_outputs_next[num_retire_index] = rob_queue[wraparound_tmp].wb_output;

                        break; //Break out of retire loop
                    end
                end else begin
                    //If the row is not complete, check the CDB to see if it will complete this cycle
                    need_to_break = `TRUE;
                    for(CDB_index = 0; CDB_index < `N; CDB_index = CDB_index + 1) begin 
                        if (CDB_output[CDB_index].valid) begin
                        //For each row in the CDB

                            if (rob_queue[wraparound_tmp].rob_id == CDB_output[CDB_index].rob_id) begin
                                
                                //If the current row's destination register is equal to the current CDB phys_reg, 
                                //increase the number of retired rows by 1
                                if(rob_queue[wraparound_tmp].wb_output.rd_mem)begin
                                    num_loads_retire_next = num_loads_retire_next+1;
                                end
                                if(rob_queue[wraparound_tmp].wb_output.wr_mem)begin
                                    store_retire_stall_next = 1;
                                    rd_st_idx = rob_queue[wraparound_tmp].phys_reg_dest;
                                    //rd_st_idx = map_table_next[rob_queue[wraparound_tmp].arch_reg_dest].phys_reg;

                                    store_retire_memory_request_next.size = rob_queue[wraparound_tmp].wb_output.mem_size;
                                    store_retire_memory_request_next.addr = CDB_output[CDB_index].result;
                                    store_retire_memory_request_next.valid = `TRUE;

                                    //If we are trying to retire a store, then we need to stall until it is actually written to mem.
                                    need_to_break = `TRUE;
                                    break;
                                end
                                else begin
                                    num_rows_retire_next = num_rows_retire_next+1;
                                end

                                if (CDB_output[CDB_index].branch_mispredict) begin 
                                    //If the matching CDB instruction is a branch mispredict, stop retiring rows

                                    retiring_branch_mispredict_next_cycle = `TRUE;
                                    branch_target = CDB_output[CDB_index].result;
                                    need_to_break = `TRUE;
                                    retired_arch_regs_next[num_retire_index] = rob_queue[wraparound_tmp].arch_reg_dest;
                                    retired_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].phys_reg_dest;
                                    retired_old_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].old_phys_reg_dest;
                                    wb_testbench_outputs_next[num_retire_index] = rob_queue[wraparound_tmp].wb_output;
                                    break; //Break out of CDB loop
                                
                                end else begin
                                    //If we found a match in the CDB and it wasn't a branch mispredict, continue retiring.

                                    need_to_break = `FALSE;

                                    break; //Break out of CDB loop
                                end
                            end
                        end
                    end

                    if (need_to_break) begin
                        //If we didn't find a match in the CDB or we found a match, but it was a branch mispredict, 
                        //  stop retiring

                        break; //Break out of retire loop
                    end
                end
                retired_arch_regs_next[num_retire_index] = rob_queue[wraparound_tmp].arch_reg_dest;
                retired_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].phys_reg_dest;
                retired_old_phys_regs_next[num_retire_index] = rob_queue[wraparound_tmp].old_phys_reg_dest;
                wb_testbench_outputs_next[num_retire_index] = rob_queue[wraparound_tmp].wb_output;
            end
        end
    end
    
    `ifdef DEBUG_OUT_ROB
        assign head_pointer_debug = head_pointer;
        assign next_head_pointer_debug = next_head_pointer;
        assign rob_queue_debug = rob_queue;
    `endif

endmodule

`endif
