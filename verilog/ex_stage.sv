//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  ex_stage.v                                           //
//                                                                      //
//  Description :  instruction execute (EX) stage of the pipeline;      //
//                 given the instruction command code CMD, select the   //
//                 proper input A and B for the ALU, compute the result,//
//                 and compute the condition for branches, and pass all //
//                 the results down the pipeline. MWB                   //
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __EX_STAGE_SV__
`define __EX_STAGE_SV__

`include "sys_defs.svh"
`include "ISA.svh"


module ex_stage (
	input clock, 
	input system_reset, 
	input branch_mispredict_next_cycle,

	input RS_EX_PACKET [`N-1:0] input_rows,

	input CACHE_ROW [`NUM_LD-1:0] forwarding_ld_return,
	input CACHE_ROW [`NUM_LD-1:0] memory_ld_return,

	input logic [`NUM_ROBS_BITS-1:0] head_rob_id,

	input need_to_squash,
	input FLUSHED_INFO flushed_info,

	output EX_LD_REQ [`NUM_LD-1:0] lsq_forward_request,
	output EX_LD_REQ [`NUM_LD-1:0] dcache_memory_request,
	
	output EX_CP_PACKET [`N-1:0] ex_packet_out,
	output EX_LSQ_PACKET [`NUM_ST-1:0] ex_lsq_st_out, //Stores that have finished executing
	output EX_LSQ_PACKET [`NUM_LD-1:0] ex_lsq_ld_out, //Loads that have finished executing (and are not stalled)
	output [`NUM_FUNC_UNIT_TYPES-1:0] [31:0] num_fu_free,

	output logic execute_flush_detection,
	output FLUSHED_INFO execute_flushed_info

	`ifdef DEBUG_OUT_EX
	,output EX_CP_PACKET [`NUM_ALU-1:0] alu_packets_debug,
	output EX_CP_PACKET [`NUM_FP-1:0] fp_packets_debug,
	output EX_CP_PACKET [`NUM_LD-1:0] ld_packets_debug
	`endif
);
logic [`NUM_LD-1:0] [`XLEN-1:0] addresses;

logic reset;
assign reset = system_reset || branch_mispredict_next_cycle;

//Values that we need but could have their inputs changed:
logic 			[`N-1:0] [`XLEN-1:0] 			PCs;
logic 			[`N-1:0] [`XLEN-1:0] 			NPCs;
logic 			[`N-1:0] [`XLEN-1:0] 			rs1s;
logic 			[`N-1:0] [`XLEN-1:0] 			rs2s;
logic 			[`N-1:0] 						valids;
INST 			[`N-1:0] 						insts;
ALU_FUNC 		[`N-1:0]    					alu_funcs;
FUNC_UNITS 		[`N-1:0] 						functional_units;
ALU_OPA_SELECT 	[`N-1:0]						opa_selects;
ALU_OPB_SELECT 	[`N-1:0]						opb_selects;
logic 			[`N-1:0] 						cond_branches;
logic 			[`N-1:0] 						uncond_branches;
logic 			[`N-1:0] [`NUM_ROBS_BITS - 1:0] rob_ids;		
logic 			[`N-1:0] [`NUM_PHYS_BITS - 1:0] dest_regs;
logic 			[`N-1:0] 						branch_predictions;
logic 			[`N-1:0]						halts;
logic 			[`N-1:0]						illegals;
MEM_SIZE		[`N-1:0]						sizes;

//TODO: Change these if the inputs change
always_comb begin
	
	//$display("Made it to here ex_stage");
	for (int i = 0; i < `N; i = i + 1) begin
		PCs[i] 				= input_rows[i].PC;
		NPCs[i] 			= input_rows[i].NPC;
		rs1s[i] 			= input_rows[i].rs1_value;
		rs2s[i] 			= input_rows[i].rs2_value;
		insts[i] 			= input_rows[i].inst;
		alu_funcs[i] 		= input_rows[i].alu_func;
		functional_units[i] = input_rows[i].functional_unit;
		opa_selects[i] 		= input_rows[i].opa_select;
		opb_selects[i] 		= input_rows[i].opb_select;
		cond_branches[i] 	= input_rows[i].cond_branch;
		uncond_branches[i]	= input_rows[i].uncond_branch;
		rob_ids[i] 			= input_rows[i].rob_id;		
		dest_regs[i] 		= input_rows[i].dest_reg;
		halts[i]			= input_rows[i].halt;
		illegals[i]			= input_rows[i].illegal;
		sizes[i]			= input_rows[i].size;

		//If NPC =/= PC + 4, then we are predicting taken. Otherwise we are predicting not taken.
		branch_predictions[i] = ((input_rows[i].PC + 'd4) != input_rows[i].NPC);

		if (reset) begin
			valids[i] = `FALSE;
		end else if (need_to_squash) begin
			if (flushed_info.is_branch_mispredict) begin
				//If this is a mispredict, don't flush equal instructions.
				if (`LEFT_STRICTLY_YOUNGER(flushed_info.head_rob_id, input_rows[i].rob_id, flushed_info.mispeculated_rob_id)) begin
					valids[i] = `FALSE;
				end else begin
					valids[i] = input_rows[i].valid;
				end
			end else begin
				//If this is a lsq squash, squash equal rob ids.
				if (`LEFT_YOUNGER_OR_EQUAL(flushed_info.head_rob_id, input_rows[i].rob_id, flushed_info.mispeculated_rob_id)) begin
					valids[i] = `FALSE;
				end else begin
					valids[i] = input_rows[i].valid;
				end
			end
		end
		else begin
			//If we're not squashing, then just check if the input row is valid.
			valids[i] = input_rows[i].valid;
		end
	end
end






integer i, j, k, v, n, p, r;
logic [`N-1:0] alu_starts;
logic [`N-1:0] mult_starts;

logic [31:0] num_mult_executing_next;
logic [31:0] num_mult_starting;

logic [31:0] num_ld_starting;

logic  [`NUM_ALU-1:0] [`XLEN-1:0] alu_results;
logic  [`NUM_FP-1:0] [`XLEN-1:0] mult_results; 
logic  [`NUM_ALU-1:0] alu_dones;
logic  [`NUM_FP-1:0] mult_dones;

logic [31:0] num_mult_dones;
logic [31:0] num_alu_dones;
logic [31:0] num_ld_dones;

logic [`NUM_FP-1:0] mult_busys;


logic [`NUM_FP - 1: 0] fp_free_list;
logic [`NUM_FP - 1: 0] fp_free_list_next;

logic [`NUM_LD - 1: 0] ld_free_list;
logic [`NUM_LD - 1: 0] ld_free_list_next;

EX_CP_PACKET [`NUM_ALU-1:0] alu_packets;
EX_CP_PACKET [`NUM_FP-1:0] fp_packets;
EX_CP_PACKET [`NUM_LD-1:0] ld_packets;

`ifdef DEBUG_OUT_EX
assign alu_packets_debug = alu_packets;
assign fp_packets_debug = fp_packets;
assign ld_packets_debug = ld_packets;
`endif


EX_CP_PACKET [`NUM_FP - 1 : 0] mult_in_packets;
logic [`NUM_FP - 1 : 0] need_to_stall_fp;

logic [`NUM_LD-1:0] is_signed;

logic [`NUM_ALU - 1 : 0] is_alu_cond_branch;
logic [`NUM_ALU - 1 : 0] is_alu_uncond_branch;

//Need to store up to NUM_ROBS halt instructions in a stack if we need to stall them
parameter halt_stack_size = `NUM_ROBS;
EX_CP_PACKET [halt_stack_size - 1:0] halt_stack;
EX_CP_PACKET [halt_stack_size - 1:0] halt_stack_next;



//Load I/O
logic [`NUM_LD-1:0] ld_start;
logic [`NUM_LD-1:0] [`XLEN-1:0] ld_opa;
logic [`NUM_LD-1:0] [`XLEN-1:0] ld_opb;
logic [`NUM_LD-1:0] ld_stall;
logic [`NUM_LD-1:0] ld_busy;
logic [`NUM_LD-1:0] ld_done;
logic [`NUM_LD-1:0] [`XLEN-1:0] ld_result;
logic [`NUM_LD-1:0] [`NUM_ROBS_BITS - 1:0] ld_in_rob_id;
logic [`NUM_LD-1:0] [`NUM_PHYS_BITS - 1:0] ld_in_dest_reg;
logic [`NUM_LD-1:0] [`XLEN-1:0] ld_in_pcs;
MEM_SIZE [`NUM_LD-1:0] ld_in_sizes;
logic [`NUM_LD-1:0] ld_in_is_signed;

MEM_SIZE [`NUM_LD-1:0] ld_output_size;


logic [31:0] num_ld_executing_next;


assign num_fu_free[ALU] = `NUM_ALU;
assign num_fu_free[FP] = `NUM_FP - num_mult_executing_next;
assign num_fu_free[INVALID] = `NUM_INVALID;
//assign num_fu_free[ST] = 1; We are dealing with store instructions by saying their FU is ALU
assign num_fu_free[LD] = `NUM_LD - num_ld_executing_next;


// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
		for (int i = 0; i < `NUM_FP; i = i + 1) begin
			fp_free_list[i] <= `SD `TRUE;
			halt_stack <= `SD 0;
		end

		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			ld_free_list[i] <= `SD `TRUE;
			halt_stack <= `SD halt_stack_next;
		end

	end else begin
		fp_free_list <= `SD fp_free_list_next;
		ld_free_list <= `SD ld_free_list_next;
		
	end

end

integer num_completed;
integer num_alu_found;
integer alu_index;
integer fp_index;
integer halt_index;

EX_CP_PACKET temp_halt_packet;


always_comb begin
	
end




//How many we are about to start executing
always_comb begin
	num_mult_starting = 0;
	for (r = 0; r < `N; r = r + 1) begin
		if (valids[r] && (functional_units[r] == FP) && ~halts[j]) begin
			num_mult_starting = num_mult_starting + 1;
		end
	end

	num_ld_starting = 0;
	for (int i = 0; i < `N; i = i + 1) begin
		if (valids[r] && (functional_units[r] == LD) && ~halts[j]) begin
			num_ld_starting = num_ld_starting + 1;
		end
	end
end



logic [`N-1:0] [`XLEN-1:0] opa_mux_out, opb_mux_out;



logic [`N-1:0] brcond_result;


//Temporary Values
logic is_c_br; //Is Conditional Branch?
logic is_un_br; //Is Unconditional Branch?
logic take_br; //Take Branch?


//ALU OPA/OPB
integer alu_packet_index, alu_reset;

logic [`NUM_FP-1:0] [`XLEN-1:0] opa_fp, opb_fp;
ALU_FUNC [`NUM_FP-1:0] fp_funcs;



//FP Assign the FU, set OPA/OPB/FU Function
integer fp_ind, fp_ind_2;
integer num_st_executing;


always_comb begin


	num_completed = 0;
	num_alu_dones = 0;
	num_mult_dones = 0;
	num_ld_dones = 0;

//######################
//# Set ex_packet_out #
//#####################
	ex_packet_out = 0;
	//Add ALU results to output packet
	for (alu_index = 0; alu_index < `NUM_ALU; alu_index = alu_index + 1) begin
		if (alu_packets[alu_index].valid) begin
			ex_packet_out[num_completed] = alu_packets[alu_index];
			num_alu_dones = num_alu_dones + 1;
			num_completed = num_completed + 1;
		end
	end

	
	//Add LD results to output packets
	ld_stall = 0;
	ex_lsq_ld_out = 0;
	for (int ld_index = 0; ld_index < `NUM_LD; ld_index = ld_index + 1) begin
		if (ld_done[ld_index]) begin
			if (num_completed < `N) begin
				ex_lsq_ld_out[num_ld_dones].address = addresses[ld_index];
				ex_lsq_ld_out[num_ld_dones].value = ld_packets[ld_index].result;
				ex_lsq_ld_out[num_ld_dones].rob_id = ld_packets[ld_index].rob_id;
				ex_lsq_ld_out[num_ld_dones].valid = `TRUE;
				ex_lsq_ld_out[num_ld_dones].is_signed = ld_packets[ld_index].is_signed;
				ex_lsq_ld_out[num_ld_dones].size = ld_output_size[ld_index];

				ex_packet_out[num_completed] = ld_packets[ld_index];
				ex_packet_out[num_completed].is_ld = `TRUE; 

				num_ld_dones = num_ld_dones + 1;
				num_completed = num_completed + 1;
			end else begin
				ld_stall[ld_index] = `TRUE;
			end
		end
	end


	//Add FP results to output packet
	for (fp_index = 0; fp_index < `NUM_FP; fp_index = fp_index + 1) begin
		need_to_stall_fp[fp_index] = `FALSE;
		if (mult_dones[fp_index]) begin
			if (num_completed < `N) begin
				ex_packet_out[num_completed] = fp_packets[fp_index];
				num_mult_dones = num_mult_dones + 1;
				num_completed = num_completed + 1;
			end else begin
				need_to_stall_fp[fp_index] = `TRUE;
			end
		end
	end

	halt_stack_next = halt_stack;
	//Add Halt results to output packet
	for (halt_index = 0; halt_index < `N; halt_index = halt_index + 1) begin
		if (valids[halt_index] && halts[halt_index]) begin
			//We don't care about the result or branch mispredict for halt instructions
			temp_halt_packet.result = 0;
			temp_halt_packet.branch_mispredict = 0;

			temp_halt_packet.rob_id = input_rows[halt_index].rob_id;
			temp_halt_packet.dest_reg = input_rows[halt_index].dest_reg;
			temp_halt_packet.valid = `TRUE;
			temp_halt_packet.halt = `TRUE;
			temp_halt_packet.illegal = `FALSE;
			temp_halt_packet.is_ld = `FALSE;
			temp_halt_packet.PC = PCs[halt_index];
			temp_halt_packet.is_uncond_branch = `FALSE;

			if (num_completed < `N) begin
				ex_packet_out[num_completed] = temp_halt_packet;
				num_completed = num_completed + 1;
			end else begin
				//If we need to stall it, just put it on the stack
				for (int i = 0; i < halt_stack_size; i = i + 1) begin
					if (~halt_stack_next[i].valid) begin
						halt_stack_next[i] = temp_halt_packet;
						break;
					end
				end
			end
		end
	end

	//Take halt instructions off the stack if possible
	for (int i = halt_stack_size - 1; i >= 0; i = i - 1) begin
		if (num_completed >= `N) begin
			//If we don't have room to pop anything off of the stack, break
			break;
		end else if (~halt_stack_next[0].valid) begin
			//If the halt stack is completely empty, then just break to save time.
			break;
		end else if (halt_stack_next[i].valid) begin
			//If we have room, and we have something to pop, pop it and put it in the out packet.
			ex_packet_out[num_completed] = halt_stack_next[i];
			halt_stack_next[i] = 0;
			num_completed = num_completed + 1;
		end 
	end



	//TODO: Illegal Instructions


end


always_comb begin
	execute_flush_detection = `FALSE;
	for (int i = 0; i < `N; i = i + 1) begin
		if (ex_packet_out[i].valid && ex_packet_out[i].branch_mispredict) begin
			if (~execute_flush_detection) begin
				//If this is the first mispredict, then just set the output based on this.
				execute_flush_detection = `TRUE;
				execute_flushed_info.head_rob_id = head_rob_id;
				execute_flushed_info.mispeculated_rob_id = ex_packet_out[i].rob_id;
				execute_flushed_info.mispeculated_PC = ex_packet_out[i].result;
				execute_flushed_info.is_branch_mispredict = `TRUE;
			end else if (`LEFT_STRICTLY_YOUNGER(head_rob_id, execute_flushed_info.mispeculated_rob_id, ex_packet_out[i].rob_id)) begin
				//If this is older than the currect oldest, replace it.
				execute_flush_detection = `TRUE;
				execute_flushed_info.head_rob_id = head_rob_id;
				execute_flushed_info.mispeculated_rob_id = ex_packet_out[i].rob_id;
				execute_flushed_info.mispeculated_PC = ex_packet_out[i].result;
				execute_flushed_info.is_branch_mispredict = `TRUE;
			end
		end
	end
end

//####################################
//# This Comb Block Sets ALU Packets #
//####################################
always_comb begin
	//######################
	//# Reset ALU Packets #
	//#####################
	alu_packets = 0;
	alu_packet_index = 0;	

	//######################
	//# Assign OPA and OPB #
	//######################
	for (j = 0; j < `N; j = j + 1) begin
		opa_mux_out[j] = `XLEN'hdeadfbac;
		//Assign OPA for ALU
		case (opa_selects[j]) 
			OPA_IS_RS1:  opa_mux_out[j] = rs1s[j];
			OPA_IS_NPC:  opa_mux_out[j] = NPCs[j];  
			OPA_IS_PC:   opa_mux_out[j] = PCs[j];    
			OPA_IS_ZERO: opa_mux_out[j] = 0;
		endcase

		//Assign OPB for ALU
		opb_mux_out[j] = `XLEN'hfacefeed;
		case (opb_selects[j]) 
			OPB_IS_RS2:   opb_mux_out[j] =  rs2s[j]; 
			OPB_IS_I_IMM: opb_mux_out[j] = `RV32_signext_Iimm(insts[j]);
			OPB_IS_S_IMM: opb_mux_out[j] = `RV32_signext_Simm(insts[j]);
			OPB_IS_B_IMM: opb_mux_out[j] = `RV32_signext_Bimm(insts[j]);
			OPB_IS_U_IMM: opb_mux_out[j] = `RV32_signext_Uimm(insts[j]);
			OPB_IS_J_IMM: opb_mux_out[j] = `RV32_signext_Jimm(insts[j]);
		endcase

		

		//###############
		//# Set ALU I/O #
		//###############

		//Assign is_cond_branch for ALU
		is_alu_cond_branch[alu_packet_index] = cond_branches[j];
		is_alu_uncond_branch[alu_packet_index] = uncond_branches[j];

		if (valids[j] && functional_units[j] == ALU && ~halts[j]) begin
			
			is_c_br = cond_branches[j];
			is_un_br = uncond_branches[j];
			take_br = is_un_br || (is_c_br && brcond_result[j]);


			alu_packets[alu_packet_index].rob_id = rob_ids[j];
			alu_packets[alu_packet_index].PC = PCs[j];
			alu_packets[alu_packet_index].is_ld = `FALSE;
			alu_packets[alu_packet_index].is_signed = `FALSE; //This only matters for loads
			alu_packets[alu_packet_index].is_uncond_branch = is_un_br;
			
			
			//If this is a store instruction, set the destination register to 0.
			//	(Ask Rohan why)
			//Otherwise, pass through dest reg.

			//Check if this is a store
			casez (insts[v])
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					alu_packets[alu_packet_index].dest_reg = 0;
				end
				default : begin
					alu_packets[alu_packet_index].dest_reg = dest_regs[j];
				end
			endcase
			
			
			alu_packets[alu_packet_index].valid = `TRUE;

			//Misprediction if this is a branch and either:
			// 1. We predicted taken when in fact untaken (or vice versa)
			// 2. We predicted taken correctly, but got the branch target wrong
			alu_packets[alu_packet_index].branch_mispredict = 	(is_c_br || is_un_br) && 
																(
																	(branch_predictions[j] != take_br) || 
																	(take_br && (alu_results[j] != NPCs[j]))
																);

			//If this is a conditional branch and we predict taken, but it is in fact not taken, 
			//then we should put PC + 4 here.
			//Otherwise, this is just the output of the ALU.
			alu_packets[alu_packet_index].result = ((is_c_br || is_un_br) && (branch_predictions[j] && ~take_br)) ? 
														(PCs[j] + 'd4) : alu_results[j];	

			


			alu_packet_index = alu_packet_index + 1;
		end
	end
end


always_comb begin
//##################
//# Set Free Lists #
//##################
	fp_free_list_next = 0;
	num_mult_executing_next = 0;
	


	//Note that because of squashing and stalling, we should fully recalculate num_executing/free_lists every cycle.
	//This will say that the FUs are busy for 1 cycle too long, which is unoptimal, but not incorrect.
	
	for (int i = 0; i < `NUM_FP; i = i + 1) begin

		//Because of the way that the FUs output, we cannot start assigning until the next cycle.
		//The same is true for LDs

		if (mult_dones[i] && ~need_to_stall_fp[i]) begin
			//If we are finishing a FP, wait an additional cycle to it back to the free list
			fp_free_list_next[i] = `FALSE; //This should theorhetically be true, but leave it as false.
			num_mult_executing_next = num_mult_executing_next + 1; //If we chance free list to be true, this should be removed.
		end else if (mult_busys[i]) begin
			fp_free_list_next[i] = `FALSE;
			num_mult_executing_next = num_mult_executing_next + 1;
		end else begin
			fp_free_list_next[i] = `TRUE;
		end
	end

	ld_free_list_next = 0;
	num_ld_executing_next = 0;
	for (int j = 0; j < `NUM_LD; j = j + 1) begin
		if (ld_done[j] && ~ld_stall[j]) begin
			//If we are finishing a LD, wait an additional cycle to it back to the free list
			ld_free_list_next[j] = `FALSE; //This should theorhetically be true, but leave it as false.
			num_ld_executing_next = num_ld_executing_next + 1; //If we chance free list to be true, this should be removed.
		end else if (ld_busy[j]) begin
			ld_free_list_next[j] = `FALSE;
			num_ld_executing_next = num_ld_executing_next + 1;
		end else begin
			ld_free_list_next[j] = `TRUE;
		end
	end


	//Reset Inputs
	alu_starts = {`FALSE};
	mult_starts = {`FALSE};
	ld_start = {`FALSE};

	mult_in_packets = 0;

	ld_in_dest_reg = 0;
	ld_in_rob_id = 0;
	ld_in_pcs = 0;
	ld_in_sizes = 0;

	is_signed = 0;
	ld_in_is_signed = 0;
	opa_fp = 0;
	opb_fp = 0;
	fp_funcs = 0;
	ld_opa = 0;
	ld_opb = 0;

	//Reset store outputs (Ld outputs are done elsewhere)
	ex_lsq_st_out = 0;
	num_st_executing = 0;
	
	for (v = 0; v < `N; v = v + 1) begin
		if (valids[v]) begin
			case(alu_funcs[v])
			ALU_MUL, ALU_MULH, ALU_MULHSU, ALU_MULHU:      
			begin //FP
				for (fp_ind_2 = 0; fp_ind_2 < `NUM_FP; fp_ind_2 = fp_ind_2 + 1) begin
					
					if (fp_free_list_next[fp_ind_2]) begin
						fp_free_list_next[fp_ind_2] = `FALSE;

						//Set OPA
						opa_fp[fp_ind_2] = `XLEN'hdeadfbac;
						case (opa_selects[v])
							OPA_IS_RS1:  opa_fp[fp_ind_2] = rs1s[v];
							OPA_IS_NPC:  opa_fp[fp_ind_2] = NPCs[v];  
							OPA_IS_PC:   opa_fp[fp_ind_2] = PCs[v];    
							OPA_IS_ZERO: opa_fp[fp_ind_2] = 0;
						endcase

						//Set OPB
						opb_fp[fp_ind_2] = `XLEN'hfacefeed;
						case (opb_selects[v]) 
							OPB_IS_RS2:   opb_fp[fp_ind_2] =  rs2s[v]; 
							OPB_IS_I_IMM: opb_fp[fp_ind_2] = `RV32_signext_Iimm(insts[v]);
							OPB_IS_S_IMM: opb_fp[fp_ind_2] = `RV32_signext_Simm(insts[v]);
							OPB_IS_B_IMM: opb_fp[fp_ind_2] = `RV32_signext_Bimm(insts[v]);
							OPB_IS_U_IMM: opb_fp[fp_ind_2] = `RV32_signext_Uimm(insts[v]);
							OPB_IS_J_IMM: opb_fp[fp_ind_2] = `RV32_signext_Jimm(insts[v]);
						endcase

						//Set ALU Func
						fp_funcs[fp_ind_2] = alu_funcs[v];

						mult_in_packets[fp_ind_2].result = 0; //This will be replaced
						mult_in_packets[fp_ind_2].branch_mispredict = `FALSE; //Cannot be a branch (and thus cannot mispredict)
						mult_in_packets[fp_ind_2].rob_id = rob_ids[v]; //pass-through from dispatch
						mult_in_packets[fp_ind_2].dest_reg = dest_regs[v]; //pass-through from dispatch
						mult_in_packets[fp_ind_2].valid = `FALSE; //Will be set to true once FP is done
						mult_in_packets[fp_ind_2].halt = halts[v];
						mult_in_packets[fp_ind_2].illegal = illegals[v];
						mult_in_packets[fp_ind_2].PC = PCs[v];

						//Start it
						mult_starts[fp_ind_2] = `TRUE;

						num_mult_executing_next = num_mult_executing_next + 1;
						break;
					end
				end
			end
			
			ALU_ADD, ALU_SUB, ALU_AND, ALU_SLT, ALU_SLTU,
			ALU_OR, ALU_XOR, ALU_SRL, ALU_SLL, ALU_SRA: 
				begin
					if (functional_units[v] == ALU) begin
						alu_starts[v] = `TRUE;

						//Check if this is a store
						casez (insts[v])
							`RV32_SB, `RV32_SH, `RV32_SW: begin
								ex_lsq_st_out[num_st_executing].address = alu_results[v];
								ex_lsq_st_out[num_st_executing].value = rs2s[v];
								ex_lsq_st_out[num_st_executing].rob_id = rob_ids[v];
								ex_lsq_st_out[num_st_executing].valid = `TRUE;

								num_st_executing = num_st_executing + 1;
							end
							default : begin
								//Do nothing for non-store instructions
							end
						endcase
						
					end
					else if (functional_units[v] == LD) begin
						for (int ld_ind_2 = 0; ld_ind_2 < `NUM_LD; ld_ind_2 = ld_ind_2 + 1) begin
							if (ld_free_list_next[ld_ind_2]) begin
								ld_free_list_next[ld_ind_2] = `FALSE;

								ld_start[ld_ind_2] = `TRUE;

								//Set OPA
								ld_opa[ld_ind_2] = `XLEN'hdeadfbac;
								case (opa_selects[v])
									OPA_IS_RS1:  ld_opa[ld_ind_2] = rs1s[v];
									OPA_IS_NPC:  ld_opa[ld_ind_2] = NPCs[v];  
									OPA_IS_PC:   ld_opa[ld_ind_2] = PCs[v];    
									OPA_IS_ZERO: ld_opa[ld_ind_2] = 0;
								endcase

								//Set OPB
								ld_opb[ld_ind_2] = `XLEN'hfacefeed;
								case (opb_selects[v]) 
									OPB_IS_RS2:   ld_opb[ld_ind_2] =  rs2s[v]; 
									OPB_IS_I_IMM: ld_opb[ld_ind_2] = `RV32_signext_Iimm(insts[v]);
									OPB_IS_S_IMM: ld_opb[ld_ind_2] = `RV32_signext_Simm(insts[v]);
									OPB_IS_B_IMM: ld_opb[ld_ind_2] = `RV32_signext_Bimm(insts[v]);
									OPB_IS_U_IMM: ld_opb[ld_ind_2] = `RV32_signext_Uimm(insts[v]);
									OPB_IS_J_IMM: ld_opb[ld_ind_2] = `RV32_signext_Jimm(insts[v]);
								endcase

								casez (insts[v]) 
									`RV32_LB, `RV32_LH: is_signed[v] = `TRUE;
									default : is_signed[v] = `FALSE;
								endcase

								ld_in_rob_id[ld_ind_2] = rob_ids[v];
								ld_in_dest_reg[ld_ind_2] = dest_regs[v];
								ld_in_pcs[ld_ind_2] = PCs[v];
								ld_in_sizes[ld_ind_2] = sizes[v];
								ld_in_is_signed[ld_ind_2] = is_signed[v];
								//size is just directly passed in, doesn't need to be here.

								num_ld_executing_next = num_ld_executing_next + 1;
								break;
							end
						end
					end
				end

			default:      
				begin 
				end                                                   // here to prevent latches
			endcase
		end
	end
end // always_comb



// use a mux to determine which result to grab
genvar m;
generate for (m = 0; m < `N; m = m + 1) begin: multi_gen
// instantiate the ALUs
alu alu_0 (
	// Inputs
	.rs1(rs1s[m]),
	.rs2(rs2s[m]),
	.opa(opa_mux_out[m]),
	.opb(opb_mux_out[m]),
	.func(alu_funcs[m]),
	.br_func(insts[m].b.funct3),
	.is_cond_branch(cond_branches[m]),
	.is_uncond_branch(uncond_branches[m]),
	.clock(clock),
	.reset(reset),
	.start(alu_starts[m]),

	// Output
	.result(alu_results[m]),
	.done(alu_dones[m]),
	.branch_cond(brcond_result[m])
);

// instantiate the Multipliers
mul mul_0 (
	//Inputs
	.opa(opa_fp[m]),
	.opb(opb_fp[m]),
	.func(fp_funcs[m]), // TODO: replace with dispatched_rows[m].alu_func
	.clock(clock),
	.reset(reset),
	.start(mult_starts[m]),
	.in_packet(mult_in_packets[m]),
	.stall(need_to_stall_fp[m]),

	//Squashing Inputs
	.need_to_squash(need_to_squash),
	.flushed_info(flushed_info),

	//Ouputs
	.busy(mult_busys[m]),
	.result(mult_results[m]),
	.actually_ready(mult_dones[m]),
	.out_packet(fp_packets[m])
);

end endgenerate

genvar z;
generate for (z = 0; z < `NUM_LD; z = z + 1) begin : gen_lds
load ld_0 (
	//Inputs
	.clock(clock),
	.reset(reset),
	.start(ld_start[z]),
	.opa(ld_opa[z]),
	.opb(ld_opb[z]),
	//We should be passing in the entire packet; do not index these two
	.lsq_return_packets(forwarding_ld_return), 
	.dcache_return_packets(memory_ld_return),

	.need_to_stall(ld_stall[z]),
	.in_rob_id(ld_in_rob_id[z]),
	.in_dest_reg(ld_in_dest_reg[z]),
	.in_pc(ld_in_pcs[z]),
	.size(ld_in_sizes[z]),
	.is_signed(ld_in_is_signed[z]),

	//Squashing Inputs
	.need_to_squash(need_to_squash),
	.flushed_info(flushed_info),

	//Outputs
	.busy(ld_busy[z]),
	.lsq_forward_request(lsq_forward_request[z]),
	.dcache_memory_request(dcache_memory_request[z]),
	.ld_done(ld_done[z]),
	.out_packet(ld_packets[z]),
	.address(addresses[z]),
	.internal_mem_size(ld_output_size[z])
);
end endgenerate



endmodule // module ex_stage



//####################################################################################################################
//####################################################################################################################
//####################################################################################################################
//####################################################################################################################
//####################################################################################################################
 
module load (
	input clock,
	input reset,
	input start,
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	input CACHE_ROW [`N-1:0] lsq_return_packets,
	input CACHE_ROW [`N-1:0] dcache_return_packets,
	input need_to_stall,
	input [`NUM_ROBS_BITS - 1:0] in_rob_id,
	input [`XLEN-1:0] in_pc,
	input [`NUM_PHYS_BITS - 1:0] in_dest_reg,
	input MEM_SIZE size,
	input is_signed,

	input need_to_squash,
	input FLUSHED_INFO flushed_info,

	output logic busy,
	output EX_LD_REQ lsq_forward_request,
	output EX_LD_REQ dcache_memory_request,
	output logic ld_done,
	output EX_CP_PACKET out_packet,
	output logic [`XLEN-1:0] address,
	output MEM_SIZE internal_mem_size
);

logic found_match;
logic [`XLEN-1:0] returned_result;
always_comb begin
	found_match = `FALSE;

	//If we don't find a match, this shouldn't be a value.
	returned_result = 'x;

	for (int i = 0; i < `NUM_LD; i = i + 1) begin
		// $display("lsq valid %b", lsq_return_packets[i].valid);
		// $display("lsq size %h", lsq_return_packets[i].size);
		// $display("lsq addr %h", lsq_return_packets[i].addr);
		if (lsq_return_packets[i].valid &&
			(lsq_return_packets[i].size == internal_mem_size) &&
			(lsq_return_packets[i].addr == address)
		) begin
			// $display("Received Data From LSQ");
			// $display("Address: %h, Data: %h", address, lsq_return_packets[i].line);
			//$display("Dump: %h", lsq_return_packets);
			found_match = `TRUE;
			returned_result = lsq_return_packets[i].line;
			break;
		end else if (
			dcache_return_packets[i].valid &&
			(dcache_return_packets[i].size == internal_mem_size) &&
			(dcache_return_packets[i].addr == address)
		) begin
			// $display("Received Data From DCache");
			// $display("Address: %h, Data: %h", address, dcache_return_packets[i].line);
			found_match = `TRUE;
			returned_result = dcache_return_packets[i].line;
			break;
		end
	end
end

logic [`XLEN-1:0] result;
logic [`XLEN-1:0] current_result;
assign current_result = (busy && found_match) ? returned_result : result;

logic stalling;
assign ld_done = stalling || (busy && found_match);


logic [31:0] lb_mask;
logic [31:0] lh_mask;

assign lb_mask = 32'hffff_ff00;
assign lh_mask = 32'hffff_0000;

logic is_signed_internal;

always_comb begin
	out_packet.result = current_result;
	// $display("current_result %h", current_result);
	// $display("busy %b", busy);
	// $display("found match %b", found_match);
	if (is_signed_internal) begin
		if((internal_mem_size == BYTE) && current_result[7]) begin
			out_packet.result = (lb_mask | current_result);
		end else if ((internal_mem_size == HALF) && current_result[15]) begin
			out_packet.result = (lh_mask | current_result);
		end
	end
	//$display("out_packet: %h", out_packet);
end

assign out_packet.branch_mispredict = `FALSE;
assign out_packet.valid = `TRUE;
assign out_packet.halt = `FALSE;
assign out_packet.illegal = `FALSE;
assign out_packet.is_ld = `TRUE;
assign out_packet.is_signed = is_signed_internal;
assign out_packet.is_uncond_branch = `FALSE;

logic ask_for_forwarding;
logic ask_for_memory;

assign lsq_forward_request.valid = ask_for_forwarding;
assign lsq_forward_request.address = address;
assign lsq_forward_request.size = internal_mem_size;
assign lsq_forward_request.rob_id = out_packet.rob_id;

assign dcache_memory_request.valid = ask_for_memory;
assign dcache_memory_request.address = address;
assign dcache_memory_request.size = internal_mem_size;
assign dcache_memory_request.rob_id = out_packet.rob_id;



//Whether or not we actually need to squash;
	logic actually_squashing;

	//We don't care about the equality difference between flush types since this can't be equal.
	assign actually_squashing = (need_to_squash) &&
								`LEFT_YOUNGER_OR_EQUAL(flushed_info.head_rob_id, out_packet.rob_id, flushed_info.mispeculated_rob_id);

always_ff @(posedge clock) begin
	if (reset || actually_squashing) begin
		busy <= `FALSE;
		ask_for_forwarding <= `FALSE;
		ask_for_memory <= `FALSE;
		address <= 'x;
		result <= 'x;
		stalling <= `FALSE;
		out_packet.rob_id <= 'x;
		out_packet.dest_reg <= 'x;
		out_packet.PC <= 'x;
		internal_mem_size <= DOUBLE; //default value, since this should not be possible in our processor
		is_signed_internal <= `FALSE;

	end else if (start) begin
		//If we are starting, then we can calculate the address result in 1 cycle and begin the memory fetch.

		if (busy) begin
			//Note that it should not be possible that start and busy are true at the same time
			$display("@@@WARNING: LD start and busy");
		end
		
		busy <= `TRUE;
		ask_for_forwarding <= `TRUE;
		ask_for_memory <= `FALSE;
		address <= opa + opb;
		result <= 'x;
		stalling <= `FALSE;
		out_packet.rob_id <= in_rob_id;
		out_packet.dest_reg <= in_dest_reg;
		out_packet.PC <= in_pc;
		internal_mem_size <= size;
		is_signed_internal <= is_signed;
		
	end else if (busy && found_match) begin
		//If we got our result back from forwarding

		ask_for_forwarding <= `FALSE;
		ask_for_memory <= `FALSE;
		result <= returned_result;

		if (need_to_stall) begin
			//If we need to stall, then keep busy TRUE and stall
			busy <= `TRUE;
			stalling <= `TRUE;
		end else begin
			//If we don't need to stall, then set busy to FALSE (since we can accept a new load next cycle)
			busy <= `FALSE;
			stalling <= `FALSE;
		end
	end else if (busy && ask_for_forwarding) begin
		//We missed our forwarding, so request memory

		ask_for_forwarding <= `FALSE;
		ask_for_memory <= `TRUE;

	end else if (stalling) begin

		//If we stalled on a previous cycle, check to see if we need to keep stalling
		if (need_to_stall) begin
			//If we need to stall, then store our result and keep busy TRUE
			busy <= `TRUE;
			stalling <= `TRUE;

		end else begin
			//If we don't need to stall, then set busy to FALSE (since we can accept a new load next cycle)
			busy <= `FALSE;
			stalling <= `FALSE;
		end
	end else if (busy) begin
		//We are waiting for memory, and we should keep requesting memory until we get it.
		ask_for_memory <= `TRUE;

	end else begin
		//We are doing nothing; waiting for input.
		busy <= `FALSE;
		ask_for_forwarding <= `FALSE;
		ask_for_memory <= `FALSE;
		address <= 'x;
		result <= 'x;
		stalling <= `FALSE;
	end


end


endmodule


// The ALU
// given the command code CMD and proper operands A and B, compute the
// result of the instruction
// This module is purely combinational
module alu (
	input [`XLEN-1:0] rs1,
	input [`XLEN-1:0] rs2,
	input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	input [2:0] br_func,
	input ALU_FUNC          func,
	input logic is_cond_branch,
	input logic is_uncond_branch,
	input clock,
	input reset,
	input start,

	output logic [`XLEN-1:0] result,
	output logic done,
	output logic branch_cond
);

	wire signed [`XLEN-1:0]   signed_rs1, signed_rs2;

	wire signed [`XLEN-1:0]   signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;

	assign signed_opa = opa;
	assign signed_opb = opb;

	//Change these to opa/opb for inf loop
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;

	always_comb begin
		branch_cond = `FALSE;

		if (is_cond_branch) begin
			//func actually contains a branch condition

			//TODO: Set result correctly
			case(br_func)
				BRANCH_BEQ: branch_cond = signed_rs1 == signed_rs2; // BEQ
				BRANCH_BNE: branch_cond = signed_rs1 != signed_rs2; // BNE
				BRANCH_BLT: branch_cond = signed_rs1 < signed_rs2;  // BLT
				BRANCH_BGE: branch_cond = signed_rs1 >= signed_rs2; // BGE
				BRANCH_BLTU: branch_cond = rs1 < rs2;                // BLTU
				BRANCH_BGEU: branch_cond = rs1 >= rs2;               // BGEU

				default: branch_cond = `FALSE;
			endcase
		end
		
		//Regardless of if this is a branch or not, set the result.
		case (func)
			ALU_ADD:      result = opa + opb;
			ALU_SUB:      result = opa - opb;
			ALU_AND:      result = opa & opb;
			ALU_SLT:      result = signed_opa < signed_opb;
			ALU_SLTU:     result = opa < opb;
			ALU_OR:       result = opa | opb;
			ALU_XOR:      result = opa ^ opb;
			ALU_SRL:      result = opa >> opb[4:0];
			ALU_SLL:      result = opa << opb[4:0];
			ALU_SRA:      result = signed_opa >>> opb[4:0];// arithmetic from logical shift

			
			default:      result = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	
	end

	always_ff @(posedge clock) begin
		if (reset) begin
			done <= `SD `FALSE;
		end else begin
			done <= `SD start;
		end
	end


endmodule // alu


/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mult.sv                                             //
//                                                                     //
//  Description :  A pipelined multiplier module with parameterized    //
//                 number of stages, as seen in project 2.             //
//                 Shouldn't need any changes for project 4.           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __MULT_SV__
`define __MULT_SV__

`include "sys_defs.svh"

`define MULT_DEFAULT_N_STAGES 4

// TODO: attach this to the alu (add a check in execute if an FU hasn't finished)
// feel free to change this module's input/output behavior as needed, but it must remain pipelined

// also note that there are different types of multiplies that must be handled (upper half, signed/unsigned)

module mult #(parameter NUM_STAGES = `MULT_DEFAULT_N_STAGES) (
	input             clock, reset,
	input             start,
	input             mcand_sign, mplier_sign, // NOTE: need to manually determine sign of mcand/mplier
	input [`XLEN-1:0] mcand, mplier,

	output [(2*`XLEN)-1:0] product,
	output                 done
);

	logic [(2*`XLEN)-1:0] mcand_in, mplier_in, mcand_out, mplier_out; // out signals are unused
	// sign extend the inputs
	assign mcand_in  = mcand_sign  ? {{`XLEN{mcand[`XLEN-1]}}, mcand}   : {`XLEN'('b0), mcand};
	assign mplier_in = mplier_sign ? {{`XLEN{mplier[`XLEN-1]}}, mplier} : {`XLEN'('b0), mplier};

	logic [NUM_STAGES-2:0][2*`XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGES-2:0][2*`XLEN-1:0] internal_products;
	logic [NUM_STAGES-2:0]              internal_dones;
	mult_stage #(.NUM_STAGES(NUM_STAGES)) mstage [NUM_STAGES-1:0] (
		// Inputs
		.clock      (clock),
		.reset      (reset),
		.start      ({internal_dones, start}),
		.mplier_in  ({internal_mpliers, mplier_in}),
		.mcand_in   ({internal_mcands, mcand_in}),
		.product_in ({internal_products, 64'h0}),

		// Outputs
		.mplier_out  ({mplier_out, internal_mpliers}),
		.mcand_out   ({mcand_out, internal_mcands}),
		.product_out ({product, internal_products}),
		.done        ({done, internal_dones})
	);

endmodule // module mult


module mult_stage #(parameter NUM_STAGES = `MULT_DEFAULT_N_STAGES) (
	input                 clock, reset, start,
	input [2*`XLEN-1:0] mplier_in, mcand_in,
	input [2*`XLEN-1:0] product_in,

	output logic                 done,
	output logic [2*`XLEN-1:0] mplier_out, mcand_out,
	output logic [2*`XLEN-1:0] product_out
);

	parameter NUM_BITS = (2*`XLEN)/NUM_STAGES;

	logic [2*`XLEN-1:0] prod_in_reg, partial_prod, next_partial_product;
	logic [2*`XLEN-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[NUM_BITS-1:0] * mcand_in;

	assign next_mplier = {NUM_BITS'('b0), mplier_in[2*`XLEN-1:NUM_BITS]};
	assign next_mcand  = {mcand_in[(2*`XLEN-1-NUM_BITS):0], NUM_BITS'('b0)};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg  <= `SD product_in;
		partial_prod <= `SD next_partial_product;
		mplier_out   <= `SD next_mplier;
		mcand_out    <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done <= `SD 1'b0;
		end else begin
			done <= `SD start;
		end
	end

endmodule // module mult_stage

`endif //__MULT_SV__


//The Multiplier

module mul (
    input [`XLEN-1:0] opa,
	input [`XLEN-1:0] opb,
	ALU_FUNC          func,
    input clock,
    input reset,
	input start,
	input EX_CP_PACKET in_packet,
	input stall,

	input need_to_squash,
	input FLUSHED_INFO flushed_info,

	output logic busy,
	output logic [`XLEN-1:0] result,
    output logic actually_ready,
	output EX_CP_PACKET out_packet
);
    wire signed [`XLEN-1:0]   signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
    logic mcand_sign;
    logic mplier_sign;

	ALU_FUNC internal_func;

	logic done;
	logic ready;

	//Whether or not we actually need to squash;
	logic actually_squashing;

	assign actually_ready = ready || done;
	assign signed_opa = opa;
	assign signed_opb = opb;

	assign out_packet.result = done ? result : ((reset || actually_squashing) ? 'x : out_packet.result);
	assign out_packet.valid = `TRUE;
	assign out_packet.is_ld = `FALSE;
	assign out_packet.is_signed = `FALSE; //This only matters for loads.
	assign out_packet.is_uncond_branch = `FALSE;

	assign actually_squashing = (need_to_squash) &&
								`LEFT_YOUNGER_OR_EQUAL(flushed_info.head_rob_id, out_packet.rob_id, flushed_info.mispeculated_rob_id);

	always_ff @(posedge clock) begin
		if (reset || actually_squashing) begin
			ready <= `SD `FALSE;

			out_packet.dest_reg <= `SD 0;
			out_packet.branch_mispredict <= `SD `FALSE;
			out_packet.rob_id <= `SD 0;
			out_packet.halt <= `SD `FALSE;
			out_packet.illegal <= `SD `FALSE;
			out_packet.PC <= `SD 0;
			internal_func <= `SD ALU_INVALID;

			busy <= `SD `FALSE;
			
		end else if (start) begin
			ready <= `SD `FALSE;

			//When we're starting, read in the in_packet to save values for later.
			out_packet.dest_reg <= `SD in_packet.dest_reg;
			out_packet.branch_mispredict <= `SD in_packet.branch_mispredict;
			out_packet.rob_id <= `SD in_packet.rob_id;
			out_packet.halt <= `SD in_packet.halt;
			out_packet.illegal <= `SD in_packet.illegal;
			out_packet.PC <= `SD in_packet.PC;
			internal_func <= `SD func;

			//If we're starting, then busy is true 
			busy <= `SD `TRUE;

		end else if ((done || ready) && ~stall) begin
			//If we are done and not stalling, then we have read out the value.
			ready <= `SD `FALSE;
			busy <= `FALSE;
		end else if (done || ready) begin
			//If we are done, but stalling, then we need to hold the value.
			ready <= `SD `TRUE;
			busy <= `TRUE;
		end else begin
			//Otherwise, we are not ready.
			ready <= `SD `FALSE;
			busy <= `SD busy;
		end 
	end
    //assign mcand_sign = 0'b0;
    //assign mplier_sign = 0'b0;

    wire [2*`XLEN-1:0] mult_product;
    always_comb begin
        case(func)
            ALU_MUL:      begin 
								mcand_sign = 1'b1; 
								mplier_sign = 1'b1; 
						  end
			ALU_MULH:     begin 
								mcand_sign = 1'b1;
								mplier_sign = 1'b1; 
						  end
			ALU_MULHSU:   begin 
								mcand_sign = 1'b1; 
								mplier_sign = 1'b0; 
						  end
			ALU_MULHU:    begin 
								mcand_sign = 1'b0;
								mplier_sign = 1'b0; 
						  end

			default:      begin 
								mcand_sign = 1'b1; 
								mplier_sign = 1'b1; 
					      end
        endcase
        
    end

    mult mult0(.clock(clock), .reset(reset || actually_squashing), .start(start), .mcand_sign(mcand_sign), .mplier_sign(mplier_sign), .mcand(opa), .mplier(opb), 
                .product(mult_product), .done(done));

    always_comb begin
        case(internal_func)
            ALU_MUL:      result = mult_product[`XLEN-1:0];
			ALU_MULH:     result = mult_product[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   result = mult_product[2*`XLEN-1:`XLEN];
			ALU_MULHU:    result = mult_product[2*`XLEN-1:`XLEN];

				default:      result = `XLEN'hfacebeec;  // here to prevent latches
        endcase
    end
endmodule

`endif // __EX_STAGE_SV__
