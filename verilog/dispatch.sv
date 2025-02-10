/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dispatch.sv                                         //
//                                                                     //
//  Description :  Parameterized dispatch stage for N-way fetch,       //
//                 issue, and complete. Also completes decoding of     //
//                 instruction.                                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef DISPATCH_SV_
`define DISPATCH_SV_

`include "sys_defs.svh"
`include "verilog/rob.sv"
`include "verilog/free_list.sv"
`include "verilog/reservation_station.sv"
`include "verilog/regfile.sv"

module decoder (
	input IF_ID_PACKET [`N-1:0] if_packet,
	output ID_EX_PACKET [`N-1:0] id_packet_out,
	output DEST_REG_SEL [`N-1:0] dest_reg
);

	INST inst;
	logic valid_inst_in;


	always_comb begin
		//$display("Dispatch Comb 1");
		// default control values:
		// - valid instructions must override these defaults as necessary.
		// - id_packet_out[i].opa_select, id_packet_out[i].opb_select, and id_packet_out[i].alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		

		foreach(id_packet_out[i]) begin 
			id_packet_out[i].opa_select    = OPA_IS_RS1;
			id_packet_out[i].opb_select    = OPB_IS_RS2;
			id_packet_out[i].alu_func      = ALU_ADD;
			dest_reg[i] 				   = DEST_NONE;
			id_packet_out[i].csr_op        = `FALSE;
			id_packet_out[i].rd_mem        = `FALSE;
			id_packet_out[i].wr_mem        = `FALSE;
			id_packet_out[i].mem_size	   = BYTE;
			id_packet_out[i].cond_branch   = `FALSE;
			id_packet_out[i].uncond_branch = `FALSE;
			id_packet_out[i].halt          = `FALSE;
			id_packet_out[i].illegal       = `FALSE;
			id_packet_out[i].inst 		   = if_packet[i].inst;
			id_packet_out[i].PC			   = if_packet[i].PC;
			id_packet_out[i].NPC		   = if_packet[i].NPC;
			inst 						   = if_packet[i].inst;
	    	valid_inst_in 				   = if_packet[i].valid;
			
			if(valid_inst_in) begin
				casez (inst)
					`RV32_LUI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opa_select = OPA_IS_ZERO;
						id_packet_out[i].opb_select = OPB_IS_U_IMM;
					end
					`RV32_AUIPC: begin 
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opa_select = OPA_IS_PC;
						id_packet_out[i].opb_select = OPB_IS_U_IMM;
					end
					`RV32_JAL: begin
						dest_reg[i]      = DEST_RD;
						id_packet_out[i].opa_select    = OPA_IS_PC;
						id_packet_out[i].opb_select    = OPB_IS_J_IMM;
						id_packet_out[i].uncond_branch = `TRUE;
					end
					`RV32_JALR: begin
						dest_reg[i]      = DEST_RD;
						id_packet_out[i].opa_select    = OPA_IS_RS1;
						id_packet_out[i].opb_select    = OPB_IS_I_IMM;
						id_packet_out[i].uncond_branch = `TRUE;
					end
					`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
					`RV32_BLTU, `RV32_BGEU: begin
						id_packet_out[i].opa_select  = OPA_IS_PC;
						id_packet_out[i].opb_select  = OPB_IS_B_IMM;
						id_packet_out[i].cond_branch = `TRUE;
					end
					`RV32_LB,`RV32_LBU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].rd_mem     = `TRUE;
						id_packet_out[i].mem_size	= BYTE;

					end
					`RV32_LH,`RV32_LHU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].rd_mem     = `TRUE;
						id_packet_out[i].mem_size	= HALF;
					end
					`RV32_LW: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].rd_mem     = `TRUE;
						id_packet_out[i].mem_size	= WORD;

					end
					`RV32_SB: begin
						id_packet_out[i].opb_select = OPB_IS_S_IMM;
						id_packet_out[i].wr_mem     = `TRUE;	
						id_packet_out[i].mem_size 	= BYTE;						
					end
					`RV32_SH: begin
						id_packet_out[i].opb_select = OPB_IS_S_IMM;
						id_packet_out[i].wr_mem     = `TRUE;	
						id_packet_out[i].mem_size	= HALF;			
					end	 
					`RV32_SW: begin
						id_packet_out[i].opb_select = OPB_IS_S_IMM;
						id_packet_out[i].wr_mem     = `TRUE;
						id_packet_out[i].mem_size	= WORD;
					end
					`RV32_ADDI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
					end
					`RV32_SLTI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_SLT;
					end
					`RV32_SLTIU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_SLTU;
					end
					`RV32_ANDI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_AND;
					end
					`RV32_ORI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_OR;
					end
					`RV32_XORI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_XOR;
					end
					`RV32_SLLI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_SLL;
					end
					`RV32_SRLI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_SRL;
					end
					`RV32_SRAI: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].alu_func   = ALU_SRA;
					end
					`RV32_ADD: begin
						dest_reg[i]   = DEST_RD;
					end
					`RV32_SUB: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SUB;
					end
					`RV32_SLT: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SLT;
					end
					`RV32_SLTU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SLTU;
					end
					`RV32_AND: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_AND;
					end
					`RV32_OR: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_OR;
					end
					`RV32_XOR: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_XOR;
					end
					`RV32_SLL: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SLL;
					end
					`RV32_SRL: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SRL;
					end
					`RV32_SRA: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_SRA;
					end
					`RV32_MUL: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_MUL;
					end
					`RV32_MULH: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_MULH;
					end
					`RV32_MULHSU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_MULHSU;
					end
					`RV32_MULHU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].alu_func   = ALU_MULHU;
					end
					`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
						id_packet_out[i].csr_op = `TRUE;
					end
					`WFI: begin
						id_packet_out[i].halt = `TRUE;
						id_packet_out[i].alu_func = ALU_INVALID;
					end
					default: begin
						id_packet_out[i].illegal = `TRUE;
						id_packet_out[i].alu_func = ALU_INVALID;
					end
			
			endcase // casez (inst)
			end // if(valid_inst_in)

			id_packet_out[i].valid = valid_inst_in & ~id_packet_out[i].illegal;
			
		end
	end // always
endmodule // decoder






module dispatch (
	input clock,
	input reset,
	// take in N ROB rows 
	input IF_ID_PACKET [`N-1:0] if_id_packet_in,  // from fetch stage
	input CDB_ROW [`N-1:0] CDB_table,
	input [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free, //from execute stage
    input store_memory_complete,
	input load_flush_next_cycle,
	input load_flush_this_cycle,
    input FLUSHED_INFO load_flush_info,
	

	output logic [$clog2(`NUM_ROWS + 1) - 1:0] num_free_rs_rows,
	output logic [`NUM_ROBS_BITS:0] num_free_rob_rows,
	output RS_EX_PACKET [`N-1:0]  issued_rows,
	output logic retiring_branch_mispredict_next_cycle_output,
	output logic [`XLEN-1:0] retiring_branch_target_next_cycle,
	output WB_OUTPUTS [`N-1:0] wb_testbench_outputs,
	output logic [$clog2(`N+1):0] num_rows_retire,
	output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs,
	output logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs,
	output logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] register_file_out,
	output DISPATCHED_LSQ_PACKET [`N-1:0] dispatched_loads_stores,
	output MEMORY_STORE_REQUEST store_retire_memory_request,
    output logic [$clog2(`N+1):0] num_loads_retire,
    output logic [$clog2(`N+1):0] num_stores_retire,
    output logic [`NUM_ROBS_BITS - 1:0] next_head_pointer

	`ifdef DEBUG_OUT_DISPATCH 
		,output ID_EX_PACKET [`N-1:0] id_packet_out, 
		output MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table_debug,
		output MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices_debug,
		output logic [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS - 1:0] rda_idx_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS - 1:0] rdb_idx_debug,
		output logic [`NUM_PHYS_BITS-1:0] rd_st_idx_debug,
		output logic [`N-1:0][`XLEN-1:0] rda_out_debug,
		output logic [`N-1:0][`XLEN-1:0] rdb_out_debug,
		output logic [`XLEN-1:0] rd_st_out_debug 
	`endif 
	

	`ifdef DEBUG_OUT_ROB
		,output logic [`NUM_ROBS_BITS-1:0] tail_pointer,
		output logic retiring_branch_mispredict_next_cycle,
		output ROB_ROW [`NUM_ROBS - 1 : 0] rob_queue_debug
	`endif

	`ifdef DEBUG_OUT_RS
		,output RESERVATION_ROW [`NUM_ROWS-1:0] reservation_rows_debug
	`endif

	//TODO: pass in immediates and other instruction info to reservation station row
);

FLUSHED_INFO clocked_flush_info;

MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table ;
MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table_next ;

MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table ;
MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table_next ;

DEST_REG_SEL [`N-1:0] dest_reg_select;
//logic reset_or_branch_mispredict ;
logic retiring_branch_mispredict;
//assign reset_or_branch_mispredict = reset || retiring_branch_mispredict; //We think the bug with num_free_rs_rows is here


// FREE LIST
logic [`NUM_PHYS_REGS-1:0] arch_reg_list;
logic [`N-1 : 0] [`NUM_PHYS_BITS - 1 : 0] first_n_free_regs;
logic [$clog2(`N + 1): 0] num_free_regs_used;


// ROB INPUTS
logic [$clog2(`N + 1): 0] num_valid_instructions;
logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices;
logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices;
logic [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs;
logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_store_retire_source_registers;
//CDB needs to be passed in


logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs;

// ROB OUTPUTS
logic [`NUM_REGISTERS-1:0][`NUM_PHYS_BITS-1:0] unrolled_map_table_entries;
logic [`NUM_REGISTERS-1:0] unrolled_map_table_valid;
logic [`NUM_PHYS_REGS-1:0] unrolled_free_regs;
`ifndef DEBUG_OUT_ROB

	logic [`NUM_ROBS_BITS-1:0] tail_pointer;
	logic retiring_branch_mispredict_next_cycle;
	
`endif
assign retiring_branch_mispredict_next_cycle_output = retiring_branch_mispredict_next_cycle;

//RS INPUTS
logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_1;
logic [`N-1:0] phys_reg_1_ready;
logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_2; 
logic [`N-1:0] phys_reg_2_ready;
logic [`N-1:0] [`NUM_ROBS_BITS-1:0] rob_ids;
logic [`N-1:0] [31:0] rs_instr_input;
ID_EX_PACKET [`N-1:0] inst_info;

logic [`N-1:0][`XLEN-1:0] rda_out;
logic [`N-1:0][`XLEN-1:0] rdb_out;  
logic [`XLEN-1:0] rd_st_out;

//RS OUTPUTS
// all RS outputs are ouputs of dispatch itself


logic [`N-1:0][`NUM_PHYS_BITS-1:0] rda_idx;
logic [`N-1:0][`NUM_PHYS_BITS-1:0] rdb_idx;
logic [`NUM_PHYS_BITS-1:0] rd_st_idx;
logic [`N-1:0][`NUM_PHYS_BITS-1:0] wr_idx;
logic [`N-1:0][`XLEN-1:0] wr_data;

decoder decoder(
	.if_packet(if_id_packet_in), 
	.id_packet_out(id_packet_out), 
	.dest_reg(dest_reg_select)
);


//keep track of which physical registers are currently mapped to architectural registers in arch map table
//used to create input into free list that is used on branch mispredict
always_comb begin 
	arch_reg_list = {`NUM_PHYS_REGS{1'b1}};
	arch_reg_list[0] = 0;
	foreach(arch_map_table_next[r_idx])begin 
		arch_reg_list[arch_map_table_next[r_idx].phys_reg] = 0;
	end
end


logic [`NUM_PHYS_REGS-1:0] phys_reg_holds_ready_val_next;
free_list free_list(
  .clock(clock),
  .reset(reset),
  .number_free_regs_used(num_free_regs_used),
  .num_retired(num_rows_retire),
  .retired_list(retired_old_phys_regs), //tells free list which registers to add back in
  .arch_reg_free_list(arch_reg_list),
  .branch_mispredict_this_cycle(retiring_branch_mispredict),
  .first_n_free_regs(first_n_free_regs),
  .load_flush_this_cycle(load_flush_this_cycle),
  .load_flush_freed(unrolled_free_regs),
  .CDB_table(CDB_table),
  .phys_reg_holds_ready_val_next(phys_reg_holds_ready_val_next)
); // free_list

rob rob_inst(.clock(clock),
			 .reset(reset),
			 .num_inst_dispatched(num_valid_instructions),
			 .dispatched_preg_dest_indices(dispatched_preg_dest_indices),
			 .dispatched_preg_old_dest_indices(dispatched_preg_old_dest_indices),
			 .dispatched_store_retire_source_registers(dispatched_store_retire_source_registers),
			 .dispatched_arch_regs(dispatched_arch_regs),
			 .CDB_output(CDB_table),
			 .id_packet_out(id_packet_out),
			 .rd_st_out(rd_st_out),
			 .store_memory_complete(store_memory_complete),
			 .map_table_next(map_table_next), //TODO: maybe map table next?

			 .rd_st_idx(rd_st_idx),
			 .num_loads_retire(num_loads_retire),
			 .num_stores_retire(num_stores_retire),
			 .store_retire_memory_request(store_retire_memory_request),

			 .load_flush_info(clocked_flush_info),
			 .load_flush_this_cycle(load_flush_this_cycle),
			 .load_flush_next_cycle(load_flush_next_cycle),


			 .num_free_rob_rows(num_free_rob_rows),
			 .tail_pointer(tail_pointer),
			 .retired_arch_regs(retired_arch_regs),
			 .retired_phys_regs(retired_phys_regs),
			 .retired_old_phys_regs(retired_old_phys_regs),
			 .num_rows_retire(num_rows_retire),
			 .retiring_branch_mispredict_next_cycle(retiring_branch_mispredict_next_cycle),
			 .branch_target(retiring_branch_target_next_cycle),
			 .wb_testbench_outputs(wb_testbench_outputs),
			 .next_head_pointer(next_head_pointer),
			 .unrolled_map_table_entries(unrolled_map_table_entries),
			 .unrolled_map_table_valid(unrolled_map_table_valid),
			 .unrolled_free_regs(unrolled_free_regs)

			 `ifdef DEBUG_OUT_ROB
				,.rob_queue_debug(rob_queue_debug)
    		`endif
); // ROB



reservation_station rs(.clock(clock),
					   .reset(reset),
					   .CDB_table(CDB_table),
					   .insts(rs_instr_input),
					   .phys_reg_1(phys_reg_1),
					   .phys_reg_1_ready(phys_reg_1_ready),
					   .phys_reg_2(phys_reg_2),
					   .phys_reg_2_ready(phys_reg_2_ready),
					   .phys_reg_dest(dispatched_preg_dest_indices),
					   .rob_ids(rob_ids),
					   .inst_info(inst_info),
					   .num_rows_input(num_valid_instructions),
					   .num_fu_free_next(num_fu_free),
					   .rda_out(rda_out),
					   .rdb_out(rdb_out),
					   .rda_idx(rda_idx),
					   .rdb_idx(rdb_idx),
					   .retiring_branch_mispredict_next_cycle(retiring_branch_mispredict_next_cycle),
					   .load_flush_this_cycle(load_flush_this_cycle),
					   .load_flush_info(clocked_flush_info),


					   .num_free_rows_next(num_free_rs_rows),
					   .issued_rows(issued_rows)

					   `ifdef DEBUG_OUT_RS
							,.rows(reservation_rows_debug)
					   `endif
); // reservation_station

//Instantion for register file here

// compare retired_phys_regs w. expack destreg


	always_comb begin
		for (int i=0; i<`N; i+=1) begin	
			wr_idx[i] = CDB_table[i].phys_regs;
			wr_data[i] =  CDB_table[i].is_uncond_branch ? CDB_table[i].PC_plus_4 : CDB_table[i].result; 
		end
	end

	//I think this needs to be done in dispatch -> have the retired phys regs write their value
	regfile regfile_0 (
		//Inputs
		.reset(reset),
		.rda_idx(rda_idx),
		.rdb_idx(rdb_idx),
		.rd_st_idx(rd_st_idx),
		// TODO: logic matching retired_phys_regs with completed ex_pack.result
		.wr_idx(wr_idx),
		.wr_data(wr_data),
		.clock(clock),

		//Outputs
		.rda_out(rda_out),
		.rdb_out(rdb_out),
		.rd_st_out(rd_st_out),
		.register_file_out(register_file_out)
	);

integer free_list_index;
integer c_idx;
integer h;
integer ls_index;
always_comb begin 
	//$display("Made it to here dispatch");
	map_table_next =  map_table;
	arch_map_table_next = arch_map_table;
	num_valid_instructions = 0;
	free_list_index = 0;
	num_free_regs_used = 0;
	ls_index = 0;



	//set default values for all dispatch info so that we don't
	//latch since we only provide an if and nothing in the elses in some of the logic
	//below
	dispatched_preg_old_dest_indices = 0;
	dispatched_preg_dest_indices = 0;
	dispatched_arch_regs = 0;
	dispatched_store_retire_source_registers = 0;
	rob_ids = {`N{`NUM_ROBS_BITS'b0}};
	rs_instr_input = {`N{7'bxxxxxxx}};
	phys_reg_1 = 0;
	phys_reg_1_ready = 0;
	phys_reg_2 = 0;
	phys_reg_2_ready = 0;
	inst_info = 0;
	c_idx = 0;
	dispatched_loads_stores = 0;



	//Update architectural map table to account for all retired instructions
	//free list directly takes retired_phys_regs as input so that takes care of 
	//adding registers back to the free list
	for(int r_idx = 0; r_idx < `N; r_idx = r_idx+1) begin 
		if (retired_arch_regs[r_idx] != 0) begin
			arch_map_table_next[retired_arch_regs[r_idx]].phys_reg = retired_phys_regs[r_idx];
			arch_map_table_next[retired_arch_regs[r_idx]].ready = `TRUE;
		end
	end

	//If no branch mispredict go through with completes and dispatch, otherwise
	//disregard and just set map table next to be architectural map table
	if (retiring_branch_mispredict) begin
		map_table_next = arch_map_table_next;

		//clearing reservation station and rob is handled
		//via sending branch_mispredict signal to rob and rs
	end
	else begin 


		//Update map table ready bits to represent completes
		foreach (map_table_next[m_idx]) begin 
			foreach (CDB_table[c_idx]) begin 
				if (CDB_table[c_idx].valid != `FALSE && 
						map_table_next[m_idx].phys_reg == CDB_table[c_idx].phys_regs && 
						CDB_table[c_idx].phys_regs != 0) begin 
						map_table_next[m_idx].ready = `TRUE;
				end
			end
		end

		if(load_flush_this_cycle) begin
			for(int u_idx = 0; u_idx < `NUM_REGISTERS; u_idx = u_idx+1)begin
				if(unrolled_map_table_valid[u_idx])begin
					map_table_next[u_idx].phys_reg = unrolled_map_table_entries[u_idx];
					map_table_next[u_idx].ready = phys_reg_holds_ready_val_next[unrolled_map_table_entries[u_idx]];
				end
			end

		end

		//Dispatch instructions
		for (h=0;h<`N;h=h+1) begin
			if (id_packet_out[h].valid) begin 
				num_valid_instructions = num_valid_instructions+1;
				rob_ids[h] = tail_pointer+h;

				if(id_packet_out[h].wr_mem || id_packet_out[h].rd_mem)begin
					dispatched_loads_stores[ls_index].PC = id_packet_out[h].PC;
					dispatched_loads_stores[ls_index].rob_id = rob_ids[h];
					dispatched_loads_stores[ls_index].valid = 1;
					dispatched_loads_stores[ls_index].is_store = id_packet_out[h].wr_mem;
					dispatched_loads_stores[ls_index].mem_size = id_packet_out[h].mem_size;
					if(id_packet_out[h].wr_mem)begin
						dispatched_store_retire_source_registers[h] = map_table_next[if_id_packet_in[h].inst.r.rs2].phys_reg;
					end
					ls_index = ls_index+1;
				end


				
				rs_instr_input[h] = if_id_packet_in[h].inst;
				inst_info[h] = id_packet_out[h];
			
				//TODO: upper immediate instructions don't have rs1, how do we check for this?
				//we need to check for this because in this scenario we should set readyu bit to 1
				//so that it can immediately be issued. UPDATE: Am doing this by checking
				//whether OPA_IS_RS1 I believe this is correct since I believe anything that has
				//either OPA_IS_ZERO or OPA_IS_NPC or OPA_IS_PC should have phys_reg_1_ready be true immediately
				if((id_packet_out[h].opa_select == OPA_IS_RS1 || id_packet_out[h].cond_branch || id_packet_out[h].wr_mem) && if_id_packet_in[h].inst.r.rs1 != 0 && ~id_packet_out[h].halt && ~id_packet_out[h].illegal) begin
					phys_reg_1[h] = map_table_next[if_id_packet_in[h].inst.r.rs1].phys_reg;
					phys_reg_1_ready[h] = map_table_next[if_id_packet_in[h].inst.r.rs1].ready;
					//$display("checking map table for arch reg %d for instruction %h rs1, mapped preg:%d, ready: %d",if_id_packet_in[h].inst.r.rs1,h,map_table_next[if_id_packet_in[h].inst.r.rs1].phys_reg,map_table_next[if_id_packet_in[h].inst.r.rs1].ready);
				end

				//TODO: What about other opa_selects????

				else begin 
					phys_reg_1_ready[h] = `TRUE;
				end


				//if instruction uses rs2 then get it from map table
				//otherwise it is an immediate so mark ready as true
				if ((id_packet_out[h].opb_select == OPB_IS_RS2 || id_packet_out[h].cond_branch || id_packet_out[h].wr_mem) && if_id_packet_in[h].inst.r.rs2 != 0 && ~id_packet_out[h].halt && ~id_packet_out[h].illegal) begin
					phys_reg_2[h] = map_table_next[if_id_packet_in[h].inst.r.rs2].phys_reg;
					phys_reg_2_ready[h] = map_table_next[if_id_packet_in[h].inst.r.rs2].ready;
				end
				else begin 
					phys_reg_2_ready[h] = `TRUE;
				end 


				//if instruction has a destination register
				//1. get old physical destination register from map table (needs to use map_table_next for case of consecutive)
				//   instructions writing to same architectural register
				//2. update map table to hold new physical register destination and mark as not ready
				//3. update physical destination register
				//4. update index in free_list
				if (dest_reg_select[h] == DEST_RD && if_id_packet_in[h].inst.r.rd != 0) begin
					num_free_regs_used = num_free_regs_used+1;
					dispatched_preg_old_dest_indices[h] = map_table_next[if_id_packet_in[h].inst.r.rd].phys_reg;
					map_table_next[if_id_packet_in[h].inst.r.rd].phys_reg = first_n_free_regs[free_list_index];
					map_table_next[if_id_packet_in[h].inst.r.rd].ready = `FALSE;
					dispatched_preg_dest_indices[h] = first_n_free_regs[free_list_index];
					dispatched_arch_regs[h] = if_id_packet_in[h].inst.r.rd;
					free_list_index = free_list_index+1;
				end
			end
		end
	end 
end // always_comb for map_table, free_list, and arch_map_table


// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
		foreach(map_table[i]) begin
			map_table[i].phys_reg 		 <= `SD 0; // we could also have this be i
			map_table[i].ready 			<= `SD `TRUE; 
			arch_map_table[i].phys_reg <= `SD 0; // we could also have this be i
			arch_map_table[i].ready    <= `SD `TRUE; 
		end
		retiring_branch_mispredict <= `SD `FALSE;
		clocked_flush_info <= `SD 0;
	end else begin // if (reset)
		map_table 		 <= `SD map_table_next;
		arch_map_table <= `SD arch_map_table_next;
		retiring_branch_mispredict <= `SD retiring_branch_mispredict_next_cycle;
		clocked_flush_info <= `SD load_flush_info;
	end
end 


`ifdef DEBUG_OUT_DISPATCH 
		assign map_table_debug = map_table;
		assign arch_map_table_debug = arch_map_table;
		assign dispatched_preg_dest_indices_debug = dispatched_preg_dest_indices;
		assign dispatched_preg_old_dest_indices_debug = dispatched_preg_old_dest_indices;
		assign dispatched_arch_regs_debug = dispatched_arch_regs;
		assign retired_old_phys_regs_debug = retired_old_phys_regs;
		assign rda_idx_debug = rda_idx;
		assign rdb_idx_debug = rdb_idx;
		assign rd_st_idx_debug = rd_st_idx_debug;
		assign rda_out_debug = rda_out;
		assign rdb_out_debug = rdb_out;
		assign rd_st_out_debug = rd_st_out;
`endif

endmodule // dispatch






`endif // __DISPATCH_SV__
