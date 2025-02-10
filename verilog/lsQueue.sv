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
// `define NUM_ROBS    32

// `define LQ_SIZE     8
// `define LQ_N_SIZE   `LQ_SIZE+`N
// `define LQ_BITS     $clog2(`LQ_SIZE)
// 
// `define SQ_SIZE     8
// `define SQ_N_SIZE   `SQ_SIZE+`N
// `define SQ_BITS     $clog2(`SQ_SIZE)
// 
// `define CMD_SIZE    (`LQ_SIZE+`SQ_SIZE)
// `define CMD_BITS    $clog2(`CMD_SIZE)


module retire_search(
    input RETIRE_ROW [`N-1:0]       retire_in,
    input LQ_ROW    [`LQ_BITS-1:0]  load_queue,
    input SQ_ROW    [`SQ_BITS-1:0]  store_queue,

    output logic [`LQ_SIZE-1:0] load_retire,
    output logic [`SQ_SIZE-1:0] store_retire
);
    // sub module retire_search
    // input retire_in: retire request from rob
    // input load_queue: internal load queue registers
    // input store_queue: internal store queue registers
    //
    // output load_retire: a 1 bit array with load queue retire marked
    //  for generating load_queue_next
    // output store_retire: a 1 bit array with store queue retire marked
    //  for generating store_queue_next

    always_comb begin
        // this comb block loop though load queue and store queue,
        // mark retire TRUE when the slot is valid, and matches the 
        // rob_id among the retire request list
        for(int i=0; i<`LQ_SIZE; i+=1) begin
            load_retire[i] = 1'b0;
            for(int j=0; j<`N; j+=1) begin
                if( retire_in[j].retire &&
                    load_queue[i].valid && 
                    load_queue[i].rob_id==retire_in[j].rob_id) begin
                    load_retire[i] = 1'b1;
                end
            end
        end
        for(int i=0; i<`SQ_SIZE; i+=1) begin
            store_retire[i] = 1'b0;
            for(int j=0; j<`N; j+=1) begin
                if( retire_in[j].retire &&
                    store_queue[i].valid && 
                    store_queue[i].rob_id==retire_in[j].rob_id) begin
                    store_retire[i] = 1'b1;
                end
            end
        end
    end

endmodule


module queue_reorder(
    input LSQ_ROW   [`N-1:0]        load_store_in,
    input SQ_ROW    [`SQ_SIZE-1:0]  store_queue,

    output LQ_ROW   [`N-1:0]        load_queue_in,
    output SQ_ROW   [`N-1:0]        store_queue_in
);
    // sub module
    // input LSQ_ROW: the load/store request array
    // input store_queue: internal store queue register
    //  for value forwarding to load request
    //
    // output load_queue_in: filting the load requests among 
    //  load_store_in
    // output store_queue_in: filting the store requests among
    //  load_store_in

    logic    [$clog2(`N):0]  num_load;
    logic    [$clog2(`N):0]  num_store;

    always_comb begin
        // calc # of load/store ready to get into the queue
        // this will loop through load/store queue and count 
        // the number of which will be pushed into load/store
        // queue
        // +    for in the internal for-loop of upcoming load
        //      rows, we campare the address with the store_queue
        //      and input load_store_queue to match and bypass \
        //      the data from oldest store which still younger 
        //      than the load.
        num_load = 'b0;
        num_store = 'b0;
        load_queue_in = 'b0;
        store_queue_in = 'b0;
        for(int i=0; i<`N; i+=1) begin
            case(load_store_in[i].mem_cmd)
                BUS_LOAD: begin
                    load_queue_in[num_load].mem_addr = 
                        load_store_in[i].mem_addr;

                    load_queue_in[num_load].tag_dest = 
                        load_store_in[i].tag_dest;

                    load_queue_in[num_load].rob_id = 
                        load_store_in[i].rob_id;

                    load_queue_in[num_load].valid = 1'b1;

                    for(int j=i; j>=0; j-=1) begin
                        if( store_queue_in[j].mem_cmd==BUS_STORE && 
                            store_queue_in[j].mem_addr==load_queue_in[num_load].mem_addr) begin
                            load_queue_in[num_load].complete = 1'b1;
                            load_queue_in[num_load].mem_data = store_queue_in[j].mem_data;
                            break;
                        end
                    end
                    if(~load_queue_in[num_load].complete) begin
                        for(int j=`SQ_SIZE-1; j>=0; j-=1) begin 
                            if( store_queue[j].valid && 
                                store_queue[j].mem_addr==load_queue_in[num_load].mem_addr) begin
                                load_queue_in[num_load].complete = 1'b1;
                                load_queue_in[num_load].mem_data = store_queue[j].mem_data;
                                break;
                            end
                        end
                    end

                    num_load = num_load+1'b1;
                end
                BUS_STORE: begin
                    store_queue_in[num_store].mem_addr = 
                        load_store_in[i].mem_addr;

                    store_queue_in[num_store].mem_data = 
                        load_store_in[i].mem_data;

                    store_queue_in[num_store].rob_id = 
                        load_store_in[i].rob_id;

                    store_queue_in[num_store].valid = 1'b1;

                    // store_queue_in[num_store].complete = 1'b0;

                    num_store = num_store+1'b1;
                end
                default: ;
            endcase
        end
    end

endmodule


module ldstQueue(
    input clock,
    input reset,

    // special input through pipeline
    // for age, process control, etc
    input squash,
    input [`NUM_PHYS_BITS-1:0]  head_rob_id,

    // input of issued requests
    input LSQ_ROW   [`N-1:0]    load_store_in,
    input RETIRE_ROW[`N-1:0]    retire_in,

    // receive the input from memory
	input [3:0]  mem2proc_response,
	input [63:0] mem2proc_data,
	input [3:0]  mem2proc_tag,

    // output l/s request to memory
	output logic [`XLEN-1:0]    proc2mem_addr,
	output logic [63:0]         proc2mem_data,
    `ifndef CACHE_MODE
	output MEM_SIZE             proc2mem_size,
    `endif
	output logic [1:0]          proc2mem_command,

    // output for dispatch to issue new l/s instr
    output logic [`LQ_BITS:0] num_load_queue_free,
    output logic [`SQ_BITS:0] num_store_queue_free,

    // output for dispatch to squash itself and recover
    // rob, rs, etc
    output logic                        error_detect,
    output logic [`NUM_ROBS_BITS-1:0]   error_rob_id,

    // output for complete stage
    // it will only select at most N complete load/store 
    // in ordered
    output LQ_ROW [`N-1:0] load_complete,
    output SQ_ROW [`N-1:0] store_complete
);

    CMD_ROW [`CMD_SIZE-1:0] mem_cmd_queue;
    CMD_ROW [`CMD_SIZE-1:0] mem_cmd_queue_next;

    LQ_ROW [`N-1:0]         load_in;
    LQ_ROW [`LQ_SIZE-1:0]   load_queue;
    LQ_ROW [`LQ_SIZE-1:0]   load_queue_next;
    logic [`LQ_SIZE-1:0]    load_retire;
    logic [`LQ_BITS:0]      num_load_queue_used;
    logic [`LQ_BITS:0]      num_load_queue_used_next;

    SQ_ROW [`N-1:0]         store_in;
    SQ_ROW [`SQ_SIZE-1:0]   store_queue;
    SQ_ROW [`SQ_SIZE-1:0]   store_queue_next;
    logic [`SQ_SIZE-1:0]    store_retire;
    logic [`SQ_BITS:0]      num_store_queue_used;
    logic [`SQ_BITS:0]      num_store_queue_used_next;


    retire_search rets0(
        .retire_in(retire_in),
        .load_queue(load_queue),
        .store_queue(store_queue),

        .load_retire(load_retire),
        .store_retire(store_retire)
    );

    queue_reorder quer0(
        .load_store_in(load_store_in),
        .store_queue(store_queue),

        .load_queue_in(load_in),
        .store_queue_in(store_in)
    );


    always_comb begin
        // this comb block will count the used units 
        //  in load/store queue, and will generate the 
        //  number of free slots for issue logic
        // also, it will generate the logic of load/store queue
        //  for next cycle
        //      LOAD:
        //          1. copy from (old) load queue, while skipping 
        //              everything which is requeired to retired
        //          2. copy from load queue input
        //          !. if any one of them is complete, loop through
        //              the store input to see if it is actually 
        //              earlier, if yes, an error is detected and
        //              lsq need to be squashed.
        //      STORE:
        //          1. copy from (old) store queue, while skipping
        //              everything is called retired
        //          2. copy from store queue input
        int i=0;
        int j=0;
        num_load_queue_used_next = 'b0;
        num_store_queue_used_next = 'b0;
        load_queue_next = 'b0;
        store_queue_next = 'b0;
        for(i=0; i<`LQ_SIZE; i+=1) begin
            if( load_queue[i].valid && ~load_retire[i]) begin
                load_queue_next[num_load_queue_used_next] = 
                    load_queue[i];
                if( mem2proc_tag==BUS_LOAD && 
                    load_queue_next[num_load_queue_used_next].rob_id==mem_cmd_queue[0].rob_id) begin

                    load_queue_next[num_load_queue_used_next].mem_data = 
                        mem2proc_data;

                    load_queue_next[num_load_queue_used_next].complete = 
                        1'b1;
                end
                if(load_queue_next[num_load_queue_used_next].complete) begin
                    logic [$clog2(`N):0] lq_rob, si_rob;
                    for(j=0; j<`N; j+=1) begin
                        lq_rob = (load_queue_next[num_load_queue_used_next].rob_id<head_rob_id)? 
                                load_queue_next[num_load_queue_used_next].rob_id+`NUM_ROBS: 
                                load_queue_next[num_load_queue_used_next].rob_id;
                        si_rob = (store_in[j].rob_id<head_rob_id)? 
                                store_in[j].rob_id+`NUM_ROBS: 
                                store_in[j].rob_id;

                        if( store_in[j].valid && 
                            store_in[j].mem_addr==load_queue_next[num_load_queue_used_next].mem_addr && 
                            si_rob < lq_rob) begin

                            load_queue_next[num_load_queue_used_next].mem_data = 
                                store_in[j].mem_data;

                            load_queue_next[num_load_queue_used_next].error_detect = 
                                load_queue[i].complete;
                        end
                    end
                end
                num_load_queue_used_next = 
                    num_load_queue_used_next+1'b1;
            end
        end
        for(int i=0; i<`SQ_SIZE; i+=1) begin
            if( store_queue[i].valid && ~store_retire[i]) begin
                store_queue_next[num_store_queue_used_next] = 
                    store_queue[i];
                if( mem2proc_tag==BUS_STORE && 
                    store_queue_next[num_store_queue_used_next].rob_id==mem_cmd_queue[0].rob_id) begin

                    store_queue_next[num_store_queue_used_next].complete = 
                        1'b1;
                end
                num_store_queue_used_next = 
                    num_store_queue_used_next+1'b1;
            end
        end
        for(int i=0; i<`N; i+=1) begin
            if( load_in[i].valid) begin
                load_queue_next[num_load_queue_used_next] = 
                    load_in[i];
                num_load_queue_used_next = 
                    num_load_queue_used_next+1'b1;
            end
            if( store_in[i].valid) begin
                store_queue_next[num_store_queue_used_next] = 
                    store_in[i];
                num_store_queue_used_next = 
                    num_store_queue_used_next+1'b1;
            end
        end
    end

    always_comb begin
        // generate memory command queue 
        //  1. copy from old mem command queue
        //  2. pop the first out if memory returns a 
        //      complete (BUS_LOAD/BUS_STORE) tag.
        //  3. add everything in load store queue input
        //      in ordered (if valid).
        int i = 0;
        mem_cmd_queue_next = 'b0;
        if(mem2proc_tag == mem_cmd_queue[0].mem_cmd) begin
            for(i=0; i<`CMD_SIZE-1; i+=1) begin
                mem_cmd_queue_next[i] = mem_cmd_queue[i+1];
                if(mem_cmd_queue[i].mem_cmd==BUS_NONE) begin
                    break;
                end
            end
        end else begin
            for(i=0; i<`CMD_SIZE; i+=1) begin
                mem_cmd_queue_next[i] = mem_cmd_queue[i];
                if(mem_cmd_queue[i].mem_cmd==BUS_NONE) begin
                    break;
                end
            end
        end
        for(int x=0; x<`N; x+=1) begin
            if(load_store_in[x].valid) begin
                mem_cmd_queue_next[i].mem_cmd = 
                    load_store_in[x].mem_cmd;
                mem_cmd_queue_next[i].rob_id = 
                    load_store_in[x].rob_id;
                i = i+1;
            end
        end
    end

    always_comb begin 
        // generate the logic output to memory
        // check the type of the first memory command
        // queue and map the memory address/value 
        // request from the relative queue with rob id 
        // stored in memory command queue.
        int i;
        for(i=0; i<`CMD_SIZE; i+=1) begin
            if( (load_queue[i].valid && 
                    mem_cmd_queue[0].rob_id==load_queue[i].rob_id) || 
                (store_queue[i].valid &&
                    mem_cmd_queue[0].rob_id==store_queue[i].rob_id)) begin
                break;
            end
        end
	    proc2mem_addr = 'b0;
	    proc2mem_data = 'b0;
        `ifndef CACHE_MODE
	    proc2mem_size = 'b0;
        `endif
	    proc2mem_command = BUS_NONE;
        case(mem_cmd_queue[0].mem_cmd)
            BUS_LOAD: begin
	            proc2mem_addr = load_queue[i].mem_addr;
                `ifndef CACHE_MODE
	            proc2mem_size = DOUBLE
                `endif
	            proc2mem_command = BUS_LOAD;
            end
            BUS_STORE: begin
	            proc2mem_addr = store_queue[i].mem_addr;
	            proc2mem_data = store_queue[i].mem_data;
                `ifndef CACHE_MODE
	            proc2mem_size = DOUBLE;
                `endif
	            proc2mem_command = BUS_STORE;
            end
            default: ;
        endcase

    end

    always_comb begin
        // calculate the free sapce for issueing
        num_load_queue_free = `LQ_SIZE - num_load_queue_used;
        num_store_queue_free = `SQ_SIZE - num_store_queue_used;
    end

    always_comb begin
        // detect if there is an error load
        // in load queue register.
        // this gives an 1 cycle delay of rising the error
        // record the rob_id from the oldest error slot
        error_detect = 1'b0;
        error_rob_id = 'b0;
        for(int i=0; i<`LQ_SIZE; i+=1) begin
            if(load_queue[i].error_detect) begin
                error_detect = 1'b1;
                error_rob_id = load_queue[i].rob_id;
                break;
            end
        end
    end

    always_comb begin
        // generate N way load/store queue for complete
        // stage. also support the number of valid
        // results.
        int l=0;
        int s=0;
        load_complete = 'b0;
        store_complete = 'b0;
        for(int i=0; i<`LQ_SIZE; i+=1) begin
            if(load_queue[i].complete) begin
                load_complete[l] = load_queue[i];
                l = l+1;
            end
        end
        for(int i=0; i<`SQ_SIZE; i+=1) begin
            if(store_queue[i].complete) begin
                store_complete[s] = store_queue[i];
                s = s+1;
            end
        end
    end

    // state ff update
    always_ff @(posedge clock) begin
        // push flipflop stages
        // if squash is TRUE, also clear everything
        // otherwise, just move on
        if (reset) begin
            load_queue              <= 'b0;
            num_load_queue_used     <= 'b0;
            store_queue             <= 'b0;
            num_store_queue_used    <= 'b0;
            mem_cmd_queue           <= 'b0;
        end else if(squash) begin
            load_queue              <= 'b0;
            num_load_queue_used     <= 'b0;
            store_queue             <= 'b0;
            num_store_queue_used    <= 'b0;
            mem_cmd_queue           <= 'b0;
        end else begin
            load_queue              <= load_queue_next;
            num_load_queue_used     <= num_load_queue_used_next;
            store_queue             <= store_queue_next;
            num_store_queue_used    <= num_store_queue_used_next;
            mem_cmd_queue           <= mem_cmd_queue_next;
        end
     end

endmodule

`endif

