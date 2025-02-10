`ifndef __ICACHE_SV__
`define __ICACHE_SV__

`include "sys_defs.svh"

// internal macros, no other file should need these
`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

module icache (
	input 						clock,
	input 						reset,
	input MEMORY_RESPONSE		mem2proc_packet, // from memory
	input IF_INST_REQ [`N-1:0]	fetch_req, // from instruction fetch stage
	input TAG_LOCATION			mem_service_broadcast, // from instruction fetch stage

	// to fetch stage
	output MEMORY_REQUEST 		icache_req,	// to memory
	output CACHE_INST [`N-1:0] 	icache_rows_out // value is (valid) ? memory[icache[k].addr] : junk
    `ifdef DEBUG_OUT_ICACHE
	, output ICACHE_PACKET [`CACHE_LINES-1:0] icache_debug,
	output logic [3:0] current_mem_tag_debug,
	output ICACHE_REQ inst_req_debug,
	output logic got_mem_response_debug,
	output logic capture_mem_tag_debug,
	output logic found_request_debug,
	output logic miss_outstanding_debug, // whether a miss has received its response tag to wait on
	output logic changed_addr_debug,
	output logic update_mem_tag_debug,
	output logic unanswered_miss_debug,
	output ICACHE_REQ inst_req_last_debug
`endif
);

    MEMORY_REQUEST 		icache_req_next;

    ICACHE_PACKET [`CACHE_LINES-1:0] icache;
	ICACHE_PACKET [`CACHE_LINES-1:0] icache_next;

    
    ICACHE_REQ [`N-1:0] current_requests;
    ICACHE_REQ [`N-1:0] requests_next;

    // assign icache_req.addr = {current_request.tag, current_request.index, 3'b0};
    // assign icache_req.valid = current_request.valid;
    // assign icache_req.command = current_request.command;
    // assign icache_req.data = 64'haaaa_aaaa_abcd_dcba;

    logic sent_request_this_cycle;
    logic already_requested;
    logic cache_hit;
    logic [12-`CACHE_LINE_BITS:0] request_tag;  
    logic [`CACHE_LINE_BITS-1:0] request_index;

    logic [`CACHE_LINE_BITS-1:0] fulfilled_index;

    logic mshr_is_full;
    logic [$clog2(`N):0] mshr_free_index;

    always_comb begin
        mshr_is_full = `TRUE;
        mshr_free_index = 0;

        for (int k = 0; k < `N; k = k+1) begin
            if (current_requests[k].valid == `FALSE) begin
                mshr_is_full = `FALSE;
                mshr_free_index = k;
                break;
            end
        end
    end

    // check if the MSHR is full and find free index;



    always_comb begin
        //$display("mshr_free_index: %h", mshr_free_index);
        fulfilled_index = 0;
        icache_next = icache;

        requests_next = current_requests;
        sent_request_this_cycle = 0;

        icache_req_next = 0;

        for (int table_index = 0; table_index < `N; table_index = table_index + 1) begin
            if (current_requests[table_index].valid) begin
                if (current_requests[table_index].command == BUS_LOAD && 
                (mem_service_broadcast ==  Icache) && 
                (mem2proc_packet.response != 0)) begin

                    requests_next[table_index].command = BUS_NONE;
                    requests_next[table_index].mem_tag = mem2proc_packet.response;
                end else if ((current_requests[table_index].command == BUS_NONE) && 
                    (current_requests[table_index].mem_tag == mem2proc_packet.tag)) begin
                    fulfilled_index = table_index;
                    icache_next[current_requests[table_index].index].data = mem2proc_packet.data;
                    icache_next[current_requests[table_index].index].tag = current_requests[table_index].tag;
                    icache_next[current_requests[table_index].index].valid = `TRUE;
                    requests_next[table_index].mem_tag = 0;
                    requests_next[table_index].valid = `FALSE;

                end else if ((current_requests[table_index].command == BUS_LOAD) && 
                ((mem_service_broadcast !=  Icache) || mem2proc_packet.response == 0)) begin
                    
                        sent_request_this_cycle = `TRUE;
                        icache_req_next.addr = {current_requests[table_index].tag, current_requests[table_index].index, 3'b0};
                        icache_req_next.valid = `TRUE;
                        icache_req_next.data = 'hdead_beef;
                        icache_req_next.command = BUS_LOAD;
                 end
            end
        end

        
        for (int i = 0; i < `N; i = i + 1) begin
            cache_hit = 0;
            if (fetch_req[i].valid) begin
                {request_tag, request_index} = fetch_req[i].addr[15:3];

                cache_hit = (icache_next[request_index].valid && (request_tag == icache_next[request_index].tag));

                icache_rows_out[i].addr = fetch_req[i].addr;
                icache_rows_out[i].valid = cache_hit;

                for (int j = 0; j < 2; j = j + 1) begin
                    if (j == fetch_req[i].addr[2]) begin
                        icache_rows_out[i].inst = icache_next[request_index].data >> (32 * j);
                        break;
                    end
                end

                already_requested = `FALSE;
                if (~cache_hit && ~sent_request_this_cycle && ~mshr_is_full) begin
                    for (int k = 0; k < `N; k = k + 1) begin
                        if (current_requests[k].valid && current_requests[k].addr == fetch_req[i].addr) begin
                            already_requested = `TRUE;
                            break;
                        end
                    end

                    sent_request_this_cycle = `TRUE;
                    requests_next[mshr_free_index].valid = `TRUE;
                    requests_next[mshr_free_index].index = request_index;
                    requests_next[mshr_free_index].tag = request_tag;
                    requests_next[mshr_free_index].command = BUS_LOAD;
                    requests_next[mshr_free_index].addr = fetch_req[i].addr;
                    requests_next[mshr_free_index].mem_tag = 0;

                    icache_req_next.addr = {request_tag, request_index, 3'b0};
                    icache_req_next.valid = `TRUE;
                    icache_req_next.data = 'hdead_beef;
                    icache_req_next.command = BUS_LOAD;
                end
            end
        end
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            icache <= `SD 0;
            current_requests <= `SD 0;
            icache_req <= `SD 0;
        end else begin
            icache <= `SD icache_next;
            current_requests <= `SD requests_next;
            icache_req <= `SD icache_req_next;
        end
    end
endmodule
`endif
