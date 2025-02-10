/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.sv                                         //
//                                                                     //
//  Description :  Parametrized N-way instruction fetch module.        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __IF_STAGE_SV__
`define __IF_STAGE_SV__

`include "verilog/branch_pred.sv"

module if_stage (
            input clock,                                  // system clock
            input reset,                                  // system reset
            input branch_mispredict_next_cycle, 
            input [$clog2(`N+1)-1:0] num_to_fetch,                 // number of fetched instructions
            input [`XLEN-1:0] branch_target,              // target pc: use if branch_mispredict_next_cycle is TRUE
            input CACHE_INST [`N-1:0] 	icache_rows_in, // values returned from icache: value is (valid) ? memory[icache[k].addr] : junk
	        input FLUSHED_INFO execute_flushed_info,
            input FLUSHED_INFO load_flush_info,
            input load_flush_next_cycle,

        	output logic [`XLEN-1:0] proc2Imem_addr,       // Address sent to Instruction memory
            output IF_ID_PACKET [`N-1:0] if_packet_out,    // Output data packet from IF going to Dispatch, see sys_defs for signal information
            output IF_INST_REQ [`N-1:0]	fetch_req, // from instruction fetch stage
            output IF_INST_REQ [`N-1:0]	fetch_to_icache_req //  goes to instruction cache


            `ifdef DEBUG_OUT_FETCH
                ,output logic [`N-1:0] [`XLEN-1:0] pred_PC_debug,
                 output logic [`N-1:0] [`XLEN-1:0] pred_NPC_debug
            `endif
);

logic [`XLEN-1:0] starting_PC;
logic [`XLEN-1:0] input_starting_PC;
logic [`XLEN-1:0] next_starting_PC;

logic [`N-1:0] [`XLEN-1:0] pred_PC; //N-1:0 to avoid OOB
logic [`N-1:0] [`XLEN-1:0] pred_NPC;

`ifdef DEBUG_OUT_FETCH
     assign pred_PC_debug = pred_PC;
     assign pred_NPC_debug = pred_NPC;
`endif

logic [2*`XLEN-1:0] PC_inst;
integer j, i;

logic [`N-1:0] [`XLEN-1:0] pred_target;

branch_pred b1 (
    // Inputs
  	.clock(clock),
	.reset(reset),
    .execute_flushed_info(execute_flushed_info),
    .starting_PC(input_starting_PC),

    // Outputs
	.pred_PC(pred_PC),
    .pred_NPC(pred_NPC)
); // branch_pred 

always_comb begin
    //$display("Made it to here IF");
    if_packet_out = 0;
    
    //If we are mispredicting, we want to start at the actual branch target, rather than continuing from last time
    input_starting_PC = branch_mispredict_next_cycle ? branch_target : 
                        (load_flush_next_cycle ? load_flush_info.mispeculated_PC : starting_PC);
    next_starting_PC = input_starting_PC;

    for (j = 0; j < num_to_fetch; j = j+1) begin 
        if_packet_out[j].PC = pred_PC[j];
        fetch_req[j].addr = pred_PC[j];
        fetch_req[j].valid = `TRUE;


        if_packet_out[j].NPC = pred_NPC[j];
        if_packet_out[j].valid =  icache_rows_in[j].valid; // `TRUE;

        if_packet_out[j].inst = icache_rows_in[j].inst;

        if (icache_rows_in[j].valid) begin
            next_starting_PC = pred_NPC[j];
        end else begin
            //next_starting_PC = next_starting_PC;
            break;
        end
/*
        PC_inst = tb_mem[if_packet_out[j].PC[`XLEN-1:3]];
        //if_packet_out[j].inst = pred_NPC[j][2] ? PC_inst[63:32] : PC_inst[31:0];
        if_packet_out[j].inst = pred_PC[j][2] ? PC_inst[63:32] : PC_inst[31:0];
*/
    end
end

// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if (reset) begin
        starting_PC <= `SD 0;                // initial PC value is 0
    end else begin
        starting_PC <= `SD next_starting_PC;
    end
end


// address of the instruction we're fetching (Mem gives us 64 bits, so 3 0s at the end)
//TODO: Check this value
assign proc2Imem_addr = {pred_PC[0][`XLEN-1:3], 3'b0};






endmodule
`endif
