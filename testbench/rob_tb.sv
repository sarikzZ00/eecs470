`include "sys_defs.svh"
`include "ISA.svh"


module rob_test;

    //NOTE: This test does not work unless "DEBUG_OUT_ROB" is defined.

    //This will test ROB for any superscalar number.

    //Inputs
    logic clock;
    logic reset;
    logic [$clog2(`N + 1): 0] num_inst_dispatched;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_dest_indices;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] dispatched_preg_old_dest_indices;
    logic [`N-1:0][`NUM_REG_BITS-1:0] dispatched_arch_regs;
    CDB CDB_output;

    
    //Outputs
    logic [`NUM_ROBS_BITS:0] num_free_rob_rows; //Correctly not "-1"
    logic [`NUM_ROBS_BITS-1:0] tail_pointer;
    logic [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_phys_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] retired_old_phys_regs;
    logic [$clog2(`N + 1):0] num_rows_retire;
    logic retiring_branch_mispredict_next_cycle;
    logic [`XLEN-1:0] branch_target;

    //Debug Outputs
    logic [`NUM_ROBS_BITS - 1:0] head_pointer_debug;
    logic [`NUM_ROBS_BITS - 1:0] next_tail_pointer_debug;
    logic [`NUM_ROBS_BITS - 1:0] next_head_pointer_debug;
    ROB_ROW [`NUM_ROBS - 1:0] rob_queue_debug;

    //Expected Outputs
    logic [`NUM_ROBS_BITS-1:0] expected_tail_pointer;
    logic [`NUM_ROBS_BITS-1:0] expected_head_pointer; 
    logic [`NUM_ROBS_BITS-1:0] expected_next_tail_pointer;
    logic [`NUM_ROBS_BITS-1:0] expected_next_head_pointer;
    logic [$clog2(`N + 1):0] expected_num_rows_retire;
    logic [`NUM_ROBS_BITS:0] expected_num_free_rob_rows; //Correctly not "-1"
    logic [`N-1:0][`NUM_REG_BITS-1:0] expected_retired_arch_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_retired_phys_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_old_retired_phys_regs;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0] expected_retired_old_phys_regs;
    logic expected_retiring_branch_mispredict_next_cycle;
    ROB_ROW [`NUM_ROBS - 1: 0] expected_rob_queue;
    
    rob tb(
        //Inputs
        .clock(clock),
        .reset(reset),
        .num_inst_dispatched(num_inst_dispatched),
        .dispatched_preg_dest_indices(dispatched_preg_dest_indices),
        .dispatched_preg_old_dest_indices(dispatched_preg_old_dest_indices),
        .dispatched_arch_regs(dispatched_arch_regs),
        .CDB_output(CDB_output),

        //Outputs 
        .num_free_rob_rows(num_free_rob_rows), 
        .retired_arch_regs(retired_arch_regs),
        .retired_phys_regs(retired_phys_regs),
        .tail_pointer_output(tail_pointer),
        .retired_old_phys_regs(retired_old_phys_regs),
        .num_rows_retire(num_rows_retire),
        .retiring_branch_mispredict_next_cycle(retiring_branch_mispredict_next_cycle),
        .branch_target(branch_target)
        
        `ifdef DEBUG_OUT_ROB
            ,.head_pointer_debug(head_pointer_debug),
            .next_head_pointer_debug(next_head_pointer_debug),
            .rob_queue_debug(rob_queue_debug),
            .next_tail_pointer_debug(next_tail_pointer_debug)
        `endif
    );

    integer reset_index;
    integer rob_queue_index;
    integer n_successive_rob_rows_index;
    integer expected_index;
    task hard_reset;
    begin

        for(reset_index = 0; reset_index < `N; reset_index = reset_index + 1) begin 
            dispatched_arch_regs[reset_index] = {{0}};
            dispatched_preg_dest_indices[reset_index] = {{0}};
            dispatched_preg_old_dest_indices[reset_index] = {{0}};
        end
        num_inst_dispatched = 0;
        CDB_output = 0;

        expected_head_pointer = 0;
        expected_tail_pointer = 0;
        expected_next_tail_pointer = 0;
        expected_next_head_pointer = 0;
        expected_num_rows_retire = 0;
        expected_num_free_rob_rows = `NUM_ROBS;
        expected_retired_arch_regs = 0;
        expected_retired_phys_regs = 0;
        expected_retired_old_phys_regs = 0;
        expected_retiring_branch_mispredict_next_cycle = 0;
        expected_rob_queue = 0;

        for (int i = 0; i < `NUM_ROBS; i = i + 1) begin
            expected_rob_queue[i].rob_id = i;
        end

    end
    endtask

    task exit_on_error;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $finish;
      end
    endtask

    
    task print_debug_values;
        begin
            $display("--------------------------");
            $display("tail_pointer:%d\n", tail_pointer);
            $display("head_pointer_debug:%d\n", head_pointer_debug);
            $display("next_head_pointer_debug:%d\n", next_head_pointer_debug);
            $display("next_tail_pointer_debug:%d\n", next_tail_pointer_debug);
            $display("--------------------------");
            
        end
    endtask

    task print_ROB;
        input [`NUM_ROBS_BITS-1:0] lowerbound;
        input [`NUM_ROBS_BITS-1:0] upperbound;
        input ROB_ROW [`NUM_ROBS - 1:0] rob_queue;
        for(rob_queue_index = lowerbound; rob_queue_index < upperbound; rob_queue_index = rob_queue_index + 1) begin
                $display("--------------------------------------");
                $display("rob_queue index:%d ", rob_queue_index);
                $display("rob_queue arch dest:%d ", rob_queue[rob_queue_index].arch_reg_dest);
                $display("rob_queue phys reg dest:%d ", rob_queue[rob_queue_index].phys_reg_dest);
                $display("rob_queue old phys reg dest:%d ", rob_queue[rob_queue_index].old_phys_reg_dest);
                $display("rob_queue rob_id:%d ", rob_queue[rob_queue_index].rob_id);
                $display("rob_queue complete:%d ", rob_queue[rob_queue_index].complete);
                $display("rob_queue busy:%d ", rob_queue[rob_queue_index].busy);
                $display("rob_queue branch_mispredict:%d ", rob_queue[rob_queue_index].branch_mispredict);
                $display("");
        end
    endtask


    //####################
    //# Comparison Tasks #
    //####################

    task compare_tail_pointer;
        input [`NUM_ROBS_BITS-1:0] tail_pointer_debug;
        input [`NUM_ROBS_BITS-1:0] expected_tail_pointer;
        if (tail_pointer_debug != expected_tail_pointer) begin
            $display("Tail Pointer Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_tail_pointer);
            $display("Actual: %d", tail_pointer_debug);
            
            exit_on_error();
        end
    endtask

    task compare_head_pointer;
        input [`NUM_ROBS_BITS-1:0] head_pointer_debug;
        input [`NUM_ROBS_BITS-1:0] expected_head_pointer;
        if (head_pointer_debug != expected_head_pointer) begin
            $display("Head Pointer Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_head_pointer);
            $display("Actual: %d", head_pointer_debug);
            
            exit_on_error();
        end
    endtask

    task compare_next_tail_pointer;
        input [`NUM_ROBS_BITS-1:0] next_tail_pointer;
        input [`NUM_ROBS_BITS-1:0] expected_next_tail_pointer;
        if (next_tail_pointer != expected_next_tail_pointer) begin
            $display("Next Tail Pointer Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_next_tail_pointer);
            $display("Actual: %d", next_tail_pointer);
            
            exit_on_error();
        end
    endtask

    task compare_next_head_pointer;
        input [`NUM_ROBS_BITS-1:0] next_head_pointer_debug;
        input [`NUM_ROBS_BITS-1:0] expected_next_head_pointer;
        if (next_head_pointer_debug != expected_next_head_pointer) begin
            $display("Next Head Pointer Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_next_head_pointer);
            $display("Actual: %d", next_head_pointer_debug);
            
            exit_on_error();
        end
    endtask
    
    task compare_num_rows_retire;
        input [$clog2(`N + 1):0] num_rows_retire;
        input [$clog2(`N + 1):0] expected_num_rows_retire;
        if (num_rows_retire != expected_num_rows_retire) begin
            $display("Number of Retired Rows Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_num_rows_retire);
            $display("Actual: %d", num_rows_retire);
            
            exit_on_error();
        end
    endtask

    task compare_num_free_rows;
        input [`NUM_ROBS_BITS:0] num_free_rob_rows;
        input [`NUM_ROBS_BITS:0] expected_num_free_rob_rows;
        if (num_free_rob_rows != expected_num_free_rob_rows) begin
            $display("Number of Free Rows Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_num_free_rob_rows);
            $display("Actual: %d", num_free_rob_rows);
            
            exit_on_error();
        end
    endtask

    
    task compare_retired_arch_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] retired_arch_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] expected_retired_arch_regs;
        foreach (retired_arch_regs[arch_reg_index]) begin
            if (retired_arch_regs[arch_reg_index] != expected_retired_arch_regs[arch_reg_index]) begin
                $display("Retired Architectural Registers Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", arch_reg_index);
                
                $display("Expected: %d", expected_retired_arch_regs[arch_reg_index]);
                $display("Actual: %d", retired_arch_regs[arch_reg_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_retired_phys_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] retired_phys_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] expected_retired_phys_regs;
        foreach (retired_phys_regs[phys_reg_index]) begin
            if (retired_phys_regs[phys_reg_index] != expected_retired_phys_regs[phys_reg_index]) begin
                $display("Retired Physical Registers Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", phys_reg_index);
                
                $display("Expected: %d", expected_retired_phys_regs[phys_reg_index]);
                $display("Actual: %d", retired_phys_regs[phys_reg_index]);
                
                exit_on_error();
            end
        end
    endtask

    task compare_retired_old_phys_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] retired_old_phys_regs;
        input [`N-1:0][`NUM_REG_BITS-1:0] expected_retired_old_phys_regs;
        foreach (retired_old_phys_regs[old_phys_reg_index]) begin
            if (retired_old_phys_regs[old_phys_reg_index] != expected_retired_old_phys_regs[old_phys_reg_index]) begin
                $display("Number of Retired Old Phys Reg Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", old_phys_reg_index);
                
                $display("Expected: %d", expected_retired_old_phys_regs[old_phys_reg_index]);
                $display("Actual: %d", retired_old_phys_regs[old_phys_reg_index]);
                exit_on_error();
            end
        end
    endtask

    task compare_branch_mispredict;
        input retiring_branch_mispredict_next_cycle;
        input expected_retiring_branch_mispredict_next_cycle;
        if (retiring_branch_mispredict_next_cycle != expected_retiring_branch_mispredict_next_cycle) begin
            $display("Branch Mispredict Signal Wrong at Time: %4.0f", $time);
            $display("Expected: %d", expected_retiring_branch_mispredict_next_cycle);
            $display("Actual: %d", retiring_branch_mispredict_next_cycle);
            exit_on_error();
        end
    endtask
    

    task compare_rob_queue;
        input ROB_ROW [`NUM_ROBS-1:0] rob_queue_debug;
        input ROB_ROW [`NUM_ROBS-1:0] expected_rob_queue;
        for (int rob_queue_index = 0; rob_queue_index < `NUM_ROBS; rob_queue_index = rob_queue_index + 1) begin
            // $display("Index: %d", rob_queue_index);
            // $display("Expected:");
            // print_ROB(rob_queue_index, rob_queue_index + 1, expected_rob_queue);
            // $display("Actual:");
            // print_ROB(rob_queue_index, rob_queue_index + 1, rob_queue_debug);

            if (rob_queue_debug[rob_queue_index] != expected_rob_queue[rob_queue_index]) begin
                $display("ROB Queue Wrong at Time: %4.0f", $time);
                $display("Index %d Incorrect", rob_queue_index);
                
                $display("Expected:");
                $display("\tarch_reg_dest: %d", expected_rob_queue[rob_queue_index].arch_reg_dest);
                $display("\tphys_reg_dest: %d", expected_rob_queue[rob_queue_index].phys_reg_dest);
                $display("\told_phys_reg_dest: %d", expected_rob_queue[rob_queue_index].old_phys_reg_dest);
                $display("\trob_id_vec: %d", expected_rob_queue[rob_queue_index].rob_id);
                $display("\tcomplete: %b", expected_rob_queue[rob_queue_index].complete);
                $display("\tbusy: %b", expected_rob_queue[rob_queue_index].busy);
                $display("\tbranch_mispredict: %b", expected_rob_queue[rob_queue_index].branch_mispredict);
                $display("");


                $display("Actual:");
                $display("\tarch_reg_dest: %d", rob_queue_debug[rob_queue_index].arch_reg_dest);
                $display("\tphys_reg_dest: %d", rob_queue_debug[rob_queue_index].phys_reg_dest);
                $display("\told_phys_reg_dest: %d", rob_queue_debug[rob_queue_index].old_phys_reg_dest);
                $display("\trob_id_vec: %d", rob_queue_debug[rob_queue_index].rob_id);
                $display("\tcomplete: %b", rob_queue_debug[rob_queue_index].complete);
                $display("\tbusy: %b", rob_queue_debug[rob_queue_index].busy);
                $display("\tbranch_mispredict: %b", rob_queue_debug[rob_queue_index].branch_mispredict);
                $display("");
                
                exit_on_error();
            end
        end
    endtask

    typedef struct packed {
        logic [`NUM_ROBS_BITS-1:0] tpd; //tail_pointer;
        logic [`NUM_ROBS_BITS-1:0] etp; //expected_tail_pointer;

        logic [`NUM_ROBS_BITS-1:0] hpd; //head_pointer_debug;
        logic [`NUM_ROBS_BITS-1:0] ehp; //expected_head_pointer;

        logic [`NUM_ROBS_BITS-1:0] ntp; //next_tail_pointer;
        logic [`NUM_ROBS_BITS-1:0] entp; //expected_next_tail_pointer;

        logic [`NUM_ROBS_BITS-1:0] nhpd; //next_head_pointer_debug;
        logic [`NUM_ROBS_BITS-1:0] enhp; //expected_next_head_pointer;

        logic [$clog2(`N + 1):0] nrr; //num_rows_retire;
        logic [$clog2(`N + 1):0] enrr; //expected_num_rows_retire;

        logic [`NUM_ROBS_BITS:0] nfrr; //num_free_rob_rows;
        logic [`NUM_ROBS_BITS:0] enfrr; //expected_num_free_rob_rows;

        logic [`N-1:0][`NUM_REG_BITS-1:0] rar; //retired_arch_regs;
        logic [`N-1:0][`NUM_REG_BITS-1:0] erar; //expected_retired_arch_regs;

        logic [`N-1:0][`NUM_PHYS_BITS-1:0] rpr; //retired_phys_regs;
        logic [`N-1:0][`NUM_PHYS_BITS-1:0] erpr; //expected_retired_phys_regs;

         logic [`N-1:0][`NUM_PHYS_BITS-1:0] ropr; //retired_old_phys_regs;
        logic [`N-1:0][`NUM_PHYS_BITS-1:0] eropr; //expected_old_retired_phys_regs;

        logic rbmnc; //retiring_branch_mispredict_next_cycle;
        logic erbmnc; //expected_retiring_branch_mispredict_next_cycle;

        ROB_ROW [`NUM_ROBS - 1:0] rqd; //rob_queue_debug;
        ROB_ROW [`NUM_ROBS - 1:0] erq; //expected_rob_queue;
    } COMPARE_ALL_PACKET;

    task compare_all;
        input COMPARE_ALL_PACKET in_packet;
                
        //$display("Comparing All");
        compare_rob_queue(in_packet.rqd, in_packet.erq);
        compare_tail_pointer(in_packet.tpd, in_packet.etp);
        compare_head_pointer(in_packet.hpd, in_packet.ehp);
        compare_next_tail_pointer(in_packet.ntp, in_packet.entp);
        compare_next_head_pointer(in_packet.nhpd, in_packet.enhp);
        compare_num_rows_retire(in_packet.nrr, in_packet.enrr);
        compare_num_free_rows(in_packet.nfrr, in_packet.enfrr);
        compare_retired_arch_regs(in_packet.rar, in_packet.erar);
        compare_retired_phys_regs(in_packet.rpr, in_packet.erpr);
        compare_retired_old_phys_regs(in_packet.ropr, in_packet.eropr);
        compare_branch_mispredict(in_packet.rbmnc, in_packet.erbmnc);
    endtask

    task finish_successfully;
        $display("@@@Passed");
        $finish;
    endtask

    //TODO: Move this to the actual testbench
    /*compare_all(tail_pointer_debug, expected_tail_pointer,
                head_pointer_debug, expected_head_pointer,
                next_tail_pointer, expected_next_tail_pointer,
                next_head_pointer_debug, expected_next_head_pointer,
                num_rows_retire, expected_num_rows_retire,
                num_free_rob_rows, expected_num_free_rob_rows,
                retired_arch_regs, expected_retired_arch_regs,
                retired_phys_regs, expected_retired_phys_regs,
                retiring_branch_mispredict_next_cycle, expected_retiring_branch_mispredict_next_cycle,
                rob_queue_debug, expected_rob_queue
    );*/


    //########################
    //# End Comparison Tasks #
    //########################

    


    always begin
        #10 clock = ~clock;
    end

    

    



    COMPARE_ALL_PACKET compare_packet;
    assign compare_packet.tpd = tail_pointer;
    assign compare_packet.etp = expected_tail_pointer;
    assign compare_packet.hpd = head_pointer_debug;
    assign compare_packet.ehp = expected_head_pointer;
    assign compare_packet.ntp = next_tail_pointer_debug;
    assign compare_packet.entp = expected_next_tail_pointer;
    assign compare_packet.nhpd = next_head_pointer_debug;
    assign compare_packet.enhp = expected_next_head_pointer;
    assign compare_packet.nrr = num_rows_retire;
    assign compare_packet.enrr = expected_num_rows_retire;
    assign compare_packet.nfrr = num_free_rob_rows;
    assign compare_packet.enfrr = expected_num_free_rob_rows;
    assign compare_packet.rar = retired_arch_regs;
    assign compare_packet.erar = expected_retired_arch_regs;
    assign compare_packet.rpr = retired_phys_regs;
    assign compare_packet.erpr = expected_retired_phys_regs;
    assign compare_packet.ropr = retired_old_phys_regs;
    assign compare_packet.eropr = expected_retired_old_phys_regs;
    assign compare_packet.rbmnc = retiring_branch_mispredict_next_cycle;
    assign compare_packet.erbmnc = expected_retiring_branch_mispredict_next_cycle;
    assign compare_packet.rqd = rob_queue_debug;
    assign compare_packet.erq = expected_rob_queue;


    always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
        #5; compare_all(compare_packet); //#5 Allows time for all outputs to settle
    end

    initial begin
        clock = 0;
        //$monitor("Time: %4.0f", $time);
        if (`N == 1) begin
            reset = 1;
            hard_reset();
            @(negedge clock);
            print_debug_values();
            @(negedge clock);
            reset = 0;
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");
            $display("Beginning Tests for N = 1");
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");
            print_debug_values();
            

            @(negedge clock); //Time 60
            //Change Inputs
            $display("Setting Inputs");
            num_inst_dispatched = 1;
            dispatched_arch_regs[0] = `NUM_REG_BITS'd1;
            dispatched_preg_dest_indices[0] = `NUM_PHYS_BITS'd1;
            dispatched_preg_old_dest_indices[0] = `NUM_PHYS_BITS'd0;

            //Change Expectations
            expected_head_pointer = 0;
            expected_tail_pointer = 0;
            expected_next_tail_pointer = 1;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 1;
            expected_retired_arch_regs = 0;
            expected_retired_phys_regs = 0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;
            expected_rob_queue = 0;

            for (int i = 0; i < `NUM_ROBS; i = i + 1) begin
                expected_rob_queue[i].rob_id = i;
            end

            @(negedge clock); //Time 80
            //Change Inputs
            num_inst_dispatched = 0;

            //Change Expected
            $display("Change Expected");
            expected_tail_pointer = 1;
            expected_rob_queue[0].busy = `TRUE;
            expected_rob_queue[0].phys_reg_dest = 1;
            expected_rob_queue[0].arch_reg_dest = 1;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;


            @(negedge clock); //Time 100
            //Change Inputs
            num_inst_dispatched = 1;
            dispatched_preg_dest_indices[0] = `NUM_PHYS_BITS'd2;
            dispatched_preg_old_dest_indices[0] = `NUM_PHYS_BITS'd0;

            //Change Expectations
            expected_head_pointer = 0;
            expected_tail_pointer = 1;
            expected_next_tail_pointer = 2;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 2;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //Time 120
            //Change Inputs
            num_inst_dispatched = 0;

            //Change Expected
            expected_tail_pointer = 2;
            expected_rob_queue[1].busy = `TRUE;
            expected_rob_queue[1].phys_reg_dest = 2;
            expected_rob_queue[1].arch_reg_dest = 1;


            @(negedge clock); //Time 140
            //Change Inputs
            num_inst_dispatched = 1;
            dispatched_preg_dest_indices[0] = `NUM_PHYS_BITS'd3;
            dispatched_preg_old_dest_indices[0] = `NUM_PHYS_BITS'd0;

            //Change Expectations
            expected_head_pointer = 0;
            expected_tail_pointer = 2;
            expected_next_tail_pointer = 3;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 3;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //Time 160
            //Change Inputs
            num_inst_dispatched = 0;

            //Change Expected
            expected_tail_pointer = 3;
            expected_rob_queue[2].busy = `TRUE;
            expected_rob_queue[2].phys_reg_dest = 3;
            expected_rob_queue[2].arch_reg_dest = 1;

            
            


            @(negedge clock); //Time 180
            //Change Inputs
            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd1; 
            CDB_output.rob_id[0] = `NUM_ROBS_BITS'd0;
            CDB_output.valid[0] = 1;

            //Change Expectations
            expected_head_pointer = 0;
            expected_tail_pointer = 3;
            expected_next_tail_pointer = 3;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 3;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //Time 200
            //Change Inputs
            CDB_output.valid[0] = `FALSE;

            //Change Expected
            expected_tail_pointer = 3;
            expected_next_head_pointer = 1;
            expected_rob_queue[0].complete = 1;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd1;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd1;
            expected_retired_old_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_num_rows_retire = 1;
            expected_num_free_rob_rows = `NUM_ROBS - 2;
            
            @(negedge clock); //Time 220

            expected_head_pointer = 1;
            expected_num_rows_retire = 0;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_rob_queue[0].complete = `FALSE;
            expected_rob_queue[0].busy = `FALSE;

            expected_rob_queue[0].arch_reg_dest = 0;
            expected_rob_queue[0].phys_reg_dest = 0;


            @(negedge clock); //Time 240

            @(negedge clock); //Time 260
    

            //Change Inputs
            num_inst_dispatched = 1;
            dispatched_preg_dest_indices[0] = `NUM_PHYS_BITS'd4;
            dispatched_preg_old_dest_indices[0] = `NUM_PHYS_BITS'd0;
            expected_num_free_rob_rows = `NUM_ROBS - 3;

            //Change Expected
            if (`NUM_ROBS == 4) begin
                expected_next_tail_pointer = 0;
                $display("Overflow Working Correctly");
            end else begin
                expected_next_tail_pointer = 4;
            end


            @(negedge clock); //Time 280

            num_inst_dispatched = 0;

            //Change Expected
            if (`NUM_ROBS == 4) begin
                expected_tail_pointer = 0;
            end else begin
                expected_tail_pointer = 4;
            end
            expected_rob_queue[3].arch_reg_dest = `NUM_REG_BITS'd1;
            expected_rob_queue[3].phys_reg_dest = `NUM_PHYS_BITS'd4;
            expected_rob_queue[3].old_phys_reg_dest = `NUM_PHYS_BITS'd0;
            expected_rob_queue[3].busy = 1'b1;


            //These branch mispredict tests only work for N = 1
            if (`N == 1) begin
                @(negedge clock); //Time 300
                //Change Inputs
                CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd3; 
                CDB_output.rob_id[0] = `NUM_ROBS_BITS'd2;
                CDB_output.valid[0] = `TRUE;
                CDB_output.branch_mispredict = `TRUE;

                expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
                expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;

                @(negedge clock); //Time 320
                //Change Inputs
                CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd2; 
                CDB_output.rob_id[0] = `NUM_ROBS_BITS'd1;
                CDB_output.valid[0] = `TRUE;
                CDB_output.branch_mispredict = `FALSE;

                expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
                expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;

                //Change Expected
                expected_rob_queue[2].complete = `TRUE;
                expected_rob_queue[2].branch_mispredict = `TRUE;



                @(negedge clock); //Time 340
                //#########################################################
                // This cycle we are retiring a non-branch mispredict. 
                // Next cycle we are retiring a branch mispredict
                //#########################################################


                //Change Input
                CDB_output.valid[0] = `FALSE;

                //Change Expected
                expected_next_head_pointer = 2;
                expected_num_rows_retire = 1;

                expected_retired_arch_regs[0] = `NUM_REG_BITS'd1;
                expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd2;


                expected_rob_queue[1].complete = `TRUE;

                expected_retiring_branch_mispredict_next_cycle = `TRUE;

                expected_num_free_rob_rows = `NUM_ROBS - 2;




                @(negedge clock); //Time 360
                //############################################################################
                //Retiring Branch Mispredict this cycle; Everything should reset next cycle.

                expected_next_head_pointer = 0;
                expected_next_tail_pointer = 0;

                expected_rob_queue[1] = 0;
                expected_rob_queue[1].rob_id = 1;

                expected_retired_arch_regs[0] = `NUM_REG_BITS'd1;
                expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd3;

                expected_head_pointer = 2;

                expected_num_free_rob_rows = `NUM_ROBS;

                expected_retiring_branch_mispredict_next_cycle = `FALSE;




                @(negedge clock); //Time 380
                //Everything should be reset this cycle
                expected_head_pointer = 0;
                expected_tail_pointer = 0;


                finish_successfully();
            end //End Tests Exclusive for N = 1
        end
        if (`N == 2) begin
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");
            $display("Beginning Tests for N = 2");
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");

            
            
            reset = 1;
            hard_reset();
            @(negedge clock);
            print_debug_values();
            @(negedge clock);
            reset = 0; 
            num_inst_dispatched = 2;
            dispatched_arch_regs[1:0] = {`NUM_REG_BITS'd2, `NUM_REG_BITS'd1};
            dispatched_preg_dest_indices[1:0] = {`NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd1};
            dispatched_preg_old_dest_indices[1:0] = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            
            expected_head_pointer = 0;
            expected_tail_pointer = 0;
            expected_next_tail_pointer = 2;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 2;
            expected_retired_arch_regs = 0;
            expected_retired_phys_regs = 0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;


            @(negedge clock); //Time 60

            num_inst_dispatched = 0;

            //Change Expected
            expected_tail_pointer = 2;
            expected_rob_queue[0].busy = `TRUE;
            expected_rob_queue[0].phys_reg_dest = 1;
            expected_rob_queue[0].arch_reg_dest = 1;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;


            expected_rob_queue[1].busy = `TRUE;
            expected_rob_queue[1].phys_reg_dest = 2;
            expected_rob_queue[1].arch_reg_dest = 2;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;

            @(negedge clock); //Time 80
            num_inst_dispatched = 2;
            dispatched_arch_regs[1:0] = {`NUM_REG_BITS'd4, `NUM_REG_BITS'd3};
            dispatched_preg_dest_indices[1:0] = {`NUM_PHYS_BITS'd4, `NUM_PHYS_BITS'd3};
            dispatched_preg_old_dest_indices[1:0] = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            
            expected_head_pointer = 0;
            expected_tail_pointer = 2;
            expected_next_tail_pointer = 4;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 4;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;


            @(negedge clock);//Time 100

            num_inst_dispatched = 0;

            //Change Expected
            $display("Change Expected");
            expected_tail_pointer = 4;
            expected_rob_queue[2].busy = `TRUE;
            expected_rob_queue[2].phys_reg_dest = 3;
            expected_rob_queue[2].arch_reg_dest = 3;

            expected_rob_queue[3].busy = `TRUE;
            expected_rob_queue[3].phys_reg_dest = 4;
            expected_rob_queue[3].arch_reg_dest = 4;
        

            @(negedge clock); //Time 120
            //Change Inputs
            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd1; 

            CDB_output.valid[0] = 1;



            //Change Expectations
            expected_head_pointer = 0;
            expected_tail_pointer = 4;
            expected_next_tail_pointer = 4;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 4;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //Time 140
            //Change Inputs
            CDB_output.valid[0] = `FALSE;

            //Change Expected
            expected_tail_pointer = 4;
            expected_next_head_pointer = 1;
            
            expected_rob_queue[0].complete = `TRUE;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd1;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd1;
            expected_retired_old_phys_regs[0] = `NUM_PHYS_BITS'd0;

            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;
            expected_retired_old_phys_regs[1] = `NUM_PHYS_BITS'd0;

            expected_num_rows_retire = 1;
            expected_num_free_rob_rows = `NUM_ROBS - 3;
            
            @(negedge clock); //Time 160

            expected_head_pointer = 1;
            expected_num_rows_retire = 0;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;

            expected_rob_queue[0] = 0;
            expected_rob_queue[0].rob_id = 0; //Unneeded for this particular case, but in general reminder to set id when resetting row.


            @(negedge clock); //Time 180
            //Change Inputs
            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd2; 
            CDB_output.rob_id[0] = `NUM_ROBS_BITS'd1;
            CDB_output.phys_regs[1] = `NUM_PHYS_BITS'd3;
            CDB_output.rob_id[1] = `NUM_ROBS_BITS'd2;
            CDB_output.valid[0] = 1;
            CDB_output.valid[1] = 1;


            //Change Expectations
            expected_head_pointer = 1;
            expected_tail_pointer = 4;
            expected_next_tail_pointer = 4;
            expected_next_head_pointer = 1;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 3;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //Time 200
            //Change Inputs
            CDB_output.valid[0] = `FALSE;
            CDB_output.valid[1] = `FALSE;
            //Change Expected
            expected_tail_pointer = 4;
            expected_next_head_pointer = 3;
            
            expected_rob_queue[0].complete = `FALSE;
            expected_rob_queue[1].complete = `TRUE;
            expected_rob_queue[2].complete = `TRUE;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd2;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd3;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd2;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd3;
            expected_retired_old_phys_regs[0] = `NUM_PHYS_BITS'd0;

            expected_num_rows_retire = 2;
            expected_num_free_rob_rows = `NUM_ROBS - 1;
            
            @(negedge clock); //Time 220

            expected_head_pointer = 3;
            expected_num_rows_retire = 0;
            expected_retired_arch_regs[0] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[0] = `NUM_PHYS_BITS'd0;
            expected_retired_arch_regs[1] = `NUM_REG_BITS'd0;
            expected_retired_phys_regs[1] = `NUM_PHYS_BITS'd0;

            expected_rob_queue[1] = 0;
            expected_rob_queue[1].rob_id = 1; //Unneeded for this particular case, but in general reminder to set id when resetting row.

            expected_rob_queue[2] = 0;
            expected_rob_queue[2].rob_id = 2; //Unneeded for this particular case, but in general reminder to set id when resetting row.

            @(negedge clock); //240

        end
        if (`N == 5 && `NUM_ROBS==32 && `NUM_ROBS_BITS == 5) begin
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");
            $display("Beginning Tests for N = 5");
            $display("$$$$$$$$$$$$$$$$$$$$$$$$$");

            #6; reset = 1; //Wait until after automatic checks to do reset
            hard_reset();
                        
            @(negedge clock); //260
            reset = 0;

            //########################################################################
            //This test dispatches 15 instructions, completes them out of order,
            //Then has a branch mispredict as instruction number 12.
            //########################################################################

            num_inst_dispatched = 5;
            dispatched_arch_regs[4:0] = {`NUM_REG_BITS'd5, `NUM_REG_BITS'd4, `NUM_REG_BITS'd3, `NUM_REG_BITS'd2, `NUM_REG_BITS'd1};
            dispatched_preg_dest_indices[4:0] = {`NUM_PHYS_BITS'd5, `NUM_PHYS_BITS'd4, `NUM_PHYS_BITS'd3, `NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd1};
            dispatched_preg_old_dest_indices[4:0] = {`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            
            expected_head_pointer = 0;
            expected_tail_pointer = 0;
            expected_next_tail_pointer = 5;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 5;
            expected_retired_arch_regs = 0;
            expected_retired_phys_regs = 0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //280

            dispatched_arch_regs[4:0] = {`NUM_REG_BITS'd10, `NUM_REG_BITS'd9, `NUM_REG_BITS'd8, `NUM_REG_BITS'd7, `NUM_REG_BITS'd6};
            dispatched_preg_dest_indices[4:0] = {`NUM_PHYS_BITS'd10, `NUM_PHYS_BITS'd9, `NUM_PHYS_BITS'd8, `NUM_PHYS_BITS'd7, `NUM_PHYS_BITS'd6};
            dispatched_preg_old_dest_indices[4:0] = {`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};

            expected_head_pointer = 0;
            expected_tail_pointer = 5;
            expected_next_tail_pointer = 10;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 10;
            expected_retired_arch_regs = 0;
            expected_retired_phys_regs = 0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            for (int i = 0; i < 5; i = i + 1) begin
                expected_rob_queue[i].busy = `TRUE;
                expected_rob_queue[i].arch_reg_dest = i + 1;
                expected_rob_queue[i].phys_reg_dest = i + 1;

            end

            @(negedge clock); //300

            dispatched_arch_regs[4:0] = {`NUM_REG_BITS'd15, `NUM_REG_BITS'd14, `NUM_REG_BITS'd13, `NUM_REG_BITS'd12, `NUM_REG_BITS'd11};
            dispatched_preg_dest_indices[4:0] = {`NUM_PHYS_BITS'd15, `NUM_PHYS_BITS'd14, `NUM_PHYS_BITS'd13, `NUM_PHYS_BITS'd12, `NUM_PHYS_BITS'd11};
            dispatched_preg_old_dest_indices[4:0] = {`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0,`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};

            expected_head_pointer = 0;
            expected_tail_pointer = 10;
            expected_next_tail_pointer = 15;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 15;
            expected_retired_arch_regs = 0;
            expected_retired_phys_regs = 0;
            expected_retired_old_phys_regs = 0;
            expected_retiring_branch_mispredict_next_cycle = 0;

            for (int i = 5; i < 10; i = i + 1) begin
                expected_rob_queue[i].busy = `TRUE;
                expected_rob_queue[i].arch_reg_dest = i + 1;
                expected_rob_queue[i].phys_reg_dest = i + 1;

            end

            @(negedge clock); //320
            num_inst_dispatched = 0;

            expected_tail_pointer = 15;

            

            for (int i = 10; i < 15; i = i + 1) begin
                expected_rob_queue[i].busy = `TRUE;
                expected_rob_queue[i].arch_reg_dest = i + 1;
                expected_rob_queue[i].phys_reg_dest = i + 1;

            end


            @(negedge clock); //340
            @(negedge clock); //360

            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd1;
            CDB_output.rob_id[0] = `NUM_ROBS_BITS'd0;
            CDB_output.phys_regs[1] = `NUM_PHYS_BITS'd5;
            CDB_output.rob_id[1] = `NUM_ROBS_BITS'd4;
            CDB_output.phys_regs[2] = `NUM_PHYS_BITS'd12;
            CDB_output.rob_id[2] = `NUM_ROBS_BITS'd11;
            CDB_output.phys_regs[3] = `NUM_PHYS_BITS'd15;
            CDB_output.rob_id[3] = `NUM_ROBS_BITS'd14;
            CDB_output.phys_regs[4] = `NUM_PHYS_BITS'd7;
            CDB_output.rob_id[4] = `NUM_ROBS_BITS'd6;
            CDB_output.valid = {`TRUE, `TRUE, `TRUE, `TRUE, `TRUE};
            CDB_output.branch_mispredict = {`FALSE, `FALSE, `FALSE, `FALSE, `FALSE};

            

            @(negedge clock); //380

            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd2;
            CDB_output.rob_id[0] = `NUM_ROBS_BITS'd1;
            CDB_output.phys_regs[1] = `NUM_PHYS_BITS'd6;
            CDB_output.rob_id[1] = `NUM_ROBS_BITS'd5;
            CDB_output.phys_regs[2] = `NUM_PHYS_BITS'd13;
            CDB_output.rob_id[2] = `NUM_ROBS_BITS'd12;
            CDB_output.phys_regs[3] = `NUM_PHYS_BITS'd14;
            CDB_output.rob_id[3] = `NUM_ROBS_BITS'd13;
            CDB_output.phys_regs[4] = `NUM_PHYS_BITS'd8;
            CDB_output.rob_id[4] = `NUM_ROBS_BITS'd7;
            CDB_output.valid = {`TRUE, `TRUE, `TRUE, `TRUE, `TRUE};
            CDB_output.branch_mispredict = {`FALSE, `FALSE, `FALSE, `FALSE, `FALSE};

            //Note, these are all 1 lower than the physical registers that are broadcasted
            expected_rob_queue[0].complete = `TRUE;
            expected_rob_queue[4].complete = `TRUE;
            expected_rob_queue[6].complete = `TRUE;
            expected_rob_queue[11].complete = `TRUE;
            expected_rob_queue[14].complete = `TRUE;


            expected_head_pointer = 0;
            expected_tail_pointer = 15;
            expected_next_tail_pointer = 15;
            expected_next_head_pointer = 1;
            expected_num_rows_retire = 1;
            expected_num_free_rob_rows = `NUM_ROBS - 14;
            expected_retired_arch_regs = {`NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd1};
            expected_retired_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd1};
            expected_retired_old_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retiring_branch_mispredict_next_cycle = 0;
            

            @(negedge clock); //400
            

            CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd3; 
            CDB_output.rob_id[0] = `NUM_ROBS_BITS'd2;
            CDB_output.phys_regs[1] = `NUM_PHYS_BITS'd4;
            CDB_output.rob_id[1] = `NUM_ROBS_BITS'd3;
            CDB_output.phys_regs[2] = `NUM_PHYS_BITS'd9; 
            CDB_output.rob_id[2] = `NUM_ROBS_BITS'd8;
            CDB_output.phys_regs[3] = `NUM_PHYS_BITS'd10;
            CDB_output.rob_id[3] = `NUM_ROBS_BITS'd9;
            CDB_output.phys_regs[4] = `NUM_PHYS_BITS'd11;
            CDB_output.rob_id[4] = `NUM_ROBS_BITS'd10;
            CDB_output.valid = {`TRUE, `TRUE, `TRUE, `TRUE, `TRUE};
            CDB_output.branch_mispredict = {`TRUE, `FALSE, `FALSE, `FALSE, `FALSE};



            //Row 0 got retired
            expected_rob_queue[0] = 0;
            expected_rob_queue[0].rob_id = 0;


            //Note, these are all 1 lower than the physical registers that are broadcasted
            expected_rob_queue[1].complete = `TRUE;
            expected_rob_queue[5].complete = `TRUE;
            expected_rob_queue[7].complete = `TRUE;
            expected_rob_queue[12].complete = `TRUE;
            expected_rob_queue[13].complete = `TRUE;

            expected_head_pointer = 1;
            expected_tail_pointer = 15;
            expected_next_tail_pointer = 15;
            expected_next_head_pointer = 2;
            expected_num_rows_retire = 1;
            expected_num_free_rob_rows = `NUM_ROBS - 13;
            expected_retired_arch_regs = {`NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd2};
            expected_retired_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd2};
            expected_retired_old_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retiring_branch_mispredict_next_cycle = 0;

            @(negedge clock); //420
            //RETIRING BRANCH MISPREDICT NEXT CYCLE
            CDB_output.valid = {`FALSE, `FALSE, `FALSE, `FALSE, `FALSE};

            

            //Row 1 got retired
            expected_rob_queue[1] = 0;
            expected_rob_queue[1].rob_id = 1;


            //Note, these are all 1 lower than the physical registers that are broadcasted
            expected_rob_queue[2].complete = `TRUE;
            expected_rob_queue[3].complete = `TRUE;
            expected_rob_queue[8].complete = `TRUE;
            expected_rob_queue[9].complete = `TRUE;
            expected_rob_queue[10].complete = `TRUE;

            expected_rob_queue[10].branch_mispredict = `TRUE;


            expected_head_pointer = 2;
            expected_tail_pointer = 15;
            expected_next_tail_pointer = 15;
            expected_next_head_pointer = 7;
            expected_num_rows_retire = 5;
            expected_num_free_rob_rows = `NUM_ROBS - 8;
            expected_retired_arch_regs = {`NUM_REG_BITS'd7, `NUM_REG_BITS'd6, `NUM_REG_BITS'd5, `NUM_REG_BITS'd4, `NUM_REG_BITS'd3};
            expected_retired_phys_regs = {`NUM_PHYS_BITS'd7, `NUM_PHYS_BITS'd6, `NUM_PHYS_BITS'd5, `NUM_PHYS_BITS'd4, `NUM_PHYS_BITS'd3};
            expected_retired_old_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retiring_branch_mispredict_next_cycle = `TRUE;

            @(negedge clock); //440
            //RETIRING BRANCH MISPREDICT THIS CYCLE

            //We are also dispatching 5 new instructions at the same time.
            num_inst_dispatched = 5;

            dispatched_arch_regs[4:0] = {`NUM_REG_BITS'd5, `NUM_REG_BITS'd4, `NUM_REG_BITS'd3, `NUM_REG_BITS'd2, `NUM_REG_BITS'd1};
            dispatched_preg_dest_indices[4:0] = {`NUM_PHYS_BITS'd16, `NUM_PHYS_BITS'd15, `NUM_PHYS_BITS'd14, `NUM_PHYS_BITS'd13, `NUM_PHYS_BITS'd12};
            dispatched_preg_old_dest_indices[4:0] = {`NUM_PHYS_BITS'd5,`NUM_PHYS_BITS'd4,`NUM_PHYS_BITS'd3,`NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd1};




            //Retired rows
            expected_rob_queue[2] = 0;
            expected_rob_queue[2].rob_id = 2;
            expected_rob_queue[3] = 0;
            expected_rob_queue[3].rob_id = 3;
            expected_rob_queue[4] = 0;
            expected_rob_queue[4].rob_id = 4;
            expected_rob_queue[5] = 0;
            expected_rob_queue[5].rob_id = 5;
            expected_rob_queue[6] = 0;
            expected_rob_queue[6].rob_id = 6;


            

            expected_head_pointer = 7;
            expected_tail_pointer = 15;
            expected_next_tail_pointer = 5; //Branch misprediction sets this to 0, then the dispatched rows sets this to 5
            expected_next_head_pointer = 0; //Branch misprediction sets this to 0
            expected_num_rows_retire = 4;
            expected_num_free_rob_rows = `NUM_ROBS - 5;
            expected_retired_arch_regs = {`NUM_REG_BITS'd0, `NUM_REG_BITS'd11, `NUM_REG_BITS'd10, `NUM_REG_BITS'd9, `NUM_REG_BITS'd8};
            expected_retired_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd11, `NUM_PHYS_BITS'd10, `NUM_PHYS_BITS'd9, `NUM_PHYS_BITS'd8};
            expected_retired_old_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retiring_branch_mispredict_next_cycle = `FALSE;

            @(negedge clock); //460
            num_inst_dispatched = 0;

            //Branch Mispredict Resets ROB
            expected_rob_queue = 0;

            for (int i = 0; i < `NUM_ROBS; i = i + 1) begin
                expected_rob_queue[i].rob_id = i;
            end


            //Newly Dispatched Rows
            for (int i = 0; i < 5; i = i + 1) begin
                expected_rob_queue[i].arch_reg_dest = i + 1;
                expected_rob_queue[i].phys_reg_dest = i + 12;
                expected_rob_queue[i].old_phys_reg_dest = i + 1;
                expected_rob_queue[i].busy = `TRUE;
            end


            expected_head_pointer = 0;
            expected_tail_pointer = 5;
            expected_next_tail_pointer = 5;
            expected_next_head_pointer = 0;
            expected_num_rows_retire = 0;
            expected_num_free_rob_rows = `NUM_ROBS - 5;
            expected_retired_arch_regs = {`NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0, `NUM_REG_BITS'd0};
            expected_retired_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retired_old_phys_regs = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
            expected_retiring_branch_mispredict_next_cycle = `FALSE;

            @(negedge clock); //480
            @(negedge clock); //500


        end


        finish_successfully();
    end

endmodule






        /*$display("Dispatching 5");
        num_inst_dispatched = 5;
        dispatched_preg_dest_indices = {`NUM_PHYS_BITS'd3, `NUM_PHYS_BITS'd4, `NUM_PHYS_BITS'd7, `NUM_PHYS_BITS'd8, `NUM_PHYS_BITS'd10};
        dispatched_preg_old_dest_indices = {`NUM_PHYS_BITS'd17, `NUM_PHYS_BITS'd11, `NUM_PHYS_BITS'd12, `NUM_PHYS_BITS'd13, `NUM_PHYS_BITS'd14};
        dispatched_inst_valid = `N'b11111;
        print_debug_values();
        expected_n_successive_rob_rows = {`NUM_ROBS_BITS'd10,`NUM_ROBS_BITS'd9,`NUM_ROBS_BITS'd8,`NUM_ROBS_BITS'd7,`NUM_ROBS_BITS'd6};
        
        @(negedge clock);
        num_inst_dispatched = 0;
        print_debug_values();
        check_valid(n_successive_rob_rows, expected_n_successive_rob_rows);
        print_ROB(0,6);
        @(negedge clock);
        $display("Dispatching 4");
        num_inst_dispatched = 4;
        dispatched_preg_dest_indices = {`NUM_PHYS_BITS'd30, `NUM_PHYS_BITS'd31, `NUM_PHYS_BITS'd32, `NUM_PHYS_BITS'd33, `NUM_PHYS_BITS'd34};
        dispatched_preg_old_dest_indices = {`NUM_PHYS_BITS'd20, `NUM_PHYS_BITS'd21, `NUM_PHYS_BITS'd22, `NUM_PHYS_BITS'd23, `NUM_PHYS_BITS'd24};
        dispatched_inst_valid = `N'b01111;
        expected_n_successive_rob_rows = {`NUM_ROBS_BITS'd14,`NUM_ROBS_BITS'd13,`NUM_ROBS_BITS'd12,`NUM_ROBS_BITS'd11,`NUM_ROBS_BITS'd10};
        print_debug_values();
        @(negedge clock);
        num_inst_dispatched = 0;
        print_debug_values();
        check_valid(n_successive_rob_rows, expected_n_successive_rob_rows);
        print_debug_values();
        
        //print_ROB();*/
