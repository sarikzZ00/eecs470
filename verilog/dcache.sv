//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  dcache.sv                                            //
//                                                                      //
//  Description :  the data cache module that reroutes memory           //
//                 accesses to decrease misses                          //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __DCACHE_SV__
`define __DCACHE_SV__

`include "sys_defs.svh"
`include "verilog/arbiter.sv"

// internal macros, no other file should need these

// INTERNAL STRUCTS for determining what to send to the arbiter

typedef struct packed {
	// NEVER ASSIGN THE addr FIELD
	logic [12-`CACHE_LINE_BITS:0]	tag;
	logic [`CACHE_LINE_BITS-1:0] 	index;
											// = (command == BUS_LOAD) ? {load_tag, index} : {store_tag, index};
	EXAMPLE_CACHE_BLOCK				data;
	logic							valid;
	logic							evict;  // value used should be (evict) ? addr_store : addr_load;
	BUS_COMMAND						command; // what we are sending to memory
	BUS_COMMAND						servicing; // are we trying to satisfy a load or a store
} DCACHE_REQ;


// If a parallel load and store go to the same location, in the same cycle, the load will return the wrong value

// TODO: set status to evicted or invalid on an eviction request 

// We send a request to the arbiter only on the posedge clock
// Checks all N load requests. N cache rows are always sent back, but some may be invalid
module dcache (
	input 							clock,
	input 							reset,
	input MEMORY_RESPONSE			mem2proc_packet, // from memory
	input EX_LD_REQ [`NUM_LD-1:0]	load_req, // from execute stage
	input MEMORY_STORE_REQUEST		store_req, // stores come from ROB via dispatch
	input TAG_LOCATION				mem_service_broadcast, // returns the tag associated to the last request to memory

	output MEMORY_REQUEST 			dcache_req,	// to memory
	// to fetch stage
	output CACHE_ROW [`NUM_LD-1:0] 	dcache_rows_out, // value is (valid) ? memory[proc2Dcache_addr] : junk
	output logic					write_success
	`ifdef DEBUG_OUT_DCACHE
		,
		output DCACHE_PACKET [`CACHE_LINES-1:0] dcache_debug,
		output logic [3:0] current_mem_tag_debug,
		output DCACHE_REQ inst_req_debug,
		output logic got_mem_response_debug,
		output logic capture_mem_tag_debug,
		output logic found_request_debug,
		output logic miss_outstanding_debug, // whether a miss has received its response tag to wait on
		output logic changed_addr_debug,
		output logic update_mem_tag_debug,
		output logic unanswered_miss_debug,
		output DCACHE_REQ inst_req_last_debug
	`endif
);


// (1) NO DCACHE NEXT
// split up comb blocks


// assign dcache request variable based on values in self_load_req and self_store_req

	DCACHE_PACKET [`CACHE_LINES-1:0] dcache;
	DCACHE_PACKET [`CACHE_LINES-1:0] dcache_next;

	// note: cache tags, not memory tags
	logic [`CACHE_LINE_BITS - 1:0] cache_index;
	logic [`CACHE_LINE_BITS - 1:0] found_index_load_latched;
	logic [12-`CACHE_LINE_BITS:0]  	cache_tag, 
									store_load_tag, store_cache_tag, 
									load_cache_tag_latched, found_index_load_tag;

	
	DCACHE_REQ inst_req; // request leaving arbiter
	DCACHE_REQ inst_req_last; // request leaving arbiter

	DCACHE_REQ self_load_req;
	DCACHE_REQ self_store_req;

	logic [`XLEN-1:0] req_addr; 
	logic [3:0] current_mem_tag;
	logic [63:0] mask;



	logic waiting_for_mem_response;
	logic got_mem_data;
	logic capture_mem_tag;
	logic found_request;
	logic miss_outstanding;
	logic changed_addr;
	logic update_mem_tag;
	logic unanswered_miss; 
	logic store_for_mem_success;
	logic evict_load;
	logic evict_store;
	

	integer req_index;
	logic found_request_load, found_request_store;
	logic store_to_mem_success;

	

	`ifdef DEBUG_OUT_DCACHE
		assign dcache_debug = dcache;
		assign inst_req_debug 			= inst_req;
		assign current_mem_tag_debug 	= current_mem_tag;
		assign got_mem_response_debug 	= got_mem_data;
		assign capture_mem_tag_debug 	= capture_mem_tag;
		assign found_request_debug 		= found_request;
		assign miss_outstanding_debug 	= miss_outstanding;; 
		assign changed_addr_debug 		= changed_addr;
		assign update_mem_tag_debug 	= update_mem_tag;
		assign unanswered_miss_debug 	= unanswered_miss;
		assign inst_req_last_debug 		= inst_req_last;
	`endif


	assign capture_mem_tag 	= (mem_service_broadcast ==  Dcache); 
	assign req_addr 		= {inst_req.tag, inst_req.index, 3'b0};
	assign dcache_req 		= {inst_req.valid, req_addr, inst_req.data, inst_req.command};
	assign got_mem_data = (current_mem_tag == mem2proc_packet.tag) && (current_mem_tag != 0);


	assign changed_addr = (inst_req.index != inst_req_last.index) || (inst_req.tag != inst_req_last.tag) || (inst_req.valid != inst_req_last.valid);

	assign update_mem_tag = capture_mem_tag && inst_req.valid && (changed_addr  || miss_outstanding  || got_mem_data || store_to_mem_success);

	assign found_request = found_request_store || found_request_load;

	assign unanswered_miss = changed_addr ? found_request 
	                                      : miss_outstanding && 
										  	((mem2proc_packet.response == 0) ||
											(mem_service_broadcast != Dcache));

	assign store_to_mem_success = (inst_req.valid == `TRUE) && (inst_req.command == BUS_STORE) && (current_mem_tag != 0) && capture_mem_tag; // MIGHT BE (mem2proc_packet.response != 0) ;

	assign waiting_for_mem_response = (miss_outstanding || changed_addr);



	/*

	logic block_load_requests;
	assign block_load_requests = (store_req.valid == `TRUE) && (self_store_req.valid == `TRUE);
	*/

	// TODO: set cache_index before dcache_stat_next init
	always_comb begin
		found_request_load 	= `FALSE;
		found_request_store	= `FALSE;
		write_success 		= `FALSE; // this is fine to have here because we always favor STORES 

		dcache_rows_out 	= 0;
		inst_req.valid		= inst_req_last.valid;
		inst_req.index		= inst_req_last.index;
		inst_req.tag		= inst_req_last.tag;
		dcache_next			= dcache;


		// ORDER OF PRIORITY
		// (1) Current memory operation
		// (2) Pending Stores
		// (2) Pending Loads





		// NOW WE HAVE HANDLED ALL LOAD HITS AND ALL STORE HITS


		if (inst_req_last.valid == `FALSE) begin
			// FIND OUT IF WE NEED ANY NEW MEMORY OPERATIONS TO SATIFY STORE REQUESTS
			if (store_req.valid == `TRUE) begin
				{cache_tag, cache_index} = store_req.addr[15:3];

				if (dcache[cache_index].tag != cache_tag || dcache[cache_index].status == Invalid) begin
					found_request_store = `TRUE;
					evict_store			= (dcache[cache_index].status == Dirty) ? `TRUE : `FALSE;
					
					// STORE
					store_cache_tag = cache_tag;

					self_store_req.index = cache_index;  // this will need to change for an associative cache
				end
			end

			// FIND OUT IF WE NEED ANY NEW MEMORY OPERATIONS TO SATIFY LOAD REQUESTS
			for (req_index = 0; req_index < `NUM_LD; req_index = req_index + 1) begin
				if (load_req[req_index].valid == `TRUE) begin
					{cache_tag, cache_index} = load_req[req_index].address[15:3];
					// The only case we need to evict is when page is dirty and tags do not match
					// if dirty page needs to be evicted |-> send a store request to memory
					if (dcache[cache_index].tag != cache_tag || dcache[cache_index].status == Invalid) begin

						found_request_load 		= `TRUE;
						evict_load				= (dcache[cache_index].status == Dirty) ? `TRUE : `FALSE;
						store_load_tag 			= cache_tag;
						found_index_load_tag    = dcache[cache_index].tag;
						self_load_req.index	 	= cache_index;  // this will need to change for an associative cache
						break;
					end
				end // if load_req[req_index].valid
			end // foreach 



			// NOW SET INST_REQ
			if (found_request_store) begin
				inst_req.valid = `TRUE;
				inst_req.servicing	= BUS_STORE;
				inst_req.index 		= self_store_req.index;
				inst_req.evict		= evict_store;
				inst_req.command 	= (evict_store) ? BUS_STORE : BUS_LOAD; // store_req.addr[13:3]
				inst_req.tag 		= (evict_store) ? dcache[self_store_req.index].tag : store_cache_tag; // store_req.addr[13:3]
				inst_req.data 		= (evict_store) ? dcache[self_store_req.index].block : 'hbeef_face;					 
			end else if (found_request_load) begin
				inst_req.valid = `TRUE;
				inst_req.servicing	= BUS_LOAD;
				inst_req.evict		= evict_load;
				inst_req.index 		= self_load_req.index;
				inst_req.command 	= (evict_load) ? BUS_STORE : BUS_LOAD; // store_req.addr[13:3]
				inst_req.tag 		= (evict_load) ? dcache[self_load_req.index].tag : store_load_tag;
				inst_req.data 		= (evict_load) ? dcache[self_load_req.index].block : 'hbeef_face;					 
			end

		end else begin // INST_REQ.valid == TRUE

			if (store_to_mem_success == `TRUE) begin
				assert(inst_req.evict == `TRUE);
				assert(inst_req.command == BUS_STORE);

				// DO A FSM BASED ON EVICT BIT
				inst_req.valid 	= (inst_req.evict) ? `TRUE : `FALSE;
				inst_req.evict	= `FALSE;

				if (inst_req_last.servicing == BUS_STORE) begin
					inst_req.tag = store_cache_tag;
				end else if (inst_req_last.servicing == BUS_LOAD) begin
					inst_req.tag = store_load_tag; // TODO: it is possible that this changed
				end else begin
					assert(`FALSE == `TRUE);
				end
				inst_req.command = BUS_LOAD;
			end
			
			if (!waiting_for_mem_response && inst_req_last.command == BUS_LOAD) begin
				inst_req.command = BUS_NONE;
			end 

			// UPDATE DCACHE
			if (got_mem_data == `TRUE) begin 
				dcache_next[inst_req.index].block	= mem2proc_packet.data;
				dcache_next[inst_req.index].tag 	= inst_req.tag;
				dcache_next[inst_req.index].status 	= Valid;
				inst_req.valid = `FALSE;
			end 
		end

		// RESPOND TO ALL CACHE HITS
		// get the tags and addresses of the outstanding things that require unified memory oeprations

		// DO STORE CACHE HITS
		if (store_req.valid == `TRUE) begin
			{cache_tag, cache_index} = store_req.addr[15:3];
			if (/* dcache[cache_index].status == Invalid || */
						((dcache[cache_index].status inside {Dirty, Valid}) &&
						dcache[cache_index].tag == cache_tag)) begin // we do not need to evict or send to memory
				// set dirty bit and write
				dcache_next[cache_index].status	= Dirty;
				case (store_req.size) 
					BYTE: begin
						dcache_next[cache_index].block.byte_level[store_req.addr[2:0]] = store_req.data[7:0];
					end
					HALF: begin
						assert(store_req.addr[0] == 0);
						dcache_next[cache_index].block.half_level[store_req.addr[2:1]] = store_req.data[15:0];
					end
					WORD: begin
						assert(store_req.addr[1:0] == 0);
						dcache_next[cache_index].block.word_level[store_req.addr[2]] = store_req.data[31:0];
					end
					default: begin
						assert(store_req.addr[1:0] == 0);
						dcache_next[cache_index].block.word_level[store_req.addr[2]] = store_req.data[31:0];
					end
				endcase
				write_success = `TRUE;
			end 
		end


		// DO LOAD CACHE HITS
		for (req_index = 0; req_index < `NUM_LD; req_index = req_index + 1) begin
			if (load_req[req_index].valid == `TRUE) begin
				{cache_tag, cache_index} = load_req[req_index].address[15:3];

				// LOAD HIT
				if (/* dcache[cache_index].status == Invalid || */
						((dcache_next[cache_index].status inside {Dirty, Valid /*, Evicted */}) &&
						dcache_next[cache_index].tag == cache_tag)) begin

					dcache_rows_out[req_index].addr 	= load_req[req_index].address;
					dcache_rows_out[req_index].size 	= load_req[req_index].size;
					dcache_rows_out[req_index].valid	= `TRUE; // should always be true since we are only handling cache hits here

					case (dcache_rows_out[req_index].size)
						BYTE: 	begin 
							mask = 64'hff;
							for (int i = 0; i < 8; i = i + 1) begin
								if (i == load_req[req_index].address[2:0] ) begin
									dcache_rows_out[req_index].line = (dcache_next[cache_index].block >> (8 * i)) & mask;
									break;
								end
							end
						end 
						HALF: 	begin 
							mask = 64'hffff;
							assert(load_req[req_index].address[0] == 0);
							for (int i = 0; i < 4; i = i + 1) begin
								if (i == load_req[req_index].address[2:1] ) begin
									dcache_rows_out[req_index].line = (dcache_next[cache_index].block >> (16 * i)) & mask;
									break;
								end
							end
						end
						WORD: 	begin 
							mask = 64'hffff_ffff;
							assert(load_req[req_index].address[1:0] == 0);
							for (int i = 0; i < 2; i = i + 1) begin
								if (i == load_req[req_index].address[2] ) begin
									dcache_rows_out[req_index].line = (dcache_next[cache_index].block >> (32 * i)) & mask;
									break;
								end
							end
						end
						DOUBLE: begin 
							assert(load_req[req_index].address[2:0] == 0);
							dcache_rows_out[req_index].line = dcache_next[cache_index].block;
						end
						default: begin 
							assert(load_req[req_index].address[2:0] == 0);
							dcache_rows_out[req_index].line = dcache_next[cache_index].block;
						end
					endcase
				end
			end // if load_req[req_index].valid
		end // foreach 

	end // always_comb 

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			dcache				<= `SD 0; // set all cache data to 0 (including valid bits)
			inst_req_last.index 	<= `SD -1;
			inst_req_last.tag 		<= `SD -1;
			inst_req_last.valid 	<= `SD `FALSE;
			inst_req_last.command 	<= `SD BUS_NONE;
	
			current_mem_tag			<= `SD 0;
			miss_outstanding		<= `SD `FALSE;
			load_cache_tag_latched  <= `SD 0;

		end else begin
			dcache 				<= `SD dcache_next;
			inst_req_last 		<= `SD inst_req;
			load_cache_tag_latched  <= `SD store_load_tag;

			/*self_load_req_last	<= `SD self_load_req;
			self_store_req_last	<= `SD self_store_req;*/

			if (inst_req.valid == `FALSE && (found_request == `FALSE)) begin
				current_mem_tag	<= `SD 0;
			end else if (update_mem_tag) begin
				current_mem_tag <= `SD mem2proc_packet.response;
			end

			miss_outstanding 	<= `SD unanswered_miss;
		end
	end

endmodule // module dcache

`endif

