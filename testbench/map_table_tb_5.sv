//TODO: Figure out if this actually overrides correctly:
`define N 5

module reservation_station_test;

    logic [`N-1:0] [31:0] opcode;
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_1;
    logic [`N-1:0] phys_reg_1_ready;
    CDB CDB_output;   
    logic clock;  
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_2; 
    logic [`N-1:0] phys_reg_2_ready;
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_dest;
    logic [`N-1:0] [`NUM_ROBS_BITS - 1:0] rob_ids;
    logic [$clog2(`N) - 1: 0] num_rows_input;           
    logic reset;            
    logic executestart;
    logic [$clog2(`N) - 1: 0] num_rows_logic;
    logic [$clog2(`NUM_ROWS) - 1:0] num_free_rows;
    logic [(`NUM_FUNC_UNIT_TYPES) - 1: 0] [31:0] num_fu_free;
    RESERVATION_ROW [`N-1:0] issued_rows;
    RESERVATION_ROW [`N-1:0] issued_rows_test;

    `ifdef DEBUG_OUT_RS 
      logic [`NUM_ROWS-1:0] ready_to_issue_debug;
      RESERVATION_ROW [`NUM_ROWS-1:0] rows_debug;
      logic [`N-1:0] [$clog2(`NUM_ROWS) - 1 : 0] not_busy_list_debug;
      logic [`N-1:0] [$clog2(`NUM_ROWS) - 1 : 0] ready_list_debug;
      logic signed [31:0] num_ready_to_issue_debug;
      logic signed [`NUM_ROWS - 1 : 0] [31:0] row_fu_available_debug;
      FUNC_UNITS [`NUM_ROWS - 1 : 0] row_fu_debug;
      logic [(`NUM_FUNC_UNIT_TYPES) - 1: 0] [31:0] current_avail_fus_debug;
    `endif
    

    
    reservation_station r5( .clock(clock), .reset(reset), .opcode(opcode), 
                            .phys_reg_1(phys_reg_1), .phys_reg_1_ready(phys_reg_1_ready), 
                            .phys_reg_2(phys_reg_2), .phys_reg_2_ready(phys_reg_2_ready),
                            .phys_reg_dest(phys_reg_dest),
                            .rob_ids(rob_ids),
                            .CDB_output(CDB_output), .num_rows_input(num_rows_input), .executestart(executestart),
                            .num_free_rows(num_free_rows), .num_fu_free(num_fu_free), .issued_rows(issued_rows)
                            `ifdef DEBUG_OUT_RS 
                              ,
                              .rows_debug(rows_debug),
                              .not_busy_list_debug(not_busy_list_debug),
                              .ready_list_debug(ready_list_debug),
                              .num_ready_to_issue_debug(num_ready_to_issue_debug),
                              .row_fu_debug(row_fu_debug),
                              .current_avail_fus_debug(current_avail_fus_debug)
                            `endif  
                            );
    integer i;
    integer k;
    logic correct;
    assign correct = `TRUE; //check if num_free_rows is equivalent to the expected free rows and that the all instructions are valid         
    
    integer rows_debug_index;
    integer not_busy_list_index;
    integer ready_list_index;
    integer row_fu_index;
    integer curr_avail_index;
    
    //Prints result if incorrect in combinational logic
    always_ff @(posedge clock) begin
      if(!correct) begin 
        $display("@@@Failed Incorrect at time %4.0f",$time);
        $finish;
      end
		end  
    
    task exit_on_error;
      input RESERVATION_ROW [`N-1:0] issued_rows;
      input RESERVATION_ROW [`N-1:0] issued_rows_correct;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $display("@@@ expected");
                  $finish;
      end
    endtask


    task print_debug;
      `ifdef DEBUG_OUT_RS 
            
            $display("rows_debug:");
            for (rows_debug_index = 0; rows_debug_index < `NUM_ROWS; rows_debug_index = rows_debug_index + 1) begin
              $display("Row Number %d", rows_debug_index);
              $display("Rob ID: %d\tDest Tag: %d\tTag 1: %d\tTag2: %d", 
              rows_debug[rows_debug_index].rob_id,
              rows_debug[rows_debug_index].tag_dest,
              rows_debug[rows_debug_index].tag_1,
              rows_debug[rows_debug_index].tag_2
              );
              $display("Tag 1 Ready: %b\tTag 2 Ready: %b\tBusy: %b\tFU: %d",
              rows_debug[rows_debug_index].ready_tag_1,
              rows_debug[rows_debug_index].ready_tag_2,
              rows_debug[rows_debug_index].busy,
              rows_debug[rows_debug_index].functional_unit
              );
              $display("");
            end

            $display("not_busy_list_debug:");
            for (not_busy_list_index = 0; not_busy_list_index < `N; not_busy_list_index = not_busy_list_index + 1) begin
              $display("%d\n", not_busy_list_debug[not_busy_list_index]);
            end

            $display("ready_list_debug:");
            for (ready_list_index = 0; ready_list_index < `N; ready_list_index = ready_list_index + 1) begin
              $display("%d\n", ready_list_debug[ready_list_index]);
            end

            $display("num_ready_to_issue: %d\n",num_ready_to_issue_debug);

            
            $display("curr_avail_fus:");  
            for (curr_avail_index = 0; curr_avail_index < `NUM_FUNC_UNIT_TYPES; curr_avail_index = curr_avail_index + 1) begin
              $display("Number of %d units free: %d\n",curr_avail_index,current_avail_fus_debug[curr_avail_index]);
            end
            /*
            for(row_fu_index = 0; row_fu_index < `NUM_ROWS; row_fu_index = row_fu_index+1) begin
              $display("Row Index: %d", row_fu_index);
              $display("row_fu: %d", row_fu_debug[row_fu_index]);
              $display("row_fu_available: %d", row_fu_available_debug[row_fu_index]);
              $display("");
            end
            */
          `endif 

    endtask

    task hard_reset;
        ///Resetting
        //opcode = {5{0}}; //Replicate "0" 5 times
        opcode = {0};
	phys_reg_1 = {`NUM_PHYS_BITS'b0};
        phys_reg_1_ready[0] = {`TRUE};
        phys_reg_2_ready[0] = {`TRUE};
        phys_reg_2 = {`NUM_PHYS_BITS'b0};
        phys_reg_dest = {`NUM_PHYS_BITS'b0};
        rob_ids = {`NUM_ROBS_BITS'b0};
        executestart = 0;
        num_rows_input = 0;
        CDB_output = 0;
        reset = 1;
    endtask

    task check_internal_rows;
      $display("");
    endtask

    task compare_correct;
      input RESERVATION_ROW [`N-1:0] issued_rows;
      input RESERVATION_ROW [`N-1:0] issued_rows_correct;

      print_debug();
      for (i = 0; i < `N; i = i + 1) begin
        
        if (issued_rows[i] != issued_rows_correct[i]) begin
          $display("Issued Row Number: %d", i);
          $display("Issued Row Correct");
          $display("Rob ID: %d\tDest Tag: %d\tTag 1: %d\tTag2: %d", 
              issued_rows_correct[i].rob_id,
              issued_rows_correct[i].tag_dest,
              issued_rows_correct[i].tag_1,
              issued_rows_correct[i].tag_2
              );
          $display("Tag 1 Ready: %b\tTag 2 Ready: %b\tBusy: %b\tFU: %b",
              issued_rows_correct[i].ready_tag_1,
              issued_rows_correct[i].ready_tag_2,
              issued_rows_correct[i].busy,
              issued_rows_correct[i].functional_unit
              );
          $display("");
          $display("Incorrect Row");
         $display("Rob ID: %d\tDest Tag: %d\tTag 1: %d\tTag2: %d", 
              issued_rows[i].rob_id,
              issued_rows[i].tag_dest,
              issued_rows[i].tag_1,
              issued_rows[i].tag_2
              );
          $display("Tag 1 Ready: %b\tTag 2 Ready: %b\tBusy: %b\tFU:%b",
              issued_rows[i].ready_tag_1,
              issued_rows[i].ready_tag_2,
              issued_rows[i].busy,
              issued_rows[i].functional_unit
              );
          $display("");

          for (k = 0; k < `N; k = k + 1) begin
              $display("k=%d", k);
              $display("issued: %b", issued_rows[k]);
              $display("correct: %b", issued_rows_correct[k]);
              $display("");
          end

          

          exit_on_error( issued_rows, issued_rows_correct );
        end
      end
      //$display("%h", ready_to_issue_debug);
      //$display("%h", rows_debug);
    endtask




    always begin
        #10 clock = ~clock;
    end
    
    always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
        #1;
        $display("opcode:%h num_free_rows:%d\n", opcode, num_free_rows);
    end



    integer fu_types;
    integer fu_free_index;
    FUNC_UNITS fu_temp;
    integer test_1_issued_index;
    initial begin
        $display("STARTING TESTBENCH!");
        //Initial State where we pass in noop values into the pipeline and the pipeline is in reset
        clock = 0;
        hard_reset(); //Also sets 'reset' to 1
        @(negedge clock);
        reset = 0;

        @(negedge clock);
        // now the reservation station is clear
        $display("RESERVATION STATION IS CLEARED!");
        compare_correct(issued_rows, {{1'b0}});

        @(negedge clock);
        compare_correct(issued_rows, {{1'b0}});
        reset = 1;
        @(negedge clock);

// TEST 1
// check that a ready instruction can be issued
        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("STARTING TEST 1!");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");

        


        executestart = 0;
        num_rows_input = 5;
        CDB_output = 0;
        reset = 0;
        
        for (fu_free_index = 0; fu_free_index < `NUM_FUNC_UNIT_TYPES; fu_free_index = fu_free_index+1) begin
          num_fu_free[fu_free_index] = 10;
        end

        $display("num_fu_free:");  
        for (fu_types = 0; fu_types < `NUM_FUNC_UNIT_TYPES; fu_types = fu_types + 1) begin
          fu_temp = fu_types;
          $display("Number of %s units free: %d\n",fu_temp.name(),num_fu_free[fu_types]);
        end


        opcode = {`RV32_ADD, `RV32_ADD, `RV32_ADD, `RV32_ADD, `RV32_ADD};
        // $display("`RV32_ADD is: %b", `RV32_ADD);
        // $display("`RV32_MUL is: %b", `RV32_MUL);
        // $display("opcode[0]: %b", opcode[0]);
        // $display("`RV32_ADD[31:25] is: %b", `RV32_ADD[31:25]);


        phys_reg_1 = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
        phys_reg_2 = {`NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0, `NUM_PHYS_BITS'd0};
        phys_reg_1_ready = {`TRUE, `TRUE, `TRUE, `TRUE, `TRUE};
        phys_reg_2_ready = {`TRUE, `TRUE, `TRUE, `TRUE, `TRUE};
        rob_ids = {`NUM_ROBS_BITS'd0, `NUM_ROBS_BITS'd1, `NUM_ROBS_BITS'd2, `NUM_ROBS_BITS'd3, `NUM_ROBS_BITS'd4};
        /*CDB_output.phys_regs[0] = `NUM_PHYS_BITS'd19; // junk value
        CDB_output.valid[0] = 1'b0;*/
        phys_reg_dest = {`NUM_PHYS_BITS'd1, `NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd3, `NUM_PHYS_BITS'd4, `NUM_PHYS_BITS'd5};

        for (test_1_issued_index = 0; test_1_issued_index < `N; test_1_issued_index = test_1_issued_index + 1) begin
          issued_rows_test[test_1_issued_index].rob_id = (`N - test_1_issued_index) - 1;
          issued_rows_test[test_1_issued_index].tag_dest = `N - test_1_issued_index;
          issued_rows_test[test_1_issued_index].tag_1 = `NUM_PHYS_BITS'd0;
          issued_rows_test[test_1_issued_index].tag_2 = `NUM_PHYS_BITS'd0;
          issued_rows_test[test_1_issued_index].ready_tag_1 = `TRUE;
          issued_rows_test[test_1_issued_index].ready_tag_2 = `TRUE;
          issued_rows_test[test_1_issued_index].busy = `TRUE;
          issued_rows_test[test_1_issued_index].functional_unit = ALU;
        end
        $display("Same Cycle");
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        num_rows_input = 0; //Make sure we only pass in the instruction once.
        $display("1 after");
        // the dispatched instruction needs to be in the RS for at least one cycle
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        $display("2 after");
        // now the instruction should be issued 
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        $display("3 after");
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        @(negedge clock);
        $display("");
        $display("");
        $display("");
        
        $display("@@@PASSED");
        $finish;
    end
endmodule
