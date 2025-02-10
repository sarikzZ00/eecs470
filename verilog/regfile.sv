/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __REGFILE_SV__
`define __REGFILE_SV__

`include "sys_defs.svh"

module regfile (
	input reset,
	input [`N-1:0][`NUM_PHYS_BITS-1:0]      rda_idx, rdb_idx,wr_idx, // read/write index
	input [`NUM_PHYS_BITS-1:0]	rd_st_idx,
	input [`N-1:0][`XLEN-1:0] 				wr_data,                  // write data
	input clock,

	output logic [`N-1:0] [`XLEN-1:0] rda_out, rdb_out,  // read data
	output logic [`XLEN-1:0] rd_st_out,
	output logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] register_file_out //Only for WB file
);

	logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] registers; // 32, 64-bit Registers
	logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] registers_next;

	assign register_file_out = registers_next;

	always_comb begin
		foreach(rda_idx[r_idx]) begin
			if (rda_idx[r_idx] == `ZERO_REG)
				rda_out[r_idx] = 0;
			else begin 
				rda_out[r_idx] = registers[rda_idx[r_idx]];
				foreach(wr_idx[w]) begin 
					if((wr_idx[w] == rda_idx[r_idx]))
						rda_out[r_idx] = wr_data[w];//internal forwarding
				end
			end
		end
	end

	// Read port B
	always_comb begin
		foreach(rdb_idx[r_idx])begin
			if (rdb_idx[r_idx] == `ZERO_REG)
				rdb_out[r_idx] = 0;
			else begin
				rdb_out[r_idx] = registers[rdb_idx[r_idx]];
				foreach(wr_idx[w]) begin 
					if((wr_idx[w] == rdb_idx[r_idx]))
						rdb_out[r_idx] = wr_data[w]; //internal forwarding
				end
			end
		end
	end

	always_comb begin
		registers_next = registers;

		//Update registesr with written data
		for (int i = 0; i < `N; i = i + 1) begin
			registers_next[wr_idx[i]] = wr_data[i];
		end
		//REG 0 should always be 0
		registers_next[0] = 0;

		//Read out store register. Note that this does forwarding automatically.
		rd_st_out = registers_next[rd_st_idx];
	end

	always_ff @(posedge clock) begin
		if (reset) begin
			registers <= 0;
		end else begin
			registers <= registers_next;
		end
	end


	//##################
	//# Old Code Below #
	//##################

	// // Read port for store retires
	// always_comb begin
	// 	if (rd_st_idx == `ZERO_REG)
	// 		rd_st_out = 0;
	// 	else begin
	// 		rd_st_out = registers[rd_st_idx];
	// 		foreach(wr_idx[w]) begin 
	// 			if((wr_idx[w] == rd_st_idx))
	// 				rd_st_out = wr_data[w]; //internal forwarding
	// 		end
	// 	end
	// end

	// assign register_file_out = registers;
	
	// // Write port
	// always_ff @(posedge clock) begin
	// 	foreach(wr_data[w]) begin 
	// 		registers[wr_idx[w]] <= `SD wr_data[w];
	// 	end
	// end

endmodule // regfile
`endif //__REGFILE_SV__
