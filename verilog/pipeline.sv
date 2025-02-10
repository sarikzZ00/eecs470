/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.sv                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


/*
NOTE: All debug variables must be off to synthesize
NOTE: CACHE_MODE must be on
*/

`ifndef __PIPELINE_SV__
`define __PIPELINE_SV__

`include "sys_defs.svh"
`include "verilog/if_stage.sv"
`include "verilog/dispatch.sv"
`include "verilog/ex_stage.sv"
`include "verilog/complete.sv"
`include "verilog/LSQ.sv"
`include "verilog/dcache.sv"
`include "verilog/icache.sv"


module pipeline (
	input        clock,             // System clock
	input        reset,             // System reset
	
	//TODO: Should these inputs be N-way?
	input [3:0]  mem2proc_response, // Tag from memory about current request
	input [63:0] mem2proc_data,     // Data coming back from memory
	input [3:0]  mem2proc_tag,      // Tag from memory about current reply
	input [63:0] tb_mem [`MEM_64BIT_LINES - 1:0],


	output logic [1:0]       proc2mem_command, // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,    // Address sent to memory
	output logic [63:0]      proc2mem_data,    // Data sent to memory
/*
`ifndef CACHE_MODE
	output MEM_SIZE          proc2mem_size,    // data size sent to memory
`endif
*/

	output EXCEPTION_CODE    pipeline_error_status,
	output WB_OUTPUTS [`N-1:0] wb_testbench_outputs,
	output logic [$clog2(`N + 1):0]			num_rows_retire,
	output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs,
	output logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs,
	output logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] register_file_out
	//output logic [4:0]       pipeline_commit_wr_idx,
	//output logic [`XLEN-1:0] pipeline_commit_wr_data,
	//output logic             pipeline_commit_wr_en,
	//output logic [`XLEN-1:0] pipeline_commit_NPC,

	// testing hooks (these must be exported so we can test
	// the synthesized version) data is tested by looking at
	// the final values in memory

    //Debug outputs for reservation rows
	`ifdef DEBUG_OUT_RS
		,output RESERVATION_ROW [`NUM_ROWS-1:0] current_reservation_rows_debug
	`endif

	`ifdef DEBUG_OUT_DISPATCH 
		,output ID_EX_PACKET [`N-1:0] id_packet_out_debug, 
		output MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table_debug,
		output MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices_debug,
		output logic [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs_debug,
		output RS_EX_PACKET [`N-1:0]			issued_rows_debug,
		output logic [$clog2(`NUM_ROWS):0]	num_free_rs_rows_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS - 1:0] rda_idx_debug,
		output logic [`N-1:0][`NUM_PHYS_BITS - 1:0] rdb_idx_debug,
		output logic [`NUM_PHYS_BITS-1:0] rd_st_idx_debug,
		output logic [`N-1:0][`XLEN-1:0] rda_out_debug,
		output logic [`N-1:0][`XLEN-1:0] rdb_out_debug,
		output logic [`XLEN-1:0] rd_st_out_debug, 

		output DISPATCHED_LSQ_PACKET [`N-1:0] dispatched_loads_stores_debug,
		output MEMORY_STORE_REQUEST store_retire_memory_request_debug,
		output logic [$clog2(`N+1):0] num_loads_retire_debug,
		output logic [$clog2(`N+1):0] num_stores_retire_debug
	`endif 

	`ifdef DEBUG_OUT_EX
		,output EX_CP_PACKET [`N-1:0] ex_packet_out_debug,
		output [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free_debug,
		output EX_CP_PACKET [`NUM_ALU-1:0] alu_packets,
		output EX_CP_PACKET [`NUM_FP-1:0] fp_packets,
		output EX_CP_PACKET [`NUM_LD-1:0] ld_packets,
		output EX_LSQ_PACKET [`NUM_LD-1:0] ex_lsq_load_packet,
		output EX_LSQ_PACKET [`NUM_ST-1:0] ex_lsq_store_packet,
		output EX_LD_REQ [`NUM_LD-1:0] ex_mem_request,
		output EX_LD_REQ [`NUM_LD-1:0] load_request
	`endif

	`ifdef DEBUG_OUT_ROB
		,output logic [`NUM_ROBS_BITS-1:0] 		tail_pointer_debug,
		output logic [`NUM_ROBS_BITS:0]			num_free_rob_rows_debug,
		output logic							branch_mispredict_next_cycle_debug,
		output logic [`XLEN-1:0]				retiring_branch_target_debug,
		output logic 							retiring_branch_mispredict_next_cycle_debug,
		output ROB_ROW [`NUM_ROBS - 1 : 0] rob_queue_debug
	`endif

	// Outputs from IF-Stage
	`ifdef DEBUG_OUT_FETCH
		,output logic [`N-1:0] [`XLEN-1:0] pred_PC_debug,
		output logic [`N-1:0] [`XLEN-1:0] pred_NPC_debug,
		output logic [$clog2(`N+1)-1:0] num_to_fetch_debug,
		output IF_ID_PACKET [`N-1:0] if_packet_out    
	`endif

	`ifdef DEBUG_OUT_LSQ
		//Debug Outputs from the LSQ that will determine certain quantitities such as the head pointer, tail pointer, and current state
		//of the load and store queue.
		,output logic [`LQ_BITS-1:0]  head_pointer_lq,
		output logic [`SQ_BITS-1:0]  head_pointer_sq,
		output logic [`LQ_BITS-1:0]	 tail_pointer_lq,
		output logic [`SQ_BITS-1:0]	 tail_pointer_sq,
		output logic [`SQ_BITS:0]  sq_count,
		output logic [`LQ_BITS:0]  lq_count,
		output SQ_ROW [`SQ_SIZE-1:0] store_queue,
		output LQ_ROW [`LQ_SIZE-1:0] load_queue,
		output logic [`LQ_BITS-1:0]  load_queue_alias_index,
		output CACHE_ROW [`NUM_LD-1:0]	forwarding_ld_return
	`endif
	
	`ifdef DEBUG_OUT_ICACHE
		, output ICACHE_PACKET [`CACHE_LINES-1:0] icache_debug,
		output logic [3:0] current_mem_tag_debug,
		output MEMORY_REQUEST icache_req,
		output CACHE_INST [`N-1:0] 	icache_rows_out,
		output ICACHE_REQ inst_req_debug,
		output got_mem_response_debug,
		output capture_mem_tag_debug,
		output found_request_debug,
		output miss_outstanding_debug, // whether a miss has received its response tag to wait on
		output changed_addr_debug,
		output update_mem_tag_debug,
		output unanswered_miss_debug,
		output ICACHE_REQ inst_req_last_debug,
		output TAG_LOCATION mem_service_broadcast
	`endif


	`ifdef DEBUG_OUT_DCACHE
		,output CACHE_ROW [`NUM_LD-1:0] dcache_rows_out,
		output DCACHE_PACKET [`CACHE_LINES-1:0] dcache_debug,
		output logic write_success,
		output MEMORY_REQUEST dcache_req
	`endif
	
	`ifdef DEBUG_OUT_COMPLETE 
        ,output CDB_ROW [`N-1:0] cdb_table_debug,
        output [`N-1:0] [`XLEN-1:0] ld_replacement_values_debug, 
        output [`NUM_ROBS_BITS - 1:0] rob_head_pointer_debug, 
        output [`NUM_ROBS_BITS - 1:0] squash_younger_than_debug
    `endif
);

	// Outputs from dCache
	`ifndef DEBUG_OUT_DCACHE
		CACHE_ROW [`NUM_LD-1:0] dcache_rows_out;
		logic write_success;
		MEMORY_REQUEST dcache_req;
	`endif


	`ifndef DEBUG_OUT_EX
		EX_LSQ_PACKET [`NUM_LD-1:0] 					ex_lsq_load_packet;
		EX_LSQ_PACKET [`NUM_ST-1:0]						ex_lsq_store_packet;
		EX_LD_REQ [`NUM_LD-1:0] ex_mem_request;
		EX_LD_REQ [`NUM_LD-1:0] load_request;
	`endif

	`ifndef DEBUG_OUT_COMPLETE 
        CDB_ROW [`N-1:0] cdb_table_debug;
        logic [`N-1:0] [`XLEN-1:0] ld_replacement_values_debug;
        logic [`NUM_ROBS_BITS - 1:0] rob_head_pointer_debug; 
        logic [`NUM_ROBS_BITS - 1:0] squash_younger_than_debug;
    `endif


	
	// Pipeline register enables
	logic if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;

	
	
	// Outputs from MEM-Stage
	logic [`XLEN-1:0] mem_result_out;
	logic [`XLEN-1:0] proc2Dmem_addr;
	logic [`XLEN-1:0] proc2Dmem_data;
	logic [1:0]       proc2Dmem_command;


	// Outputs from If-Stage
	logic [`XLEN-1:0]					proc2Icache_addr; // TODO: should be N-way
	IF_ID_PACKET [`N-1:0]				if_packet;

	// Outputs from Dispatch-Stage
	logic [$clog2(`NUM_ROWS):0]			num_free_rs_rows;
	logic [`NUM_ROBS_BITS:0]			num_free_rob_rows;
	RS_EX_PACKET [`N-1:0]				issued_rows;
	logic								branch_mispredict_next_cycle;
	logic [`XLEN-1:0]					retiring_branch_target;
	DISPATCHED_LSQ_PACKET [`N-1:0] dispatched_loads_stores;
	MEMORY_STORE_REQUEST store_retire_memory_request;
	logic [$clog2(`N+1):0] num_loads_retire;
	logic [$clog2(`N+1):0] num_stores_retire;

	// More Conditional Outputs from Dispatch-stage
	/*
	`ifdef DEBUG_OUT_DISPATCH 
		ID_EX_PACKET [`N-1:0]			id_packet_out; 
	`endif 
	*/
	`ifndef CACHE_MODE
		MEM_SIZE						proc2Dmem_size;
	`endif

	// Outputs from Execute-stage
	EX_CP_PACKET [`N-1:0] ex_pack;
	logic [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free;
	
	
	

	// Outputs from Complete-Stage
	CDB_ROW [`N-1:0] CDB_table;

	`ifdef DEBUG_OUT_ROB 
		assign num_free_rob_rows_debug = num_free_rob_rows;
		//assign num_free_rob_rows_debug = 2;
	`endif


	logic [`NUM_LD-1:0]								load_forward_request;
	logic [`NUM_LD-1:0] [`XLEN-1:0]					load_forward_address;					
	
	logic [`NUM_ROBS_BITS-1:0]						head_rob_id;

    // input of issued requests
    DISPATCHED_LSQ_PACKET [`N-1:0]    				dispatched_memory_instructions;
	logic [`NUM_ROBS_BITS-1:0]						num_retire_loads;
	logic [`NUM_ROBS_BITS-1:0]						num_retire_stores;

    // output for dispatch to issue new l/s instr
    logic [`LQ_BITS:0] num_rows_load_queue_free;
    logic [`SQ_BITS:0] num_rows_store_queue_free;
	logic [`N-1:0] [`XLEN-1:0] ld_replacement_values;
	`ifndef DEBUG_OUT_LSQ
		CACHE_ROW [`NUM_LD-1:0]	forwarding_ld_return;
	`endif

    // output for dispatch to squash itself and recover
    // rob, rs, etc
    logic error_detect;
	FLUSHED_INFO flushed_info;

	logic execute_flush_detection;
	FLUSHED_INFO execute_flushed_info;

	logic lsq_flush_detection;
	FLUSHED_INFO lsq_flushed_info;

	assign error_detect = execute_flush_detection || lsq_flush_detection;

	//Assign the true flushed_info
	always_comb begin
		flushed_info = 0;
		if (execute_flush_detection && ~lsq_flush_detection) begin
			flushed_info = execute_flushed_info;
		end else if (lsq_flush_detection && ~execute_flush_detection) begin
			flushed_info = lsq_flushed_info;
		end else if (execute_flush_detection && lsq_flush_detection) begin
			//We want to flush using the older instruction
			if (`LEFT_STRICTLY_YOUNGER(head_rob_id, execute_flushed_info.mispeculated_rob_id, lsq_flushed_info.mispeculated_rob_id)) begin
				flushed_info = lsq_flushed_info;
			end else begin
				flushed_info = execute_flushed_info;
			end
		end
	end 
	
   
	logic branch_flush;
	

	//inputs to icache
	IF_INST_REQ [`N-1:0]	fetch_req;

	`ifndef DEBUG_OUT_ICACHE
	TAG_LOCATION			mem_service_broadcast;
	`endif

	//Outputs from icache
	//MEMORY_REQUEST 			icache_req;
	// CACHE_INST [`N-1:0] 	icache_rows_out;

`ifdef DEBUG_OUT_ICACHE
	logic waiting_tag_debug;
`endif

assign if_packet_out = if_packet;

//////////////////////////////////////////////////
//                                              //
//               Testbench Outputs              //
//                                              //
//////////////////////////////////////////////////
	
	
	integer halt_or_illegal_index;
	always_comb begin
		pipeline_error_status = NO_ERROR;
		for(halt_or_illegal_index = 0; halt_or_illegal_index < num_rows_retire; halt_or_illegal_index = halt_or_illegal_index + 1) begin
			if(wb_testbench_outputs[halt_or_illegal_index].halt_detected) begin
				pipeline_error_status = HALTED_ON_WFI;
				break;
			end else if(wb_testbench_outputs[halt_or_illegal_index].illegal_inst_detected) begin 
				pipeline_error_status = ILLEGAL_INST;
				break;
			end
		end
	end


//////////////////////////////////////////////////
//                                              //
//                   CACHES                     //
//                                              //
//////////////////////////////////////////////////

	MEMORY_RESPONSE mem2proc_packet;
	MEMORY_REQUEST arbiter_req;

	arbiter arbiter_0(
		// INPUTS
		.clock(clock),
		.reset(reset),
		.icache_req(icache_req), // Icache -> arbiter 
		.dcache_req(dcache_req), // Dcache -> arbiter 
//		.pfetch_req(pfetch_req), // Pfetch -> arbiter 
	
		// OUTPUTS
		.arbiter_req(arbiter_req),
		.mem_service_broadcast(mem_service_broadcast)
	);


	icache icache_0(
		// INPUTS
		.clock(clock),
		.reset(reset),
		.mem2proc_packet(mem2proc_packet),
		.fetch_req(fetch_req),
		.mem_service_broadcast(mem_service_broadcast), 

		// OUTPUTS
		.icache_req(icache_req),
		.icache_rows_out(icache_rows_out)
	`ifdef DEBUG_OUT_ICACHE
		, 
		.icache_debug(icache_debug),
		.current_mem_tag_debug(current_mem_tag_debug),
		.inst_req_debug(inst_req_debug),
		.got_mem_response_debug(got_mem_response_debug),
		.capture_mem_tag_debug(capture_mem_tag_debug),
		.found_request_debug(found_request_debug),
		.miss_outstanding_debug(miss_outstanding_debug), // whether a miss has received its response tag to wait on
		.changed_addr_debug(changed_addr_debug),
		.update_mem_tag_debug(update_mem_tag_debug),
		.unanswered_miss_debug(unanswered_miss_debug),
		.inst_req_last_debug(inst_req_last_debug)

	`endif

	);


	assign mem2proc_packet = { mem2proc_response, mem2proc_data, mem2proc_tag };
	assign proc2mem_command = arbiter_req.command; 
	assign proc2mem_addr = arbiter_req.addr;
	assign proc2mem_data   = arbiter_req.data;

	dcache dcache_0(
		// INPUT
		.clock(clock),
		.reset(reset),
		.mem2proc_packet(mem2proc_packet), 
		.load_req(ex_mem_request), 
		.store_req(store_retire_memory_request), 
		
		//.capture_mem_tag(1'b1), //TODO Change this and uncomment out below line
		.mem_service_broadcast(mem_service_broadcast), 

		// OUTPUT	
	`ifdef DEBUG_OUT_DCACHE
		.dcache_debug(dcache_debug),
	`endif
		.dcache_req(dcache_req),
		.dcache_rows_out(dcache_rows_out), 
		.write_success(write_success)
	);

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	// these are debug signals that are now included in the packet,
	// breaking them out to support the legacy debug modes
	

	logic [$clog2(`N+1)-1:0] num_to_fetch;
	logic [$clog2(`N+1)-1:0] num_to_fetch_next;
	logic [$clog2(`N+1)-1:0] num_to_fetch_real;
	assign num_to_fetch_real = (branch_mispredict_next_cycle || error_detect) ? 0 : num_to_fetch;
	always_comb begin
		if(branch_mispredict_next_cycle || error_detect)begin
			num_to_fetch_next = 0;
		end
		else begin
			if(`N < num_free_rob_rows && `N < num_free_rs_rows) begin
				num_to_fetch_next = `N;
			end
			else if (num_free_rob_rows < num_free_rs_rows)begin
				num_to_fetch_next = num_free_rob_rows;
			end
			else begin
				num_to_fetch_next = num_free_rs_rows;
			end
		end
	end



	if_stage if_stage_0 (
		// Inputs
		.clock (clock),
		.reset (reset),
		.num_to_fetch(num_to_fetch_real),
		.fetch_req(fetch_req),
		.branch_mispredict_next_cycle(branch_mispredict_next_cycle), // given by head pointer in ROB (take branch value)
		.branch_target(retiring_branch_target),
        .execute_flushed_info(execute_flushed_info),

		.icache_rows_in(icache_rows_out),

		.load_flush_next_cycle(error_detect),
		.load_flush_info(flushed_info),
		// Outputs
		//.proc2Imem_addr(proc2Ichache_addr), //TODO: Uncomment this out for iCache
		.if_packet_out(if_packet)

		`ifdef DEBUG_OUT_FETCH
			,.pred_PC_debug(pred_PC_debug),
			.pred_NPC_debug(pred_NPC_debug)
		`endif
	); // if_stage

	`ifdef DEBUG_OUT_FETCH
		assign num_to_fetch_debug = num_to_fetch;
	`endif

//////////////////////////////////////////////////
//                                              //
//               Dispatch-Stage                 //
//                                              //
//////////////////////////////////////////////////

	// TODO:
	// (1) Add PC values of all inst in the ROB
	// (2) Add branch prediction values to branches (junk for non branches)
	// (3) use this together with prediction direction to compute next_PC

	`ifdef DEBUG_OUT_DISPATCH 
		assign num_free_rs_rows_debug = num_free_rs_rows;
		assign issued_rows_debug = issued_rows;
		assign store_retire_memory_request_debug = store_retire_memory_request;
		assign dispatched_loads_stores_debug = dispatched_loads_stores;
		assign num_loads_retire_debug = num_loads_retire;
		assign num_stores_retire_debug = num_stores_retire;

	`endif	

	logic flushing_this_cycle;
	always_ff @ (posedge clock) begin
		if (reset) begin
			flushing_this_cycle <= 0;
			num_to_fetch <= `SD 0;
		end else begin
			flushing_this_cycle <= error_detect;
			num_to_fetch <= `SD num_to_fetch_next;
		end

	end

	

	dispatch dispatch_0 (
	// Inputs

		//System Inputs
		.clock(clock),
		.reset(reset),
		
		//Inputs From IF
		.if_id_packet_in(if_packet),
		
		//Inputs From Complete
		.CDB_table(CDB_table),
		
		//Inputs From Execute
		.num_fu_free(num_fu_free),

		//Inputs from LSQ
		.load_flush_next_cycle(error_detect),
		.load_flush_this_cycle(flushing_this_cycle),
		.load_flush_info(flushed_info),

		//Inputs From dcache 
		.store_memory_complete(write_success),
		

	// Outputs
		.num_free_rs_rows(num_free_rs_rows),
		.num_free_rob_rows(num_free_rob_rows),

		//Outputs to Execute
		.issued_rows(issued_rows),

		//Outputs to LSQ
		.next_head_pointer(head_rob_id),
		.dispatched_loads_stores(dispatched_memory_instructions),
		.num_loads_retire(num_loads_retire),
		.num_stores_retire(num_stores_retire),

		//Outputs to ?
		.retiring_branch_mispredict_next_cycle_output(branch_mispredict_next_cycle),
		.retiring_branch_target_next_cycle(retiring_branch_target),
		.wb_testbench_outputs(wb_testbench_outputs),
		.num_rows_retire(num_rows_retire),
		.retired_phys_regs(retired_phys_regs),
		.retired_arch_regs(retired_arch_regs),
		.register_file_out(register_file_out),
		.store_retire_memory_request(store_retire_memory_request)
		

		// ROB retires for regfile
		`ifdef DEBUG_OUT_DISPATCH 
			,.id_packet_out(id_packet_out_debug), 
			.map_table_debug(map_table_debug),
			.arch_map_table_debug(arch_map_table_debug),
			.dispatched_preg_dest_indices_debug(dispatched_preg_dest_indices_debug),
			.dispatched_preg_old_dest_indices_debug(dispatched_preg_old_dest_indices_debug),
			.dispatched_arch_regs_debug(dispatched_arch_regs_debug),
			.retired_old_phys_regs_debug(retired_old_phys_regs_debug),
			.rda_idx_debug(rda_idx_debug),
			.rdb_idx_debug(rdb_idx_debug),
			.rda_out_debug(rda_out_debug),
			.rdb_out_debug(rdb_out_debug)
		`endif 

		`ifdef DEBUG_OUT_ROB
			,.tail_pointer(tail_pointer_debug),
			.retiring_branch_mispredict_next_cycle(retiring_branch_mispredict_next_cycle_debug),
			.rob_queue_debug(rob_queue_debug)
		`endif

		`ifdef DEBUG_OUT_RS
			,.reservation_rows_debug(current_reservation_rows_debug)
		`endif
	); // dispatch_stage


	
//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//////////////////////////////////////////////////
	

	ex_stage ex_stage_0 (
	//Inputs
		// System Inputs
		.clock(clock),
		.system_reset(reset),
		.branch_mispredict_next_cycle(branch_mispredict_next_cycle),

		.head_rob_id(head_rob_id),

		//Inputs from RS
		.input_rows(issued_rows),

		// Inputs from dcache
		.memory_ld_return(dcache_rows_out),

		// Inputs from LSQ
		.forwarding_ld_return(forwarding_ld_return),
		
		.need_to_squash(error_detect),
		.flushed_info(flushed_info),

	// Outputs
		//Outputs to Complete
		.ex_packet_out(ex_pack),

		//Output to RS
		.num_fu_free(num_fu_free),

		//Output to LSQ
		.lsq_forward_request(load_request),
		.ex_lsq_ld_out(ex_lsq_load_packet),
		.ex_lsq_st_out(ex_lsq_store_packet),
		//Output to dcache
		.dcache_memory_request(ex_mem_request),

		//Outputs to pipeline
		.execute_flush_detection(execute_flush_detection),
		.execute_flushed_info(execute_flushed_info)

		//Debug Outputs
		`ifdef DEBUG_OUT_EX
		,.alu_packets_debug(alu_packets),
		.fp_packets_debug(fp_packets),
		.ld_packets_debug(ld_packets)
		`endif
	); // ex_stage

	`ifdef DEBUG_OUT_EX
		assign ex_packet_out_debug = ex_pack;
		assign num_fu_free_debug = num_fu_free;
	`endif


//////////////////////////////////////////////////
//                                              //
//               Complete-Stage                 //
//                                              //
//////////////////////////////////////////////////

	complete complete_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.ex_pack(ex_pack),
		.ld_replacement_values(ld_replacement_values),
		.branch_mispredict_next_cycle(branch_mispredict_next_cycle),

		.need_to_squash(error_detect),
		.squash_younger_than(flushed_info.mispeculated_rob_id),
		.rob_head_pointer(head_rob_id),
		.is_branch_mispredict(flushed_info.is_branch_mispredict),

		// Outputs
		.cdb_table(CDB_table)
		`ifdef DEBUG_OUT_COMPLETE 
        	,.cdb_table_debug(cdb_table_debug),
        	.ld_replacement_values_debug(ld_replacement_values_debug), 
        	.rob_head_pointer_debug(rob_head_pointer_debug), 
        	.squash_younger_than_debug(squash_younger_than_debug)
    	`endif
	); // complete

//////////////////////////////////////////////////
//                                              //
//               LSQ                            //
//                                              //
//////////////////////////////////////////////////

LSQ load_store_queue (
    .clock(clock),
    .reset(reset),

	//Universal signal coming from dispatch that will clear the pipleine on a branch mispredict
	.branch_mispredict(branch_mispredict_next_cycle),
    
	//Inputs from the Execute Stage for completed loads and stores 
	.load_request(load_request),
	.ex_lsq_load_packet(ex_lsq_load_packet), 
	.ex_lsq_store_packet(ex_lsq_store_packet), 
	.execute_flush_detection(execute_flush_detection),
	.execute_flushed_info(execute_flushed_info),

	//Input from dispatch to keep track of the head of the rob
	.head_rob_id(head_rob_id),

    //Inputs from dispatch to determine the dispatched retired loads and stores
    .dispatched_memory_instructions(dispatched_memory_instructions),
	.num_retire_loads(num_loads_retire),  
	.num_retire_stores(num_stores_retire),  

	//Output to the complete stage 
	.signed_ld_replacement_values(ld_replacement_values),

    //Outputs sent to execute for if the forward value is found
	.lsq_send_to_ex(forwarding_ld_return),
	//.forward_found(forward_found),
	//.forward_value(forward_value),
	//.load_forward_address_output(load_forward_address_output),

	//Outputs number of free rows in the load and store queues which will be sent to dispatch
    .num_rows_load_queue_free(num_rows_load_queue_free),
    .num_rows_store_queue_free(num_rows_store_queue_free),

    // output for dispatch for a load squash
    .error_detect(lsq_flush_detection),
	
	//Output to ROB to keep track of the mispeculated ROB ID, mispeculated PC, and head rob id
	.flushed_info(lsq_flushed_info)

	`ifdef DEBUG_OUT_LSQ
		//Debug Outputs from the LSQ that will determine certain quantitities such as the head pointer, tail pointer, and current state
		//of the load and store queue.
		,.head_pointer_lq_debug(head_pointer_lq),
		.head_pointer_sq_debug(head_pointer_sq),
		.tail_pointer_lq_debug(tail_pointer_lq),
		.tail_pointer_sq_debug(tail_pointer_sq),
		.sq_count_debug(sq_count),
		.lq_count_debug(lq_count),
		.store_queue_debug(store_queue),
		.load_queue_debug(load_queue),
		.load_queue_alias_index_debug(load_queue_alias_index)
	`endif

);


endmodule // module OoO processor

`endif // __PIPELINE_SV__
