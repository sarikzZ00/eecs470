
// TODO: this will eventualaly be put into the dispatch module.
// TODO: We need to set the ready bits

/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  map_table.sv                                        //
//                                                                     //
//  Description :  Parameterized MapTable for N-way fetch, issue,      //
//                 and complete. Stores the free list.                 //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MAP_TABLE_SV__
`define __MAP_TABLE_SV__

`include "sys_defs.svh"

//TO DO: Need an architectural Map Table to preserve precise state
module map_table (
	input reset,
	input clock,
	input [`N-1:0] [`NUM_ARCH_BITS - 1:0] reg_dest,
	input PHYS_ARCH_PAIR reg_dest_complete [`N-1:0],  // architectural registers
	input [`N-1:0] [`NUM_PHYS_BITS - 1:0] first_n_free_reg, // from the free list

  output MAP_TABLE_ENTRY  map_table [`NUM_REGISTERS - 1 : 0]

	`ifdef DEBUG_OUT_MAP_TABLE
		,
    output MAP_TABLE_ENTRY  map_table_next_debug [`NUM_REGISTERS - 1 : 0]
	`endif  
); 

MAP_TABLE_ENTRY  map_table_next [`NUM_REGISTERS - 1 : 0];

`ifdef DEBUG_OUT_MAP_TABLE
	assign map_table_next_debug = map_table_next;
`endif  




// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
		foreach(map_table[i]) begin
			map_table[i].phys_reg = 0; // we could also have this be i
			map_table[i].ready = `FALSE; // TODO: this should probably be true
		end
	end else begin // if (reset)
		map_table <= `SD  map_table_next;
	end
end // always_ff @posedge


integer k;
integer free_index;
always_comb begin
	map_table_next = map_table;
	free_index = 0;
	// loop through N issued instructions and set the dest reg correctly
	foreach (reg_dest[k]) begin
		if (reg_dest[k]) begin 
			// always assign r0 to p0
			map_table_next[reg_dest[k]].phys_reg =  first_n_free_reg[free_index];
			map_table_next[reg_dest[k]].ready = `FALSE;
			free_index =  free_index + 1;
		end
	end
 
	foreach (reg_dest_complete[comp_index]) begin
		// check that the completed reg is valid and if the phys reg completed equals the reg in the map_table, set ready bit
		if (reg_dest_complete[comp_index].phys &&
			map_table_next[reg_dest_complete[comp_index].arch].phys_reg == reg_dest_complete[comp_index].phys) begin
			map_table_next[reg_dest_complete[comp_index].arch].ready  = `TRUE;
		end
	end
end


endmodule // module map_table

`endif //__MAP_TABLE___
