
`define N 2
module reservation_station_test_2; 
    logic [`N-1:0] [31:0] opcode;
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_1;
    logic [`N-1:0] phys_reg_1_ready;
    CDB CDB_output;   
    logic clock;  
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_2; 
    logic [`N-1:0] phys_reg_2_ready;
    logic [`N-1:0] [`NUM_PHYS_BITS - 1:0] phys_reg_dest;
    logic [`N-1:0] [`NUM_ROBS_BITS - 1:0] rob_ids;
    logic [$clog2(`N + 1) - 1: 0] num_rows_input;           
    logic reset;            
    logic executestart;
    logic [$clog2(`N + 1) - 1: 0] num_rows_logic;
    logic [$clog2(`NUM_ROWS):0] num_free_rows;
    logic [(`NUM_FUNC_UNIT_TYPES) - 1: 0] [31:0] num_fu_free;
    RESERVATION_ROW [`N-1:0] issued_rows;
    RESERVATION_ROW [`N-1:0] issued_rows_test;
    ID_EX_PACKET [`N-1:0] inst_info;
    logic [`N-1:0][`XLEN-1:0] rda_out;
    logic [`N-1:0][`XLEN-1:0] rdb_out;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rda_idx;
    logic [`N-1:0][`NUM_PHYS_BITS-1:0]       rdb_idx;
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
    

    
    reservation_station r1( .clock(clock), .reset(reset), .opcode(opcode), 
                            .phys_reg_1(phys_reg_1), .phys_reg_1_ready(phys_reg_1_ready), 
                            .phys_reg_2(phys_reg_2), .phys_reg_2_ready(phys_reg_2_ready),
                            .phys_reg_dest(phys_reg_dest),
                            .rob_ids(rob_ids),
                            .CDB_output(CDB_output), .num_rows_input(num_rows_input), .inst_info(inst_info),
                            .num_free_rows(num_free_rows), .num_fu_free(num_fu_free), .issued_rows(issued_rows),
                            .rda_out(rda_out),.rdb_out(rdb_out),.rda_idx(rda_idx),.rdb_idx(rdb_idx)
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
            for (not_busy_list_index = 0; not_busy_list_index < $clog2(`NUM_ROWS); not_busy_list_index = not_busy_list_index + 1) begin
              $display("%d\n", not_busy_list_debug[not_busy_list_index]);
            end

            $display("ready_list_debug:");
            for (ready_list_index = 0; ready_list_index < $clog2(`NUM_ROWS); ready_list_index = ready_list_index + 1) begin
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
        // check that 2 instructions that ready instruction can be issued
        // 0 + 0 =  7
        // 1 + 1 = 8
        $display(" ");
        $display("$$$$$$$$$$$$$$$$");
        $display("STARTING TEST 1!");
        $display("$$$$$$$$$$$$$$$$");
        $display(" ");
        executestart = 0;
        num_rows_input = 2;
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

        opcode = {`RV32_ADD,`RV32_ADD};
        phys_reg_1 = {`NUM_PHYS_BITS'd1, `NUM_PHYS_BITS'd0};
        phys_reg_2 = {`NUM_PHYS_BITS'd1, `NUM_PHYS_BITS'd0};
        phys_reg_1_ready = {`TRUE, `TRUE};
        phys_reg_2_ready = {`TRUE, `TRUE};
        rob_ids = {`NUM_ROBS_BITS'd1, `NUM_ROBS_BITS'd0};
        phys_reg_dest = {`NUM_PHYS_BITS'd8, `NUM_PHYS_BITS'd7};

        issued_rows_test[0].rob_id      = 0;
        issued_rows_test[0].tag_dest    = 7;
        issued_rows_test[0].tag_1       = 0;
        issued_rows_test[0].tag_2       = 0;
        issued_rows_test[0].ready_tag_1 = 1;
        issued_rows_test[0].ready_tag_2 = 1;
        issued_rows_test[0].busy        = 1; 
        issued_rows_test[0].functional_unit = ALU;

        issued_rows_test[1].rob_id      = 1;
        issued_rows_test[1].tag_dest    = 8;
        issued_rows_test[1].tag_1       = 1;
        issued_rows_test[1].tag_2       = 1;
        issued_rows_test[1].ready_tag_1 = 1;
        issued_rows_test[1].ready_tag_2 = 1;
        issued_rows_test[1].busy        = 1; 
        issued_rows_test[1].functional_unit = ALU;
        
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        num_rows_input = 0; //Make sure we only pass in the instruction once.

        // the dispatched instruction needs to be in the RS for at least one cycle
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        // now the instruction should be issued 
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        $display("");
        $display("");
        $display("");
        

        // TEST 2
        // Phys regs have a dependancy
        //  9 =  2 + 7
        //  10 =  8 - 2  
        @(negedge clock);
        @(negedge clock);
        $display("$$$$$$$$$$$$$$$$");
        $display("STARTING TEST 2!");
        $display("$$$$$$$$$$$$$$$$");
        num_rows_input = 2;

        opcode = {`RV32_SUB, `RV32_ADD};
        phys_reg_1 = {`NUM_PHYS_BITS'd8, `NUM_PHYS_BITS'd2};
        phys_reg_2 = {`NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd7};
        phys_reg_1_ready = {`TRUE, `TRUE};
        phys_reg_2_ready = {`TRUE, `TRUE};
        phys_reg_dest = {`NUM_PHYS_BITS'd10, `NUM_PHYS_BITS'd9};
        rob_ids = {`NUM_ROBS_BITS'd4, `NUM_ROBS_BITS'd3};


        issued_rows_test[0].rob_id      = 3;
        issued_rows_test[0].tag_dest    = 9;
        issued_rows_test[0].tag_1       = 2;
        issued_rows_test[0].tag_2       = 7;
        issued_rows_test[0].ready_tag_1 = 1;
        issued_rows_test[0].ready_tag_2 = 1;
        issued_rows_test[0].busy        = 1; 
        issued_rows_test[0].functional_unit = ALU;

        issued_rows_test[1].rob_id      = 4;
        issued_rows_test[1].tag_dest    = 10;
        issued_rows_test[1].tag_1       = 8;
        issued_rows_test[1].tag_2       = 2;
        issued_rows_test[1].ready_tag_1 = 1;
        issued_rows_test[1].ready_tag_2 = 1;
        issued_rows_test[1].busy        = 1; 
        issued_rows_test[1].functional_unit = ALU;
        
        @(negedge clock);
        num_rows_input = 0; //Make sure we only pass in the instruction once.
        // now the instruction should be issued 
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);

        // both rows should be stored
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        $display("");
        $display("");
        $display("");

        hard_reset(); //Also sets 'reset' to 1
        @(negedge clock);
        reset = 0;
        issued_rows_test[0] = `EMPTY_RES_ROW;
        issued_rows_test[1] = `EMPTY_RES_ROW;
        @(negedge clock);
        // now the reservation station is clear
        $display("RESERVATION STATION IS CLEARED!");
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        compare_correct(issued_rows, {{1'b0}});
        reset = 1;
        @(negedge clock);
        
        
        
        // TEST dependent instructions to wait for CDB
        // 7 = 2 + 3
        // 8 = 7 && 2
        $display("$$$$$$$$$$$$$$$$");
        $display("STARTING TEST 3!");
        $display("$$$$$$$$$$$$$$$$");
        executestart = 0;
        num_rows_input = 2;
        CDB_output = 0;
        reset = 0;

        opcode = {`RV32_AND, `RV32_ADD};
        phys_reg_1 = {`NUM_PHYS_BITS'd7, `NUM_PHYS_BITS'd2};
        phys_reg_2 = {`NUM_PHYS_BITS'd2, `NUM_PHYS_BITS'd3};
        phys_reg_1_ready = {`FALSE, `TRUE};
        phys_reg_2_ready = {`TRUE, `TRUE};
        phys_reg_dest = {`NUM_PHYS_BITS'd8,`NUM_PHYS_BITS'd7};
        rob_ids = {`NUM_ROBS_BITS'd1, `NUM_ROBS_BITS'd0};

        #5; compare_correct(issued_rows, {{1'b0}});


        @(negedge clock);
        num_rows_input = 0; 



        compare_correct(issued_rows, {{1'b0}});
        // now the instruction should be issued 

        @(negedge clock);
        $display("Got here");

        issued_rows_test[0].rob_id      = 0;
        issued_rows_test[0].tag_dest    = 7;
        issued_rows_test[0].tag_1       = 2;
        issued_rows_test[0].tag_2       = 3;
        issued_rows_test[0].ready_tag_1 = 1;
        issued_rows_test[0].ready_tag_2 = 1;
        issued_rows_test[0].busy        = 1; 
        issued_rows_test[0].functional_unit = ALU;
        #5; compare_correct(issued_rows, issued_rows_test);
 


        @(negedge clock);
        $display("Checking for print");

        issued_rows_test[0] = {{1'b0}};

        #5;compare_correct(issued_rows, issued_rows_test);
        // now the instruction should be issued 

        @(negedge clock);
        CDB_output.valid[0] = `TRUE;
        CDB_output.phys_regs[0] = 7;





        #5; compare_correct(issued_rows, issued_rows_test);
        /*@(negedge clock);
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        
        // nothing should have changed until 9 is broadcast on the CDB
        compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);

        // Now the dependent instruction can issue
        compare_correct(issued_rows, {{1'b0}});*/


        @(negedge clock);
        compare_correct(issued_rows, {{1'b0}});
        @(negedge clock);
        issued_rows_test[0].rob_id      = 1;
        issued_rows_test[0].tag_dest    = 8;
        issued_rows_test[0].tag_1       = 7;
        issued_rows_test[0].tag_2       = 2;
        issued_rows_test[0].ready_tag_1 = 1;
        issued_rows_test[0].ready_tag_2 = 1;
        issued_rows_test[0].busy        = 1; 
        issued_rows_test[0].functional_unit = ALU;
        #5;compare_correct(issued_rows, issued_rows_test);
        @(negedge clock);
        @(negedge clock);
        $display("@@@PASSED");
        $finish;
    end


endmodule
