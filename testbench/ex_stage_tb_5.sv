
`include "ISA.svh"
`include "sys_defs.svh"

// N = 5, 
// Need to check for branch_condition

module ex_stage_new_test;

    logic clock;
    logic reset;
    //logic RESERVATION_ROW [`N-1:0] dispatched_rows;
    logic [`N-1:0] [`XLEN-1:0] rs1_value;
    logic [`N-1:0] [`XLEN-1:0] rs2_value;
    logic [`N-1:0] alu_start;
	logic [`N-1:0] mult_start;

    ALU_OPA_SELECT opa_select [0:`N-1];
    ALU_OPB_SELECT opb_select [0:`N-1];
    ALU_FUNC alu_func [0:`N-1];

   EX_CP_PACKET ex_packet_out  [0:`N-1];
   EX_CP_PACKET ex_packet_out_correct [0:`N-1];

    ex_stage_new ex1 (.clock(clock), .reset(reset),  
                      .rs1_value(rs1_value), .rs2_value(rs2_value), .alu_start(alu_start), .mult_start(mult_start),
                       .opa_select(opa_select), .opb_select(opb_select), .alu_func(alu_func), 
                       .ex_packet_out(ex_packet_out));


    always begin
        #10 clock = ~clock;
    end

    task exit_on_error;
      begin
                  $display("@@@Failed",$time);
                  $display("@@@ Incorrect at time %4.0f", $time);
                  $display("@@@ Time:%4.0f clock:%b", $time, clock);
                  $display("@@@ expected");
                  $finish;
      end
    endtask

    integer i, j, k;

    task print_out_FUs;
        input EX_CP_PACKET ex_packet_out [0:`N-1];
        $display("Current ALU FUs status");
        foreach (ex_packet_out[i]) begin
            $display("Result = %d, FU done = %b", ex_packet_out[i].result, ex_packet_out[i].done);
        end
    endtask

    task check_correct;
        input EX_CP_PACKET ex_packet_out [`N-1:0];
        input EX_CP_PACKET ex_packet_out_correct [`N-1:0];
            foreach (ex_packet_out[j]) begin
                if (ex_packet_out[j].result != ex_packet_out_correct[j].result
                    || ex_packet_out[j].done != ex_packet_out_correct[j].done) begin
                        $display("EX is incorrect");
                        $display("Expected : ");
                        print_out_FUs(ex_packet_out_correct);

                        $display("");
                        $display("Actual: ");
                        print_out_FUs(ex_packet_out);

                        exit_on_error();

                    end

            end

    endtask



        initial begin
            $display("STARTING TESTBENCH!");
            clock = 0;

            
        // TEST 1, 5 ADDS (N = 5)

            reset = 1;

            @(negedge clock);
            @(negedge clock);


            reset = 0;


            ex_packet_out_correct[0].result = 32'd50; // 20 + 30 = 50
            ex_packet_out_correct[1].result = 32'd90; // 40 + 50 = 90
            ex_packet_out_correct[2].result = 32'd13; // 6 + 7 = 13
            ex_packet_out_correct[3].result = 32'd7;  // 8 - 1 = 7
            ex_packet_out_correct[4].result = 32'hA0000000;
 
            opa_select[0] = 2'h0;
            opa_select[1] = 2'h0;
            opa_select[2] = 2'h0;
            opa_select[3] = 2'h0;
            opa_select[4] = 2'h0;

            opb_select[0] = 4'h0;
            opb_select[1] = 4'h0;
            opb_select[2] = 4'h0;
            opb_select[3] = 4'h0;   
            opb_select[4] = 4'h0;

            alu_func[0] = ALU_ADD;
            alu_func[1] = ALU_ADD;
            alu_func[2] = ALU_ADD;
            alu_func[3] = ALU_SUB;
            alu_func[4] = ALU_AND;

            rs1_value[0] = 32'd20;
            rs1_value[1] = 32'd40;
            rs1_value[2] = 32'd6;
            rs1_value[3] = 32'd8;
            rs1_value[4] = 32'hA000000A;

            rs2_value[0] = 32'd30;
            rs2_value[1] = 32'd50;
            rs2_value[2] = 32'd7;
            rs2_value[3] = 32'd1;
            rs2_value[4] = 32'hA00000A0;

            alu_start[0] = 1'b1;
            alu_start[1] = 1'b1;
            alu_start[2] = 1'b1;
            alu_start[3] = 1'b1;
            alu_start[4] = 1'b1;
            

            mult_start[0] = 1'b0;
            mult_start[1] = 1'b0;
            mult_start[2] = 1'b0;
            mult_start[3] = 1'b0;
            mult_start[4] = 1'b0;
            

            @(negedge clock);
            @(negedge clock);

            check_correct(ex_packet_out, ex_packet_out_correct);

        


        // TEST 2, 5 MULS
            reset = 1;

            @(negedge clock);
            @(negedge clock);


            reset = 0;


            ex_packet_out_correct[0].result = 32'd56; // 7 * 8 = 56
            ex_packet_out_correct[1].result = 32'h00000010; // MULH: 0x0008,0000
                                                      //       0x0002,0000
                                                      //     = 0x0000,0016
            ex_packet_out_correct[2].result = 32'd10; // 5 * (2) = 10
            ex_packet_out_correct[3].result = 32'd3216;  // 48 * 67 = 3216
            ex_packet_out_correct[4].result = 32'd1000; // 100 * 10 = 1000
 
            opa_select[0] = 2'h0;
            opa_select[1] = 2'h0;
            opa_select[2] = 2'h0;
            opa_select[3] = 2'h0;
            opa_select[4] = 2'h0;

            opb_select[0] = 4'h0;
            opb_select[1] = 4'h0;
            opb_select[2] = 4'h0;
            opb_select[3] = 4'h0;   
            opb_select[4] = 4'h0;

            alu_func[0] = ALU_MUL;
            alu_func[1] = ALU_MULH;
            alu_func[2] = ALU_MUL;
            alu_func[3] = ALU_MUL;
            alu_func[4] = ALU_MUL;

            rs1_value[0] = 32'd7;
            rs1_value[1] = 32'h00080000;
            rs1_value[2] = 32'd5;
            rs1_value[3] = 32'd48;
            rs1_value[4] = 32'd100;

            rs2_value[0] = 32'd8;
            rs2_value[1] = 32'h00020000;
            rs2_value[2] = 32'd2;
            rs2_value[3] = 32'd67;
            rs2_value[4] = 32'd10;

            alu_start[0] = 1'b0;
            alu_start[1] = 1'b0;
            alu_start[2] = 1'b0;
            alu_start[3] = 1'b0;
            alu_start[4] = 1'b0;
            

            mult_start[0] = 1'b1;
            mult_start[1] = 1'b1;
            mult_start[2] = 1'b1;
            mult_start[3] = 1'b1;
            mult_start[4] = 1'b1;
            

            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);

            check_correct(ex_packet_out, ex_packet_out_correct);

        
        // TEST 3, 2 ALUs, 3 MULs
        reset = 1;

            @(negedge clock);
            @(negedge clock);


            reset = 0;


            ex_packet_out_correct[0].result = 32'd10; // 30 - 20 = 10
            ex_packet_out_correct[1].result = 32'd5; // 2 + 3 = 5
            ex_packet_out_correct[2].result = 32'd10; // 5 * (2) = 10
            ex_packet_out_correct[3].result = 32'd3216;  // 48 * 67 = 3216
            ex_packet_out_correct[4].result = 32'd1000; // 100 * 10 = 1000
 
            opa_select[0] = 2'h0;
            opa_select[1] = 2'h0;
            opa_select[2] = 2'h0;
            opa_select[3] = 2'h0;
            opa_select[4] = 2'h0;

            opb_select[0] = 4'h0;
            opb_select[1] = 4'h0;
            opb_select[2] = 4'h0;
            opb_select[3] = 4'h0;   
            opb_select[4] = 4'h0;

            alu_func[0] = ALU_SUB;
            alu_func[1] = ALU_ADD;
            alu_func[2] = ALU_MUL;
            alu_func[3] = ALU_MUL;
            alu_func[4] = ALU_MUL;

            rs1_value[0] = 32'd30;
            rs1_value[1] = 32'd2;
            rs1_value[2] = 32'd5;
            rs1_value[3] = 32'd48;
            rs1_value[4] = 32'd100;

            rs2_value[0] = 32'd20;
            rs2_value[1] = 32'd3;
            rs2_value[2] = 32'd2;
            rs2_value[3] = 32'd67;
            rs2_value[4] = 32'd10;

            alu_start[0] = 1'b1;
            alu_start[1] = 1'b1;
            alu_start[2] = 1'b0;
            alu_start[3] = 1'b0;
            alu_start[4] = 1'b0;
            

            mult_start[0] = 1'b0;
            mult_start[1] = 1'b0;
            mult_start[2] = 1'b1;
            mult_start[3] = 1'b1;
            mult_start[4] = 1'b1;
            

            @(negedge clock);
            @(negedge clock);
            @(negedge clock);
            @(negedge clock);

            check_correct(ex_packet_out, ex_packet_out_correct);

            $display("@@@ PASSED");
            print_out_FUs(ex_packet_out);
            $finish;
        end



    


endmodule
