/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  free_list.sv                                        //
//                                                                     //
//  Description :  Parameterized Free List for N-way fetch, issue,     //
//                 and complete. Outputs the first N free registers.   //
//                 Assumes no structural hazards (which is             //
//                 safe to assume given the # of phys reg)             //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __FREELIST_SV_
`define __FREELIST_SV_

`include "sys_defs.svh"
//TO DO: Need an architectural free list to maintain precise state
module free_list(
    input clock,
    input reset,
    input [$clog2(`N + 1): 0] number_free_regs_used,
    input [$clog2(`N + 1):0] num_retired,
    input [`N - 1 : 0] [`NUM_PHYS_BITS - 1: 0] retired_list,
    input [`NUM_PHYS_REGS-1:0] arch_reg_free_list, //k-th position is off if pK is on architectural register,
    input branch_mispredict_this_cycle,
    input load_flush_this_cycle,
    input [`NUM_PHYS_REGS-1:0] load_flush_freed,
    input CDB_ROW [`N-1:0] CDB_table,

    output logic [`N-1 : 0] [`NUM_PHYS_BITS - 1 : 0] first_n_free_regs, //Free physical registers that will be sent to the ROB (amount will be dependant on number of dispatched instructions)
    output logic [`NUM_PHYS_REGS-1:0] phys_reg_holds_ready_val_next
    
    `ifdef DEBUG_OUT_FREE_LIST
    ,
    output logic [`NUM_PHYS_REGS-1 : 0] free_list_debug,
    output logic [`NUM_PHYS_REGS-1 : 0] free_list_next_debug

    `endif
);
/* VARIABLES */

// store number of free registers

logic [`NUM_PHYS_REGS-1 : 0] free_list; // K-th position is on if pK is free. (Acts as the valid bit list for the registers)
logic [`NUM_PHYS_REGS-1 : 0] free_list_next;
logic [`NUM_PHYS_REGS-1:0] phys_reg_holds_ready_val;

`ifdef DEBUG_OUT_FREE_LIST
    assign free_list_debug = free_list;
    assign free_list_next_debug = free_list_next_debug;
`endif

integer i;
always_ff @(posedge clock) begin
    if (reset) begin
        free_list[0] <= `SD `FALSE;
        phys_reg_holds_ready_val[0] <= `SD `TRUE;
        for (i = 1; i < `NUM_PHYS_REGS; i = i + 1) begin
            free_list[i] <= `SD 1'b1;
            phys_reg_holds_ready_val[i] <= `SD `FALSE;
        end
    end else begin
        if(branch_mispredict_this_cycle) begin 
            free_list <= `SD arch_reg_free_list;
            phys_reg_holds_ready_val <= `SD ~arch_reg_free_list;
        end
        else begin
            free_list <= `SD free_list_next;
            phys_reg_holds_ready_val <= `SD phys_reg_holds_ready_val_next;
        end
    end
end


/*
COMB BLOCK for adding first N free register indices to first_n_free_regs
first_n_free_regs is a queue that stores the indices of free physical registers
*/
integer k; //index in free regs
integer free_index; //Index we are indexing into the first_n_free_regs
always_comb begin
  first_n_free_regs = 0;
  free_index = 0;
  for (k = 0; k < `NUM_PHYS_REGS; k = k+1) begin
    if (free_index < `N) begin
      if (free_list[k]) begin
        first_n_free_regs[free_index] = k;
        
        free_index = free_index + 1;
      end
    end
  end
end


/*
COMB BLOCK for updating free_list_next
free_list_next has to have all used physical registers be set to false
and also set all retired physical registers be set to true
*/
integer l;
integer m;
always_comb begin
    free_list_next = free_list;
    phys_reg_holds_ready_val_next = phys_reg_holds_ready_val;
    for(int c_idx = 0; c_idx < `N; c_idx = c_idx+1)begin
        phys_reg_holds_ready_val_next[CDB_table[c_idx].phys_regs] = 1;
    end

    if(load_flush_this_cycle)begin
        for(int f_idx=1; f_idx <`NUM_PHYS_REGS; f_idx = f_idx+1 )begin //phys reg 0 always holds valid value
            if (load_flush_freed[f_idx])begin
                free_list_next[f_idx] = 1;
                phys_reg_holds_ready_val_next[f_idx] = 0;
            end
        end    
    end
    for (l = 0; l < number_free_regs_used; l = l + 1) begin
        free_list_next[first_n_free_regs[l]] = `FALSE;
        phys_reg_holds_ready_val_next[first_n_free_regs[l]] = 0;
    end
    for (m = 0; m < num_retired; m = m + 1) begin
        if (retired_list[m] != 0) begin //We can never put register 0 on the free list
            free_list_next[retired_list[m]] = `TRUE;
            phys_reg_holds_ready_val_next[retired_list[m]] = 0;
        end
    end
end

  
endmodule
`endif
