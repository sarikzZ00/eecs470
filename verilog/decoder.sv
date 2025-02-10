/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  decoder.sv                                          //
//                                                                     //
//  Description :  Parameterized decoder stage for N-way fetch,        //
//                 issue, and complete. Also completes decoding of     //
//                 instruction.                                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __DECODER_SV__
`define __DECODER_SV__

module decoder (
	input IF_ID_PACKET [`N-1:0] if_packet,
	output ID_EX_PACKET [`N-1:0] id_packet_out,
	output DEST_REG_SEL [`N-1:0] dest_reg
);

	INST inst;
	logic valid_inst_in;


	always_comb begin
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
			id_packet_out[i].cond_branch   = `FALSE;
			id_packet_out[i].uncond_branch = `FALSE;
			id_packet_out[i].halt          = `FALSE;
			id_packet_out[i].illegal       = `FALSE;
			id_packet_out[i].inst 		   = if_packet[i].inst
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
					`RV32_LB, `RV32_LH, `RV32_LW,
					`RV32_LBU, `RV32_LHU: begin
						dest_reg[i]   = DEST_RD;
						id_packet_out[i].opb_select = OPB_IS_I_IMM;
						id_packet_out[i].rd_mem     = `TRUE;
					end
					`RV32_SB, `RV32_SH, `RV32_SW: begin
						id_packet_out[i].opb_select = OPB_IS_S_IMM;
						id_packet_out[i].wr_mem     = `TRUE;
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
					end
					default: id_packet_out[i].illegal = `TRUE;
			
			endcase // casez (inst)
			end // if(valid_inst_in)
			id_packet_out[i].valid = valid_inst_in & ~id_packet_out[i].illegal;
		end
	end // always
endmodule // decoder


`endif // __DECODER_SV__
