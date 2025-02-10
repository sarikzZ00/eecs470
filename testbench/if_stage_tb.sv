module if_stage_tb;
    logic clock;              // system clock
    logic reset;              // system reset
    logic branch_mispredict_next_cycle;  // only go to next instruction when true
                                            // makes pipeline behave as single-cycle
    logic  [`N-1:0] num_to_fetch;  // taken-branch signal
    logic [`XLEN-1:0] branch_target;   // target pc: use if take_branch is TRUE
    logic [63:0] tb_mem [`MEM_64BIT_LINES - 1:0];     // Data coming back from instruction-memory

    IF_ID_PACKET [`N-1:0] if_packet_out; // Address sent to Instruction memory
    IF_ID_PACKET [`N-1:0] expected_if_packet_out; // Address sent to Instruction memory
    
    if_stage if1(
            .clock(clock), 
            .reset(reset), 
            .branch_mispredict_next_cycle(branch_mispredict_next_cycle), 
            .num_to_fetch(num_to_fetch),
            .branch_target(branch_target),
            .tb_mem(tb_mem),
            .if_packet_out(if_packet_out)                                    
        );
    
    always begin
        #10 clock = ~clock;
    end

    task exit_on_error;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $finish;
      end
    endtask;

    task check_if_packet_out;
        input IF_ID_PACKET [`N-1:0] if_packet_out;
        input IF_ID_PACKET [`N-1:0] expected_if_packet_out;
        foreach(if_packet_out[reg_index]) begin 
            if(if_packet_out[reg_index].valid != expected_if_packet_out[reg_index].valid) begin
                $display("Valid wrong at index:%d", reg_index);
                $display("Expected:%b", expected_if_packet_out[reg_index].valid);
                $display("Actual:%b", if_packet_out[reg_index].valid);
                exit_on_error();
            end

            if(if_packet_out[reg_index].inst[6:0] != expected_if_packet_out[reg_index].inst[6:0]) begin
                $display("Inst opcode wrong at index:%d", reg_index);
                $display("Expected opcode:%h", expected_if_packet_out[reg_index].inst[6:0]);
                $display("Actual opcode:%h", if_packet_out[reg_index].inst[6:0]);
                exit_on_error();
            end

            if(if_packet_out[reg_index].PC != expected_if_packet_out[reg_index].PC) begin
                $display("PC wrong at index:%d", reg_index);
                $display("Expected:%d", expected_if_packet_out[reg_index].PC);
                $display("Actual:%d", if_packet_out[reg_index].PC);
                exit_on_error();
            end

            if(if_packet_out[reg_index].NPC != expected_if_packet_out[reg_index].NPC) begin
                $display("NPC wrong at index:%d", reg_index);
                $display("Expected:%d", expected_if_packet_out[reg_index].NPC);
                $display("Actual:%d", if_packet_out[reg_index].NPC);
                exit_on_error();
            end
        end
    endtask;

    integer i;
    initial 
    begin 
        $readmemh("./program.mem", tb_mem);
        
        $display("rdata:");

        for (i=0; i < `N; i=i+1) begin
            $display("%d:%h",i,tb_mem[i]);
        end
    end
    
    always @(negedge clock) begin
        $display("##########");
        $display("Time: %4.0f", $time);
        $display("##########");
    end

    initial begin
        //TEST 0 
        clock = 0;
        reset = 1;
        @(negedge clock); //Time 20
        reset = 0;
        branch_mispredict_next_cycle = 0;
        num_to_fetch = 0;
        branch_target = 0;
        @(negedge clock); //Time 40
        expected_if_packet_out[0].valid = 0;
        expected_if_packet_out[0].NPC = 0;
        expected_if_packet_out[0].PC = 0;
        expected_if_packet_out[0].inst[6:0] = 0;
        #1;check_if_packet_out(if_packet_out, expected_if_packet_out);
        @(negedge clock); //Time 60

        $display("test1");
        //TEST 1
        branch_mispredict_next_cycle = 0;
        num_to_fetch = 1;
        branch_target = 0;
        expected_if_packet_out[0].valid = 1;
        expected_if_packet_out[0].NPC = 4;
        expected_if_packet_out[0].PC = 0;
        expected_if_packet_out[0].inst[6:0] = 7'b0010011;
        #1;check_if_packet_out(if_packet_out, expected_if_packet_out);
        @(negedge clock); //Time 80
        num_to_fetch = 2;
        branch_target = 0;
        expected_if_packet_out[0].valid = 1;
        expected_if_packet_out[0].NPC = 8;
        expected_if_packet_out[0].PC = 4;
        expected_if_packet_out[0].inst[6:0] = 'h37;

        expected_if_packet_out[1].valid = 1;
        expected_if_packet_out[1].NPC = 12;
        expected_if_packet_out[1].PC = 8;
        expected_if_packet_out[1].inst[6:0] = 'h13;

        #1;check_if_packet_out(if_packet_out, expected_if_packet_out);
        @(negedge clock); //Time 100
        num_to_fetch = 0;
        branch_target = 20;
        branch_mispredict_next_cycle = 1;
        @(negedge clock);
        num_to_fetch = 2;
        expected_if_packet_out[0].valid = 1;
        expected_if_packet_out[0].NPC = 24;
        expected_if_packet_out[0].PC = 20;
        expected_if_packet_out[0].inst[6:0] = 'h13;
        expected_if_packet_out[1].valid = 1;
        expected_if_packet_out[1].NPC = 28;
        expected_if_packet_out[1].PC = 24;
        expected_if_packet_out[1].inst[6:0] = 'h33;
        #1;check_if_packet_out(if_packet_out, expected_if_packet_out);
        @(negedge clock);
        $display("@@@Passed");
        $finish;
    end

endmodule
