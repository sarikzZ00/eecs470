`include "sys_defs.svh"
`include "testbench/mem.sv"
module mem_tb ();

    // input 
	logic               clk;
    logic [`XLEN-1:0]   proc2mem_addr;
	logic [63:0]        proc2mem_data;
    `ifndef CACHE_MODE
	    MEM_SIZE  proc2mem_size;
    `endif
	logic [1:0]         proc2mem_command;
    
    logic [`XLEN-1:0]   proc2mem_addr0;
	logic [63:0]        proc2mem_data0;
    `ifndef CACHE_MODE
	    MEM_SIZE  proc2mem_size0;
    `endif
	logic [1:0]         proc2mem_command0;

    // output 
	logic [3:0]  mem2proc_response;
	logic [63:0] mem2proc_data;
	logic [3:0]  mem2proc_tag;

    task print_mem_output;
    begin
        $display("mem2proc_response %h", mem2proc_response);
        $display("mem2proc_data     %h", mem2proc_data);
        $display("mem2proc_tag      %h", mem2proc_tag);
        $display("");
    end
    endtask

    task clear_in;
    begin
        proc2mem_addr0 = 0;
	    proc2mem_data0 = 0;
	    proc2mem_size0 = 0;
	    proc2mem_command0 = 0;
    end
    endtask

    mem_test mt0(
	    .clk(clk),
	    .proc2mem_addr0(proc2mem_addr0),
	    .proc2mem_data0(proc2mem_data0),
        `ifndef CACHE_MODE
	        .proc2mem_size0(proc2mem_size0),
        `endif
	    .proc2mem_command0(proc2mem_command0),

	    .proc2mem_addr(proc2mem_addr),
	    .proc2mem_data(proc2mem_data),
        `ifndef CACHE_MODE
	        .proc2mem_size(proc2mem_size),
        `endif
	    .proc2mem_command(proc2mem_command)
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
//     mem mem0(
// 	    .clk(clk),
// 	    .proc2mem_addr(proc2mem_addr),
// 	    .proc2mem_data(proc2mem_data),
//         `ifndef CACHE_MODE
// 	        .proc2mem_size(proc2mem_size),
//         `endif
// 	    .proc2mem_command(proc2mem_command),
// 
// 	    .mem2proc_response(mem2proc_response),
// 	    .mem2proc_data(mem2proc_data),
// 	    .mem2proc_tag(mem2proc_tag)
//     );
// 
    always begin
        #7 clk = ~clk;
    end

    initial begin
	    clk = 0;
        clear_in();

        @(posedge clk); `SD;

        // write to addr addrA
        begin
        int addrA = 32'h0000_0000;

        proc2mem_addr0 = addrA;
        proc2mem_size0 = DOUBLE;
        proc2mem_command0 = BUS_LOAD;
		addrA = addrA + 4;

        @(posedge clk); `SD;
        clear_in();

        repeat(7) begin
            print_mem_output();
            @(posedge clk); `SD;
        end

        proc2mem_addr0 = addrA;
        proc2mem_size0 = DOUBLE;
        proc2mem_command0 = BUS_STORE;
		addrA = addrA + 4;

        @(posedge clk); `SD;
        clear_in();

        repeat(7) begin
            print_mem_output();
            @(posedge clk); `SD;
        end

        $display("read from mem");
        proc2mem_addr0 = addrA;
        proc2mem_size0 = DOUBLE;
        proc2mem_command0 = BUS_STORE;
		addrA = addrA + 4;

        @(posedge clk); `SD;
        clear_in();

        repeat(7) begin
            print_mem_output();
            @(posedge clk); `SD;
        end


        end

        repeat (10) @(posedge clk);

        $finish;

    end


endmodule


