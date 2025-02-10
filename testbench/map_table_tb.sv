module map_table_test;

    // NOTE: This test does not work unless "DEBUG_OUT_MAP_TABLE" is defined.
    // NOTE: Assumes that N <= 10

    // This will test map_table for any N.

    //Inputs
    logic clock;
    logic reset;
	logic [`N-1:0] [`NUM_ARCH_BITS - 1:0] reg_dest;
	logic [`N-1 : 0] [`NUM_PHYS_BITS - 1 : 0] first_n_free_reg;
	PHYS_ARCH_PAIR reg_dest_complete [`N-1:0];  // architectural registers


    //Outputs
    MAP_TABLE_ENTRY  map_table [`NUM_REGISTERS - 1 : 0];

    `ifdef DEBUG_OUT_MAP_TABLE
        MAP_TABLE_ENTRY  map_table_next [`NUM_REGISTERS - 1 : 0];
    `endif 


    //Expected Outputs
    MAP_TABLE_ENTRY  expected_map_table [`NUM_REGISTERS - 1 : 0];

    `ifdef DEBUG_OUT_MAP_TABLE
        MAP_TABLE_ENTRY  expected_map_table_next [`NUM_REGISTERS - 1 : 0];
    `endif 




    map_table m1(
        //Inputs
        .clock(clock),
        .reset(reset),
        .reg_dest(reg_dest),
        .first_n_free_reg(first_n_free_reg),
        .reg_dest_complete(reg_dest_complete),

        //Outputs
        .map_table(map_table)
        `ifdef DEBUG_OUT_MAP_TABLE
            ,
            .map_table_next_debug(map_table_next)
        `endif  
    );

    task exit_on_error;
      begin
                  $display("@@@ Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $finish;
      end
    endtask

    task print_map_table;
        input MAP_TABLE_ENTRY map_table [`NUM_REGISTERS - 1 : 0];
            foreach(map_table[comp_index]) begin
                if (map_table[comp_index].ready)
                    $display("+\t%d", map_table[comp_index].phys_reg);
                else
                    $display(" \t%d", map_table[comp_index].phys_reg);
            end
 
    endtask


        integer reg_index;
    integer compare_map_table_index;
    task compare_map_table;
        input MAP_TABLE_ENTRY map_table [`NUM_REGISTERS - 1 : 0];
        input MAP_TABLE_ENTRY  expected_map_table [`NUM_REGISTERS - 1 : 0];
        foreach(map_table[k]) begin
            if (map_table[k].phys_reg != expected_map_table[k].phys_reg
                || map_table[k].ready != expected_map_table[k].ready) begin
                $display("MAP TABLE incorrect.");
                $display("Expected: ");
                print_map_table(expected_map_table);

                $display("");
                $display("Actual: ");
                print_map_table(map_table);

                exit_on_error();
            end
        end
    endtask

    integer reset_index;
    task hard_reset;
        $display("RESETTING!");

        reset = 1;
        reg_dest = 0;
        foreach(reg_dest_complete[m]) begin
            reg_dest_complete[m].phys = 0;
            reg_dest_complete[m].arch = 0;
        end
        first_n_free_reg = 0;
        $display("DONE RESETTING!");

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
    integer i2, i3, i4, i5, i6, i7, i8;
    integer J;
    initial begin
        $display("STARTING TESTBENCH!");
        //Initial State where we pass in noop values into the pipeline and the pipeline is in reset
        clock = 0;
        hard_reset(); //Also sets 'reset' to 1
        @(negedge clock);
        @(negedge clock);


        //Set inputs
        reset = 0;

        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("Setting Starting Values");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");


        $display("TESTING: filling map table");

    // NOTE: we might change reset conditions
        foreach(expected_map_table[i]) begin
            expected_map_table[i].ready = `FALSE;
            expected_map_table[i].phys_reg = 0;
        end 

        for(J=0; J <= $floor(`NUM_REGISTERS / `N); J = J+1) begin

            @(negedge clock)

            if (J < $floor(`NUM_REGISTERS / `N)) begin
                foreach(first_n_free_reg[i]) begin
                    first_n_free_reg[i] = J*`N + i + 1;  
                    reg_dest[i] = J*`N + i + 1;
                end
            end
            else begin 
                foreach(reg_dest[i]) begin
                    reg_dest[i] = 0;
                end
            end



            foreach(expected_map_table[i]) begin
                expected_map_table[i].ready = `FALSE;
                if (i >= (J-1) * `N && i < J * `N) begin
                    expected_map_table[i + 1].phys_reg =  i + 1;
                end
            end

            compare_map_table(map_table, expected_map_table);
            print_map_table(map_table);
        end
       

        $display("Map Table filled");

        @(negedge clock)


        $display("TESTING: setting ready bits");
  
        compare_map_table(map_table, expected_map_table);
        print_map_table(map_table);

        for(J=0; J <= $floor(`NUM_REGISTERS / `N); J = J+1) begin


            foreach(reg_dest_complete[i]) begin
                reg_dest_complete[i].phys = `NUM_REGISTERS - (J*`N + i + 1);  
                reg_dest_complete[i].arch = J*`N + i + 1;  
                if (J*`N + i + 1 == 16) begin 
                    expected_map_table[16].ready = `TRUE;  
                end
            end

            @(negedge clock)
            compare_map_table(map_table, expected_map_table);
            print_map_table(map_table);
        end
 



        $display("@@@ PASSED");
        $display("For N = %d", `N);
        $finish;

    end


endmodule 
