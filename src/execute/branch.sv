`ifndef __BRANCH_SV
`define __BRANCH_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`else

`endif

module branch 
    import common::*;
    import pipes::*;(

        input decode_data_t dataD,
        input pre_branch_data_t pre_branch,
        input CCR_t ccr,
        input word_t aluout,
        output branch_data_t dataB,
        output u2 false_branch
    );

    u1 branch;

    always_comb begin
        if(dataD.ctl.op == B)begin
            if(dataD.pc_instr.raw_instr[14:12] == 3'b000 && ccr.z) begin
                branch = 1;
            end else if(dataD.pc_instr.raw_instr[14:12] == 3'b001 && ~ccr.z) begin
                branch = 1;
            end else if(dataD.pc_instr.raw_instr[14:12] == 3'b100 && (ccr.n ^ ccr.v) && ~ccr.z) begin
                branch = 1;
            end else if(dataD.pc_instr.raw_instr[14:12] == 3'b101 && ((~(ccr.n ^ ccr.v)) | ccr.z)) begin
                branch = 1;
            end else if(dataD.pc_instr.raw_instr[14:12] == 3'b110 && ~(ccr.c | ccr.z)) begin
                branch = 1;
            end else if(dataD.pc_instr.raw_instr[14:12] == 3'b111 && (ccr.c || ccr.z)) begin
                branch = 1;
            end else begin
                branch = 0;
            end
        end else if(dataD.ctl.op == J)begin
            branch = 1;
        end else begin
            branch = 0;
        end
    end

    always_comb begin
        if(dataD.ctl.branchorjump) begin
            if(branch == pre_branch.branch)begin
                dataB.branch = 0;
                false_branch = 2'b11;
            end else begin
                dataB.branch = 1;
                false_branch = 2'b00;

                if(pre_branch.branch) dataB.pc_branch = pre_branch.pcplus4;
                else dataB.pc_branch = pre_branch.pc_branch;
            end
        end else begin
            false_branch = 2'b10;
            dataB.branch = 0;
        end
    end

endmodule

`endif 