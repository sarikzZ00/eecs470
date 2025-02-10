`include "sys_defs.vh"

// LAB6 TODO: functionality check list
// [ ] update elements on positive clock edge
// [ ] if enable and command is WRITE, store data to write_idx
// [ ] validate that write_idx is not too large
// [ ] if enable and command is READ, set read_idx to first idx of matching data
// [ ] set hit to high if found, or low if not
// [ ] pass the testbench
// [ ] pass testbench in synthesis (don't worry about clock period)

module CAM #(parameter SIZE=`CAM_SIZE) (
	input clock, reset,
	input enable,
	input COMMAND command,
	input [31:0]  data,
	input [$clog2(SIZE)-1:0] write_idx,

	output logic [$clog2(SIZE)-1:0] read_idx,
	output logic hit
);

	// LAB6 TODO: Fill in design here
	// note: must work for all sizes, including non powers of two

	logic [31:0] cam_mem [SIZE-1:0];
	logic [10:0] i;
	always_ff @(posedge clock) begin
		if (reset) begin
			for (i = 0; i < SIZE; i++) begin
					cam_mem[i] <= 0;
			end
		end else begin
			if(enable && (command == WRITE)) begin
				cam_mem[write_idx] <= data;
				hit <= 0;
				read_idx <= 0;
			end else if (enable && (command == READ)) begin
				hit <= 0;
				for (i = 0; i < SIZE; i++) begin
					if (cam_mem[i] == data) begin 
						hit <= 1;
						read_idx <= i; 
						break;
					end
				end
			end else begin
				read_idx <= 0;
				hit <= 0; 
			end
		end
	end
	
	

endmodule
