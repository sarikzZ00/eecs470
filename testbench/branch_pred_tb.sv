module branch_pred_test();

logic 				clk;
logic 				reset;
CDB_ROW [`N-1:0] 	cdb_table;
logic [`XLEN-1:0] 	PC;
logic [`XLEN-1:0] 	NPC;

logic [`N-1:0]				is_taken;
logic [`N-1:0][`XLEN-1:0]	pred_target;

`ifdef DEBUG_OUT_BANCH_PRED
	logic 			branch_pred_debug_out;
`endif  

task exit_on_error;
	begin
		$display("@@@Failed",$time);
		$display("@@@ Incorrect at time %4.0f", $time);
		$finish;
	end
endtask

task in_check(
	input logic in,
	input logic exp_in
);
	begin
		if(in != exp_in) begin
			$display("val:%b\nexp:%b", in, exp_in);
			exit_on_error();
		end
	end
endtask //automatic


task hard_reset();
	begin
		for(int i=0; i<`N; i+=1) begin
			cdb_table[i].valid = 'b0;
			cdb_table[i].rob_id = 'b0;
			cdb_table[i].phys_reg = 'b0;
			cdb_table[i].branch_mispredict = 'b0;
			cdb_table[i].branch_target = 'b0;
		end
	end
endtask;

branch_pred(
	.clock(clk), 
	.reset(reset), 
	.cdb_table(cdb_table),
	.PC(PC),
	.NPC(NPC),
	.is_taken(is_taken),
	.pred_target(pred_target)

	`ifdef DEBUG_OUT_BANCH_PRED
		,
    	.branch_pred_debug_out(branch_pred_debug_out)
	`endif  
);

assign NPC = PC + 4;

always begin
	#7 clk = ~clk;
end

initial begin
	clk = 1'b0;
	reset = 1'b1;
	PC = 'b0;
	hard_reset();
	@(negedge clk);
	reset = 1'b0;

	for(int i=0; i<20; i+=1) begin
		; // do nothing
	end

	$display("test PASSED");
	$finish;
end

endmodule
