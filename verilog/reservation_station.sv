/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  reservation_station.sv                              //
//                                                                     //
//  Description :  Parameterized RS for N-way fetch, issue,            //
//                 and complete. Supports branch squashing             //
//                 and reset. Very simple selection logic              //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __RESERVATION_STATION_SV__
`define __RESERVATION_STATION_SV__
`include "sys_defs.svh"
`include "ISA.svh"


module reservation_station (
    // the first num_rows_input are guaranteed to be valid
    input [`N-1:0] [31:0] insts,
    input clock,
    input reset,
    // TODO: might be better to pass in as a CDB struct
    // CDB: N structs which contain (phys reg)
    input CDB_ROW [`N-1:0] CDB_table,     // an input signal from the Complete stage
    input [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_1,
    input [`N-1:0] phys_reg_1_ready,
    input [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_2, //Are we using this input?
    input [`N-1:0] phys_reg_2_ready,
    input [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_dest,
    input [`N-1:0] [`NUM_ROBS_BITS-1:0] rob_ids,
    input ID_EX_PACKET [`N-1:0] inst_info, 
    input [`N-1:0][`XLEN-1:0] rda_out,
    input [`N-1:0][`XLEN-1:0] rdb_out,  
    input retiring_branch_mispredict_next_cycle, 
    input FLUSHED_INFO load_flush_info,
    input load_flush_this_cycle,

   
    // how many instructions are being dispatched. 
    //This should usually equal N, but might be less if we have fewer than N free rows
    input [$clog2(`N + 1): 0] num_rows_input, 
    input [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free_next, // Probably doesn't need to be 32 bits

    output logic [$clog2(`NUM_ROWS):0] num_free_rows_next,

    // output N issuable instructions
    output RS_EX_PACKET [`N-1:0] issued_rows,
    output logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rda_idx, 
    output logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rdb_idx


    `ifdef DEBUG_OUT_RS
        //Output these interals if debug
        ,output RESERVATION_ROW [`NUM_ROWS-1:0] rows
    `endif  
); 
`ifndef DEBUG_OUT_RS
//If we're not debuging, then the internals should stay internal
    RESERVATION_ROW [`NUM_ROWS-1:0] rows,
`endif

logic [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free;



FUNC_UNITS [`N-1:0]  decoded_fu;
//Checks the insts of the dispatched instruction
always_comb begin
    decoded_fu = 0;
    for (int k = 0; k < num_rows_input; k = k + 1) begin
        casez(insts[k])
            `RV32_LUI, `RV32_AUIPC, `RV32_JAL,`RV32_JALR,
            `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
            `RV32_BLTU, `RV32_BGEU, `RV32_SLTI, `RV32_SUB, `RV32_SLTIU, `RV32_ANDI,
            `RV32_ORI, `RV32_XORI, `RV32_SLLI,`RV32_SRLI, `RV32_SRAI,
            `RV32_ADD, `RV32_ADDI, `RV32_SUB, `RV32_SLT, `RV32_SLTU, `RV32_AND, `RV32_OR, `RV32_XOR, 
            `RV32_SLL, `RV32_SRL, `RV32_SRA: decoded_fu[k] = ALU;

            
            `RV32_LB, `RV32_LH, `RV32_LW,
            `RV32_LBU, `RV32_LHU: decoded_fu[k] = LD;

            //Store instructions go to the ALU
            `RV32_SB, `RV32_SH, `RV32_SW: decoded_fu[k] = ALU; //ST;

            `RV32_MUL,`RV32_MULH, `RV32_MULHSU, `RV32_MULHSU: decoded_fu[k] = FP;
            
            default: decoded_fu[k] = INVALID;
        endcase
    end
end

always_comb begin
    for (int i = 0; i < `N; i = i + 1) begin
        issued_rows[i].rs1_value = 0;
        issued_rows[i].rs2_value = 0;
    end 

    for (int i = 0; i < `N; i = i + 1) begin
        issued_rows[i].rs1_value = rda_out[i];
        issued_rows[i].rs2_value = rdb_out[i];
    end 
end


RESERVATION_ROW [`NUM_ROWS-1:0] rows_next;

integer num_already_dispatched;
integer num_already_issued;
logic [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_remaining;
always_comb begin
    num_free_rows_next = 0;
    rows_next = rows;
    num_fu_remaining = num_fu_free;
    
    num_already_dispatched = 0;
    num_already_issued = 0;
    rda_idx = 0;
    rdb_idx = 0;

    for (int j = 0; j < `N ; j = j + 1) begin
        issued_rows[j].valid 			= `FALSE;
        issued_rows[j].PC 				= 0;
        issued_rows[j].NPC 			    = 0;
        issued_rows[j].inst 			= 0;
        issued_rows[j].alu_func 		= 0;
        issued_rows[j].functional_unit	= 0;
        issued_rows[j].opa_select       = 0;
        issued_rows[j].opb_select 		= 0;
        issued_rows[j].cond_branch      = 0;
        issued_rows[j].uncond_branch    = 0;
        issued_rows[j].rob_id 			= 0;
        issued_rows[j].dest_reg         = 0;
        issued_rows[j].halt 			= 0;
        issued_rows[j].illegal      	= 0;
        issued_rows[j].size             = 0;
    end

    for(int i = 0; i < `NUM_ROWS; i = i+1) begin

        //$display("Made it inside for loop NUM_ROW, index i:%d", i );
        if((num_already_dispatched < num_rows_input) && ~rows[i].busy)begin 
            rows_next[i].busy            = `TRUE;
            rows_next[i].functional_unit = decoded_fu[num_already_dispatched]; //Not needed for static
            rows_next[i].tag_1           = phys_reg_1[num_already_dispatched];
            rows_next[i].ready_tag_1     = phys_reg_1_ready[num_already_dispatched];
            rows_next[i].tag_2           = phys_reg_2[num_already_dispatched];
            rows_next[i].ready_tag_2     = phys_reg_2_ready[num_already_dispatched];
            rows_next[i].tag_dest        = phys_reg_dest[num_already_dispatched];
            rows_next[i].rob_id          = rob_ids[num_already_dispatched];
            rows_next[i].PC              = inst_info[num_already_dispatched].PC;
            rows_next[i].NPC             = inst_info[num_already_dispatched].NPC;
            rows_next[i].inst            = inst_info[num_already_dispatched].inst;
            rows_next[i].alu_func        = inst_info[num_already_dispatched].alu_func;
            rows_next[i].opa_select      = inst_info[num_already_dispatched].opa_select;
            rows_next[i].opb_select      = inst_info[num_already_dispatched].opb_select;
            rows_next[i].cond_branch     = inst_info[num_already_dispatched].cond_branch;
            rows_next[i].uncond_branch   = inst_info[num_already_dispatched].uncond_branch;
            rows_next[i].halt            = inst_info[num_already_dispatched].halt;
            rows_next[i].illegal         = inst_info[num_already_dispatched].illegal;
            rows_next[i].mem_size        = inst_info[num_already_dispatched].mem_size;
            num_already_dispatched = num_already_dispatched+1;
        end
    end

    for (int i = 0; i < `NUM_ROWS; i = i + 1) begin
        if ((num_already_issued < `N) && rows[i].busy && rows[i].ready_tag_1 && rows[i].ready_tag_2 && ~load_flush_this_cycle) begin
            if (num_fu_remaining[rows[i].functional_unit] > 0) begin
                rows_next[i] = 0;
                //Set Issued Rows
                issued_rows[num_already_issued].valid 			= `TRUE;
                issued_rows[num_already_issued].PC 				= rows[i].PC;
                issued_rows[num_already_issued].NPC 			= rows[i].NPC;
                issued_rows[num_already_issued].inst 			= rows[i].inst;
                issued_rows[num_already_issued].alu_func 		= rows[i].alu_func;
                issued_rows[num_already_issued].functional_unit	= rows[i].functional_unit;
                issued_rows[num_already_issued].opa_select      = rows[i].opa_select;
                issued_rows[num_already_issued].opb_select 		= rows[i].opb_select;
                issued_rows[num_already_issued].cond_branch     = rows[i].cond_branch;
                issued_rows[num_already_issued].uncond_branch   = rows[i].uncond_branch;
                issued_rows[num_already_issued].rob_id 			= rows[i].rob_id;
                issued_rows[num_already_issued].dest_reg        = rows[i].tag_dest;
                issued_rows[num_already_issued].halt 			= rows[i].halt;
                issued_rows[num_already_issued].illegal     	= rows[i].illegal;
                issued_rows[num_already_issued].size            = rows[i].mem_size;
                
                //These values are not stored in RS, and are added externally
                rda_idx[num_already_issued] = rows[i].tag_1;
                rdb_idx[num_already_issued] = rows[i].tag_2;
               

                
                
                num_already_issued = num_already_issued + 1;
                num_fu_remaining[rows[i].functional_unit] = num_fu_remaining[rows[i].functional_unit] - 1;
            end
        end
        
        if (num_already_issued == `N) begin
            break;
        end
    end

    for (int i = 0; i < `NUM_ROWS; i = i + 1) begin

        for (int CDB_index = 0; CDB_index < `N; CDB_index = CDB_index + 1) begin
            //Check the CDB against reg_1 and set temp_ready_reg_1 to true if it matches
            if (rows[i].busy && CDB_table[CDB_index].valid && (CDB_table[CDB_index].phys_regs == rows[i].tag_1)) begin
                rows_next[i].ready_tag_1 = `TRUE;
            end

            //Check the CDB against reg_2 and set temp_ready_reg_2 to true if it matches
            if (rows[i].busy && CDB_table[CDB_index].valid && (CDB_table[CDB_index].phys_regs == rows[i].tag_2)) begin
                rows_next[i].ready_tag_2 = `TRUE;
            end
        end


        if(load_flush_this_cycle && ((~load_flush_info.is_branch_mispredict &&  `LEFT_YOUNGER_OR_EQUAL(load_flush_info.head_rob_id,rows[i].rob_id,load_flush_info.mispeculated_rob_id))
           || (load_flush_info.is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(load_flush_info.head_rob_id,rows[i].rob_id,load_flush_info.mispeculated_rob_id)) ))
		begin 
			rows_next[i] = 0;
		end
        
    end

    for(int k = 0; k < `NUM_ROWS; k=k+1)begin
        if (~rows[k].busy) begin
            num_free_rows_next = num_free_rows_next + 1;
        end
    end

    if (reset) begin
        num_free_rows_next = `NUM_ROWS;
    end else if (retiring_branch_mispredict_next_cycle) begin
        num_free_rows_next = `NUM_ROWS;
    end else begin
        num_free_rows_next = num_free_rows_next-num_already_dispatched+num_already_issued;
    end
end

always_ff @(posedge clock) begin
    if(reset)begin
        rows <= `SD 0;
        num_fu_free <= `SD 0;
    end
    else if(retiring_branch_mispredict_next_cycle)begin
        rows <= `SD 0;
        num_fu_free <= `SD 0;
    end
    else begin
        rows <= `SD rows_next;
        num_fu_free <= `SD num_fu_free_next;
    end

end

endmodule
`endif //Entire File
