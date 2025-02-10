/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  testbench.v                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple pipeline;       //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "testbench/mem.sv"

`ifndef CLOCK_PERIOD
`define CLOCK_PERIOD 10
`endif

`define print_time 0

module pipeline_tb;
			
	string program_memory_file;		
	string writeback_output_file;		
	int wb_fileno;

    logic clock; 
    logic reset;
    logic [63:0] tb_mem [`MEM_64BIT_LINES - 1:0];
	logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs;
	logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs;

	int fd_reservation_station;
    int fd_rob;
    int fd_dispatch;
    int fd_execute;
	int fd_cdb;
	int fd_fetch;
	int fd_map_table;
	int fd_writeback_file;
	int fd_dcache;
	int fd_icache;
	int fd_lsq;
	int fd_complete;
    
	EXCEPTION_CODE    pipeline_error_status;
	logic [$clog2(`N + 1):0]			num_rows_retire;
	WB_OUTPUTS [`N-1:0] wb_testbench_outputs;

	logic [`NUM_PHYS_REGS-1:0] [`XLEN-1:0] register_file_out;
	logic [1:0]       proc2mem_command;
	logic [`XLEN-1:0] proc2mem_addr;
	logic [63:0]      proc2mem_data;
	logic [3:0]       mem2proc_response;
	logic [63:0]      mem2proc_data;
	logic [3:0]       mem2proc_tag;
	MEM_SIZE		  proc2mem_size;
	logic [31:0] 	  clock_count;
	logic [31:0] 	  instr_count;

    `ifdef DEBUG_OUT_RS
		RESERVATION_ROW [`NUM_ROWS-1:0] current_reservation_rows;
	`endif
    
    /*
	`ifdef DEBUG_OUT_ROB
		RESERVATION_ROW [`N-1:0] current_reservation_rows;
	`endif
	*/

    `ifdef DEBUG_OUT_DISPATCH 
		ID_EX_PACKET [`N-1:0] id_packet_out_debug;
		MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] map_table_debug;
		MAP_TABLE_ENTRY  [`NUM_REGISTERS - 1 : 0] arch_map_table_debug;
		logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices_debug;
		logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices_debug;
		logic [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs_debug;
		
		logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs_debug;
		logic [$clog2(`NUM_ROWS):0] num_free_rs_rows_debug;
		RS_EX_PACKET [`N-1:0] issued_rows_debug;
		logic [`N-1:0][`NUM_PHYS_BITS-1:0] rda_idx_debug;
		logic [`N-1:0][`NUM_PHYS_BITS-1:0] rdb_idx_debug; 
		logic [`N-1:0][`XLEN-1:0] rda_out_debug;
		logic [`N-1:0][`XLEN-1:0] rdb_out_debug; 
	`endif 

    `ifdef DEBUG_OUT_EX
		EX_CP_PACKET [`N-1:0] ex_packet_out;
		logic [`NUM_FUNC_UNIT_TYPES-1 : 0] [31:0] num_fu_free;
		EX_CP_PACKET [`NUM_ALU-1:0] alu_packets;
		EX_CP_PACKET [`NUM_FP-1:0] fp_packets;
		EX_CP_PACKET [`NUM_LD-1:0] ld_packets;
		EX_LSQ_PACKET [`NUM_LD-1:0] ex_lsq_load_packet;
		EX_LSQ_PACKET [`NUM_ST-1:0] ex_lsq_store_packet;
		EX_LD_REQ [`NUM_LD-1:0] ex_mem_request;
		EX_LD_REQ [`NUM_LD-1:0] load_request;
	`endif

	`ifdef DEBUG_OUT_ROB
		logic [`NUM_ROBS_BITS-1:0] 		tail_pointer_output;
		logic [$clog2(`NUM_ROWS):0]	num_free_rs_rows;
		logic [`NUM_ROBS_BITS:0]		num_free_rob_rows;
		logic							branch_mispredict_next_cycle;
		logic [`XLEN-1:0]				retiring_branch_target;
		logic 							retiring_branch_mispredict_next_cycle;
		ROB_ROW [`NUM_ROBS - 1 : 0]		rob_queue_debug;
	`endif

	`ifdef DEBUG_OUT_FETCH
		logic [`N-1:0] [`XLEN-1:0] pred_PC_debug;
        logic [`N-1:0] [`XLEN-1:0] pred_NPC_debug;
		logic [$clog2(`N+1)-1:0] num_to_fetch_debug;
		IF_ID_PACKET [`N-1:0] if_packet_out;

	`endif

	`ifdef DEBUG_OUT_LSQ
		logic 	[`LQ_BITS-1:0] head_pointer_lq;
		logic 	[`SQ_BITS-1:0] head_pointer_sq;
		logic 	[`LQ_BITS-1:0] tail_pointer_lq;
		logic 	[`SQ_BITS-1:0] tail_pointer_sq;
		logic 	[`SQ_BITS:0] sq_count;
		logic 	[`LQ_BITS:0] lq_count;
		SQ_ROW  [`SQ_SIZE-1:0] store_queue;
		LQ_ROW	[`LQ_SIZE-1:0] load_queue;
		logic	[`LQ_BITS-1:0] load_queue_alias_index;
		CACHE_ROW [`NUM_LD-1:0] forwarding_ld_return;
	`endif

	`ifdef DEBUG_OUT_ICACHE
		ICACHE_PACKET [`CACHE_LINES-1:0] icache_debug;
		logic [3:0] current_mem_tag_debug;
		CACHE_INST [`N-1:0] 	icache_rows_out;
		MEMORY_REQUEST icache_req;
		ICACHE_REQ inst_req_debug;
		logic got_mem_response_debug;
		logic capture_mem_tag_debug;
		logic found_request_debug;
		logic miss_outstanding_debug; // whether a miss has received its response tag to wait on
		logic changed_addr_debug;
		logic update_mem_tag_debug;
		logic unanswered_miss_debug;
		ICACHE_REQ inst_req_last_debug;
		TAG_LOCATION mem_service_broadcast;
	`endif
	
	`ifdef DEBUG_OUT_DCACHE
		CACHE_ROW [`NUM_LD-1:0] dcache_rows_out;
		logic write_success;
		MEMORY_REQUEST dcache_req;
		DCACHE_PACKET [`CACHE_LINES-1:0] dcache_debug;
	`endif

	`ifdef DEBUG_OUT_COMPLETE 
        CDB_ROW [`N-1:0] cdb_table;
        logic [`N-1:0] [`XLEN-1:0] ld_replacement_values; 
        logic [`NUM_ROBS_BITS - 1:0] rob_head_pointer; 
        logic [`NUM_ROBS_BITS - 1:0] squash_younger_than;
    `endif

	pipeline core (
		//Inputs
		.clock(clock),
		.reset(reset),
		.tb_mem(tb_mem),
		.mem2proc_response(mem2proc_response),
		.mem2proc_data(mem2proc_data),
		.mem2proc_tag(mem2proc_tag),
		
		
		//Outputs
		.proc2mem_command(proc2mem_command),
		.proc2mem_addr(proc2mem_addr),
		.proc2mem_data(proc2mem_data),
		.pipeline_error_status(pipeline_error_status),
		.num_rows_retire(num_rows_retire),
		.wb_testbench_outputs(wb_testbench_outputs),
		.retired_phys_regs(retired_phys_regs),
		.retired_arch_regs(retired_arch_regs),
		.register_file_out(register_file_out),
		.forwarding_ld_return(forwarding_ld_return)



        `ifdef DEBUG_OUT_RS
		    ,.current_reservation_rows_debug(current_reservation_rows)
	    `endif
        
        `ifdef DEBUG_OUT_DISPATCH 
		    ,.id_packet_out_debug(id_packet_out_debug), 
		    .map_table_debug(map_table_debug),
		    .arch_map_table_debug(arch_map_table_debug),
		    .dispatched_preg_dest_indices_debug(dispatched_preg_dest_indices_debug),
		    .dispatched_preg_old_dest_indices_debug(dispatched_preg_old_dest_indices_debug),
		    .dispatched_arch_regs_debug(dispatched_arch_regs_debug),
		    .retired_old_phys_regs_debug(retired_old_phys_regs_debug),
			.issued_rows_debug(issued_rows_debug),
		    .num_free_rs_rows_debug(num_free_rs_rows_debug),
			.rda_idx_debug(rda_idx_debug),
			.rdb_idx_debug(rdb_idx_debug),
			.rda_out_debug(rda_out_debug),
			.rdb_out_debug(rdb_out_debug)
	    `endif 

		`ifdef DEBUG_OUT_ROB
			,.tail_pointer_debug(tail_pointer_output),
			.num_free_rob_rows_debug(num_free_rob_rows),
			.branch_mispredict_next_cycle_debug(branch_mispredict_next_cycle),
			.retiring_branch_target_debug(retiring_branch_target),
			.retiring_branch_mispredict_next_cycle_debug(retiring_branch_mispredict_next_cycle),
			.rob_queue_debug(rob_queue_debug)
		`endif

        `ifdef DEBUG_OUT_EX
		    ,.ex_packet_out_debug(ex_packet_out),
		    .num_fu_free_debug(num_fu_free),
			.alu_packets(alu_packets),
			.fp_packets(fp_packets),
			.ld_packets(ld_packets),
			.ex_lsq_load_packet(ex_lsq_load_packet),
			.ex_lsq_store_packet(ex_lsq_store_packet),
			.ex_mem_request(ex_mem_request),
			.load_request(load_request)
	    `endif

		`ifdef DEBUG_OUT_FETCH
			,.pred_PC_debug(pred_PC_debug),
			.pred_NPC_debug(pred_NPC_debug),
			.num_to_fetch_debug(num_to_fetch_debug),
			.if_packet_out(if_packet_out)
	    `endif

		`ifdef DEBUG_OUT_LSQ
			,.head_pointer_lq(head_pointer_lq),
			.head_pointer_sq(head_pointer_sq),
			.tail_pointer_lq(tail_pointer_lq),
			.tail_pointer_sq(tail_pointer_sq),
			.sq_count(sq_count),
			.lq_count(lq_count),
			.store_queue(store_queue),
			.load_queue(load_queue),
			.load_queue_alias_index(load_queue_alias_index)
		`endif

		`ifdef DEBUG_OUT_DCACHE
			,.dcache_rows_out(dcache_rows_out),
			.dcache_debug(dcache_debug),
			.write_success(write_success),
			.dcache_req(dcache_req)
		`endif

	`ifdef DEBUG_OUT_ICACHE
		, .icache_debug(icache_debug),
		.current_mem_tag_debug(current_mem_tag_debug),
		.icache_req(icache_req),
		.icache_rows_out(icache_rows_out),
		.inst_req_debug(inst_req_debug),
		.got_mem_response_debug(got_mem_response_debug),
		.capture_mem_tag_debug(capture_mem_tag_debug),
		.found_request_debug(found_request_debug),
		.miss_outstanding_debug(miss_outstanding_debug), // whether a miss has received its response tag to wait on
		.changed_addr_debug(changed_addr_debug),
		.update_mem_tag_debug(update_mem_tag_debug),
		.unanswered_miss_debug(unanswered_miss_debug),
		.inst_req_last_debug(inst_req_last_debug),
		.mem_service_broadcast(mem_service_broadcast)
	`endif


		`ifdef DEBUG_OUT_COMPLETE 
        	,.cdb_table_debug(cdb_table),
        	.ld_replacement_values_debug(ld_replacement_values), 
        	.rob_head_pointer_debug(rob_head_pointer), 
        	.squash_younger_than_debug(squash_younger_than)
    	`endif
	);
    
	mem memory (
		// Inputs
		.clk              (clock),
		.proc2mem_command (proc2mem_command),
		.proc2mem_addr    (proc2mem_addr),
		.proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
		.proc2mem_size    (proc2mem_size),
`endif

		// Outputs
		.mem2proc_response (mem2proc_response),
		.mem2proc_data     (mem2proc_data),
		.mem2proc_tag      (mem2proc_tag)
	);
   
   initial begin
		// set paramterized strings, see comment at start of module
		if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
			$display("Loading memory file: %s", program_memory_file);
		end else begin
			$display("Loading default memory file: program.mem");
			program_memory_file = "program.mem";
		end
		if ($value$plusargs("WRITEBACK=%s", writeback_output_file)) begin
			$display("Using writeback output file: %s", writeback_output_file);
		end else begin
			$display("Using default writeback output file: writeback.out");
			writeback_output_file = "writeback.out";
		end
		
		clock = 1'b0;
		reset = 1'b0;

		// Pulse the reset signal
		$display("@@\n@@\n@@  %t  Asserting System reset......", $realtime);
		reset = 1'b1;
		@(posedge clock);
		@(posedge clock);

		// store the compiled program's hex data into memory
		$readmemh(program_memory_file, memory.unified_memory);
    $vcdpluson;
    $vcdplusmemon;
		@(posedge clock);
		@(posedge clock);
		`SD;
		// This reset is at an odd time to avoid the pos & neg clock edges

		reset = 1'b0;
		$display("@@  %t  Deasserting System reset......\n@@\n@@", $realtime);

		wb_fileno = $fopen(writeback_output_file);

	end


//#################################
//# HELPER PRINT/FPRINT FUNCTIONS #
//#################################

	//############
	//# Dispatch #
	//############

		//#######################
		//# Reservation Station #
		//#######################
	task fprint_reservation_row;
		input integer fd;
		input RESERVATION_ROW in_row;
		input integer index;

		$fdisplay(fd, "Index: %d, Rob ID: %d, Dest Tag: %d, Tag 1: %d, Tag 2: %d, Tag 1 Ready: %b,\
			Tag 2 Ready: %b, Busy: %b, FU: %d, PC: %h, NPC: %h, inst: %h, alu_func: %b, opa_select: %b,\
			opb_select: %b, cond_branch: %b, uncond_branch: %b, halt: %b, illegal: %b", 
			index,
			in_row.rob_id,
			in_row.tag_dest,
			in_row.tag_1,
			in_row.tag_2, 
			in_row.ready_tag_1,
			in_row.ready_tag_2,
			in_row.busy,
			in_row.functional_unit,
			in_row.PC,
			in_row.NPC,
			in_row.inst,
			in_row.alu_func,
			in_row.opa_select,
			in_row.opb_select,
			in_row.cond_branch,
			in_row.uncond_branch,
			in_row.halt,
			in_row.illegal
		);
	endtask

		//#######
		//# ROB #
		//#######

	task fprint_rob_row;
		input integer fd;
		input ROB_ROW in_row;
		//Rob ID functions as an index already

		$fdisplay(fd, "Rob ID: %d, Arch Reg Dest: %d, Phys Reg Dest: %d, Old Phys Reg Dest: %d,\
					 Complete: %d, Busy: %d, Branch Mispredict: %d, Branch Target: %h, PC: %h, Halt Detected: %d,\
					 Illegal_Inst: %d, Wr_Reg: %d, Wr_mem: %d",
			in_row.rob_id,
			in_row.arch_reg_dest,
			in_row.phys_reg_dest,
			in_row.old_phys_reg_dest,
			in_row.complete,
			in_row.busy,
			in_row.branch_mispredict,
			in_row.branch_target,
			in_row.wb_output.PC,
			in_row.wb_output.halt_detected,
			in_row.wb_output.illegal_inst_detected,
			in_row.wb_output.wr_reg,
			in_row.wb_output.wr_mem
		);
	endtask

		//#######
		//# CDB #
		//#######

	task fprint_cdb_row;
		input integer fd;
		input integer index;
		input CDB_ROW in_row;
		//Rob ID functions as an index already

		$fdisplay(fd, "Index: %d, Phys_Reg: %h, Valid:%h, Branch Mispredict:%h, Rob ID:%h, Result:%h, PC_plus_4:%h, \
					is_uncond_branch:%h, halt:%h, illegal:%h",
			index,
			in_row.phys_regs,
			in_row.valid,
			in_row.branch_mispredict,
			in_row.rob_id,
			in_row.result,
			in_row.PC_plus_4,
			in_row.is_uncond_branch,
			in_row.halt,
			in_row.illegal
		);
	endtask


	//###########
	//# Execute #
	//###########
	task fprint_ex_cp_packet;
        input integer fd;
        input EX_CP_PACKET in_packet;
        input integer index;

        $fdisplay(fd, "Index: %d, result: %h, branch_mispredict: %h, rob_id: %d, dest_reg: %d, valid %b, is_ld: %b, halt: %b, illegal: %b",
            index,
            in_packet.result,
            in_packet.branch_mispredict,
            in_packet.rob_id,
            in_packet.dest_reg,
            in_packet.valid,
			in_packet.is_ld,
            in_packet.halt,
            in_packet.illegal
        );
    endtask


	task fprint_ex_lsq_packet;
        input integer fd;
        input EX_LSQ_PACKET in_packet;
        input integer index;

        $fdisplay(fd, "Index: %d, address: %h, value: %h, rob_id: %d, valid: %b",
            index,
            in_packet.address,
            in_packet.value,
            in_packet.rob_id,
            in_packet.valid
        );
    endtask

	task fprint_ex_ld_req_packet;
		input integer fd;
		input EX_LD_REQ in_packet;
		input integer index;

		$fdisplay(fd, "Index: %d, address: %h, rob_id: %d, mem_size: %d, valid: %b",
			index,
			in_packet.address,
			in_packet.rob_id,
			in_packet.size,
			in_packet.valid
		);
	endtask

	//##########
	// LSQ 
	//##########
	task fprint_lq_row;
		input integer fd;
		input LQ_ROW in_packet;
		input integer index;

		$fdisplay(fd, "Index: %d, PC:%h, mem_addr: %h, mem_data:%h, complete:%h, valid:%b, retire_bit:%h, rob_id: %d, age:%h, store_tail:%h, mem_size:%h",
			index,
			in_packet.PC,
			in_packet.mem_addr,
			in_packet.mem_data,
			in_packet.complete,
			in_packet.valid, 
			in_packet.retire_bit,
			in_packet.rob_id,
			in_packet.age,
			in_packet.store_tail,
			in_packet.mem_size
		);
	endtask

	task fprint_sq_row;
		input integer fd;
		input SQ_ROW in_packet;
		input integer index;

		$fdisplay(fd, "Index: %d, PC: %h, mem_addr: %h, mem_data:%h, complete:%h, valid:%b, retire_bit:%h, rob_id: %d, age:%h, load_tail:%h, mem_size:%h",
			index,
			in_packet.PC,
			in_packet.mem_addr,
			in_packet.mem_data,
			in_packet.complete,
			in_packet.valid, 
			in_packet.retire_bit,
			in_packet.rob_id,
			in_packet.age,
			in_packet.load_tail,
			in_packet.mem_size
		);
	endtask


	//##########
	//# dCache #
	//##########

	task fprint_cache_row;
		input integer fd;
		input CACHE_ROW in_packet;
		input integer index;

		$fdisplay(fd, "Index: %d, line: %h, valid: %b, address: %h, size %h",
			index,
			in_packet.line,
			in_packet.valid,
			in_packet.addr,
			in_packet.size
		);
	endtask

	task fprint_memory_request;
		input integer fd;
		input MEMORY_REQUEST in_packet;
		input integer index;

		$fdisplay(fd, "Index: %d, address: %h, data: %h, command: %h",
			index,
			in_packet.addr,
			in_packet.data,
			in_packet.command
		);
	endtask

//#####################################
//# END HELPER PRINT/FPRINT FUNCTIONS #
//#####################################




	task print_map_table;
		$fdisplay(fd_map_table, "------Map Table at time:%d------", $time);
		$fdisplay(fd_map_table, "\t\tIndex  |  Phys Reg |  Ready");
		for(int i = 0; i < `NUM_REGISTERS; i = i + 1) begin 
            $fdisplay(fd_map_table, "%d\t\t\t%d\t\t\t%d", i, map_table_debug[i].phys_reg, map_table_debug[i].ready);
            
        end
		$fdisplay(fd_map_table, "------Architectural Map Table at time:%d------", $time);
		$fdisplay(fd_map_table, "\t\tIndex  |  Phys Reg |  Ready");
		for(int i = 0; i < `NUM_REGISTERS; i = i + 1) begin 
			$fdisplay(fd_map_table, "%d\t\t\t%d\t\t\t%d", i, arch_map_table_debug[i].phys_reg, arch_map_table_debug[i].ready);
		end
	endtask;



    task print_out_dispatch_outputs;
    begin
		$fdisplay(fd_dispatch, "At Time: %d", $time);
		$fdisplay(fd_dispatch, "num_free_rs_rows: %d", num_free_rs_rows_debug);
		$fdisplay(fd_dispatch, "");
		$fdisplay(fd_dispatch, "Dispatched Registers:");
        for(int j = 0; j < `N; j = j + 1) begin 
            $fdisplay(fd_dispatch, "\tAt Index %d\tDispatched Preg:%d\tOld Dispatched Preg:%d\tDispatched Arch Reg:%d", 
			j
			,dispatched_preg_dest_indices_debug[j]
			,dispatched_preg_old_dest_indices_debug[j]
			,dispatched_arch_regs_debug[j]
			);
        end
		$fdisplay(fd_dispatch, "Retired Registers:");
		for(int j = 0; j < `N; j = j + 1) begin 
            $fdisplay(fd_dispatch, "\tAt Index %d\tRetired Arch Reg:%d\tRetired Phys Reg:%d\tRetired Old Phys Reg:%d", 
			j
			,retired_arch_regs[j]
			,retired_phys_regs[j]
			,retired_old_phys_regs_debug[j]
			);
        end
		$fdisplay(fd_dispatch, "");
		$fdisplay(fd_dispatch, "RDA and RDB");
        for(int j = 0; j < `N; j = j + 1) begin 
            $fdisplay(fd_dispatch, "Row: %d, RDA Index: %d, RDA: %d, RDA Index: %d, RDB: %d",j, rda_idx_debug[j], rda_out_debug[j], rdb_idx_debug[j], rdb_out_debug[j]);
        end


		$fdisplay(fd_dispatch, "");
		$fdisplay(fd_dispatch, "Issued Rows:");
		for(int j = 0; j < `N; j = j + 1) begin
			$fdisplay(fd_dispatch, "row: %d\tvalid: %b\tPC: %d\tNPC: %d\trs1_value: %d\trs2_value: %d\tinst: %d\talu_func: %d\tfunctional_unit: %d\topa_select: %d\topb_select: %d\tcond_branch: %b\tuncond_branch: %b\trob_id: %d\tdest_reg: %d\thalt: %b\tillegal: %b",
				j,
				issued_rows_debug[j].valid,
				issued_rows_debug[j].PC,
				issued_rows_debug[j].NPC,
				issued_rows_debug[j].rs1_value,
				issued_rows_debug[j].rs2_value,
				issued_rows_debug[j].inst,
				issued_rows_debug[j].alu_func,
				issued_rows_debug[j].functional_unit,
				issued_rows_debug[j].opa_select,
				issued_rows_debug[j].opb_select,
				issued_rows_debug[j].cond_branch,
				issued_rows_debug[j].uncond_branch,
				issued_rows_debug[j].rob_id,
				issued_rows_debug[j].dest_reg,
				issued_rows_debug[j].halt,
				issued_rows_debug[j].illegal
			);
		end

		$fdisplay(fd_dispatch, "WB Outputs:");
		for(int j = 0; j < `N; j = j + 1) begin
			$fdisplay(fd_dispatch, "Index: %d\tHalt: %b\tIllegal: %b\tPC: %d\tWr Reg: %d\tWr Mem: %d\t",
				j,
				wb_testbench_outputs[j].halt_detected,
				wb_testbench_outputs[j].illegal_inst_detected,
				wb_testbench_outputs[j].PC,
				wb_testbench_outputs[j].wr_reg,
				wb_testbench_outputs[j].wr_mem
			);
		end

    end
	endtask

	task print_out_rob;
		
		$fdisplay(fd_rob, $time);
		$fdisplay(fd_rob, "tail pointer%d", tail_pointer_output);
		$fdisplay(fd_rob, "num free rob rows: %d", num_free_rob_rows);
		$fdisplay(fd_rob, "");

		$fdisplay(fd_rob, "ROB: ");
		for(int i=0; i<`NUM_ROBS; i+=1) begin
			fprint_rob_row(fd_rob, rob_queue_debug[i]);
		end
		$fdisplay(fd_rob, "");

		$fdisplay(fd_rob, "Retired Arch Regs:");
		for(int i = 0; i<`N; i+=1) begin
			$fdisplay(fd_rob, "Index %d: %d", i, retired_arch_regs[i]);
		end
		$fdisplay(fd_rob, "");

		$fdisplay(fd_rob, "Retired Phys Regs:");
		for(int i=0; i<`N; i+=1) begin
			$fdisplay(fd_rob, "Index %d: %d", i, retired_phys_regs[i]);
		end
		$fdisplay(fd_rob, "");

		$fdisplay(fd_rob, "Retired Old Phys Regs:");
		for(int i=0; i<`N; i+=1) begin
			$fdisplay(fd_rob, "Index %d: %d", i, retired_old_phys_regs_debug[i]);
		end
		$fdisplay(fd_rob, "");

		$fdisplay(fd_rob, "retiring branch mispredict next cycle: %b", retiring_branch_mispredict_next_cycle);
	endtask

	task print_out_RS;
			$fdisplay(fd_reservation_station, "Current reservation rows debug:");
			 for (int rows_debug_index = 0; rows_debug_index < `NUM_ROWS; rows_debug_index = rows_debug_index + 1) begin
              fprint_reservation_row(fd_reservation_station, current_reservation_rows[rows_debug_index], rows_debug_index);
            end
			$fdisplay(fd_reservation_station, "=====================================================================");
	endtask

	//################
	//# Fetch Prints #
	//################


	task print_out_fetch;
		$fdisplay(fd_fetch, "##########");
        $fdisplay(fd_fetch, "Time: %4.0f", $time);
        $fdisplay(fd_fetch, "##########");
        $fdisplay(fd_fetch, "");

		$fdisplay(fd_fetch, "Num_to_fetch: %d", num_to_fetch_debug);
		for (int i = 0; i < `N; i=i+1) begin
			$fdisplay(fd_fetch, "PC: %d\tNPC: %d",pred_PC_debug[i],pred_NPC_debug[i]);
			$fdisplay(fd_fetch, "IF_PACKET_OUT");
			$fdisplay(fd_fetch,"valid: %b, inst: %h, PC: %d\tNPC: %d",
				if_packet_out[i].valid, 
				if_packet_out[i].inst, 
				if_packet_out[i].PC,
				if_packet_out[i].NPC,
			);
		end
	endtask	



	//##################
	//# Execute Prints #
	//##################

	task fprint_ex_stage;
        $fdisplay(fd_execute, "##########");
        $fdisplay(fd_execute, "Time: %4.0f", $time);
        $fdisplay(fd_execute, "##########");
        $fdisplay(fd_execute, "");

        $fdisplay(fd_execute, "ex_packet_out:");
        for (int i = 0; i < `N; i = i + 1) begin
            fprint_ex_cp_packet(fd_execute, ex_packet_out[i], i);
        end
        $fdisplay(fd_execute, "");

        $fdisplay(fd_execute, "LSQ LD requests:");
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
            fprint_ex_ld_req_packet(fd_execute, load_request[i], i);
        end
        $fdisplay(fd_execute, "");

		$fdisplay(fd_execute, "dCache LD requests:");
        for (int i = 0; i < `NUM_LD; i = i + 1) begin
            fprint_ex_ld_req_packet(fd_execute, ex_mem_request[i], i);
        end
        $fdisplay(fd_execute, "");

        $fdisplay(fd_execute, "Completed Stores:");
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            fprint_ex_lsq_packet(fd_execute, ex_lsq_store_packet[i], i);
        end
        $fdisplay(fd_execute, "");

        $fdisplay(fd_execute, "Completed Loads");
        for (int i = 0; i < `NUM_ST; i = i + 1) begin
            fprint_ex_lsq_packet(fd_execute, ex_lsq_load_packet[i], i);
        end
        $fdisplay(fd_execute, "");

        $fdisplay(fd_execute, "Functional Units Free:");
        for (logic [$clog2(`NUM_FUNC_UNIT_TYPES):0] i = 0; i < `NUM_FUNC_UNIT_TYPES; i = i + 1) begin
            //print out all FUs to the same line since it's pretty small.
            $fwrite(fd_execute, "FU %d Free:%d | ", i, num_fu_free[i]);
        end
        $fwrite(fd_execute, "\n"); //End the FU line

        $fdisplay(fd_execute, "");

		`ifdef DEBUG_OUT_EX
			$fdisplay(fd_execute, "alu_packets:");
			for (int i = 0; i < `NUM_ALU; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute, alu_packets[i], i);
			end
			$fdisplay(fd_execute, "");

			$fdisplay(fd_execute, "fp_packets:");
			for (int i = 0; i < `NUM_FP; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute, fp_packets[i], i);
			end
			$fdisplay(fd_execute, "");

			$fdisplay(fd_execute, "ld_packets:");
			for (int i = 0; i < `NUM_LD; i = i + 1) begin
				fprint_ex_cp_packet(fd_execute, ld_packets[i], i);
			end
		`else 
			$fdisplay(fd_execute, "DEBUG_OUT_EX is false.");
		`endif

		$fdisplay(fd_execute, "");
        $fdisplay(fd_execute, "====================================================================================================================");
        $fdisplay(fd_execute, "");

    endtask

	//#################
	//# iCache Prints #
	//#################
	integer icache_index;

	task print_mem_icache_inputs();
	`ifdef DEBUG_OUT_ICACHE
        $fdisplay(fd_icache,"ICACHE_REQ:");
        $fdisplay(fd_icache,"Command: %0s  Addr:  %h Valid: %b", icache_req.command.name(), icache_req.addr, icache_req.valid);
        $fdisplay(fd_icache," ");
        $fdisplay(fd_icache,"INST_REQ:");
        $fdisplay(fd_icache,"tag: %h  index:  %h     valid: %b", inst_req_debug.tag, inst_req_debug.index, inst_req_debug.valid);
        $fdisplay(fd_icache,"INST_REQ_LAST:");
        $fdisplay(fd_icache,"tag: %h  index:  %h     valid: %b", inst_req_last_debug.tag, inst_req_last_debug.index, inst_req_last_debug.valid);
        $fdisplay(fd_icache,"mem_service_broadcast: %0s ", mem_service_broadcast.name());
		$fdisplay(fd_icache,"got_mem_response: %b ", got_mem_response_debug);
		$fdisplay(fd_icache,"capture_mem_tag: %b ", capture_mem_tag_debug);
		$fdisplay(fd_icache,"found_request: %b ", found_request_debug);
		$fdisplay(fd_icache,"miss_outstanding: %b ", miss_outstanding_debug);
		$fdisplay(fd_icache,"changed_addr: %b ", changed_addr_debug);
        $fdisplay(fd_icache,"update_mem_tag: %b", update_mem_tag_debug );
        $fdisplay(fd_icache,"unanswered_miss: %b", unanswered_miss_debug);

        $fdisplay(fd_icache,"MEM_response: %h,   MEM_data: %h,   MEM_tag: %h",
			mem2proc_response,
			mem2proc_data,
			mem2proc_tag
		);
			// FROM MEMORY
//        print_icache_state();
        $fdisplay(fd_icache,"ICACHE_REQ TO ICACHE:");
        $fdisplay(fd_icache,"Command: %0s  addr: %h data: %h valid:  %b", 
					icache_req.command.name(), 
					icache_req.addr, 
					icache_req.data, 
					icache_req.valid
		);
        $fdisplay(fd_icache," ");
        $fdisplay(fd_icache,"INST_REQ TO MEMORY:");
        $fdisplay(fd_icache,"data: %h  addr:  %h     valid: %b", icache_req.data, icache_req.addr, icache_req.valid);
    `endif
    endtask


	task print_icache_outputs();
	`ifdef DEBUG_OUT_ICACHE
		

        $fdisplay(fd_icache,"ICACHE_ROWS_OUT");
        $fdisplay(fd_icache,"         |  INST                     ADDR");
        $fdisplay(fd_icache,"         ------------------------------");
		for (icache_index = 0; icache_index < `NUM_LD; icache_index = icache_index + 1) begin
            if (icache_rows_out[icache_index].valid == `TRUE) begin
                $fdisplay(fd_icache,"\t%h|\t%h|",
                    icache_rows_out[icache_index].inst,
                    icache_rows_out[icache_index].addr
                );
            end
        end
    `endif
    endtask



	task print_icache;
	`ifndef DEBUG_OUT_ICACHE
		$display("Silly! You forgot to define DEBUG_OUT_ICACHE");
	`endif
	`ifdef DEBUG_OUT_ICACHE
		$fdisplay(fd_icache, "##########");
        $fdisplay(fd_icache, "Time: %4.0f", $time);
        $fdisplay(fd_icache, "##########");
        $fdisplay(fd_icache, "");
		$fdisplay(fd_icache,"INST CACHE:");
		$fdisplay(fd_icache,"            |  STATUS            TAG         DATA");
		$fdisplay(fd_icache,"         --------------------------------------");
		for (icache_index = 0; icache_index < 32; icache_index = icache_index + 1) begin
            if (icache_debug[icache_index].valid == `TRUE) begin
                $fdisplay(fd_icache,"%d|\t%h\t|\t%h\t|\t%h\t",
                    icache_index,
                    icache_debug[icache_index].valid,
                    icache_debug[icache_index].tag,
                    icache_debug[icache_index].data
                );
            end
		end
        $fdisplay(fd_icache,"         ");
        print_icache_outputs();
        print_mem_icache_inputs();
   `endif
    endtask




	task fprint_icache;
        $fdisplay(fd_icache, "##########");
        $fdisplay(fd_icache, "Time: %4.0f", $time);
        $fdisplay(fd_icache, "##########");
        $fdisplay(fd_icache, "");

		$fdisplay(fd_icache, "");

		print_icache();

//		fprint_memory_request(fd_icache, icache_req, 1);

		$fdisplay(fd_icache, "");
        $fdisplay(fd_icache, "====================================================================================================================");
        $fdisplay(fd_icache, "");
	endtask



	//#################
	//# dCache Prints #
	//#################
	integer dcache_index;
	task print_dcache;
	`ifndef DEBUG_OUT_DCACHE
		$display("Silly! You forgot to define DEBUG_OUT_DCACHE");
	`endif
	`ifdef DEBUG_OUT_DCACHE

		$fdisplay(fd_dcache,"            |  STATUS   TAG         DATA");
		$fdisplay(fd_dcache,"         --------------------------------------");
		for (dcache_index = 0; dcache_index < 32; dcache_index = dcache_index + 1) begin
			$fdisplay(fd_dcache,"\t%d\t|\t%0s\t|\t%h\t|\t%h\t",
				dcache_index,
				dcache_debug[dcache_index].status.name(),
				dcache_debug[dcache_index].tag,
				dcache_debug[dcache_index].block
			);
		end
	`endif
    endtask


	task fprint_dcache;
        $fdisplay(fd_dcache, "##########");
        $fdisplay(fd_dcache, "Time: %4.0f", $time);
        $fdisplay(fd_dcache, "##########");
        $fdisplay(fd_dcache, "");

		$fdisplay(fd_dcache, "dcache_rows_out:");
		for (int i = 0; i < `NUM_LD; i = i + 1) begin
			fprint_cache_row(fd_dcache, dcache_rows_out[i], i);
		end
		$fdisplay(fd_dcache, "");

		print_dcache();
		print_icache();


		$fdisplay(fd_dcache, "write_success: %b", write_success);
		$fdisplay(fd_dcache, "");
		fprint_memory_request(fd_dcache, dcache_req, 1);

		$fdisplay(fd_dcache, "");
        $fdisplay(fd_dcache, "====================================================================================================================");
        $fdisplay(fd_dcache, "");



	endtask


	//################
	// LSQ Prints
	//################
	task fprint_lsq_debug_outputs;
		
		$fdisplay(fd_lsq, $time);
		$fdisplay(fd_lsq, "head pointer load queue:%h", head_pointer_lq);
		$fdisplay(fd_lsq, "head pointer store queue:%h", head_pointer_sq);
		$fdisplay(fd_lsq, "tail pointer load queue:%h", tail_pointer_lq);
		$fdisplay(fd_lsq, "tail pointer store queue:%h", tail_pointer_sq);
		
		$fdisplay(fd_lsq, "Load Queue");
		for(int i = 0; i < `LQ_SIZE; i = i + 1) begin 
			fprint_lq_row(fd_lsq, load_queue[i], i);
		end
		$fdisplay(fd_lsq,"");
		
		$fdisplay(fd_lsq, "Store Queue");
		for(int j = 0; j < `SQ_SIZE; j = j + 1) begin 
			fprint_sq_row(fd_lsq, store_queue[j], j);
		end
		$fdisplay(fd_lsq,"");

		$fdisplay(fd_lsq, "$ ROWS for forwarding sent to execute");
		for(int j = 0; j < `NUM_LD; j = j + 1) begin 
			fprint_cache_row(fd_lsq, forwarding_ld_return[j], j);
		end


		$fdisplay(fd_lsq, "");
        $fdisplay(fd_lsq, "====================================================================================================================");
        $fdisplay(fd_lsq, "");
	endtask

	//################
	// Complete Prints
	//################
	task fprint_complete_debug_outputs;
		
		$fdisplay(fd_complete, $time);
		$fdisplay(fd_complete, "rob_head_pointer:%h", rob_head_pointer);
		$fdisplay(fd_complete, "squash_younger_than:%h", squash_younger_than);
		$fdisplay(fd_complete, "");
		$fdisplay(fd_complete, "");
		$fdisplay(fd_complete, "CDB Table");
		for(int ii = 0; ii < `N; ii = ii + 1) begin 
			fprint_cdb_row(fd_complete, ii, cdb_table[ii]);
		end
		$fdisplay(fd_complete, "");
		$fdisplay(fd_complete, "");
		$fdisplay(fd_complete, "Load Replacement Values");
		for(int jj = 0; jj < `N; jj = jj + 1) begin 
			$fdisplay(fd_complete, "Load Replacement Value at Index:%d:%h", jj, ld_replacement_values[jj]);
		end

		$fdisplay(fd_complete, "");
        $fdisplay(fd_complete, "====================================================================================================================");
        $fdisplay(fd_complete, "");
	endtask


    always begin
        #10 clock = ~clock;
    end

	task put_back_in_data;
		for(int i=0; i < `CACHE_LINES; i=i+1) begin
			if (dcache_debug[i].status inside {Dirty, Valid}) begin
					//$display("addr: %d, data: %h", {_cache_data[i].Blocks[j].tag, i[`SET_INDEX_BITS-1:0]}*8,   _cache_data[i].Blocks[j].data);
					memory.unified_memory[{dcache_debug[i].tag, i[`CACHE_LINE_BITS-1:0]}] = dcache_debug[i].block;
			end
        end
	endtask
	// Show contents of a range of Unified Memory, in both hex and decimal
	task show_mem_with_decimal;
		input [31:0] start_addr;
		input [31:0] end_addr;
		int showing_data;
		begin
			$display("@@@");
			showing_data=0;
			for(int k=start_addr;k<=end_addr; k=k+1)
				if (memory.unified_memory[k] != 0) begin
					$display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
					                                         memory.unified_memory[k]);
					showing_data=1;
				end else if(showing_data!=0) begin
					$display("@@@");
					showing_data=0;
				end
			$display("@@@");
		end
	endtask // task show_mem_with_decimal

	

	task show_clk_count;
		real cpi;
		begin
			cpi = (clock_count + 1.0) / instr_count;
			$display("@@  %0d cycles / %0d instrs = %f CPI\n@@",
			          clock_count+1, instr_count, cpi);
			$display("@@  %4.2f ns total time to execute\n@@\n",
			          clock_count*`CLOCK_PERIOD);
		end
	endtask

	integer debug_counter;
	integer time_debug;

	always @(posedge clock) begin
		if(reset) begin
			clock_count <= `SD 0;
			instr_count <= `SD 0;
		end else begin
			clock_count <= `SD (clock_count + 1);
			instr_count <= `SD (instr_count + num_rows_retire);
		end
	end
	
    always @(negedge clock) begin
		time_debug <= $time;
		/*
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
		*/
		$fdisplay(fd_reservation_station, "Time:%d", $time);
		$fdisplay(fd_rob, "Time:%d", $time);
		$fdisplay(fd_dispatch, "Time:%d", $time);
		$fdisplay(fd_execute, "Time:%d", $time);
		$fdisplay(fd_fetch, "Time:%d", $time);
		
		if(reset) begin
			$display("@@\n@@  %t : System STILL at reset, can't show anything\n@@",
					$realtime);
			debug_counter <= 0;
		end else begin
			#5; 
			`ifdef DEBUG_OUT_RS
				print_out_RS(); 
			`endif
			`ifdef DEBUG_OUT_DISPATCH
				print_out_dispatch_outputs();
				print_map_table();
			`endif
			`ifdef DEBUG_OUT_ROB
				print_out_rob();
			`endif
			
			`ifdef DEBUG_OUT_FETCH
				print_out_fetch();
			`endif

			fprint_ex_stage();

			`ifdef DEBUG_OUT_DCACHE
				fprint_dcache();
			`endif

			`ifdef DEBUG_OUT_LSQ
				fprint_lsq_debug_outputs();
			`endif

			`ifdef DEBUG_OUT_COMPLETE
				fprint_complete_debug_outputs();
			`endif
			// print the writeback information to writeback output file
			if (`print_time) begin
				if(num_rows_retire > 0) begin
					$fdisplay(fd_writeback_file, "time:%d, num_rows_retire:%d", $time, num_rows_retire);
					$display("time:%d, num_rows_retire:%d", $time, num_rows_retire);
					$fdisplay(wb_fileno,"time:%d, num_rows_retire:%d", $time, num_rows_retire);

				end
			end

			//Timing issue with loadflush2 solved by using registers_next instead of registers.
			for(int i = 0; i < num_rows_retire; i= i + 1) begin
				if(wb_testbench_outputs[i].wr_reg) begin
					$fdisplay(fd_writeback_file, "PC=%x, REG[%d]=%x",
						//this used to be NPC-4 in project 3
						wb_testbench_outputs[i].PC,
						retired_arch_regs[i],
						register_file_out[retired_phys_regs[i]]);
						/*
					$display("PC=%x, REG[%d]=%x",
						//this used to be NPC-4 in project 3
						wb_testbench_outputs[i].PC,
						retired_arch_regs[i],
						register_file_out[retired_phys_regs[i]]);
						*/
					$fdisplay(wb_fileno,"PC=%x, REG[%d]=%x",
						//this used to be NPC-4 in project 3
						wb_testbench_outputs[i].PC,
						retired_arch_regs[i],
						register_file_out[retired_phys_regs[i]]);

				end else begin
				//this used to be NPC-4 in project 3
					$fdisplay(fd_writeback_file, "PC=%x, ---",wb_testbench_outputs[i].PC);
//					$display("PC=%x, ---",wb_testbench_outputs[i].PC);
					$fdisplay(wb_fileno,"PC=%x, ---",wb_testbench_outputs[i].PC);
				end

				if (wb_testbench_outputs[i].halt_detected) begin
					//If we detect a retired halt, stop printing for this cycle
					//	(the pipeline will then stop, so we don't need to worry about the future)
					break;
				end
			end

			
			// deal with any halting conditions
			if(pipeline_error_status != NO_ERROR || debug_counter > 100000) begin
				$display("@@@ Unified Memory contents hex on left, decimal on right: ");
				put_back_in_data();
				show_mem_with_decimal(0,`MEM_64BIT_LINES - 1);
				// 8Bytes per line, 16kB total

				$display("@@  %t : System halted\n@@", $realtime);

				case(pipeline_error_status)
					LOAD_ACCESS_FAULT:
						$display("@@@ System halted on memory error");
					HALTED_ON_WFI:
						$display("@@@ System halted on WFI instruction");
					ILLEGAL_INST:
						$display("@@@ System halted on illegal instruction");
					default:
						$display("@@@ System halted on Timeout or Unknown Error %x",
							pipeline_error_status);
				endcase
				$display("@@@\n@@");
				show_clk_count;
				close_all_files();
				#2 $finish;
			end
			debug_counter <= debug_counter + 1;
		end // if(reset)
    end

	

	task open_all_files;
//		$display("Opening All Files");
		fd_reservation_station = $fopen("./debug_outputs/reservation_output.txt", "w");
        fd_rob = $fopen("./debug_outputs/rob_output.txt", "w");
        fd_dispatch = $fopen("./debug_outputs/dispatch_output.txt", "w");
        fd_execute = $fopen("./debug_outputs/execute_output.txt", "w");
		fd_fetch = $fopen("./debug_outputs/fetch_output.txt", "w"); 
		fd_map_table = $fopen("./debug_outputs/map_table_output.txt", "w");
		fd_writeback_file = $fopen("./debug_outputs/wb.txt", "w");
		fd_dcache = $fopen("./debug_outputs/dcache_output.txt");
		fd_icache = $fopen("./debug_outputs/icache_output.txt");
		fd_lsq = $fopen("./debug_outputs/lsq_output.txt");
		fd_complete = $fopen("./debug_outputs/complete_output.txt");
	endtask

	task close_all_files;
//		$display("Closing All Files");
		$fclose(fd_writeback_file);
		$fclose(fd_reservation_station);
		$fclose(fd_rob);
		$fclose(fd_dispatch);
		$fclose(fd_execute);
		$fclose(fd_map_table);
		$fclose(fd_dcache);
		$fclose(fd_icache);
		$fclose(fd_lsq);
		$fclose(fd_complete);
	endtask;

    initial begin 
		open_all_files();
		clock = 0;
		reset = 1;
		@(posedge clock);
		#5;
		reset = 0;
        
        @(posedge clock);
		#5;
	    
		@(posedge clock);
		#5;
		
        // repeat(2000) @(posedge clock);
        // $finish;
    end
endmodule 
