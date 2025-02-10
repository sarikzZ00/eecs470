
`ifndef __COMPLETE_SV_
`define __COMPLETE_SV_

`include "sys_defs.svh"

module complete (
    input clock,
    input reset,
    input EX_CP_PACKET [`N-1:0] ex_pack,

    //Squashing inputs
    input need_to_squash,
	input [`NUM_ROBS_BITS - 1:0] squash_younger_than,
	input [`NUM_ROBS_BITS - 1:0] rob_head_pointer,
    input is_branch_mispredict,

    //Load replacement
    input [`N-1:0] [`XLEN-1:0] ld_replacement_values,
    input branch_mispredict_next_cycle,
    

    output CDB_ROW [`N-1:0] cdb_table
    `ifdef DEBUG_OUT_COMPLETE 
        ,output CDB_ROW [`N-1:0] cdb_table_debug,
        output [`N-1:0] [`XLEN-1:0] ld_replacement_values_debug, 
        output [`NUM_ROBS_BITS - 1:0] rob_head_pointer_debug, 
        output [`NUM_ROBS_BITS - 1:0] squash_younger_than_debug
    `endif
);
    CDB_ROW [`N-1:0] cdb_table_next;
    logic branch_mispredict_this_cycle;

    integer num_lds_replaced;

    always_comb begin
        //$display("Made it to here Complete");
        num_lds_replaced = 0;
        for (int i = 0; i < `N; i = i + 1) begin
            
            //Check for squashing
            if (
                (need_to_squash) 
                && 
                (
                    (~is_branch_mispredict && `LEFT_YOUNGER_OR_EQUAL(rob_head_pointer, ex_pack[i].rob_id, squash_younger_than))
                    ||
                    (is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(rob_head_pointer, ex_pack[i].rob_id, squash_younger_than))
                )
            ) begin
                //If we are squashing this instruction, then it shouldn't complete.
                cdb_table_next[i] = 0;
            end else begin
                cdb_table_next[i].valid = ex_pack[i].valid;
                cdb_table_next[i].rob_id = ex_pack[i].rob_id;
                cdb_table_next[i].phys_regs = ex_pack[i].dest_reg;
                //cdb_table_next[i].branch_mispredict = ex_pack[i].branch_mispredict; //when doing early branch resolution this should always be 0
                cdb_table_next[i].branch_mispredict = 0;
                cdb_table_next[i].is_uncond_branch = ex_pack[i].is_uncond_branch;
                cdb_table_next[i].PC_plus_4 = ex_pack[i].PC + 4;

                cdb_table_next[i].halt = ex_pack[i].halt;
                cdb_table_next[i].illegal = ex_pack[i].illegal;


                if(ex_pack[i].is_ld) begin
                    //If this is a load, then we need to get the value from the LSQ
                    //  instead of Execute, since there might have been a store that 
                    //  completed during the load's execution with the same address.
                    cdb_table_next[i].result = ld_replacement_values[num_lds_replaced];
                    //cdb_table_next[i].result = ex_pack[i].result;
                    num_lds_replaced = num_lds_replaced + 1;
                end else begin

                    //If we mispredicted, then this will ALWAYS have the correct NPC.
                    //(If we predicted taken, but was actually not taken, then this will be PC + 4.)
                    //If this was not a branch, then this is just the actual result of the FU
                    cdb_table_next[i].result = ex_pack[i].result; 
                end
                
                
            end
            //$display("%b", cdb_table_next[i]);
        end
    end

    `ifdef DEBUG_OUT_COMPLETE
        assign cdb_table_debug = cdb_table;
        assign ld_replacement_values_debug = ld_replacement_values;
        assign rob_head_pointer_debug = rob_head_pointer;
        assign squash_younger_than_debug = squash_younger_than;
    `endif
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        branch_mispredict_this_cycle <= `SD branch_mispredict_next_cycle;

        if(reset) begin
            cdb_table <= `SD 0;
        end else if (branch_mispredict_next_cycle) begin
            cdb_table <= `SD 0;
        end else if(branch_mispredict_this_cycle) begin
            cdb_table <= `SD 0;
        end else begin
            cdb_table <= `SD cdb_table_next;
        end
    end
endmodule
`endif
