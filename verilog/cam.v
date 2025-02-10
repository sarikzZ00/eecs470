
`include "sys_defs.vh"

// LAB6 TODO: functionality check list
// [x] update elements on positive clock edge
// [x] if enable and command is WRITE, store data to write_idx
// [x] validate that write_idx is not too large
// [x] if enable and command is READ, set read_idx to first idx of matching data
// [x] set hit to high if found, or low if not
// [x] pass the testbench
// [x] pass testbench in synthesis (don't worry about clock period)
// note: must work for all sizes, including non powers of two

module CAM #(parameter SIZE=`CAM_SIZE) (
	input clock, reset,
	input enable,
	input COMMAND command,
	input [31:0]  data,
	input [$clog2(SIZE)-1:0] write_idx,

	output logic [$clog2(SIZE)-1:0] read_idx,
	output logic hit
);


// instantiate a multi-dimensional array of registers
logic [SIZE -1 : 0] [31 : 0] mem;  // CAM memory
logic [SIZE -1 : 0]    valid_mem;  // discerns which memory lines are valid
logic [32 : 0] search_val; // register for requested value
logic          search_hit; // register for hit of requested value


always_comb begin
	search_hit = 'b0;
	search_val = 0;
	for (int i = 0; i < SIZE; i++) begin
		if (valid_mem[i] && mem[i] == data && enable) begin
				search_hit = 'b1;
				search_val = i;
				break;
			end
	end // for i
end // always_comb

// TODO: you might not need to clock the value
// TODO: delete search_val and just have val be in read index. 
// then it will be in the same clock cycle

// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
	if (reset) begin
			valid_mem <= `SD 0;
			hit <= `SD 0;
			read_idx <= `SD 0;
	end else begin // if (reset)
		hit <= `SD search_hit;
		read_idx <= `SD search_val;
		// check enable and valid
		if (enable && 0 <= write_idx && write_idx < SIZE) begin
			if (command == WRITE) begin
				// write and validate data at write_idx
				mem[write_idx] <= `SD data;
				valid_mem[write_idx] <= `SD 1;
			end // if (valid WRITE)
		end
	end // else (reset)
end // always



endmodule



