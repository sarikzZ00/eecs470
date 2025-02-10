/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  ldstQueue.sv                                        //
//                                                                     //
//  Description :  handle load/store request in most N way per cycle   //
//                 and send the request to memory in order.            //
//                 It will send complete load/store to complete        //
//                 stage, detet unexpected store after load and        //
//                 raise the error signal and realtive rob number.     //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __LSQUEUE_SV_
`define __LSQUEUE_SV_

`include "sys_defs.svh"

module LSQ(
    input clock,
    input reset,

    // special input through pipeline
    // for age, process control, etc
	
	//input [`NUM_LD-1:0]								load_forward_request,
	//input [`NUM_LD-1:0] [`XLEN-1:0]					load_forward_address,						
    input 											branch_mispredict,
	input EX_LD_REQ [`NUM_LD-1:0]					load_request,
	input EX_LSQ_PACKET [`NUM_LD-1:0] 					ex_lsq_load_packet, 
	input EX_LSQ_PACKET [`NUM_ST-1:0]				ex_lsq_store_packet, 
	input [`NUM_ROBS_BITS-1:0]						head_rob_id,
	input execute_flush_detection,
	input FLUSHED_INFO execute_flushed_info,
	//input MEM_SIZE [``NUM_LD-1:0] 					load_forward_mem_sizes,

    // input of issued requests
    input DISPATCHED_LSQ_PACKET [`N-1:0]    	dispatched_memory_instructions,
	input [$clog2(`N+1):0]						num_retire_loads,
	input [$clog2(`N+1):0]						num_retire_stores,

	output logic [`N-1:0] [`XLEN-1:0] 			signed_ld_replacement_values,
	output CACHE_ROW [`NUM_LD-1:0]				lsq_send_to_ex,
    // output for dispatch to issue new l/s instr
	//output logic [`NUM_LD-1:0] forward_found,
	//output logic [`NUM_LD-1:0] [`XLEN-1:0] forward_value,
	//output logic [`NUM_LD-1:0] [`XLEN-1:0] load_forward_address_output,
    output logic [`LQ_BITS:0] num_rows_load_queue_free,
    output logic [`SQ_BITS:0] num_rows_store_queue_free,
	//output MEM_SIZE [`NUM_LD-1:0]		  forward_mem_size,

    // output for dispatch to squash itself and recover
    // rob, rs, etc
    output logic                        error_detect,
	output	FLUSHED_INFO					flushed_info
	//output logic [`N-1:0][`XLEN-1:0]	complete_load_values

	`ifdef DEBUG_OUT_LSQ
		,output logic [`LQ_BITS-1:0] head_pointer_lq_debug,
		output logic [`SQ_BITS-1:0] head_pointer_sq_debug,
		output logic [`LQ_BITS-1:0] tail_pointer_lq_debug,
		output logic [`SQ_BITS-1:0] tail_pointer_sq_debug,
		output logic [`SQ_BITS:0] sq_count_debug,
		output logic [`LQ_BITS:0] lq_count_debug,
		output SQ_ROW [`SQ_SIZE-1:0] store_queue_debug,
		output LQ_ROW [`LQ_SIZE-1:0] load_queue_debug,
		output logic signed [`LQ_BITS-1:0] load_queue_alias_index_debug
	`endif

); // LSQ parameters

logic macro_debug;
logic macro_debug_2;

// head and tail pointers
logic [`LQ_BITS-1:0] head_pointer_lq;
logic [`LQ_BITS-1:0] head_pointer_lq_unretired;
logic [`LQ_BITS-1:0] head_pointer_lq_unretired_next;
logic [`SQ_BITS-1:0] head_pointer_sq;
logic [`SQ_BITS-1:0] head_pointer_sq_unretired;
logic [`SQ_BITS-1:0] head_pointer_sq_unretired_next;
logic [`LQ_BITS-1:0] head_pointer_lq_next;
logic [`SQ_BITS-1:0] head_pointer_sq_next;
logic [`LQ_BITS-1:0] tail_pointer_lq;
logic [`SQ_BITS-1:0] tail_pointer_sq;
logic [`LQ_BITS-1:0] tail_pointer_lq_next;
logic [`SQ_BITS-1:0] tail_pointer_sq_next;
logic flush_sq_found_original;
logic flush_sq_found_after_head;
logic load_forwarding_found_before_head;
logic error_detect_found;
logic need_to_break;
logic [`N-1:0] [`SQ_BITS-1:0] store_tails_for_ex_load;
logic [`NUM_ST-1:0] [`LQ_BITS-1:0] load_tails_for_ex_store;
logic [`NUM_LD-1:0] [`LQ_BITS-1:0] completed_loads_lq_index;


logic flush_ld_found_original_bmp;
logic flush_ld_found_after_head_bmp;
logic flush_st_found_original_bmp;
logic flush_st_found_after_head_bmp;


logic [`SQ_BITS:0] sq_count;
logic [`LQ_BITS:0]	lq_count;
SQ_ROW [`SQ_SIZE-1:0] store_queue;
LQ_ROW [`LQ_SIZE-1:0] load_queue;
SQ_ROW [`SQ_SIZE-1:0] store_queue_next;
LQ_ROW [`LQ_SIZE-1:0] load_queue_next;

logic [`N-1:0] [`XLEN-1:0] ld_replacement_values;
logic [31:0] lb_mask;
logic [31:0] lh_mask;

logic [1:0] store_mem_size_length;
logic [1:0] load_mem_size_length;

assign lb_mask = 32'hffff_ff00;
assign lh_mask = 32'hffff_0000;

//If this is a signed load, and we are either a byte or a half word:
//		If the left-most bit of our return value is a "1":
//			Then all bits to the left of it must also become a "1".
always_comb begin
	for (int i = 0; i < `NUM_LD; i = i + 1) begin
		signed_ld_replacement_values[i] = ld_replacement_values[i];
		if (ex_lsq_load_packet[i].is_signed) begin
			if((ex_lsq_load_packet[i].size == BYTE) && ld_replacement_values[i][7]) begin
				signed_ld_replacement_values[i] = (lb_mask | ld_replacement_values[i]);
			end else if ((ex_lsq_load_packet[i].size == HALF) && ld_replacement_values[i][15]) begin
				signed_ld_replacement_values[i] = (lh_mask | ld_replacement_values[i]);
			end
		end
	end
end


logic [`SQ_BITS-1:0] sq_overflow_tmp;
logic [`LQ_BITS-1:0] lq_overflow_tmp;
logic [`LQ_BITS-1:0] lq_index_match;
logic is_overlap;
 
integer load_queue_alias_index;
// assign ages
always_comb begin 
	//$display("Made it to here LSQ");
	load_queue_next 			= load_queue;
	store_queue_next			= store_queue;
	head_pointer_lq_next		= head_pointer_lq;
	tail_pointer_lq_next		= tail_pointer_lq;
	head_pointer_sq_next		= head_pointer_sq;
	tail_pointer_sq_next		= tail_pointer_sq;
	head_pointer_lq_unretired_next	= head_pointer_lq_unretired;
	head_pointer_sq_unretired_next 	= head_pointer_sq_unretired;
	sq_count 					= 0;
	lq_count 					= 0;
	error_detect  				= 0;
	flushed_info.head_rob_id 	= head_rob_id;
	flushed_info.mispeculated_rob_id = 0;
	flushed_info.mispeculated_PC = 0;
	flushed_info.is_branch_mispredict = 0;
	load_queue_alias_index		= 0;
	load_tails_for_ex_store		= 0;
	ld_replacement_values       = 0;
	completed_loads_lq_index	= 0;
	// put dispatched loads and stores into LQ and SQ accordingly
	for (int queue_index = 0; queue_index < `N; queue_index = queue_index + 1) begin //change from dispatched
		if (dispatched_memory_instructions[queue_index].valid) begin
			// assign age and put in LQ
			if (dispatched_memory_instructions[queue_index].is_store) begin
				// if(store_queue[tail_pointer_sq_next].retire_bit) begin 
				// 	head_pointer_sq_next = head_pointer_sq_next + 1;
				// end
				sq_overflow_tmp = tail_pointer_sq + sq_count;
				store_queue_next[sq_overflow_tmp].retire_bit 	= `FALSE;
				store_queue_next[sq_overflow_tmp].mem_addr 		= 0;
				store_queue_next[sq_overflow_tmp].value 			= 0;
				store_queue_next[sq_overflow_tmp].mem_data 		= 0;
				store_queue_next[sq_overflow_tmp].complete		= `FALSE;
				store_queue_next[sq_overflow_tmp].valid			= `TRUE;
				store_queue_next[sq_overflow_tmp].rob_id			= dispatched_memory_instructions[queue_index].rob_id;
				store_queue_next[sq_overflow_tmp].PC = 					dispatched_memory_instructions[queue_index].PC;
				store_queue_next[sq_overflow_tmp].age 			= sq_overflow_tmp;
				store_queue_next[sq_overflow_tmp].load_tail 		= tail_pointer_lq + lq_count; //tail_pointer_lq_next + lq_count
				store_queue_next[sq_overflow_tmp].mem_size		= dispatched_memory_instructions[queue_index].mem_size;
				//$display("sq_count: %h", sq_count);
				sq_count = sq_count + 1;
				tail_pointer_sq_next = tail_pointer_sq_next + 1;
				//$display("Here\t");
				//$display("tail_pointer_sq_next: %h", tail_pointer_sq_next);
			end
			else begin
				// if(load_queue[tail_pointer_lq_next].retire_bit) begin 
				// 	head_pointer_lq_next = head_pointer_lq_next + 1;
				// end
				lq_overflow_tmp = tail_pointer_lq + lq_count;
				load_queue_next[lq_overflow_tmp].retire_bit 	= `FALSE;
				load_queue_next[lq_overflow_tmp].complete	= `FALSE;
				load_queue_next[lq_overflow_tmp].valid		= `TRUE;
				load_queue_next[lq_overflow_tmp].rob_id		= dispatched_memory_instructions[queue_index].rob_id;
				load_queue_next[lq_overflow_tmp].age 		= lq_overflow_tmp;
				load_queue_next[lq_overflow_tmp].store_tail 	= tail_pointer_sq + sq_count;
				load_queue_next[lq_overflow_tmp].PC			= dispatched_memory_instructions[queue_index].PC;
				load_queue_next[lq_overflow_tmp].mem_size	= dispatched_memory_instructions[queue_index].mem_size;
				lq_count = lq_count + 1;
				tail_pointer_lq_next = tail_pointer_lq_next + 1;
			end
		end
	end

	// update the complete bit of the LQ
	foreach(ex_lsq_load_packet[update_load_index]) begin
		if (ex_lsq_load_packet[update_load_index].valid) begin
			foreach (load_queue_next[complete_load_index]) begin
					// check if rob_id matches
				if (load_queue_next[complete_load_index].valid && ex_lsq_load_packet[update_load_index].rob_id == load_queue_next[complete_load_index].rob_id) begin
					load_queue_next[complete_load_index].complete 	= `TRUE;
					load_queue_next[complete_load_index].mem_addr 	= ex_lsq_load_packet[update_load_index].address;
					load_queue_next[complete_load_index].mem_data	= ex_lsq_load_packet[update_load_index].value;
					store_tails_for_ex_load[update_load_index] = load_queue_next[complete_load_index].store_tail;
					completed_loads_lq_index[update_load_index] = complete_load_index;
					ld_replacement_values[update_load_index] = ex_lsq_load_packet[update_load_index].value;
				end
			end
		end // ex_lsq_packet.valid
	end

	// update the SQ in complete
	foreach(ex_lsq_store_packet[update_store_index]) begin
		if (ex_lsq_store_packet[update_store_index].valid) begin
			foreach (store_queue_next[complete_store_index]) begin
					// check if rob_id matches
				if (store_queue_next[complete_store_index].valid && (ex_lsq_store_packet[update_store_index].rob_id == store_queue_next[complete_store_index].rob_id)) begin
					store_queue_next[complete_store_index].complete 	= `TRUE;
					store_queue_next[complete_store_index].mem_addr 	= ex_lsq_store_packet[update_store_index].address;
					store_queue_next[complete_store_index].mem_data	    = ex_lsq_store_packet[update_store_index].value;
					load_tails_for_ex_store[update_store_index] 		= store_queue_next[complete_store_index].load_tail;
				end 
			end
		end // ex_lsq_packet.valid
	end
		

	//Retire for a given number of loads and stores
	for (int i = 0; i < num_retire_loads; i = i + 1) begin
		lq_overflow_tmp = head_pointer_lq + i;
		//load_queue_next[lq_overflow_tmp].retire_bit = `TRUE;
		load_queue_next[lq_overflow_tmp] = 0;
		head_pointer_lq_unretired_next = head_pointer_lq_unretired_next + 1;
		head_pointer_lq_next = head_pointer_lq_next + 1;
	end

	for (int i = 0; i < num_retire_stores; i = i + 1) begin
		sq_overflow_tmp = head_pointer_sq + i;
		//store_queue_next[sq_overflow_tmp].retire_bit = `TRUE;
		store_queue_next[sq_overflow_tmp] = 0;
		head_pointer_sq_unretired_next = head_pointer_sq_unretired_next + 1; 
		head_pointer_sq_next = head_pointer_sq_next + 1;
	end
	need_to_break = 0;
	error_detect_found  = 0;
	//When store completes, see if any younger stores mispeculate and flush
	//TODO: Alias checking has to be byte level, even though we are not doing byte level forwarding
	for(int ldn_index = 0; ldn_index < `LQ_SIZE; ldn_index = ldn_index + 1) begin
		//$display("outside of if ldn_index:%d",ldn_index);
		if(load_queue_next[ldn_index].complete  && load_queue_next[ldn_index].valid && ~load_queue_next[ldn_index].retire_bit) begin 
			//$display("inside of if ldn_index:%d",ldn_index);
			for(int alias_s = 0; alias_s < `N; alias_s =  alias_s + 1) begin 

				store_mem_size_length = (ex_lsq_store_packet[alias_s].size == WORD) ? 3 :
										(ex_lsq_store_packet[alias_s].size == HALF ? 1 : 0);

				load_mem_size_length =  (load_queue_next[ldn_index].mem_size == WORD) ? 3 :
										(load_queue_next[ldn_index].mem_size == HALF ? 1 : 0);

				is_overlap = ~((ex_lsq_store_packet[alias_s].address + store_mem_size_length < load_queue_next[ldn_index].mem_addr) || 
								(load_queue_next[ldn_index].mem_addr + load_mem_size_length < ex_lsq_store_packet[alias_s].address));
				//$display("ldn_index:%d,alias_s:%d,ex_lsq_store_packet[alias_s].address:%d,lqn memaddr:%d,exlsq val:%d,lqn memdata:%d,hplq next:%d,lqnext age:%d,load_tails:%d",ldn_index,alias_s,ex_lsq_store_packet[alias_s].address,load_queue_next[ldn_index].mem_addr,ex_lsq_store_packet[alias_s].value,load_queue_next[ldn_index].mem_data,head_pointer_lq_next,load_queue_next[ldn_index].age, load_tails_for_ex_store[alias_s]);
				if(ex_lsq_store_packet[alias_s].valid && is_overlap && (ex_lsq_store_packet[alias_s].value != load_queue_next[ldn_index].mem_data) &&
					`LEFT_YOUNGER_OR_EQUAL(head_pointer_lq_next,load_queue_next[ldn_index].age, load_tails_for_ex_store[alias_s])) begin 
					
					//$display("FLUSH DETECTED: idx:%d, complete: %b, valid: %b, retired: %b",ldn_index,load_queue[ldn_index].complete,load_queue[ldn_index].valid,load_queue[ldn_index].retire_bit);
					if(ldn_index >= head_pointer_lq_next)begin
						load_queue_alias_index = ldn_index;
						error_detect = 1;
						flushed_info.mispeculated_rob_id = load_queue_next[load_queue_alias_index].rob_id;
						flushed_info.mispeculated_PC = load_queue_next[load_queue_alias_index].PC;
						need_to_break = 1;
						break;
					end
					else if(~error_detect_found)begin
						load_queue_alias_index = ldn_index;
						error_detect = 1;
						flushed_info.mispeculated_rob_id = load_queue_next[load_queue_alias_index].rob_id;
						flushed_info.mispeculated_PC = load_queue_next[load_queue_alias_index].PC;
						error_detect_found = 1;
					end
				end
			end
			if(need_to_break)begin
				break;
			end
		end
	end


	load_forwarding_found_before_head = 0;
	//Forwarding logic for a completing load compared with a store instruction
	foreach(ex_lsq_load_packet[load_index]) begin 
		if (ex_lsq_load_packet[load_index].valid) begin
			for(int s_index = 0; s_index < `SQ_SIZE; s_index = s_index+1) begin
				//TODO: This forwarding logic can be optimized for when the store size > load size.
				//	Both when the addresses match, and when the store address is (slightly) smaller than the load address,
				//	but the store still fully encompasses the store request.

				if(load_forwarding_found_before_head && s_index >= head_pointer_sq_next)begin
					break;
				end
				if (store_queue_next[s_index].complete && 
					`LEFT_YOUNGER_OR_EQUAL(head_pointer_lq_next,completed_loads_lq_index[load_index],store_queue_next[s_index].load_tail) && 
					(ex_lsq_load_packet[load_index].address == store_queue_next[s_index].mem_addr) &&
					(ex_lsq_load_packet[load_index].size == store_queue_next[s_index].mem_size)) begin
						//$display("Forwarding Now For CDB: Load_Packet Index:%d; Load Index: %d, Store Index: %d; ROB_ID: %d ", load_index, completed_loads_lq_index[load_index], s_index, ex_lsq_load_packet[load_index].rob_id);
						//$display("Load Head Pointer: %d; Store Head Pointer: %d", head_pointer_lq_next, head_pointer_sq_next);
						//$display("Original Value: %h; New Value: %h", ex_lsq_load_packet[load_index].value, store_queue_next[s_index].mem_data);
						load_queue_next[completed_loads_lq_index[load_index]].mem_data = store_queue_next[s_index].mem_data;
						ld_replacement_values[load_index] = store_queue_next[s_index].mem_data;
						if(s_index < head_pointer_sq_next)begin
							load_forwarding_found_before_head = 1;
						end
				end
			end
		end
	end



	lsq_send_to_ex = 0;
	load_forwarding_found_before_head = 0;
	//Forwarding logic for an executing load compared with a store instruction
	foreach(load_request[load_index]) begin 
		if (load_request[load_index].valid) begin
			for(int s_index = 0; s_index < `SQ_SIZE; s_index = s_index+1) begin
				//TODO: This forwarding logic can be optimized for when the store size > load size.
				//	Both when the addresses match, and when the store address is (slightly) smaller than the load address,
				//	but the store still fully encompasses the store request.

				lq_index_match = 0;
				for (int l = 0; l < `LQ_SIZE; l = l + 1) begin
					if (load_queue_next[l].rob_id == load_request[load_index].rob_id) begin
						lq_index_match = l;
						break;
					end
				end

				if(load_forwarding_found_before_head && s_index >= head_pointer_sq_next)begin
					break;
				end
				//$display("completed_loads_lq_index[%d]: %h", load_index, completed_loads_lq_index[load_index]);
				if (store_queue_next[s_index].complete && //TODO: completed_loads_lq_index is WRONG because this is for completed loads; i.e. CDB. This should be something else.
					`LEFT_YOUNGER_OR_EQUAL(head_pointer_lq_next,lq_index_match,store_queue_next[s_index].load_tail) && 
					(load_request[load_index].address == store_queue_next[s_index].mem_addr) &&
					(load_request[load_index].size == store_queue_next[s_index].mem_size)) begin
						//$display("Forwarding Now For Execute: Load_Packet Index:%d; Load Index: %d, Store Index: %d; ROB_ID: %d ", load_index, completed_loads_lq_index[load_index], s_index, load_request[load_index].rob_id);
						//$display("Load Head Pointer: %d; Store Head Pointer: %d", head_pointer_lq_next, head_pointer_sq_next);
						//$display("New Value: %h", store_queue_next[s_index].mem_data);
						
						lsq_send_to_ex[load_index].addr = load_request[load_index].address;
						lsq_send_to_ex[load_index].line = store_queue_next[s_index].mem_data;
						lsq_send_to_ex[load_index].valid = 1;
						lsq_send_to_ex[load_index].size = store_queue_next[s_index].mem_size;
						if(s_index < head_pointer_sq_next)begin
							load_forwarding_found_before_head = 1;
						end
				end
			end
		end
	end

	//head and tail pointer update logic for load queue
	flush_sq_found_original =0;
	flush_sq_found_after_head = 0;
	if(error_detect)begin
		//$display("head_pointer_lq_next:%d,lq 0 age:%d,load_queue_alias_index:%d",head_pointer_lq_next,load_queue_next[0].age,load_queue_alias_index);
		for(int i = 0;i<`LQ_SIZE;i=i+1)begin
			if(`LEFT_YOUNGER_OR_EQUAL(head_pointer_lq_next,load_queue_next[i].age,load_queue_alias_index))begin
				load_queue_next[i] = 0;
			end
		end
		for(int i = 0; i<`SQ_SIZE;i=i+1)begin
			if(`LEFT_YOUNGER_OR_EQUAL(head_pointer_lq_next,store_queue_next[i].load_tail,load_queue_alias_index) && (store_queue_next[i].load_tail != load_queue_alias_index))begin
				store_queue_next[i] = 0;
				if(~flush_sq_found_original) begin
					tail_pointer_sq_next = i;
					flush_sq_found_original = 1;
				end
				if(~flush_sq_found_after_head && (store_queue_next[i].age >= head_pointer_sq_unretired_next )) begin
					tail_pointer_sq_next = i;
					flush_sq_found_after_head = 1;
				end
			end
		end
		tail_pointer_lq_next = load_queue_alias_index;
	end


	flush_ld_found_original_bmp = `FALSE;
	flush_ld_found_after_head_bmp = `FALSE;
	flush_st_found_original_bmp = `FALSE;
	flush_st_found_after_head_bmp = `FALSE;
	macro_debug = `LEFT_STRICTLY_YOUNGER(execute_flushed_info.head_rob_id, load_queue_next[0].rob_id, execute_flushed_info.mispeculated_rob_id);
	if(execute_flush_detection) begin
		for(int i = 0; i < `LQ_SIZE; i=i+1)begin
           if (execute_flushed_info.is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(execute_flushed_info.head_rob_id, load_queue_next[i].rob_id, execute_flushed_info.mispeculated_rob_id) &&
		    load_queue_next[i].valid && ~load_queue_next[i].retire_bit) begin 
			
				load_queue_next[i] = 0;
				if (~flush_ld_found_original_bmp) begin
					tail_pointer_lq_next = i;
					flush_ld_found_original_bmp = `TRUE;
				end
				if (~flush_ld_found_after_head_bmp && (i >= head_pointer_lq_next)) begin
					tail_pointer_lq_next = i;
					flush_ld_found_after_head_bmp = `TRUE;
				end
			end
		end

		for(int i = 0; i < `SQ_SIZE; i=i+1)begin
           if (execute_flushed_info.is_branch_mispredict && `LEFT_STRICTLY_YOUNGER(execute_flushed_info.head_rob_id, store_queue_next[i].rob_id, execute_flushed_info.mispeculated_rob_id) &&
		    store_queue_next[i].valid && ~store_queue_next[i].retire_bit) begin 
			
				store_queue_next[i] = 0;
				if (~flush_st_found_original_bmp) begin
					tail_pointer_sq_next = i;
					flush_st_found_original_bmp = `TRUE;
				end
				if (~flush_st_found_after_head_bmp && (i >= head_pointer_sq_next)) begin
					tail_pointer_sq_next = i;
					flush_st_found_after_head_bmp = `TRUE;
				end
			end
		end
	end
end


//To calculate num of load rows
always_comb begin 
	if (head_pointer_lq_unretired_next == tail_pointer_lq_next) begin
		if ((~load_queue_next[head_pointer_lq_unretired_next].retire_bit) && load_queue_next[head_pointer_lq_unretired_next].valid) begin
			num_rows_load_queue_free = 0;
		end else begin 
			num_rows_load_queue_free = `LQ_SIZE;
		end
	end else if (head_pointer_lq_unretired_next > tail_pointer_lq_next) begin 
		num_rows_load_queue_free = head_pointer_lq_unretired_next - tail_pointer_lq_next;
	end else begin 
		num_rows_load_queue_free = `LQ_SIZE - (tail_pointer_lq_next - head_pointer_lq_unretired_next);
	end
end

//To calculate num of store rows
always_comb begin
	if (head_pointer_sq_unretired_next == tail_pointer_sq_next) begin
		if (!store_queue_next[head_pointer_sq_unretired_next].retire_bit && store_queue_next[head_pointer_sq_unretired_next].valid) begin
			num_rows_store_queue_free = 0;
		end else begin 
			num_rows_store_queue_free = `SQ_SIZE;
		end
	end else if (head_pointer_sq_unretired_next > tail_pointer_sq_next) begin 
		num_rows_store_queue_free = head_pointer_sq_unretired_next - tail_pointer_sq_next;
	end else begin 
		num_rows_store_queue_free = `SQ_SIZE - (tail_pointer_sq_next - head_pointer_sq_unretired_next);
	end
end


//Assigning debug outputs
`ifdef DEBUG_OUT_LSQ
	assign head_pointer_lq_debug = head_pointer_lq;
	assign head_pointer_sq_debug = head_pointer_sq;
	assign tail_pointer_lq_debug = tail_pointer_lq;
	assign tail_pointer_sq_debug = tail_pointer_sq;
	assign sq_count_debug = sq_count;
	assign lq_count_debug = lq_count;
	assign store_queue_debug = store_queue;
	assign load_queue_debug = load_queue;
	assign load_queue_alias_index_debug = load_queue_alias_index;
`endif


always_ff @(posedge clock) begin
	if (reset) begin 
        head_pointer_lq <= 0;
		head_pointer_lq_unretired <= 0;
        head_pointer_sq <= 0;
		head_pointer_sq_unretired <= 0;
        tail_pointer_lq <= 0;
        tail_pointer_sq <= 0;
        load_queue 		<= 0;
        store_queue 	<= 0;
    end else if (branch_mispredict) begin 
        head_pointer_lq <= 0;
		head_pointer_lq_unretired <= 0;
        head_pointer_sq <= 0;
		head_pointer_sq_unretired <= 0;
        tail_pointer_lq <= 0;
        tail_pointer_sq <= 0;
        load_queue 		<= 0;
        store_queue 	<= 0;
    end else begin
		head_pointer_lq <= head_pointer_lq_next;
		tail_pointer_lq <= tail_pointer_lq_next;
		head_pointer_sq <= head_pointer_sq_next;
		tail_pointer_sq <= tail_pointer_sq_next;
		load_queue		<= load_queue_next;
		store_queue		<= store_queue_next;
		head_pointer_lq_unretired <= head_pointer_lq_unretired_next;
		head_pointer_sq_unretired <= head_pointer_sq_unretired_next;
	end
end



endmodule // LSQ



`endif
