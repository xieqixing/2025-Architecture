`ifndef __PREBRANCH_SV
`define __PREBRANCH_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module prebranch
    import common::*; 
    import pipes::*; (
        input logic clk, reset,
        input word_t imm, srca,
        input control_t ctl,
        input fetch_data_t pc_instr,
        input u2 false_branch,
        output branch_data_t dataPB,
        output word_t pc_branch,
        output u1 branch
    );

    u2 state;

    always_ff @(negedge clk) begin 
        if(reset) begin
            state <= 2'b00;
        end

        case(state)
            2'b00: begin
                if(false_branch == 2'b11)begin
                    state <= 2'b00;
                end else if(false_branch == 2'b00) begin
                    state <= 2'b01;
                end else begin
                    state <= 2'b00;
                end
            end

            2'b01: begin
                if(false_branch == 2'b11)begin
                    state <= 2'b00;
                end else if(false_branch == 2'b00) begin
                    state <= 2'b11;
                end else begin
                    state <= 2'b01;
                end
            end

            2'b10: begin
                if(false_branch == 2'b11)begin
                    state <= 2'b11;
                end else if(false_branch == 2'b00) begin
                    state <= 2'b00;
                end else begin
                    state <= 2'b10;
                end
            end

            2'b11: begin
                if(false_branch == 2'b11)begin
                    state <= 2'b11;
                end else if(false_branch == 2'b00) begin
                    state <= 2'b10;
                end else begin
                    state <= 2'b11;
                end
            end

            default: begin
                state <= 2'b00;
            end
        endcase
    end

    always_comb begin
        case(state)
            2'b00: begin
                branch = 0;
            end
            2'b01: begin
                branch = 0;
            end
            2'b10: begin
                branch = 1;
            end
            2'b11: begin
                branch = 1;
            end
            default: begin
                branch = 0;
            end
        endcase
    end

    always_comb begin
        if(ctl.op == B)begin
            pc_branch = pc_instr.pc + {{52{pc_instr.raw_instr[31]}}, pc_instr.raw_instr[7], pc_instr.raw_instr[30:25], pc_instr.raw_instr[11:8], 1'b0};
        end else if(ctl.op == J)begin
            if(ctl.alusrc)begin
                pc_branch = (imm + srca) & ~1;
            end else begin
                pc_branch = pc_instr.pc + {{44{pc_instr.raw_instr[31]}}, pc_instr.raw_instr[19:12], pc_instr.raw_instr[20], pc_instr.raw_instr[30:21], 1'b0};
            end
        end else begin
            pc_branch = 0;
        end
    end

    always_comb begin
        dataPB.pc_branch = pc_branch;
        dataPB.branch = branch && ctl.branchorjump;
    end
    

endmodule

`endif