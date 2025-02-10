/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  branch_pred.sv                                      //
//                                                                     //
//  Description :  Parameterized branch predictor for N-way            // 
//                 prediction of branches.  Stores a BTB struct        //
//                 and any other data structures needed for            //
//                 prediction.                                         //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __BRANCH_PRED_SV__
`define __BRANCH_PRED_SV__

`include "sys_defs.svh"
`include "ISA.svh"


module branch_pred (
	input 								clock,
	input 								reset,

	input [`XLEN-1:0] 					starting_PC,

	input FLUSHED_INFO                  execute_flushed_info,

	`ifdef DEBUG_OUT_BANCH_PRED
		output BTB_ROW [`BTB_SIZE-1:0]  btb_debug_out,
	`endif  

	output logic [`N-1:0] [`XLEN-1:0] 	pred_PC,
	output logic [`N-1:0] [`XLEN-1:0] 	pred_NPC
);

    // always_comb begin
    //     for (int i = 0; i < `N; i = i + 1) begin
    //         pred_PC[i] = starting_PC + 4 * i;
    //         pred_NPC[i] = pred_PC[i] + 4;
    //     end
    // end

    // -----------------------------------------------------------------------
	BTB_ROW [`BTB_SIZE-1:0] btb;
	BTB_ROW [`BTB_SIZE-1:0] btb_next;


    // -----------------------------------------------------------------------
    `ifdef DEBUG_OUT_BANCH_PRED
    	assign btb_debug_out = btb;
    `endif  


    // -----------------------------------------------------------------------
    // NPC pred by BTB (built in BHT for direction)
	always_comb begin
		for(int i=0; i<`N; i=i+1) begin
            pred_PC[i] = (i==0)? starting_PC: pred_NPC[i-1];
            if( btb[pred_PC[i][`LOG_BTB_SIZE:2]].valid && 
                (btb[pred_PC[i][`LOG_BTB_SIZE:2]].predictor == S_TAKEN || 
                btb[pred_PC[i][`LOG_BTB_SIZE:2]].predictor == W_TAKEN)) begin

                pred_NPC[i] = btb[pred_PC[i][`LOG_BTB_SIZE:2]].predict_target; 

            end else begin

                pred_NPC[i] = pred_PC[i] + 4;

            end
		end

	end

    // -----------------------------------------------------------------------
	// predicted PC woule be 0, 4, 8, 12 ... 4(N-1) + input PC
	// always_comb begin
	// 	pred_NPC = 'b0;
	// 	for(int i=0; i<`N; i=i+1) begin
	// 		pred_NPC[i] = pred_PC[i] + 4;
	// 	end
	// end

    // -----------------------------------------------------------------------
    // btb_next comb logic 
    always_comb begin
        // start with previous status btb
        btb_next = btb;

        // loop through ex pack to see if valid & mispred
        // if so, determine if there is target miss or a direction miss
        // update btb next then
		for(int i=0; i<`N; i=i+1) begin
            if(execute_flushed_info.is_branch_mispredict) begin
                // always valid
                btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].valid = 1'b1;
                // 1. determine if there is a direction miss (unexpected NPC)
                //      -> actual target =/= PC + 4
                // 2.1 if so, update the PC address (also branch took here)
                // 2.2 if not, update the 2 bit decision maker (no branch)
                if( execute_flushed_info.mispeculated_PC != 
                    execute_flushed_info.mispeculated_old_PC+4) begin

                    btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predict_target = 
                        execute_flushed_info.mispeculated_PC;

                    // update history with a taken confirmed
                    case(btb[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor)
	                    W_NOT_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_TAKEN;
	                    S_NOT_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                W_NOT_TAKEN;
	                    S_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_TAKEN;
	                    W_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_TAKEN;
                    endcase

                end else begin
                    // update history with a not taken confirmed
                    case(btb[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor)
	                    W_NOT_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_NOT_TAKEN;
	                    S_NOT_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_NOT_TAKEN;
	                    S_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                W_TAKEN;
	                    W_TAKEN:
                            btb_next[execute_flushed_info.mispeculated_old_PC[`LOG_BTB_SIZE:2]].predictor = 
                                S_NOT_TAKEN;
                    endcase

                end
            end
		end
    end


    // -----------------------------------------------------------------------
    // update btb regs
	always_ff @(posedge clock) begin
		if (reset) begin
			btb <= 'b0;
        // only update btb reg when branch mispredict notified from ex pack
		end else if(execute_flushed_info.is_branch_mispredict) begin
			btb <= btb_next;
		end
	end


endmodule // module branch_pred

`endif //__BRANCH_PRED_SV__

