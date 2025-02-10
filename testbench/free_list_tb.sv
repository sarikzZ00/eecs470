module free_list_test;

    //NOTE: This test does not work unless "DEBUG_OUT_FREE_LIST" is defined.

    //This will test free_list for any superscalar number.

    //Inputs
    logic clock;
    logic reset;
    logic [31:0] number_free_regs_used;
    logic [31:0] num_retired;
    logic [`N - 1 : 0] [`NUM_PHYS_BITS - 1: 0] retired_list;

    
    //Outputs
    logic [`N - 1 : 0] [`NUM_PHYS_BITS - 1 : 0] first_n_free_regs;
    logic [`NUM_PHYS_REGS-1 : 0] free_list;
    logic [`NUM_PHYS_REGS-1 : 0] free_list_next;

    //Expected Outputs
    logic [`N - 1 : 0] [`NUM_PHYS_BITS - 1 : 0] expected_first_n_free_regs;
    logic [`NUM_PHYS_REGS-1 : 0] expected_free_list;
    logic [`NUM_PHYS_REGS-1 : 0] expected_free_list_next;
    logic branch_mispredict_this_cycle;
    logic [`NUM_PHYS_REGS-1:0] arch_reg_free_list;

    free_list f1(
        //Inputs
        .clock(clock),
        .reset(reset),
        .number_free_regs_used(number_free_regs_used),
        .num_retired(num_retired),
        .retired_list(retired_list),
        .branch_mispredict_this_cycle(branch_mispredict_this_cycle),
        .arch_reg_free_list(arch_reg_free_list),

        //Outputs
        .first_n_free_regs(first_n_free_regs),
        .free_list_debug(free_list),
        .free_list_next_debug(free_list_next)
    );

    task exit_on_error;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $finish;
      end
    endtask

    integer compare_first_n_index;
    integer compare_first_n_index_2;
    integer compare_first_n_index_3;
    task compare_first_n_free_regs;
        input [`N - 1 : 0] [`NUM_PHYS_BITS - 1 : 0] first_n_free_regs;
        input [`N - 1 : 0] [`NUM_PHYS_BITS - 1 : 0] expected_first_n_free_regs;
        for (compare_first_n_index = 0; compare_first_n_index < `N; compare_first_n_index = compare_first_n_index + 1) begin
            if (first_n_free_regs[compare_first_n_index] != expected_first_n_free_regs[compare_first_n_index]) begin
                $display("first_n_free_regs incorrect.");
                $display("Expected: ");
                for (compare_first_n_index_2 = 0; compare_first_n_index_2 < `N; compare_first_n_index_2 = compare_first_n_index_2 + 1) begin
                    $display("\t%d", expected_first_n_free_regs[compare_first_n_index_2]);
                end
                $display("");
                $display("Actual: ");
                for (compare_first_n_index_3 = 0; compare_first_n_index_3 < `N; compare_first_n_index_3 = compare_first_n_index_3 + 1) begin
                    $display("\t%d", first_n_free_regs[compare_first_n_index_3]);
                end

                exit_on_error();
            end
        end
    endtask

    integer compare_free_list_index;
    integer compare_free_list_index_2;
    integer compare_free_list_index_3;
    task compare_free_list;
        input [`NUM_PHYS_REGS-1 : 0] free_list;
        input [`NUM_PHYS_REGS-1 : 0] expected_free_list;
        for (compare_free_list_index = 0; compare_free_list_index < `N; compare_free_list_index = compare_free_list_index + 1) begin
            if (free_list[compare_free_list_index] != expected_free_list[compare_free_list_index]) begin
                $display("free_list incorrect.");
                $display("Expected: ");
                for (compare_free_list_index_2 = 0; compare_free_list_index_2 < `NUM_PHYS_REGS-1; compare_free_list_index_2 = compare_free_list_index_2 + 1) begin
                    $display("\t%d", expected_free_list[compare_free_list_index_2]);
                end
                $display("");
                $display("Actual: ");
                for (compare_free_list_index_3 = 0; compare_free_list_index_3 < `NUM_PHYS_REGS-1; compare_free_list_index_3 = compare_free_list_index_3 + 1) begin
                    $display("\t%d", free_list[compare_free_list_index_3]);
                end

                exit_on_error();
            end
        end
    endtask

    integer reset_index;
    task hard_reset;
        reset = 1;
        number_free_regs_used = 0;
        num_retired = 0;

        for (reset_index = 0; reset_index < `N; reset_index = reset_index + 1) begin
            retired_list[reset_index] = 0;
        end

        foreach (arch_reg_free_list[a_idx]) begin 
            arch_reg_free_list[a_idx] = 0;
        end

        branch_mispredict_this_cycle = 0;
    endtask


    always begin
        #10 clock = ~clock;
    end

    always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
    end

    integer test_1_index;
    integer i2, i3, i4, i5, i6, i7, i8, i9,i10;
    initial begin
        $display("STARTING TESTBENCH!");
        //Initial State where we pass in noop values into the pipeline and the pipeline is in reset
        clock = 0;
        hard_reset(); //Also sets 'reset' to 1
        @(negedge clock);

        //Set inputs
        reset = 0;
        number_free_regs_used = 0;
        num_retired = 0;
        retired_list = {0};


        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Setting Starting Values");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Set expected outputs
        expected_free_list[0] = `FALSE; //REG0 should never be free
        for (test_1_index = 1; test_1_index < `NUM_PHYS_REGS; test_1_index = test_1_index + 1) begin
            expected_free_list[test_1_index] = `TRUE;
        end

        for (i2 = 0; i2 < `N; i2 = i2 + 1) begin
            expected_first_n_free_regs[i2] = i2 + 1;
        end

        

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);


        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing \"Popping\"");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Test "Popping" off the free list
        @(negedge clock)

        number_free_regs_used = `N;

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)

        for (i3 = 0; i3 < `N; i3 = i3 + 1) begin
            expected_first_n_free_regs[i3] = i3 + 1 + `N;
            expected_free_list[i3 + 1] = `FALSE;
        end
        

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)

        number_free_regs_used = 0;

        for (i4 = 0; i4 < `N; i4 = i4 + 1) begin
            expected_first_n_free_regs[i4] = i4 + 1 + (2 * `N);
            expected_free_list[i4 + 1 + `N] = `FALSE;
        end

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing Retiring");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Test retiring back onto the free list
        @(negedge clock)
        num_retired = `N;

        for (i5 = 0; i5 < `N; i5 = i5 + 1) begin
            retired_list[i5] = i5 + 1; //Retire the first N registers
        end
        

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing Both");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Test retiring and popping at the same time
        @(negedge clock)

        for (i6 = 0; i6 < `N; i6 = i6 + 1) begin
            //We've added the first N registers back into the free list
            expected_first_n_free_regs[i6] = i6 + 1;
            expected_free_list[i6 + 1] = `TRUE;

            //Retire the next N registers
            retired_list[i6] = i6 + 1 + `N;
        end

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        number_free_regs_used = `N;


        @(negedge clock)
        //We've added the second N registers back into the free list, and also popped the first N.
        for (i7 = 0; i7 < `N; i7 = i7 + 1) begin
            //We've added the second N registers back into the free list; first N have been popped
            expected_first_n_free_regs[i7] = i7 + 1 + `N;
            expected_free_list[i7 + 1] = `FALSE;
            expected_free_list[i7 + 1 + `N] = `TRUE;


            //Retire the first N registers again
            retired_list[i7] = i7 + 1;
        end

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);


        @(negedge clock)
        //We've added the first N registers back into the free list, and also popped the second N.
        for (i8 = 0; i8 < `N; i8 = i8 + 1) begin
            //We've added the first N registers back into the free list; second N have been popped
            expected_first_n_free_regs[i8] = i8 + 1;
            expected_free_list[i8 + 1] = `TRUE;
            expected_free_list[i8 + 1 + `N] = `FALSE;
        end

        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        num_retired = 0;
        number_free_regs_used = 0;

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);
        
        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing num_retired = 0");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Make sure changing the retired list while num_retired = 0 doesn't change anything
        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);
        retired_list = {1};

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);
        retired_list = {2};

        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing retiring REG0");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        //Make sure retiring REG0 doesn't do anything
        @(negedge clock)
        retired_list = {0};
        num_retired = `N;
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)
        num_retired = 0;
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);

        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Testing branch mispredict");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");

        @(negedge clock)
        hard_reset(); //Also sets 'reset' to 1

        @(negedge clock)
        reset = 0;
        for (i9 = 0; i9 < `N; i9 = i9 + 1) begin
            retired_list[i9] = i9+1;
            expected_first_n_free_regs[i9] = i9 + 3;
        end

        //assuming arbitrary values in arch reg since we are just trying to test
        //if on branch mispredict it correctly ignores retired_list and instead goes
        //off of arch_reg_free_list, only requirement for arch_reg_free_list
        //is that arch_reg_free_list[0] = 0 because this should be enforced in
        //dispatch


        branch_mispredict_this_cycle = 1;
        for (i10 = 0; i10 < `NUM_PHYS_REGS; i10 = i10 + 1) begin
            if(i10 == 0 || i10 == 1 || i10 == 2) begin 
                arch_reg_free_list[i10] = 0;
                expected_free_list[i10] = 0;
            end else begin 
                arch_reg_free_list[i10] = 1;
                expected_free_list[i10] = 1;
            end
        end


        @(negedge clock)
        compare_first_n_free_regs(first_n_free_regs, expected_first_n_free_regs);
        compare_free_list(free_list, expected_free_list);


        $display("@@@PASSED");
        $display("For N = %d", `N);
        $finish;


    end


endmodule
