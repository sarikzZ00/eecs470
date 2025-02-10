/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  mem_arbiter.sv                                      //
//                                                                     //
//  Description :  module of the memory arbiter which manages		   // 
//				   contention between the Icache, Dcache, and    	   // 
//				   prefetcher due to limited memory bandwidth.		   // 
//                 PURELY COMBINATIONAL                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

/*
	Upon Dcache and Icache making concurrent requests. 

	(1) Arbiter will choose which request to service. 
	(2) Arbiter will message the cache that X request was serviced with mem_addr Y
	(3) Cache will store tag of request 
*/

`ifndef __ARBITER_SV__
`define __ARBITER_SV__

module arbiter(
	input 					clock,
	input 					reset,
	input MEMORY_REQUEST 	icache_req, // Icache -> arbiter 
	input MEMORY_REQUEST 	dcache_req, // Dcache -> arbiter 
//	input MEMORY_REQUEST 	pfetch_req, // Pfetch -> arbiter 
	
    // arbiter -> processor
	output MEMORY_REQUEST	arbiter_req,

	// informs the caches which memory_request was chosen by the arbiter
	// so that they know which tags to associate with their requests
    output TAG_LOCATION 	mem_service_broadcast

);


	TAG_LOCATION 	current_service;



	/*
	Current algorithm is
		if (D-cache operation)
			do D-cache load;
		else
			do I-cache operation;
	*/

	TAG_LOCATION [`NUM_MEM_TAGS-1:0] map_tags_to_cache;


	always_comb begin
		if (dcache_req.command inside {BUS_STORE, BUS_LOAD} && dcache_req.valid == `TRUE) begin // load an instruction from memory
			current_service 	= Dcache;
			arbiter_req.command = dcache_req.command;
			arbiter_req.addr    = dcache_req.addr;
			arbiter_req.data    = dcache_req.data;
		end else if (icache_req.command inside {BUS_LOAD}) begin // do a data operation with memory
			current_service 	= Icache;
			arbiter_req.command = icache_req.command;
			arbiter_req.addr    = icache_req.addr;
			arbiter_req.data    = 0;
		end else begin
			current_service 	= TAGNone;
			arbiter_req.command = BUS_NONE;
			arbiter_req.addr    = 0;
			arbiter_req.data    = 0;
		end
	end

assign mem_service_broadcast = current_service;

	

	// clock in proc2mem_command
	// send back response on the next cycle
	// always_ff @(posedge clock) begin
	// 	if (reset) begin
	// 		mem_service_broadcast <= 0;
	// 	end else begin
	// 		mem_service_broadcast <= current_service;
	// 	end
	// end


// endmodule // arbiter

// end


endmodule // arbiter

`endif
